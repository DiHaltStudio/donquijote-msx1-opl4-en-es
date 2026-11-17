; Both DOS graphics editions keep their opening visible until a fresh key.
; COVER_ENTRY is the native SCREEN entry (MSX1 8800h, MSX2 C006h).
cover_after_entry:
    ld hl,(entry_operand+1)
    ld de,COVER_ENTRY
    or a
    sbc hl,de
    ret nz
    ld a,(bios_slot)
    ld h,040h
    call 0024h
cover_wait_begin:
    ei
.release:
    ld b,11
    ld c,0
.scan:
    push bc
    ld a,c
    call 0141h              ; SNSMAT: do not carry a held Enter into the cover
    pop bc
    cp 0FFh
    jr nz,.release
    inc c
    djnz .scan
    call 0156h              ; KILBUF: discard keys queued by the previous screen
cover_wait_key:
    call 009Fh              ; CHGET: no timer, no automatic advance
cover_wait_done:
    call 0156h
    di
    ret
