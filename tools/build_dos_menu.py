#!/usr/bin/env python3
"""Build the DOS1-compatible selector used by both language BAT launchers."""
from pathlib import Path
import os,subprocess
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'build/launcher';out.mkdir(parents=True,exist_ok=True)
subprocess.run([os.environ.get('SJASM','sjasm'),'-s',str(ROOT/'common/launcher/menu.asm'),str(out/'QMENU.COM')],check=True)
for name,language in [('QUIJOTE','ES'),('QUIXOTE','EN')]:
 (out/(name+'.BAT')).write_bytes(f'echo Don {"Quijote" if language=="ES" else "Quixote"} 2.0\r\nQMENU {language}\r\n'.encode('ascii'))
print(out)
