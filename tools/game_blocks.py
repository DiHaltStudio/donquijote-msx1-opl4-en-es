import json
from basic import lines

def build_game(extracted,out,disk):
    data=bytearray();tables=[];patches=[]
    for side in ('A','B'):
        folder=extracted/side
        manifest=json.loads((folder/'manifest.json').read_text())
        tables.append(f'part_{side.lower()}:')
        for rec in manifest['records']:
            if rec.get('name') not in ('MENU','SLOT','SCREEN','BLOQUE','QUIJ1','QUIJ2') or rec.get('bytes',0)<300 and rec['name']!='SLOT':continue
            block=bytearray((folder/(rec['stem']+'.bin')).read_bytes())
            def patch(offset,old,new,reason):
                assert len(old)==len(new) and block[offset:offset+len(old)]==old,(side,rec['stem'],offset)
                block[offset:offset+len(old)]=new
                patches.append(dict(part=side,file=rec['stem'],offset=offset,before=old.hex(),after=new.hex(),reason=reason))
            if rec['name']=='MENU':patch(0xdfcd-rec['load'],bytes.fromhex('210000'),bytes.fromhex('c318e0'),'Preserve clear-picture behavior and invalidate VRAM cache')
            if side=='A' and rec['name']=='MENU':patch(0xdfb5-rec['load'],bytes.fromhex('cd67df'),bytes.fromhex('c300e2'),'Natural part A ending joins part B')
            if side=='B' and rec['stem']=='07-QUIJ2':
                line=next(l for l in lines(block) if l['line']==31)
                old=bytes.fromhex('890e401f')
                for i in range(len(line['body'])-3):
                    if line['body'][i:i+4]==old:patch(line['address']-0x8000+4+i,old,bytes.fromhex('890e2000'),'Skip password in joined game')
            if (side,rec['stem']) in (('A','06-QUIJ1'),('B','05-QUIJ1')):
                base=0x2a49 if side=='A' else 0x258a
                for offset,old,new,reason in [(0x457,'f5cda3','c315e0','Draw complete room picture before text and speech'),(0xa6,'af321a','c309e0','Speech table strings'),(0x4d0,'cd2d70','cd0ce0','Speech BASIC strings'),(0x13b,'cd9f00','cd0fe0','Accept lowercase input')]:patch(base+offset,bytes.fromhex(old),bytes.fromhex(new),reason)
            if rec['name']=='QUIJ2':
                line=next(l for l in lines(block) if l['line']==7000)
                body=line['body'];at=body.index(bytes.fromhex('0ccddf29'))
                patch(line['address']-0x8000+4+at+1,bytes.fromhex('cddf'),bytes.fromhex('12e0'),'Read full picture from SD, preserve darkness branch')
                tail=at+4
                assert body[tail]==58
                replacement=bytes.fromhex('3a8e3a8f')+b' '*(len(body)-tail-4)
                patch(line['address']-0x8000+4+tail,body[tail:],replacement,'Return after loading image, keep linked-line lengths')
            offset=len(data);entry=('setup_game_slots' if rec['name']=='MENU' else 'return_only') if rec['name'] in ('MENU','SLOT') else str(rec['entry'])
            tables.append(f'    db {8+offset//16384}\n    dw {0x4000+offset%16384},{len(block)},{rec["load"]},{entry}')
            data.extend(block)
    assert len(data)<=7*16384
    (disk/'GAME.DAT').write_bytes(data.ljust(7*16384,b'\0'))
    (out/'files.inc').write_text('\n'.join(tables)+'\n')
    (out/'patches.json').write_text(json.dumps(patches,indent=2)+'\n')
