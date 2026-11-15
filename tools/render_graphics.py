#!/usr/bin/env python3
"""Generate picture-only SCREEN 2 dumps by executing original drawing streams.

Only the isolated asset v_renderer uses CPU/RAM injection. A separate input-only
walkthrough can validate these dumps against naturally reached game scenes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from basic import lines


def source_plans(side):
    stem='08-QUIJ2' if side=='A' else '07-QUIJ2'
    data=(ROOT/f'build/extracted/{side}/{stem}.bin').read_bytes()
    table={}
    for line in lines(data):
        if 7100 <= line['line'] < 7200:
            body=line['text'].split('DATA',1)[1]
            values=[]
            for token in body.split(','):
                token=token.strip().upper()
                values.append(int(token[2:],16) if token.startswith('&H') else int(token))
            assert values[-1]==255,(side,line)
            table[line['line']]=tuple(values[:-1])
    assert table
    # BASIC RESTORE n selects the first DATA line >= n. Include gaps, because
    # they deliberately share the following blank/real composition.
    rooms={}
    for room in range(1,max(table)-7100+1):
        line=min(n for n in table if n>=7100+room)
        rooms[room]=table[line]
    return data,table,rooms


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--openmsx',default='openmsx')
    p.add_argument('--machine',default='Philips_VG_8020')
    p.add_argument('--out',type=Path,default=ROOT/'build/graphics')
    args=p.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    all_scenes=[];room_map={};evidence={}
    for side in ('A','B'):
        source,table,rooms=source_plans(side)
        unique=list(dict.fromkeys(rooms.values()))
        folder=out/side;folder.mkdir(exist_ok=True)
        plans=[(f'{side.lower()}{i:03}',values) for i,values in enumerate(unique)]
        text=[f'set v_renderer {0xd956 if side=="A" else 0xd800}', 'set plans {']
        text += ['  {'+name+' {'+' '.join(map(str,values))+'}}' for name,values in plans]
        text += ['}']
        (folder/'plans.tcl').write_text('\n'.join(text)+'\n')
        done=folder/'finished.txt'
        if done.exists():done.unlink()
        env=dict(os.environ,QUIJOTE_VRAM_OUT=str(folder),QUIJOTE_VRAM_SIDE=side,
                 SDL_AUDIODRIVER='dummy',SDL_VIDEODRIVER=os.environ.get('SDL_VIDEODRIVER','x11'))
        command=[args.openmsx,'-machine',args.machine]
        command+=['-cassetteplayer',str(ROOT/'build/extracted'/side/'tape.cas')]
        command+=['-script',str(ROOT/'tools/render_graphics.tcl')]
        with (folder/'emulator.log').open('w') as log:
            subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
        assert done.read_text().startswith('PASS'),done.read_text()
        names={values:name for name,values in plans}
        room_map[side]={str(room):names[values] for room,values in rooms.items()}
        for name,streams in plans:
            raw=(folder/(name+'.bin')).read_bytes();assert len(raw)==8192
            all_scenes.append(dict(name=name,part=side,streams=list(streams),sha256=hashlib.sha256(raw).hexdigest(),path=str((folder/(name+'.bin')).relative_to(ROOT))))
        authority=json.loads((ROOT/f'build/extracted/{side}/manifest.json').read_text())
        evidence[side]=dict(basic_sha256=hashlib.sha256(source).hexdigest(),original_tsx_sha256=authority['sha256'],
                            renderer_load_images={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/f'build/extracted/{side}').glob('*.bin')},
                            data_lines={str(k):list(v) for k,v in table.items()},
                            generation_log=str((folder/'generation.tsv').relative_to(ROOT)))
    # Only picture patterns and picture colors. Names and all text remain in VRAM.
    blob=bytearray();seen={};scenes=[]
    for scene in all_scenes:
        data=(ROOT/scene['path']).read_bytes()
        if data not in seen:seen[data]=len(blob);blob.extend(data)
        scenes.append(dict(scene,offset=seen[data],bytes=len(data)))
    locations={s['name']:s['offset'] for s in scenes}
    room_offsets={side:{room:locations[name] for room,name in mapping.items()} for side,mapping in room_map.items()}
    (out/'VRAM.DAT').write_bytes(blob)
    # Two 256-entry U32 tables; FFFFFFFF denotes an undefined room. The caller
    # keeps the original darkness guard before consulting the room table.
    import struct
    index=bytearray()
    for side in ('A','B'):
        for room in range(256):index.extend(struct.pack('<I',room_offsets[side].get(str(room),0xffffffff)))
    (out/'VRAM.IDX').write_bytes(index)
    report=dict(format='QUIJOTE-PICTURE-VRAM-1',machine=args.machine,segments=[dict(vram_address=0,bytes=4096,file_offset=0),dict(vram_address=0x2000,bytes=4096,file_offset=4096)],
                scene_bytes=8192,unique_images=len(seen),packed_bytes=len(blob),packed_sha256=hashlib.sha256(blob).hexdigest(),
                compositions=len(scenes),scenes=scenes,room_offsets=room_offsets,sources=evidence,
                generation_method='Isolated original renderer, controlled PC/RAM trampoline, not input-only gameplay proof',outside_picture_unchanged=True)
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['unique_images','compositions','packed_bytes','packed_sha256']},indent=2))


if __name__=='__main__':main()
