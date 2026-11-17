#!/usr/bin/env python3
"""Render the public DOS technical reference in Spanish and English."""
from pathlib import Path
import argparse,base64,hashlib,html,json,re
import markdown
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/technical'
COLORS=['#176e91','#df8e26','#34856d','#845b9e','#65798b']
class Drawing:
 def __init__(self,title,height=420):
  self.parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 {height}" role="img"><title>{html.escape(title)}</title><defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="#416075"/></marker></defs><rect width="1000" height="100%" fill="#f5f8fb"/><style>text{{font-family:DejaVu Sans,sans-serif;fill:#19354a}}.title{{font-size:21px;font-weight:bold}}.text{{font-size:16px}}</style>'];self.text(25,34,title,True,950)
 def text(self,x,y,value,bold=False,width=920):
  font=ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf',21 if bold else 16)
  fit=f' textLength="{width}" lengthAdjust="spacingAndGlyphs"' if font.getlength(str(value))>width else ''
  self.parts.append(f'<text class="{"title" if bold else "text"}" x="{x}" y="{y}"{fit}>{html.escape(str(value))}</text>')
 def box(self,x,y,w,h,title,lines=(),colour=0):
  self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="white" stroke="{COLORS[colour%5]}" stroke-width="2"/>')
  self.text(x+15,y+29,title,True,w-30)
  for i,line in enumerate(lines):self.text(x+15,y+57+i*25,line,width=w-30)
 def arrow(self,x,y,xx,yy):self.parts.append(f'<path d="M{x},{y} L{xx},{yy}" fill="none" stroke="#416075" stroke-width="2" marker-end="url(#arrow)"/>')
 def save(self,lang,name):
  folder=OUT/'figures'/lang;folder.mkdir(parents=True,exist_ok=True)
  (folder/(name+'.svg')).write_text(''.join(self.parts)+'</svg>')
def diagrams(lang):
 def t(es,en):return es if lang=='es' else en
 d=Drawing(t('01 · Dos idiomas, dos opciones gráficas','01 · Two languages, two graphics options'),390)
 d.box(30,70,425,90,'QUIJOTE.BAT → QMENU ES',[t('Texto, órdenes y voz en español','Spanish text, commands and speech')])
 d.box(545,70,425,90,'QUIXOTE.BAT → QMENU EN',[t('Texto, órdenes y voz en inglés','English text, commands and speech')],1)
 d.box(30,250,425,95,t('1 → MSX1 o posterior','1 → MSX1 or later'),['Q1ES.COM / Q1EN.COM',t('Dibujos originales','Original pictures')],2)
 d.box(545,250,425,95,t('2 → MSX2 o posterior','2 → MSX2 or later'),['Q2ES.COM / Q2EN.COM',t('Ilustraciones mejoradas','Improved illustrations')],3)
 for x,y in [(240,240),(760,760),(450,545),(550,455)]:d.arrow(x,160,y,250)
 d.save(lang,'01-programs')
 d=Drawing(t('02 · Tres memorias diferentes','02 · Three different memories'),300)
 d.box(25,80,290,160,t('Disco / SD','Disk / SD'),[t('Todos los archivos','All files'),t('Vocabulario completo','Complete vocabulary'),t('Persistencia sin alimentación','Persists without power')])
 d.box(355,80,290,160,t('RAM del Z80','Z80 RAM'),['512 KiB mapper',t('Juego, índices, pila y caché','Game, indexes, stack and cache'),t('64 KiB visibles por páginas','64 KiB visible through pages')],1)
 d.box(685,80,290,160,'OPL4 RAM',['2 MiB',t('Muestras y cabeceras','Samples and headers'),t('Lectura autónoma del chip','Read by the sound chip')],2)
 d.arrow(315,160,355,160);d.arrow(645,160,685,160);d.save(lang,'02-memory')
 d=Drawing(t('03 · Segmentos lógicos del mapper','03 · Logical mapper segments'),490)
 rows=[('4–7',t('Aventura','Adventure'),'64 KiB'),('8–14',t('Cargables de ambas partes','Loading images for both parts'),'112 KiB'),('15',t('Puente DOS y transferencia','DOS bridge and transfer'),'16 KiB'),('16',t('Claves e índice de voz','Speech keys and unit index'),'16 KiB'),('17–18',t('Partituras','Timing scores'),'32 KiB'),('19',t('Índice gráfico y controlador MSX2','Picture index and MSX2 driver'),'16 KiB'),('20–31',t('Caché de disco opcional','Optional disk cache'),'0–192 KiB')]
 for i,(a,b,c) in enumerate(rows):
  y=65+56*i;d.box(30,y,940,45,'',colour=i);d.text(48,y+29,a,True,110);d.text(185,y+29,b,width=590);d.text(800,y+29,c,width=150)
 d.save(lang,'03-mapper')
 d=Drawing(t('04 · Ir a DOS y regresar al juego','04 · Enter DOS and return to the game'),410)
 d.box(30,75,420,110,t('1 · Juego → puente','1 · Game → bridge'),[t('DI; guardar registros y pila','DI; save registers and stack'),t('Archivo, offset y longitud','File, offset and length')])
 d.box(550,75,420,110,t('2 · Contexto de DOS','2 · DOS context'),[t('Slots, segmentos y pila propios','Its own slots, segments and stack'),t('BDOS lee a la transferencia','BDOS reads into the transfer area')],1)
 d.box(550,265,420,110,t('3 · Preparar retorno','3 · Prepare return'),[t('Recuperar primero la pila','Recover the game stack first'),'ENASLT BASIC → RAM; mapper'],2)
 d.box(30,265,420,110,t('4 · Continuar el juego','4 · Continue the game'),[t('Registros y contexto restaurados','Registers and context restored'),t('Usar los bytes leídos','Use the bytes read')],3)
 d.arrow(450,130,550,130);d.arrow(760,185,760,265);d.arrow(550,320,450,320);d.save(lang,'04-io')
 d=Drawing(t('05 · Del texto a la reproducción','05 · From text to playback'),450)
 d.box(25,70,285,110,t('Cadena del juego','Game string'),[t('Normalizar texto','Normalize text'),t('CRC-CCITT + longitud','CRC-CCITT + length')])
 d.box(355,70,290,110,t('Clave → partitura','Key → timing score'),[t('Eventos de seis bytes','Six-byte events'),t('Delta, unidad y margen','Delta, unit and margin')],1)
 d.box(690,70,285,110,t('Preparar frase','Prepare phrase'),[t('Buscar todas las unidades','Locate every unit'),t('Cargar sólo las ausentes','Load only missing samples')],2)
 d.box(160,290,680,110,t('OPL4: caché de muestras y cabeceras locales','OPL4: sample cache and local headers'),[t('Una copia de cada unidad; cabeceras por evento','One copy of each unit; headers per event'),t('Disparos programados en dos canales alternos','Scheduled triggers on two alternating channels')],3)
 d.arrow(310,125,355,125);d.arrow(645,125,690,125);d.arrow(835,180,680,290);d.save(lang,'05-speech')
 d=Drawing(t('06 · Reparto de los 2 MiB de RAM OPL4','06 · Layout of the 2 MiB OPL4 RAM'),400)
 d.box(30,65,940,80,'200000h–2007FFh',[t('Reserva para cabeceras de reproducción','Playback header reservation')])
 d.box(30,160,940,100,'200800h–3FDFFFh',[t('Pool de muestras PCM: ocho ceros + núcleo + ocho ceros','PCM sample pool: eight zero bytes + core + eight zero bytes'),t('Reutilización por ID y generación','Reuse by ID and generation')],1)
 d.box(30,275,940,85,'3FE000h–3FFFFFh',[t('Directorio: dirección del núcleo (3 B) + generación (1 B)','Directory: core address (3 B) + generation (1 B)')],2)
 d.save(lang,'06-opl4')
 d=Drawing(t('07 · SCREEN 5: dos páginas y fuente oculta','07 · SCREEN 5: two pages and a hidden font'),440)
 for x,base,num in [(30,'0000h',0),(525,'8000h',1)]:
  d.box(x,70,445,265,t(f'Página {num} · {base}',f'Page {num} · {base}'),[t('Líneas 0–127: imagen 256×128','Lines 0–127: 256×128 picture'),t('Líneas 128–191: ocho filas de texto','Lines 128–191: eight text rows'),t('Líneas 192–211: margen negro','Lines 192–211: black margin'),'',t('HMMC → imagen; HMMM → texto','HMMC → image; HMMM → text'),t('HMMV → borrado','HMMV → clear')],num)
 d.box(155,355,690,65,'F000h–FBFFh',[t('Atlas de caracteres: 256×24, celdas de 8×8','Character atlas: 256×24, 8×8 cells')],3);d.save(lang,'07-video')
 d=Drawing(t('08 · Arranque y cambio de parte','08 · Startup and part transition'),490)
 d.box(30,65,270,115,t('Menú e informe','Menu and report'),[t('Idioma y MSX1/MSX2','Language and MSX1/MSX2'),t('ENTER confirma la memoria','ENTER confirms memory')])
 d.box(365,65,270,115,t('Presentación DiHalt','DiHalt presentation'),[t('Logo y fanfarria OPL4','Logo and OPL4 fanfare'),t('Después: contraseña','Then: password')],1)
 d.box(700,65,270,115,t('Elegir parte','Select part'),[t('Entrada vacía → A','Empty input → A'),t('Clave válida → B','Valid password → B')],2)
 d.box(70,295,390,135,t('Portada A → tecla nueva','Opening A → new key'),[t('Comienza la primera parte','Part one starts'),t('El final enlaza con B','Its ending leads to B'),t('Sin volver a pedir la contraseña','Without asking for the password')],3)
 d.box(560,295,390,135,t('Portada B → tecla nueva','Opening B → new key'),[t('Comienza la segunda parte','Part two starts'),t('Ambas portadas esperan sin límite','Both openings wait indefinitely'),t('El ENTER anterior se descarta','The preceding ENTER is discarded')],4)
 d.arrow(300,125,365,125);d.arrow(635,125,700,125);d.arrow(760,180,270,295);d.arrow(880,180,760,295);d.arrow(460,360,560,360);d.save(lang,'08-startup')
def table(head,rows):return '| '+' | '.join(head)+' |\n|'+'|'.join(['---']*len(head))+'|\n'+''.join('| '+' | '.join(map(str,row))+' |\n' for row in rows)
def number(n,lang):return f'{n:,}'.replace(',','.') if lang=='es' else f'{n:,}'
def render(lang,data,pdf):
 diagrams(lang)
 def t(es,en):return es if lang=='es' else en
 def purpose(name):
  if name in ['QUIJOTE.BAT','QUIXOTE.BAT']:return t('Menú de idioma','Language launcher')
  if name=='QMENU.COM':return t('Selector de versión','Version selector')
  if name.endswith('.COM'):return t('Programa de juego','Game program')
  if name.endswith('.PCM'):return t('PCM de voz compartido','Shared speech PCM')
  if name in ['INDEX.DAT','ENINDEX.DAT']:return t('Claves e índice de unidades','Keys and unit index')
  if name in ['SCORES.DAT','ENSCORE.DAT']:return t('Partituras','Timing scores')
  return {'BRAND.DAT':t('Presentación y fanfarria','Presentation and fanfare'),'VRAM.DAT':t('Imágenes MSX1','MSX1 pictures'),'VRAM.IDX':t('Índice gráfico MSX1','MSX1 picture index'),'SC5.DAT':t('Imágenes y fuente MSX2','MSX2 pictures and font'),'SC5.IDX':t('Índice y controlador MSX2','MSX2 index and driver')}.get(name,t('Datos de aventura','Adventure data'))
 files=table([t('Archivo','File'),t('Bytes','Bytes'),t('Función','Purpose')],[(f'`{name}`',number(r['bytes'],lang),purpose(name)) for name,r in sorted(data['files'].items())])
 voice=table([t('Idioma','Language'),t('Mensajes preparados','Prepared messages'),t('Claves únicas','Unique keys'),t('Unidades','Units'),t('PCM con márgenes','PCM with margins')],[(t('Español','Spanish') if k=='es' else t('Inglés','English'),v['prepared_messages'],v['lookup_keys'],number(v['units'],lang),number(v['pcm_bytes'],lang)+' B') for k,v in data['languages'].items()])
 score=table([t('Seis bytes','Six bytes'),'Δ ticks',t('Unidad','Unit'),t('Margen','Margin'),t('Acumulado','Accumulated'),t('Segundos','Seconds')],[(f'`{e["hex"]}`',e['delta'],e['unit'],e['pad'],e['tick'],f'{e["seconds"]:.6f}'.replace('.',',') if lang=='es' else f'{e["seconds"]:.6f}') for e in data['languages']['es']['example']])
 text=(OUT/f'TECNICA-{lang}.src.md').read_text()
 replacements={'@@FILES@@':files,'@@VOICE@@':voice,'@@SCORE@@':score,'@@SD_BYTES@@':number(data['sd_file_bytes'],lang),'@@SD_MIB@@':f'{data["sd_file_bytes"]/1048576:.2f}','@@ES_MEAN@@':f'{data["languages"]["es"]["mean_seconds"]:.6f}','@@EN_MEAN@@':f'{data["languages"]["en"]["mean_seconds"]:.6f}'}
 for key,value in replacements.items():text=text.replace(key,value)
 text=text.replace('**Edición MSX-DOS','**Versión 2.0 · Edición MSX-DOS') if lang=='es' else text.replace('**MSX-DOS edition','**Version 2.0 · MSX-DOS edition')
 (OUT/f'TECNICA-{lang}.md').write_text(text)
 body=markdown.markdown(text,extensions=['tables','fenced_code','toc'],extension_configs={'toc':{'title':t('Contenido','Contents')}})
 def embed(match):
  path=(OUT/match[1]).resolve();assert path.is_relative_to(OUT.resolve()) and path.is_file(),path
  return 'src="data:image/svg+xml;base64,'+base64.b64encode(path.read_bytes()).decode()+'"'
 body=re.sub(r'src="([^"]+)"',embed,body)
 css=(OUT/'style.css').read_text().replace('@@FOOTER@@',t('Don Quijote · Referencia técnica','Don Quixote · Technical reference'))
 title=t('Don Quijote · Referencia técnica 2.0','Don Quixote · Technical reference 2.0')
 page=f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>{title}</title><style>{css}</style></head><body><main>{body}</main></body></html>'
 (OUT/f'TECNICA-{lang}.html').write_text(page)
 if pdf:
  from weasyprint import HTML
  HTML(string=page,base_url=str(OUT)).write_pdf(OUT/f'TECNICA-{lang}.pdf')
 print(lang,len(text.split()),'words;8localized diagrams')
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pdf',action='store_true');a=p.parse_args();data=json.loads((OUT/'data.json').read_text())
 for lang in ['es','en']:render(lang,data,a.pdf)
 files={f.name:dict(bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in OUT.glob('TECNICA-*') if f.suffix in ['.pdf','.html']}
 (OUT/'artifacts.json').write_text(json.dumps(dict(version='2.0',files=files),indent=2)+'\n')
if __name__=='__main__':main()
