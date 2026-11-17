; DOS startup selection, before either original tape image is loaded.
; BIOS pages are restored by branding_start. Input owns F200..F23F only here.
; Returns HL = original part descriptor, with part set to 0 or 1.
startup_select:
    xor a
    call 005Fh              ; SCREEN 0, native MSX1 text
    ei
    ld hl,startup_title
    call startup_print
startup_retry:
    ld hl,startup_prompt
    call startup_print
    call 0156h              ; KILBUF: do not consume keys held during opening
    ld hl,0F200h
    ld (startup_cursor),hl
startup_wait:
    call 009Fh              ; CHGET with BIOS keyboard interrupts enabled
    cp 13
    jr z,startup_enter
    cp 8
    jr z,startup_backspace
    cp 32
    jr c,startup_wait
    cp 127
    jr nc,startup_wait
    cp 'a'
    jr c,.case_done
    cp 'z'+1
    jr nc,.case_done
    sub 32
.case_done:
    ld hl,(startup_cursor)
    ld b,a
    ld a,l
    cp 63
    jr nc,startup_wait
    ld a,b
    ld (hl),a
    inc hl
    ld (startup_cursor),hl
    call 00A2h
    jr startup_wait
startup_backspace:
    ld hl,(startup_cursor)
    ld a,l
    or a
    jr z,startup_wait
    dec hl
    ld (startup_cursor),hl
    ld hl,startup_erase
    call startup_print
    jr startup_wait
startup_enter:
    ld hl,(startup_cursor)
    ld (hl),0
    ld hl,startup_newline
    call startup_print
    ; Normalize spaces in place, allowing extra whitespace in the password.
    ld hl,0F200h
    ld de,0F200h
.normalize:
    ld a,(hl)
    inc hl
    cp ' '
    jr z,.normalize
    ld (de),a
    inc de
    or a
    jr nz,.normalize
    ld a,(0F200h)
    or a
    jr z,startup_first
    ld de,startup_key_es
    call startup_equal
    jr z,startup_second
    ld de,startup_key_en
    call startup_equal
    jr z,startup_second
    ld hl,startup_invalid
    call startup_print
    jp startup_retry
startup_first:
    xor a
    ld (part),a
    ld hl,part_a
    jr startup_ready
startup_second:
    ld a,1
    ld (part),a
    ld hl,part_b
startup_ready:
    push hl
    ld a,2
    call 005Fh              ; initialize SCREEN2 before the original cover
    di
    pop hl
    ret
startup_equal:
    ld hl,0F200h
.loop:
    ld a,(de)
    cp (hl)
    ret nz
    inc de
    inc hl
    or a
    jr nz,.loop
    ret
startup_print:
    ld a,(hl)
    or a
    ret z
    inc hl
    push hl
    call 00A2h
    pop hl
    jr startup_print
startup_cursor: dw 0
startup_erase: db 8,' ',8,0
startup_newline: db 13,10,0
startup_key_es: db 'ELBALSAMODEFIERABRAS',0
startup_key_en: db 'THEBALMOFFIERABRAS',0
    if ENGLISH
startup_title: db 12,'DON QUIXOTE',13,10,13,10,0
startup_prompt: db 'ENTER: start part one.',13,10,'Or enter the password for part two:',13,10,'> ',0
startup_invalid: db 'Incorrect password. Try again.',13,10,13,10,0
    else
startup_title: db 12,'DON QUIJOTE',13,10,13,10,0
startup_prompt: db 'ENTER: empezar la primera parte.',13,10,'O escribe la clave de la segunda:',13,10,'> ',0
startup_invalid: db 'Clave incorrecta. Intentalo de nuevo.',13,10,13,10,0
    endif
