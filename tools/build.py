#!/usr/bin/env python3
"""Build both DOS executables and the shared SD directory from local inputs."""
import argparse,gzip,hashlib,json,os,shutil,struct,subprocess,sys
from pathlib import Path
from extract_tsx import extract
from localize import localize
from game_blocks import build_game
from native_game import assets as native_assets,transform_game,native_config
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def originals(folder):
    specs=json.loads((ROOT/'assets/originals.json').read_text())
    for side,item in specs.items():
        candidates=[p for p in folder.glob('*.tsx') if sha(p.read_bytes())==item['sha256']]
        if len(candidates)!=1:raise SystemExit(f'Missing original Side {side} in {folder}. See docs/BUILDING.md; expected SHA256 {item["sha256"]}')
        extract(candidates[0],ROOT/'build/extracted'/side)
def graphics(folder):
    expected=json.loads((ROOT/'assets/graphics.json').read_text())
    result={}
    for name,digest in expected.items():
        p=folder/name
        if not p.is_file():raise SystemExit(f'Missing {p}. Run make import-graphics RELEASE_DIR=/path/to/SD, or make graphics. See docs/BUILDING.md.')
        data=p.read_bytes()
        if name=='VRAM.IDX':
            if len(data) not in (2048,16384):raise SystemExit(f'Invalid {p} length')
            if any(data[2048:]):raise SystemExit(f'Invalid {p} padding')
            data=data[:2048]
        if sha(data)!=digest:raise SystemExit(f'Unexpected original drawing data: {p}')
        result[name]=data.ljust(16384,b'\0') if name=='VRAM.IDX' else data
    return result
def voice(language,out,disk):
    assets=ROOT/'assets/speech'/language
    c=json.loads((assets/'catalog.json').read_text());units=c['units']
    pcm=gzip.decompress((assets/'units.pcm.gz').read_bytes())
    assert all(sha(pcm[u['offset']+8:u['offset']+8+u['samples']])==u['sha256'] for u in units)
    for n,start in enumerate(range(0,len(pcm),1048576)):
        b=pcm[start:start+1048576]
        (disk/f'VOICE{n}.PCM').write_bytes(b.ljust((len(b)+16383)//16384*16384,b'\0'))
    scores=bytearray();messages={};locations={}
    for m in c['messages']:
        key=m['text_hash'],m['text_length']
        if key in messages:continue
        data=bytes.fromhex(m['score_hex']);assert len(data)<256
        if data not in locations:
            off=len(scores);locations[data]=(17+off//16384,0x4000+off%16384);scores.extend(data)
        messages[key]=locations[data]
    index=bytearray()
    for (crc,n),(bank,addr) in sorted(messages.items()):index.extend(struct.pack('<HHBH',crc,n,bank,addr))
    unit_address=0x4000+len(index)
    for u in units:index.extend(struct.pack('<IHH',u['offset'],u['samples'],0))
    assert len(index)<=16384 and len(scores)<=32768
    (disk/'INDEX.DAT').write_bytes(index.ljust(16384,b'\0'))
    (disk/'SCORES.DAT').write_bytes(scores.ljust(32768,b'\0'))
    (out/'voice-config.inc').write_text(f'VOICE_CATALOG_BANK equ 16\nVOICE_MESSAGES equ 04000h\nVOICE_MESSAGE_COUNT equ {len(messages)}\nVOICE_UNITS equ {unit_address}\nVOICE_UNIT_COUNT equ {len(units)}\n')
def build(language,pictures,model=1):
    out=ROOT/'build'/(language if model==1 else 'msx2-'+language);disk=out/'disk'
    if disk.exists():shutil.rmtree(disk)
    disk.mkdir(parents=True)
    extracted=ROOT/'build/extracted'
    if language=='en':
        localize(extracted,out/'extracted');extracted=out/'extracted'
    voice(language,out,disk);build_game(extracted,out,disk)
    for name,data in pictures.items():(disk/name).write_bytes(data)
    shutil.copyfile(ROOT/'build/branding/BRAND.DAT',disk/'BRAND.DAT')
    if model==2:
        blob,idx,offsets=native_assets(ROOT/'build/extracted')
        (disk/'VRAM.DAT').write_bytes(blob)
        (disk/'VRAM.IDX').write_bytes(idx.ljust(16384,b'\0'))
        entries=transform_game(out)
    stage=out/'src';stage.mkdir(exist_ok=True)
    for path in (ROOT/'src'/('msx2' if model==2 else '')).glob('*.asm'):
        content=path.read_text().replace('../build/',str(out)+'/').replace('../../common/',str(ROOT/'common')+'/')
        if model==2:content=content.replace('../common/',str(ROOT/'common/msx2')+'/')
        if language=='en':
            content=content.replace('ENGLISH equ 0','ENGLISH equ 1')
            if path.name=='loader.asm':
                for old,new in [('GAME    DAT','ENGAME  DAT'),('INDEX   DAT','ENINDEX DAT'),('SCORES  DAT','ENSCORE DAT'),('VOICE0  PCM','ENVOX0  PCM'),('DON QUIJOTE','DON QUIXOTE'),('Cargando datos...','Loading data...')]:content=content.replace(old,new)
        if model==2 and path.name=='loader.asm':
            content=content.replace('ENGAME  DAT' if language=='en' else 'GAME    DAT','Q2EN    DAT' if language=='en' else 'Q2ES    DAT').replace('VRAM    DAT','SC5     DAT').replace('VRAM    IDX','SC5     IDX')
        (stage/path.name).write_text(content)
    if model==2:native_config(stage,out,entries,offsets)
    for name in ([] if model==2 else ['trampoline','resident','loader']):
        subprocess.run([os.environ.get('SJASM','sjasm'),'-s',str(stage/f'{name}.asm'),str(out/f'{name}.bin')],check=True)
    (disk/'QUIJOTE.COM').write_bytes((out/'loader.bin').read_bytes())
    if language=='en':
        for p in list(disk.iterdir()):
            new={'QUIJOTE.COM':'QUIXOTE.COM','GAME.DAT':'ENGAME.DAT','INDEX.DAT':'ENINDEX.DAT','SCORES.DAT':'ENSCORE.DAT'}.get(p.name,p.name.replace('VOICE','ENVOX'))
            if new!=p.name:p.replace(disk/new)
    if model==2:
        for old,new in [('ENGAME.DAT' if language=='en' else 'GAME.DAT','Q2EN.DAT' if language=='en' else 'Q2ES.DAT'),('VRAM.DAT','SC5.DAT'),('VRAM.IDX','SC5.IDX')]:
            (disk/old).replace(disk/new)
    return disk

def main():
    p=argparse.ArgumentParser();p.add_argument('--originals',type=Path,default=ROOT/'third_party/original');p.add_argument('--graphics',type=Path,default=ROOT/'third_party/graphics');p.add_argument('--extract-only',action='store_true');a=p.parse_args()
    originals(a.originals)
    if a.extract_only:return
    images=graphics(a.graphics)
    subprocess.run([sys.executable,str(ROOT/'tools/build_branding.py')],check=True)
    subprocess.run([sys.executable,str(ROOT/'tools/build_dos_menu.py')],check=True)
    shared=ROOT/'build/SD'
    if shared.exists():shutil.rmtree(shared)
    shared.mkdir(exist_ok=True);files={}
    def add(name,path):
        data=path.read_bytes()
        if name in files:assert files[name]['sha256']==sha(data),name
        files[name]=dict(bytes=len(data),sha256=sha(data));(shared/name).write_bytes(data)
    for model in [1,2]:
        for language in ['es','en']:
            for item in build(language,images,model).iterdir():
                name=f'Q{model}{language.upper()}.COM' if item.name in ['QUIJOTE.COM','QUIXOTE.COM'] else item.name
                add(name,item)
    for name in ['QMENU.COM','QUIJOTE.BAT','QUIXOTE.BAT']:add(name,ROOT/'build/launcher'/name)
    assert len(files)==31
    (ROOT/'build/manifest.json').write_text(json.dumps(dict(version='2.0',files=files,sd_file_bytes=sum(x['bytes'] for x in files.values())),indent=2)+'\n')
    print(f'Built both languages: {len(files)} files in build/SD')
if __name__=='__main__':main()
