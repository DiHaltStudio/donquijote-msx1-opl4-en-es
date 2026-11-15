"""Check the source-only tree and prepared speech metadata without game inputs."""
from pathlib import Path
import ast,gzip,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
for p in (ROOT/'tools').glob('*.py'):ast.parse(p.read_text(),filename=str(p))
for language in ['es','en']:
    folder=ROOT/'assets/speech'/language
    catalog=json.loads((folder/'catalog.json').read_text());pcm=gzip.decompress((folder/'units.pcm.gz').read_bytes())
    for u in catalog['units']:
        start=u['offset'];core=pcm[start+8:start+8+u['samples']]
        assert hashlib.sha256(core).hexdigest()==u['sha256']
        assert pcm[start:start+8]==bytes(8) and pcm[start+8+u['samples']:start+u['bytes']]==bytes(8)
    for m in catalog['messages']:
        score=bytes.fromhex(m['score_hex']);assert len(score)<256 and len(score)%6==0
for name in ['manual-es.pdf','manual-en.pdf']:
    assert (ROOT/'docs/manual'/name).read_bytes().startswith(b'%PDF-')
for p in ROOT.rglob('*'):
    if not p.is_file() or any(part in {'.git','build','release','third_party','__pycache__'} or part.startswith('.venv') for part in p.relative_to(ROOT).parts):continue
    assert p.suffix.lower() not in {'.tsx','.cas','.rom','.omr','.dsk','.bin','.com','.sys'},p
print('Source tree and prepared speech assets: OK')
