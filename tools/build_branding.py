#!/usr/bin/env python3
"""Convert the established DiHalt opening to native MSX1 SCREEN2 data."""
from pathlib import Path
import hashlib
import itertools
import json
import struct
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/branding'
OUT=ROOT/'build/branding'
PALETTE=[(0,0,0),(0,0,0),(62,184,73),(116,208,125),(84,85,237),
         (125,118,252),(212,82,77),(66,235,245),(252,85,84),(255,121,120),
         (212,193,84),(230,206,128),(33,176,59),(201,91,186),(204,204,204),(255,255,255)]

def rle(data):
    result=bytearray()
    for value,run in itertools.groupby(data):
        count=sum(1 for _ in run)
        while count:
            n=min(255,count);result.extend((n,value));count-=n
    return bytes(result)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    image=Image.open(ASSETS/'dihalt-logo-source.png').convert('RGB').crop((0,10,256,202))
    pixels=image.load();patterns=bytearray();colors=bytearray()
    preview=Image.new('RGB',(256,192));output=preview.load()
    for band in range(3):
        for tile_y in range(8):
            for tile_x in range(32):
                for row in range(8):
                    y=band*64+tile_y*8+row;x=tile_x*8
                    scan=[pixels[x+i,y] for i in range(8)]
                    distances=[[sum((v[j]-p[j])**2 for j in range(3)) for p in PALETTE] for v in scan]
                    fg,bg=min(itertools.combinations(range(1,16),2),
                              key=lambda pair:sum(min(d[pair[0]],d[pair[1]]) for d in distances))
                    bits=0
                    for i,d in enumerate(distances):
                        bit=d[fg]<d[bg];bits=(bits<<1)|bit
                        output[x+i,y]=PALETTE[fg if bit else bg]
                    patterns.append(bits);colors.append(fg*16+bg)
    assert len(patterns)==len(colors)==6144
    (OUT/'patterns.bin').write_bytes(patterns)
    (OUT/'colors.bin').write_bytes(colors)
    pcm=(ASSETS/'dihalt.pcm').read_bytes();music=bytearray((ASSETS/'dihalt.mus').read_bytes())
    assert music[:3]==bytes(3)
    # Retain all notes/timing, with -3 dB on both PCM outputs to avoid two
    # saturated mixer samples present in the source fanfare at full level.
    pos=3
    while music[pos]!=255:
        count=music[pos];pos+=1
        if count==254:pos+=1;continue
        for _ in range(count):
            if music[pos:pos+2]==bytes([0x7e,0xf9]):music[pos+2]=0x09
            pos+=3
    (OUT/'music.bin').write_bytes(music[3:])
    a,b=rle(patterns),rle(colors)
    payload=struct.pack('<H',len(pcm))+a+b+pcm+music[3:]
    assert len(payload)<=3*16384, f'Branding needs {len(payload)} bytes, limit 49152'
    (OUT/'BRAND.DAT').write_bytes(payload.ljust(3*16384,b'\0'))
    preview.save(OUT/'dihalt-msx1.png')
    report=dict(format='QUIJOTE-BRANDING-1',source_logo='assets/branding/dihalt-logo-source.png',
                source_opl4='assets/branding/dihalt.mus',
                frames=500,duration_seconds=10,patterns_rle_bytes=len(a),colors_rle_bytes=len(b),
                pcm_mixer_attenuation_db=3,
                pcm_bytes=len(pcm),stream_bytes=len(music)-3,used_bytes=len(payload),file_bytes=49152,
                sha256=hashlib.sha256((OUT/'BRAND.DAT').read_bytes()).hexdigest(),
                inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ASSETS.iterdir()
                        if p.name in ['dihalt-logo-source.png','dihalt.pcm','dihalt.mus','dihalt-opl4.vgm']})
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
