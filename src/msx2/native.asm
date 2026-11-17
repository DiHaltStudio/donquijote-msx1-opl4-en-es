; Native SCREEN5 driver. BASIC CLEAR reserves C000..FFFF for game/bridge.
    include "../build/native-api.inc"
    org 0C000h
    jp gfx_game_init         ; C000
    jp gfx_print             ; C003
    jp gfx_cover             ; C006
    jp gfx_clear             ; C009
    jp gfx_room              ; C00C
    jp gfx_logo              ; C00F

; Command helpers own VDP under DI, restore status selection zero before I/O.
gfx_wait:
    ld a,2
    out (099h),a
    ld a,08Fh
    out (099h),a
.loop:
    in a,(099h)
    and 1
    jr nz,.loop
    xor a
    out (099h),a
    ld a,08Fh
    out (099h),a
    ret
gfx_command:
    call gfx_wait
    ld a,32
    out (099h),a
    ld a,091h
    out (099h),a
    ld hl,gfx_cmd
    ld a,(gfx_cmd+14)
    cp 0F0h
    ld b,15
    jr nz,.send
    dec b                   ; HMMC starts in disk service with its first pixel byte
.send:
    ld c,09Bh
    otir
    ret
; Initialize a command descriptor; caller sets coords/dimensions afterwards.
gfx_zero:
    ld hl,gfx_cmd
    ld de,gfx_cmd+1
    ld bc,14
    ld (hl),0
    ldir
    ret
gfx_reg:
    out (099h),a
    ld a,b
    or 080h
    out (099h),a
    ret

gfx_mode:
    ; Own bitmap mode directly, independent of the tape BASIC video state.
    di
    call gfx_wait
    xor a
    ld (gfx_page),a
    ld b,15
    call gfx_reg
    xor a
    ld b,14
    call gfx_reg
    xor a
    ld b,23
    call gfx_reg
    ld a,6
    ld (0F3DFh),a
    ld b,0
    call gfx_reg
    ld a,060h
    ld (0F3E0h),a
    ld b,1
    call gfx_reg
    ld a,01Fh
    ld (0F3E1h),a
    ld b,2
    call gfx_reg
    ld a,(0FFE7h)
    or 00Ah                ; 64 KiB addressing, sprites disabled
    ld (0FFE7h),a
    ld b,8
    call gfx_reg
    ld a,(0FFE8h)
    and 2                  ; preserve PAL/NTSC timing selection
    or 080h                ; 212 visible lines
    ld (0FFE8h),a
    ld b,9
    call gfx_reg
    ld a,0F0h
    ld (0F3E6h),a
    ld b,7
    call gfx_reg
    ld a,5
    ld (0FCAFh),a
    ret

gfx_init:
    call gfx_mode
    call gfx_zero
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,468
    ld (gfx_cmd+10),hl
    ld a,0C0h
    ld (gfx_cmd+14),a
    call gfx_command
    call gfx_wait
    call gfx_zero
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,24
    ld (gfx_cmd+10),hl
    ld hl,480               ; atlas below visible area of page 1 (64 KiB VRAM)
    ld (gfx_cmd+6),hl
    ld a,0F0h
    ld (gfx_cmd+14),a
    call gfx_command
    ld hl,0
    ld (io_offset),hl
    ld (io_offset+2),hl
    ld hl,3072
    ld (io_count),hl
    ld a,1
    ld (io_file),a
    ld a,4
    ld (io_mode),a
    call disk_read
    call gfx_finish_upload
    ret

gfx_game_init:
    call gfx_init
    ld hl,0700h
    ld (0709Eh),hl
    ei
    ret

; Abort a partial transfer on disk errors instead of waiting for missing pixels.
gfx_finish_upload:
    ld a,(io_error)
    or a
    jp z,gfx_wait
    xor a
    out (099h),a
    ld a,0AEh
    out (099h),a
    ret

gfx_print:
    di
.next:
    ld a,(hl)
    or a
    jr nz,.have
    ei
    ret
.have:
    push hl
    cp 14
    jr nc,.char
    cp 8
    jr z,.back
    call gfx_scroll
    xor a
    ld (0709Eh),a
    jr .advance
.back:
    ld a,(0709Eh)
    or a
    jr z,.advance
    dec a
    ld (0709Eh),a
    jr .advance
.char:
    cp 'a'
    jr c,.upper
    sub 32
.upper:
    sub 32
    cp 96
    jr nc,.advance
    ld (gfx_glyph),a
    call gfx_zero
    ld a,(gfx_glyph)
    and 31
    add a,a
    add a,a
    add a,a
    ld (gfx_cmd),a
    ld a,(gfx_glyph)
    and 060h
    rrca
    rrca
    ld l,a
    ld h,0
    ld de,480
    add hl,de
    ld (gfx_cmd+2),hl
    ld a,(0709Eh)
    add a,a
    add a,a
    add a,a
    ld (gfx_cmd+4),a
    ld hl,184
    ld a,(gfx_page)
    ld h,a
    ld (gfx_cmd+6),hl
    ld hl,8
    ld (gfx_cmd+8),hl
    ld (gfx_cmd+10),hl
    ld a,0D0h               ; opaque HMMM: source atlas includes cell background
    ld (gfx_cmd+14),a
    call gfx_command
    call gfx_wait
    ; The original editor changes its wrap limit from 32 to 33 while drawing
    ; the cursor. Preserve that protocol so column31 does not scroll the row.
    ld a,(07060h)
    ld b,a
    ld a,(0709Eh)
    inc a
    cp b
    jr nz,.column
    call gfx_scroll
    xor a
.column:
    ld (0709Eh),a
.advance:
    pop hl
    inc hl
    jp .next

gfx_scroll:
    call gfx_zero
    ld a,(gfx_page)
    ld h,a
    ld l,136
    ld (gfx_cmd+2),hl
    ld l,128
    ld (gfx_cmd+6),hl
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,56
    ld (gfx_cmd+10),hl
    ld a,0D0h
    ld (gfx_cmd+14),a
    call gfx_command
    call gfx_wait
    call gfx_zero
    ld a,(gfx_page)
    ld h,a
    ld l,184
    ld (gfx_cmd+6),hl
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,8
    ld (gfx_cmd+10),hl
    ld a,0C0h               ; HMMV clears only the last text row
    ld (gfx_cmd+14),a
    call gfx_command
    jp gfx_wait

gfx_clear:
    di
    ld a,255
    ld (draw_last_room),a
    call gfx_zero
    ld a,(gfx_page)
    ld (gfx_cmd+7),a
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,128
    ld (gfx_cmd+10),hl
    ld a,0C0h
    ld (gfx_cmd+14),a
    call gfx_command
    jp gfx_wait

gfx_cover:
    ld a,(cart_slot)
    ld h,040h
    call 0024h
    di
    call gfx_init
    ld hl,COVER_OFFSET & 0FFFFh
    ld de,COVER_OFFSET >> 16
    ld b,192
    call gfx_show
    ld a,(bios_slot)
    ld h,040h
    call 0024h
    di
    ret
gfx_logo:
    call gfx_init
    ld hl,LOGO_OFFSET & 0FFFFh
    ld de,LOGO_OFFSET >> 16
    ld b,192
    jr gfx_show
gfx_room:
    ld b,128
; HL/DE file offset, B picture height. Caller preserves game registers.
gfx_show:
    ld (io_offset),hl
    ld (io_offset+2),de
    ld a,b
    ld (gfx_height),a
    ld a,(game_page1)
    ld (gfx_bank),a
    call gfx_zero
    ld a,(gfx_page)
    xor 1
    ld (gfx_hidden),a
    ld (gfx_cmd+7),a
    ld hl,256
    ld (gfx_cmd+8),hl
    ld a,(gfx_height)
    ld l,a
    ld h,0
    ld (gfx_cmd+10),hl
    ld a,0F0h
    ld (gfx_cmd+14),a
    call gfx_command
    ld a,(gfx_height)
    ld h,a
    ld l,0
    srl h
    rr l                    ; height * 128 packed bytes
    ld (io_count),hl
    ld a,1
    ld (io_file),a
    ld a,4
    ld (io_mode),a
    call disk_read
    call gfx_finish_upload
    ld a,(io_error)
    or a
    jr nz,.restore
    ; Read the palette into shared bank15; mode3 is not a drawing path.
    ld hl,32
    ld (io_count),hl
    ld a,3
    ld (io_mode),a
    call disk_read
    ld a,(io_error)
    or a
    jr nz,.restore
    ld a,(gfx_height)
    cp 128
    jr nz,.flip
    ; Preserve text while preparing the other display page.
    call gfx_zero
    ld a,(gfx_page)
    ld (gfx_cmd+3),a
    ld a,128
    ld (gfx_cmd+2),a
    ld a,(gfx_hidden)
    ld (gfx_cmd+7),a
    ld a,128
    ld (gfx_cmd+6),a
    ld hl,256
    ld (gfx_cmd+8),hl
    ld hl,84
    ld (gfx_cmd+10),hl
    ld a,0D0h
    ld (gfx_cmd+14),a
    call gfx_command
    call gfx_wait
.flip:
    ; Change page and palette together during the vertical blank interval.
    in a,(099h)
.vblank:
    in a,(099h)
    and 080h
    jr z,.vblank
    ld a,15
    call set_page1
    xor a
    out (099h),a
    ld a,090h
    out (099h),a
    ld hl,05060h
    ld b,32
    ld c,09Ah
    otir
    ld a,(gfx_hidden)
    ld (gfx_page),a
    add a,a
    add a,a
    add a,a
    add a,a
    add a,a
    or 01Fh
    ld b,2
    call gfx_reg
.restore:
    ld a,(gfx_bank)
    jp set_page1

gfx_page: db 0
gfx_hidden: db 0
gfx_height: db 0
gfx_bank: db 5
gfx_glyph: db 0
gfx_cmd: ds 15,0
    assert $<0D750h
