; The established DiHalt OPL4 fanfare. Transient data occupies DOS game
; segments4..6 before the original load images overwrite those segments.
branding_start:
    di
    ld a,(v_enabled)
    ld (branding_has_chip),a
    xor a
    ld (branding_phase),a
    ld hl,0
    ld (branding_frames),hl
    ld a,(002Dh)
    or a
    jr z,.msx1
    ld a,(0FFE8h)
    and 2
    jr .frequency
.msx1:
    ld a,(002Bh)
    and 080h
.frequency:
    ld (branding_pal),a
    ld a,(cart_slot)
    ld h,040h
    call 0024h
    di
    ld a,4
    ld hl,04000h
    ld (branding_bank),a
    ld (branding_pointer),hl
    call branding_map
    call branding_get
    ld l,a
    call branding_get
    ld h,a
    ld (branding_pcm_bytes),hl
    xor a
    out (099h),a
    ld a,040h
    out (099h),a
    call branding_rle
    xor a
    out (099h),a
    ld a,060h
    out (099h),a
    call branding_rle
branding_visible:
    ld a,(v_enabled)
    or a
    jp z,branding_silent
    ld a,020h
    ld hl,0
    call v_address
    ld bc,(branding_pcm_bytes)
.upload:
    call branding_get
    out (07Fh),a
    dec bc
    ld a,b
    or c
    jr nz,.upload
    ld a,4
    ld d,060h
    call v_fm
    ld a,4
    ld d,080h
    call v_fm
    in a,(099h)
branding_music_start:
branding_next:
    call branding_get
    cp 255
    jp z,branding_done
    cp 254
    jr z,.idle
    ld (branding_writes),a
.write:
    call branding_get
    ld c,a
    call branding_get
    ld b,a
    call branding_get
    ld d,a
    call branding_write
    ld hl,branding_writes
    dec (hl)
    jr nz,.write
    call branding_frame
    ld a,(v_enabled)
    or a
    jp z,branding_done
    jp branding_next
.idle:
    call branding_get
    ld (branding_idle),a
.wait_idle:
    call branding_frame
    ld a,(v_enabled)
    or a
    jp z,branding_done
    ld hl,branding_idle
    dec (hl)
    jr nz,.wait_idle
    jp branding_next

; The established fanfare uses 50 Hz frames. Keep all 500 frames; on a
; 60 Hz VDP consume one extra vblank in every six, as in the DONE ports.
branding_frame:
.vblank:
    in a,(099h)
    and 080h
    jr z,.vblank
    ld a,(branding_pal)
    or a
    jr nz,.count
    ld a,(branding_phase)
    inc a
    cp 6
    jr c,.phase
    xor a
    ld (branding_phase),a
    jr .vblank
.phase:
    ld (branding_phase),a
.count:
    ld hl,(branding_frames)
    inc hl
    ld (branding_frames),hl
    ret

branding_silent:
    ; No chip: show the logo briefly without entering any OPL4 wait loop.
    ld b,60
.frame:
    in a,(099h)
    and 080h
    jr z,.frame
    djnz .frame
branding_done:
    ld a,(branding_has_chip)
    or a
    jr z,.restore
    ld a,4
    ld d,060h
    call v_fm
    ld a,4
    ld d,080h
    call v_fm
    ld b,24
    ld a,068h
    ld d,0
.off:
    push af
    call v_wave
    pop af
    inc a
    djnz .off
    ld a,2
    ld d,011h
    call v_wave
    ld a,0F9h
    ld d,0
    call v_wave              ; restore the accepted speech output level
    ld a,(v_enabled)
    or a
    jr z,.restore
    call v_clear_cache
.restore:
    ld a,5
    call set_page1
    ld a,(bios_slot)
    ld h,040h
    call 0024h
    di
    ld a,2
    call 005Fh
    di
    ret

branding_rle:
    ld de,6144
.run:
    call branding_get
    ld b,a
    call branding_get
    ld c,a
.byte:
    ld a,c
    out (098h),a
    dec de
    djnz .byte
    ld a,d
    or e
    jr nz,.run
    ret

branding_write:
    ; C=OPL4 address port, B=register, D=value. Wait for any previous
    ; instrument-header load before selecting another wave register.
.ready:
    in a,(0C4h)
    and 3
    jr nz,.ready
    ld a,b
    out (c),a
    call v_busy
    inc c
    ld a,d
    out (c),a
    dec c
    ret

branding_map:
    jp set_page1
branding_get:
    push hl
    ld hl,(branding_pointer)
    ld a,(hl)
    inc hl
    bit 7,h
    jr z,.keep
    push af
    ld hl,04000h
    ld a,(branding_bank)
    inc a
    ld (branding_bank),a
    call branding_map
    pop af
.keep:
    ld (branding_pointer),hl
    pop hl
    ret
branding_pointer: dw 0
branding_bank: db 0
branding_pcm_bytes: dw 0
branding_writes: db 0
branding_idle: db 0
branding_phase: db 0
branding_frames: dw 0
branding_has_chip: db 0
branding_pal: db 0
