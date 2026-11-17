"""SCREEN 5 loading-image patches and resident driver assembly."""
from pathlib import Path
import re,struct,subprocess,os,json
from PIL import Image
from basic import lines
ROOT=Path(__file__).resolve().parents[1]
def sym(path):return {k:int(v,16) for k,v in re.findall(r'^(\S+): equ ([0-9A-F]+)h',path.read_text(),re.M)}
def assemble(stage,name,out):subprocess.run([os.environ.get('SJASM','sjasm'),'-s',str(stage/f'{name}.asm'),str(out/f'{name}.bin')],check=True)
def transform_game(out):
 data=(out/'disk/GAME.DAT').read_bytes();text=(out/'files.inc').read_text();pat=re.compile(r'db (\d+)\s+dw (\d+),(\d+),(\d+),([^\n]+)')
 blocks=[];entries=[]
 for match in pat.finditer(text):
  bank,ptr,count,dest=map(int,match.group(1,2,3,4));entry=match[5].strip();off=(bank-8)*16384+ptr-0x4000;b=bytearray(data[off:off+count])
  # Full engine loading images have their runtime 7000 bootstrap inside.
  if dest in (0x8e20,0x8da9):
   at=0x2a49 if len(b)>12000 else 0x258a
   assert b[at:at+3]==bytes.fromhex('21208e')
   b[at+0xb:at+0xe]=bytes.fromhex('c300c0')
   b[at+0x2d:at+0x30]=bytes.fromhex('c303c0')
  if dest==0x8800 and b[:5]==bytes.fromhex('000a800100'):
   program=list(lines(b))
   for line in program:
    start=line['address']-0x8000+4;body=line['body']
    if line['line']==9:
     # Reserve C000..FFFF; no BASIC variable/stack may overwrite the driver.
     needle=bytes.fromhex('0c00d9') if b'\x0c\x00\xd9' in body else bytes.fromhex('0c50d7')
     pos=body.index(needle);b[start+pos:start+pos+3]=bytes.fromhex('0cffbf')
    if line['line']==10:
     assert body[:10]==bytes.fromhex('bd0f0f2c122c123ac513')
     b[start:start+10]=b' '*10  # native VDP setup replaces COLOR/SCREEN
   entries.append(int(entry))
  if dest==0x8800 and entry=='34816':entry=str(0xc006)
  blocks.append((b,dest,entry))
 # Same byte widths, descriptor addresses remain stable.
 result=bytearray();tables=[];i=0
 for line in text.splitlines():
  if line.startswith('part_'):tables.append(line)
  if line.strip().startswith('dw '):
   b,dest,entry=blocks[i];i+=1;offset=len(result)
   tables.extend([f'    db {8+offset//16384}',f'    dw {0x4000+offset%16384},{len(b)},{dest},{entry}']);result.extend(b)
 assert len(entries)==2 and len(result)<=7*16384
 (out/'disk/GAME.DAT').write_bytes(result.ljust(7*16384,b'\0'));(out/'files.inc').write_text('\n'.join(tables)+'\n')
 return entries

def assets(extracted):
    folder=ROOT/'assets/msx2'
    meta=json.loads((folder/'pictures.json').read_text())
    font=(extracted/'A/06-QUIJ1.bin').read_bytes()[0x2271:0x2271+480]
    assert len(font)==480
    pixels=bytearray(256*24)
    for c in range(60):
        for y in range(8):
            for x in range(8):pixels[((c//32)*8+y)*256+(c%32)*8+x]=15 if font[c*8+y]&(128>>x) else 0
    blob=bytearray(pixels[i]<<4|pixels[i+1] for i in range(0,len(pixels),2))
    def picture(name,height):
        im=Image.open(folder/(name+'.png'));assert im.mode=='P' and im.size==(256,height)
        indices=im.tobytes();assert max(indices)<16
        data=bytes(indices[i]<<4|indices[i+1] for i in range(0,len(indices),2))
        pal=bytes.fromhex(meta['palettes'][name]);assert len(pal)==32
        return data+pal
    offsets={}
    for name in ['COVER','DIHALT']:
        offsets[name]=len(blob);blob.extend(picture(name,192))
    room_base=len(blob)
    for name in sorted(n for n in meta['palettes'] if n.startswith('room-')):blob.extend(picture(name,128))
    idx=bytearray()
    for off in meta['room_offsets']:idx.extend(struct.pack('<I',off+room_base if off!=0xffffffff else off))
    assert len(idx)==2048
    return blob,idx,offsets

def native_config(stage,out,entries,offsets):
    api=['cart_slot','bios_slot','disk_read','set_page1','io_offset','io_count','io_mode','io_file','io_error','game_page1','draw_last_room']
    def api_file(symbols):
        (out/'native-api.inc').write_text('\n'.join(f'{k} equ {symbols.get(k,0)}' for k in api)+f'\nCOVER_OFFSET equ {offsets["COVER"]}\nLOGO_OFFSET equ {offsets["DIHALT"]}\n')
    api_file({});assemble(stage,'native',out);n=(out/'native.bin').stat().st_size
    (out/'native-config.inc').write_text(f'NATIVE_SIZE equ {n}\nBASIC_ENTRY_A equ {entries[0]}\nBASIC_ENTRY_B equ {entries[1]}\n')
    for name in ['trampoline','resident']:assemble(stage,name,out)
    api_file(sym(out/'resident.sym'));assemble(stage,'native',out);assert (out/'native.bin').stat().st_size==n
    index=bytearray((out/'disk/VRAM.IDX').read_bytes());index[2048:2048+n]=(out/'native.bin').read_bytes();(out/'disk/VRAM.IDX').write_bytes(index)
    assemble(stage,'loader',out)
