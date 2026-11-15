import argparse,hashlib,json,shutil,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--version',default='1.0');a=p.parse_args()
if not a.version or any(c not in '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-' for c in a.version):p.error('Invalid version')
out=ROOT/'release';folder=out/f'donquijote-msx1-opl4-en-es-{a.version}';folder.mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/'build/manifest.json').read_text());sd=folder/'SD';sd.mkdir(exist_ok=True)
assert not ({f.name for f in sd.iterdir()}-manifest['files'].keys()),'Unexpected package file'
for name,record in manifest['files'].items():
    src=ROOT/'build/SD'/name;assert hashlib.sha256(src.read_bytes()).hexdigest()==record['sha256'];shutil.copyfile(src,sd/name)
docs=folder/'DOCS';docs.mkdir(exist_ok=True)
for lang in ['es','en']:shutil.copyfile(ROOT/f'docs/manual/manual-{lang}.pdf',docs/f'MANUAL-{lang.upper()}.pdf')
for name in ['DESIGN.md','BUILDING.md']:shutil.copyfile(ROOT/'docs'/name,docs/name)
shutil.copyfile(ROOT/'VOICE-NOTICE.txt',folder/'VOICE-NOTICE.txt')
(folder/'README.txt').write_text('Don Quijote / Don Quixote — MSX-DOS + OPL4\n\nCopy ALL files from SD/ into ONE folder on your MSX drive.\nNextor/DOS2: enter that folder and run QUIJOTE (Spanish) or QUIXOTE (English).\nDOS1: put the same files in the drive root.\nPress ENTER at the password prompt to start part one.\nEnter the classic password to begin part two.\nRequires MSX1 or later, 512 KiB mapper RAM, OPL4 with 2 MiB wave RAM,\nand MegaFlashROM SCC+ SD or an equivalent interface compatible with this loader.\nThe DOCS directory contains the player manuals for reading on a PC.\nMSX-DOS/Nextor system files are supplied separately by their owners.\n\nOriginal game: Dinamic, 1987. Unofficial adaptation: DiHalt Studio, 2026.\n')
(folder/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=out/(folder.name+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for f in sorted(folder.rglob('*')):
        if f.is_file():
            info=zipfile.ZipInfo(str(f.relative_to(out)),date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16;z.writestr(info,f.read_bytes())
(out/'SHA256SUMS').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
print(archive)
