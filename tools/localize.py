"""Repack language tables within original reserved regions; preserve engine addresses."""
from pathlib import Path
import json,re,struct,sys,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from basic import lines
VERBS={1:'N,NORTH',2:'S,SOUTH',3:'E,EAST,RIGHT',4:'W,WEST',5:'UP,U,ASCEND',6:'DOWN,D,DESCEND',7:'TAKE,GET',8:'DROP,LEAVE',9:'LOOK,L',10:'INVENTORY,I',11:'QUIT',12:'MODE',14:'SAVE',15:'LOAD',16:'EXAMINE,INSPECT,X',17:'HELP',18:'ENTER',19:'READ',20:'OPEN',21:'PUT,WEAR',22:'BREAK',23:'FIGHT,ATTACK',24:'MAKE',25:'EAT',26:'DRINK',27:'REST,SLEEP,WAIT',28:'WATCH,VIGIL',29:'LIGHT',30:'CROSS',31:'PIG,IDIOT,SHIT,WHORE',32:'PULL,CUT',33:'EXTINGUISH',35:'CLIMB',36:'FIX,REPAIR',37:'GIVE',41:'HIT,STRIKE,MOVE',42:'JUMP',43:'KNOCK',50:'SHOO',60:'TALK',61:'SNEEZE,WHISTLE,COUGH',63:'SING',64:'MIX,STIR',65:'DIG',80:'GENTLEMAN'}
NA={1:'CRUST,BREAD',2:'APPLE',3:'HEN,CHICKEN',4:'MILKCAP',5:'DEATHCAP,MUSHROOMS',6:'BOOK,BOOKS',7:'ARMOUR,SUIT',8:'KEY',9:'STEP,STEPS,PLANK',10:'ARMS,SWORD',11:'BOTTLE',12:'CANDLE',13:'TOOL,HAMMER,MALLET',14:'RAKE',15:'STONE',21:'DUST',22:'LIBRARY',23:'DOOR,GATE,BELL',24:'STAIRS',25:'WOOD,STREETS,KITCHEN,DININGROOM,BEDROOM,ROOM,MANCHA,PINES,HALL',26:'BED',28:'WOODWORM',29:'TABLE',30:'WALL',31:'FOOD',32:'CUPBOARD',33:'CHIMNEY',34:'CHEST,BOX',35:'LIGHT',36:'GROUND,FLOOR',37:'CEILING',38:'WINDOW',39:'SHEETS',40:'SHIELD',41:'NOTICE,SIGN',42:'STONES',43:'BARRIER',44:'STREET',45:'TREE,TREES',46:'VEGETATION',47:'THISTLES,PLANTS',48:'RAVINE,HOLE',49:'CANDLESTICK',50:'WINESKINS',51:'WINE',52:'SHEEP',53:'LOCK',60:'SHELF',61:'CURTAINS',62:'RAILING',63:'ARCH',64:'HILLS',65:'PATH',70:'FLOWERS',71:'HOUSE,INN',73:'TORCH',74:'AXE',80:'MOON',81:'WELL',100:'SHIRT'}
NB={1:'BASIN,HELMET',2:'KEY',3:'SALT',4:'ROSEMARY',5:'SCROLL,RECIPE',6:'WINE',7:'ARMS,SWORD',8:'SHOVEL',9:'OIL,BOTTLE',10:'CLEAR',11:'EMPTY',12:'BRANCH,TWIG',13:'CAULDRON',14:'LOAF,BREAD',15:'COD',16:'BLACKBERRIES',17:'ACORNS',18:'NAIL',30:'SHEEP',31:'MONKS',32:'CARRIAGE',33:'MAIDEN,PRINCESS',34:'WINDMILL',35:'SAILS',36:'DOOR',37:'WINDOW',38:'MIRROR',39:'GUARD',40:'SIGN',41:'BED',42:'SACKS',43:'GROUND,FLOOR',44:'BUSH,BRAMBLE',45:'SHIRT',46:'LION',47:'BALM,FIERABRAS,INGREDIENTS,POTION,SOUP',48:'CEILING',49:'HILLS,MOUNTAINS',50:'VEGETATION',51:'SKY',80:'INGENIOUS',81:'TREE,TREES,OAKS',84:'WALL',85:'SHELF',86:'FURNITURE',87:'WARDROBE',88:'CAREFULLY,CAREFUL'}

def vocab(data,p):
 rows=[];start=p
 while data[p]!=255:
  ident,count,size=data[p:p+3];rows.append(dict(id=ident,synonyms=data[p+3:p+3+size].decode('ascii').replace('\0','').rstrip(',').split(',')));p+=size+4
 return rows,p+1

def localize(source, out):
 c=json.loads((ROOT/'assets/english/translation.json').read_text())['messages'];t={m['id']:m['text'] for m in c};out.mkdir(parents=True,exist_ok=True);reports=[];dictionaries={}
 for side,stem,base,e,basic in [('A','06-QUIJ1',0x4000,0x2a49,'08-QUIJ2'),('B','05-QUIJ1',0x4a73,0x258a,'07-QUIJ2')]:
  dest=out/side;shutil.copytree(source/side,dest,dirs_exist_ok=True)
  b=bytearray((dest/(stem+'.bin')).read_bytes());original=bytes(b)
  def fit(start,end,payload,label):
   assert len(payload)<=end-start,(side,label,len(payload),end-start)
   b[start:end]=payload.ljust(end-start,b'\0');reports.append(dict(part=side,table=label,start=start,end=end,used=len(payload),reserved=end-start))
  p=0
  for kind in ('room','message'):
   start=p;payload=bytearray()
   while original[p]!=255:
    ident=original[p];n=struct.unpack_from('<H',original,p+1)[0];txt=t[f'{side.lower()}_{kind}_{ident:03}'].encode('ascii')
    if side=='B' and kind=='room' and p==0:
     # Original B bootstrap deliberately copies from source+119; keep that boundary.
     txt=txt.ljust(n,b' ')
    payload.extend(bytes([ident])+struct.pack('<H',len(txt))+txt+b'\0');p+=n+4
   p+=1;payload.append(255);fit(start,p,payload,kind)
  dictionaries[side]={}
  for kind,offset,mapping in [('verbs',0x2b4,VERBS),('nouns',0x2d1,NA if side=='A' else NB)]:
   start=struct.unpack_from('<H',original,e+offset)[0]-base;rows,end=vocab(original,start);payload=bytearray();dictionaries[side][kind]=[]
   for row in rows:
    english=mapping[row['id']];syms=english.split(',');txt=(english+',').encode();assert all(len(s)<16 for s in syms)
    payload.extend(bytes([row['id'],len(syms),len(txt)])+txt+b'\0');dictionaries[side][kind].append(dict(**row,english=syms))
   payload.append(255);fit(start,end,payload,kind)
  start=e+struct.unpack_from('<H',original,e+0x498)[0]-0x7000;p=start;payload=bytearray()
  while original[p]!=255:
   ident=original[p];end=original.index(0,p+1);payload.extend(bytes([ident])+t[f'{side.lower()}_object_{ident:03}'].encode()+b'\0');p=end+1
  payload.append(255);fit(start,p+1,payload,'objects');assert b[e+0x33c:e+0x33e]==bytes([0xfe,5])
  b[e+0x33d]=255 # Exact English aliases: FIGHT must never match LIGHT.
  (dest/(stem+'.bin')).write_bytes(b)
  raw=(dest/(basic+'.bin')).read_bytes();result=bytearray(raw[:1])
  for line in lines(raw):
   body=line['body'];matches=list(re.finditer(rb'"([^"\x00]*)"',body))
   for i,match in reversed(list(enumerate(matches))):
    ident=f'{side.lower()}_basic_{line["line"]:04}_{i}'
    if ident in t:
     old=match[1];new=t[ident].encode();prefix=len(old)-len(old.lstrip());suffix=len(old)-len(old.rstrip());new=b' '*prefix+new+b' '*suffix
     # Quotes inside translated literals would need BASIC escaping.
     assert b'"' not in new
     body=body[:match.start()+1]+new+body[match.end()-1:]
   nxt=0x8000+len(result)+5+len(body);result.extend(struct.pack('<HH',nxt,line['line'])+body+b'\0')
  result.extend(b'\0\0');assert len(result)<=len(raw),(side,'BASIC',len(result),len(raw))
  last=list(lines(raw))[-1];program_end=last['address']-0x8000+5+len(last['body'])+2
  assert len(result)<=program_end
  result=result.ljust(program_end,b'\0')+raw[program_end:];list(lines(result));(dest/(basic+'.bin')).write_bytes(result)
 (out/'vocabulary.json').write_text(json.dumps(dictionaries,indent=2)+'\n');(out/'localization-report.json').write_text(json.dumps(reports,indent=2)+'\n');print(reports)

