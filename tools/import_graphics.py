import argparse,shutil
from pathlib import Path
from build import graphics,ROOT
p=argparse.ArgumentParser();p.add_argument('source',type=Path);a=p.parse_args()
source=a.source/'SD' if (a.source/'SD').is_dir() else a.source
images=graphics(source)
target=ROOT/'third_party/graphics';target.mkdir(parents=True,exist_ok=True)
for name,data in images.items():(target/name).write_bytes(data[:2048] if name=='VRAM.IDX' else data)
print('Drawing inputs imported into third_party/graphics')
