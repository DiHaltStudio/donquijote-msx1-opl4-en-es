; Requests are serviced with DOS memory banks mapped; the game remains intact.
disk_read:
    xor a
    ld (io_error),a
.loop:
    ld hl,(io_count)
    ld a,h
    or l
    ret z
    ld de,04000h
    or a
    sbc hl,de
    jr c,.small
    ld hl,04000h
    jr .request
.small:
    ld hl,(io_count)
.request:
    ; Also stop at 64 KiB boundaries, hence never cross a 1 MiB voice file.
    ld de,(io_offset)
    ld a,d
    cp 0C0h
    jr c,.size_ready
    push hl
    ld hl,0
    or a
    sbc hl,de
    ex de,hl
    pop hl
    or a
    sbc hl,de
    jr c,.original_size
    ex de,hl
    jr .size_ready
.original_size:
    add hl,de
.size_ready:
    ld (io_chunk),hl
    call io_request
    ld a,(io_error)
    or a
    ret nz
    ld hl,(io_count)
    ld de,(io_chunk)
    or a
    sbc hl,de
    ld (io_count),hl
    ld hl,(io_offset)
    add hl,de
    ld (io_offset),hl
    ld hl,(io_offset+2)
    ld de,0
    adc hl,de
    ld (io_offset+2),hl
    jr .loop
io_request:
    di
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ex af,af'
    push af
    ex af,af'
    exx
    push bc
    push de
    push hl
    exx
    ld (io_saved_sp),sp
    ld a,(game_page1)
    ld (io_saved_bank),a
    ld a,15
    call set_page1
    ld a,(io_file)
    ld (05000h),a
    ld hl,io_offset
    ld de,05001h
    ld bc,4
    ldir
    ld hl,(io_chunk)
    ld (05005h),hl
    ld a,(io_mode)
    ld (05007h),a
    ld a,(read_cache_bank)
    ld l,a
    ld h,0
    ld de,BANK_MAP
    add hl,de
    ld a,(hl)
    ld (05016h),a
    xor a
    ld (05013h),a
    jp 06000h

room_picture_first:
    push af
    call draw_room
    call 070A3h
    jp 0745Bh                 ; original XOR A / restore room / list objects
clear_picture:
    ld a,255
    ld (draw_last_room),a
    ld hl,0
    jp 0DFD0h                 ; original DFCD, after LD HL,0

draw_room:
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    di
    ld a,(part)
    ld hl,0DAEBh              ; part A darkness flag 100
    or a
    jr z,.darkness
    ld hl,0DAE6h              ; part B darkness flag 60
.darkness:
    bit 4,(hl)
    jp nz,.return
    ld a,(part)
    ld hl,draw_last_part
    cp (hl)
    jr nz,.load
    ld a,(0DF54h)
    ld hl,draw_last_room
    cp (hl)
    jp z,.return
.load:
    ld a,(game_page1)
    ld (draw_bank),a
    ld a,19
    call set_page1
    ld a,(0DF54h)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld a,(part)
    add a,a
    add a,a
    add a,040h
    add a,h
    ld h,a
    ld a,(hl)
    inc a
    jr z,.restore
    ld de,io_offset
    ld bc,4
    ldir
    ld a,1
    ld (io_file),a
    ld (io_mode),a
    ld hl,02000h
    ld (io_count),hl
    call disk_read
    ld a,(io_error)
    or a
    jr nz,.restore
    ld a,(0DF54h)
    ld (draw_last_room),a
    ld a,(part)
    ld (draw_last_part),a
.restore:
    ld a,(draw_bank)
    call set_page1
.return:
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ei
    ret
io_offset: ds 4,0
io_count: dw 0
io_chunk: dw 0
io_file: db 0
io_mode: db 0
io_error: db 0
io_saved_sp: dw 0
io_saved_bank: db 0
draw_bank: db 0

draw_last_room: db 255
draw_last_part: db 255

; A second cache in mapper segments20..31 holds twelve 16 KiB disk blocks.
; It saves DOS transitions when neighbouring speech units share one SD block.
read_pcm_cached:
    ld a,(read_cache_count)
    or a
    jr nz,.loop
    ; With no spare segment, keep the same PCM stream through direct reads.
    ld hl,(pcm_position)
    ld (io_offset),hl
    ld hl,(pcm_position+2)
    ld (io_offset+2),hl
    ld hl,(pcm_remaining)
    ld (io_count),hl
    xor a
    ld (io_mode),a
    ld (io_file),a
    jp disk_read
.loop:
    ld hl,(pcm_remaining)
    ld a,h
    or l
    ret z
    ld hl,(pcm_position)
    ld a,(pcm_position+2)
    ld e,a
    ld a,h
    rlca
    rlca
    and 3
    ld l,a
    ld a,e
    rlca
    rlca
    and 0FCh
    or l
    ld e,a                   ; global block id, low byte
    ld a,(pcm_position+2)
    rlca
    rlca
    and 3
    ld d,a                   ; global block id, high byte
    ld (read_block),de
    ld hl,read_tags
    ld a,(read_cache_count)
    ld b,a
.search:
    ld a,(hl)
    inc hl
    cp e
    jr nz,.next
    ld a,(hl)
    cp d
    jr z,.found
.next:
    inc hl
    djnz .search
    ld a,(read_next)
    ld (read_slot),a
    inc a
    ld hl,read_cache_count
    cp (hl)
    jr c,.next_slot
    xor a
.next_slot:
    ld (read_next),a
    ld a,(read_slot)
    call select_read_bank
    ld hl,(pcm_position)
    ld a,h
    and 0C0h
    ld h,a
    ld l,0
    ld (io_offset),hl
    ld a,(pcm_position+2)
    ld (io_offset+2),a
    xor a
    ld (io_offset+3),a
    ld (io_file),a
    ld a,2
    ld (io_mode),a
    ld hl,04000h
    ld (io_chunk),hl
    call io_request
    ld a,(io_error)
    or a
    ret nz
    ld a,(read_slot)
    add a,a
    ld l,a
    ld h,0
    ld de,read_tags
    add hl,de
    ld de,(read_block)
    ld (hl),e
    inc hl
    ld (hl),d
    jr .ready
.found:
    ld a,(read_cache_count)
    sub b
    ld (read_slot),a
    call select_read_bank
.ready:
    ld hl,(pcm_position)
    ld a,h
    and 03Fh
    ld h,a
    ex de,hl
    ld hl,04000h
    or a
    sbc hl,de                ; bytes until next disk-block boundary
    ld de,(pcm_remaining)
    or a
    sbc hl,de
    jr c,.to_boundary
    ld hl,(pcm_remaining)
    jr .count
.to_boundary:
    add hl,de
.count:
    ld (pcm_chunk),hl
    ld a,(read_cache_bank)
    call set_page1
    ld hl,(pcm_position)
    ld a,h
    and 03Fh
    or 040h
    ld h,a
    ld de,(pcm_chunk)
    ld c,07Fh
.copy:
    ld a,d
    or a
    jr z,.short
    ld b,0
    otir
    dec d
    jr .copy
.short:
    ld a,e
    or a
    jr z,.copied
    ld b,e
    otir
.copied:
    ld a,VOICE_CATALOG_BANK
    call set_page1
    ld hl,(pcm_position)
    ld de,(pcm_chunk)
    add hl,de
    ld (pcm_position),hl
    ld a,(pcm_position+2)
    adc a,0
    ld (pcm_position+2),a
    ld hl,(pcm_remaining)
    or a
    sbc hl,de
    ld (pcm_remaining),hl
    jp .loop
pcm_position: ds 4,0
pcm_remaining: dw 0
pcm_chunk: dw 0
read_tags: ds 24,255
read_next: db 0
read_slot: db 0
read_block: dw 0
read_cache_bank: db 20

select_read_bank:
    ld l,a
    ld h,0
    ld de,read_banks
    add hl,de
    ld a,(hl)
    ld (read_cache_bank),a
    ret
read_banks: ds 12,0
read_cache_count: db 12

set_page1:
    ld (game_page1),a
    push af
    push bc
    push hl
    ld l,a
    ld h,0
    ld bc,BANK_MAP
    add hl,bc
    ld a,(hl)
    out (0FDh),a
    pop hl
    pop bc
    pop af
    ret
game_page1: db 5
