; DOS1/DOS2/Nextor selector and COM chain loader. No shell-specific extensions.
    org 0100h
    jp start
language: db 0
load_size: dw 0
start:
    ; BAT supplies ES or EN in the standard DOS command tail.
    ld hl,0081h
.space:
    ld a,(hl)
    cp ' '
    jr nz,.arg
    inc hl
    jr .space
.arg:
    and 0DFh
    cp 'E'
    jr nz,menu
    inc hl
    ld a,(hl)
    and 0DFh
    cp 'N'
    jr nz,menu
    ld a,1
    ld (language),a
    ld a,'N'
    ld (fcb+4),a
menu:
    ld de,menu_es
    ld a,(language)
    or a
    jr z,.show
    ld de,menu_en
.show:
    ld c,9
    call 5
    ld de,answer
    xor a
    ld (answer+1),a
    ld c,0Ah
    call 5
    ld de,newline
    ld c,9
    call 5
    ld a,(answer+1)
    cp 1
    jr nz,menu
    ld a,(answer+2)
    cp '0'
    jp z,0
    cp '1'
    jr z,.choice
    cp '2'
    jr nz,menu
    ; BIOS MSXVER via RDSLT, without probing graphics or OPL4.
    ld a,(0FCC1h)
    and 080h
    ld hl,002Dh
    call 000Ch
    or a
    jr nz,.msx2
    ld de,need_msx2_es
    ld a,(language)
    or a
    jr z,.required
    ld de,need_msx2_en
.required:
    ld c,9
    call 5
    jr menu
.msx2:
    ld a,'2'
.choice:
    ld (fcb+2),a
    ld de,fcb
    ld c,0Fh
    call 5
    cp 0FFh
    jp z,load_error
    ld hl,(fcb+18)
    ld a,h
    or l
    jp nz,close_error
    ld hl,(fcb+16)
    ld a,h
    or l
    jp z,close_error
    ld (load_size),hl
    ld de,04000h
    or a
    sbc hl,de
    jp nc,close_error       ; preserve DOS work area and the transfer stub
    ; Random-block reads with one-byte records are supported by both DOS1
    ; and DOS2 and load exactly the file length (no padded final record).
    ld hl,1
    ld (fcb+14),hl
    ld de,08000h
    ld c,01Ah
    call 5
    ld hl,(load_size)
    ld de,fcb
    ld c,027h
    call 5
.read_result:
    or a
    jp nz,close_error
    ld de,(load_size)
    or a
    sbc hl,de
    jp nz,close_error
.loaded:
    ld de,fcb
    ld c,010h
    call 5
    ld de,0080h
    ld c,01Ah
    call 5
    xor a
    ld (0080h),a
    ld a,13
    ld (0081h),a
    ; Execute the copy outside both the destination and staging buffer.
    ld hl,transfer
    ld de,0C000h
    ld bc,transfer_end-transfer
    ldir
    ld hl,08000h
    ld de,0100h
    ld bc,(load_size)
    jp 0C000h
close_error:
    ld de,fcb
    ld c,010h
    call 5
load_error:
    ld de,error_es
    ld a,(language)
    or a
    jr z,.show
    ld de,error_en
.show:
    ld c,9
    call 5
    jp 0
transfer:
    ldir
    jp 0100h
transfer_end:
answer: db 2,0,0,0,0
fcb: db 0,'Q1ES    COM'
    ds 25,0
newline: db 13,10,'$'
menu_es: db 13,10,'DON QUIJOTE 2.0 - ESPANOL',13,10,13,10
    db '1 - Version MSX1 (MSX1 o superior)',13,10
    db '2 - Version MSX2 (MSX2 o superior)',13,10
    db '0 - Salir',13,10,'Elige 1 o 2 y pulsa ENTER: $'
menu_en: db 13,10,'DON QUIXOTE 2.0 - ENGLISH',13,10,13,10
    db '1 - MSX1 version (MSX1 or later)',13,10
    db '2 - MSX2 version (MSX2 or later)',13,10
    db '0 - Exit',13,10,'Choose 1 or 2 and press ENTER: $'
need_msx2_es: db 'La version 2 necesita un MSX2 o superior.',13,10,'$'
need_msx2_en: db 'Version 2 requires an MSX2 or later.',13,10,'$'
error_es: db 'No se puede cargar la version elegida.',13,10
    db 'Copia todos los archivos del paquete en el mismo directorio.',13,10,'$'
error_en: db 'Cannot load the selected version.',13,10
    db 'Copy all package files into the same directory.',13,10,'$'
