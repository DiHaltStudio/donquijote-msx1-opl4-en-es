#!/usr/bin/env python3
"""Decode MSX BASIC for analysis, retaining line addresses and raw bytes."""
import struct

WORDS = ('END FOR NEXT DATA INPUT DIM READ LET GOTO RUN IF RESTORE GOSUB RETURN REM STOP '
         'PRINT CLEAR LIST NEW ON WAIT DEF POKE CONT CSAVE CLOAD OUT LPRINT LLIST CLS WIDTH '
         'ELSE TRON TROFF SWAP ERASE ERROR RESUME DELETE AUTO RENUM DEFSTR DEFINT DEFSNG '
         'DEFDBL LINE OPEN FIELD GET PUT CLOSE LOAD MERGE FILES LSET RSET SAVE LFILES '
         'CIRCLE COLOR DRAW PAINT BEEP PLAY PSET PRESET SOUND SCREEN VPOKE SPRITE VDP '
         'BASE CALL TIME KEY MAX MOTOR BLOAD BSAVE DSKO$ SET NAME KILL IPL COPY CMD '
         'LOCATE TO THEN TAB( STEP USR FN SPC( NOT ERL ERR STRING$ USING INSTR ? '
         'VARPTR CSRLIN ATTR$ DSKI$ OFF INKEY$ POINT > = < + - * / ^ AND OR XOR EQV IMP MOD \\').split()
TOKENS = dict(enumerate(WORDS, 0x81))
EXT = dict(enumerate(('LEFT$ RIGHT$ MID$ SGN INT ABS SQR RND SIN LOG EXP COS TAN ATN FRE '
                       'INP POS LEN STR$ VAL ASC CHR$ PEEK VPEEK SPACE$ OCT$ HEX$ LPOS '
                       'BIN$ CINT CSNG CDBL FIX STICK STRIG PDL PAD DSKF FPOS LOC LOF').split(), 0x81))

def decode(body):
    result = ''
    p = 0
    quoted = False
    while p < len(body):
        b = body[p]; p += 1
        if b == 34:
            quoted = not quoted
            result += '"'
        elif quoted or 32 <= b < 127:
            result += chr(b)
        elif b == 0xff:
            result += EXT.get(body[p], f'{{FF:{body[p]:02X}}}'); p += 1
        elif b in (11, 12, 13, 14, 28):
            val = struct.unpack_from('<H', body, p)[0]; p += 2
            if b == 12: result += f'&H{val:04X}'
            elif b == 11: result += f'&O{val:o}'
            else: result += str(val if b != 28 or val < 32768 else val-65536)
        elif b == 15:
            result += str(body[p]); p += 1
        elif 17 <= b <= 26:
            result += str(b-17)
        elif b in (29, 31):
            size = 4 if b == 29 else 8
            result += '{MBF:' + body[p:p+size].hex() + '}'
            p += size
        else:
            result += TOKENS.get(b, f'{{{b:02X}}}')
    return result

def lines(raw, base=0x8000):
    p = 1
    while True:
        nxt, number = struct.unpack_from('<HH', raw, p)
        if not nxt: break
        end = nxt-base
        assert p+4 <= end-1 < len(raw), (p,nxt)
        assert raw[end-1] == 0
        body = raw[p+4:end-1]
        yield dict(address=base+p, line=number, body=body, text=decode(body))
        p = end

if __name__ == '__main__':
    from pathlib import Path
    import sys
    for line in lines(Path(sys.argv[1]).read_bytes()):
        print(f"{line['line']:5} {line['text']}")
