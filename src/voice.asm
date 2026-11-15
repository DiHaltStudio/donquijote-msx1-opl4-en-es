; Resident speech API. Caller has BIOS in page 0 and original game RAM in
; page 1. Mapper and OPL4 memory transfers run with DI. Playback restores
; page 1 and keeps DI while polling FT1. OPL4 PCM 0/1 and timer 1 belong here.
; Cache: PCM cores in 200800..3FDFFF; generation-tagged addresses at 3FE000.
; Each occurrence has a separate header pointing into the same cached core,
; with event-specific zero padding. No waveform is duplicated for padding.
    include "../build/voice-config.inc"
VSEQ equ 0F000h

; The original parser only accepts uppercase ASCII. Cartridge cold boot does
; not force CAPS, so normalize letters while preserving space/control keys.
voice_input:
    call 009Fh
    cp 'a'
    ret c
    cp 'z'+1
    ret nc
    sub 32
    ret

voice_text:
    ld (v_text),hl
    call v_original_text
    jp v_saved
v_original_text:
    xor a
    ld (0711Ah),a
    jp 070AAh
voice_basic:
    ld (v_text),hl
    call 0702Dh
v_saved:
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    di
    call v_speak
    ei
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ret

voice_init:
    xor a
    ld (v_enabled),a
    ld a,5
    out (0C6h),a
    nop
    nop
    ld a,3
    out (0C5h),a
    nop
    nop
    ld a,2
    out (07Eh),a
    nop
    nop
    in a,(07Fh)
    and 0E0h
    cp 020h
    jr z,.found
    ld a,0E1h
    ld (v_status),a
    ret
.found:
    ld a,2
    ld d,011h
    call v_wave
    ; Distinguish all four 512 KiB regions, detecting mirrored/missing RAM.
    ld b,4
    ld c,020h
.probe_write:
    ld a,c
    ld hl,0
    call v_address
    ld a,c
    out (07Fh),a
    add a,8
    ld c,a
    djnz .probe_write
    ld b,4
    ld c,020h
.probe_read:
    ld a,c
    ld hl,0
    call v_address
    in a,(07Fh)
    cp c
    jr nz,.bad_ram
    add a,8
    ld c,a
    djnz .probe_read
    call v_clear_cache
    ld a,1
    ld (v_enabled),a
    ld a,0A1h
    ld (v_status),a
    ret
.bad_ram:
    ld a,0E2h
    ld (v_status),a
    ret

v_clear_cache:
    ld a,03Fh
    ld hl,0E000h
    call v_address
    ld hl,VOICE_UNIT_COUNT*4
.zero:
    xor a
    out (07Fh),a
    dec hl
    ld a,h
    or l
    jr nz,.zero
    ld a,1
    ld (v_generation),a
    jp v_reset_pool
v_reset_pool:
    ld hl,00800h
    ld (v_free),hl
    ld a,020h
    ld (v_free+2),a
    ; Silent unit 0 uses the same normal allocation/cache path as other units.
    ret

; Hash printed text before switching the cartridge into page 1. CRC-CCITT
; plus normalized length; host compiler rejects every ambiguous key.
v_speak:
    ld a,(v_enabled)
    or a
    ret z
    ld hl,(v_text)
    ld de,0FFFFh
    ld ix,0
.char:
    ld a,(hl)
    inc hl
    or a
    jr z,.hashed
    cp 33
    jr c,.char
    cp 127
    jr nc,.char
    cp 'a'
    jr c,.case_done
    cp 'z'+1
    jr nc,.case_done
    sub 32
.case_done:
    inc ix
    xor d
    ld d,a
    ld b,8
.crc:
    sla e
    rl d
    jr nc,.bit_done
    ld a,e
    xor 021h
    ld e,a
    ld a,d
    xor 010h
    ld d,a
.bit_done:
    djnz .crc
    jr .char
.hashed:
    ld (v_hash),de
    ld (v_length),ix
    call v_ram_slot2
    ld (v_return_slot2),a
    call v_ram_slot
    ld (v_return_slot),a
    ld a,(cart_slot)
    ld h,040h
    call 0024h
    di
    ld a,VOICE_CATALOG_BANK
    call set_page1
    ld ix,VOICE_MESSAGES
    ld bc,VOICE_MESSAGE_COUNT
.search:
    ld a,(v_hash)
    cp (ix+0)
    jr nz,.next
    ld a,(v_hash+1)
    cp (ix+1)
    jr nz,.next
    ld a,(v_length)
    cp (ix+2)
    jr nz,.next
    ld a,(v_length+1)
    cp (ix+3)
    jr z,.match
.next:
    ld de,7
    add ix,de
    dec bc
    ld a,b
    or c
    jr nz,.search
    jp v_restore
.match:
    ld a,(ix+4)
    ld (v_src_bank),a
    ld l,(ix+5)
    ld h,(ix+6)
    ld (v_src),hl
    call set_page1
    ld de,VSEQ
.score:
    ld b,6
.score_byte:
    call v_get
    ld (de),a
    inc de
    djnz .score_byte
    push de
    ex de,hl
    dec hl
    dec hl
    dec hl
    ld a,(hl)
    dec hl
    and (hl)
    pop de
    cp 255
    jr z,.score_ready
    ld a,d
    cp 0F3h
    jr c,.score
    xor a
    ld (v_enabled),a
    ld a,0E3h
    ld (v_status),a
    jp v_restore
.score_ready:
    ld a,2
    ld d,011h
    call v_wave
    ; The compiler bounds a whole phrase below 122880 decoded bytes. Starting
    ; below 3E0000 guarantees no mid-phrase eviction of a prepared header.
    ld a,(v_free+2)
    cp 03Eh
    jr c,.space
    ld a,(v_generation)
    inc a
    ld (v_generation),a
    call z,v_clear_cache
    call v_reset_pool
.space:
    xor a
    ld (v_tone),a
    ld ix,VSEQ
.prepare:
    ld l,(ix+2)
    ld h,(ix+3)
    ld a,h
    and l
    cp 255
    jr z,.prepared
    ld (v_unit),hl
    ld de,VOICE_UNITS
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,de
    ld a,VOICE_CATALOG_BANK
    call set_page1
    ld de,v_file_offset
    ld bc,4
    ldir
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (v_samples),de
    call v_cache_lookup
    call nz,v_decode
    call v_header
    ld a,(v_tone)
    ld (ix+2),a
    ld (ix+3),0
    inc a
    ld (v_tone),a
    ld de,6
    add ix,de
    jr .prepare
.prepared:
    ld a,2
    ld d,010h
    call v_wave
    call v_restore
    jp v_play

; The game maps RAM directly, so read actual page-3 subslot bits when the
; page-1 primary is the same RAM slot. Otherwise use the BIOS slot mirror.
v_ram_slot:
    ld b,2
    jr v_slot
v_ram_slot2:
    ld b,4
v_slot:
    ld a,b
    ld (v_slot_rotations),a
    in a,(0A8h)
    ld e,a
.rotate:
    rrca
    djnz .rotate
    and 3
    ld c,a
    ld b,0
    ld hl,0FCC1h
    add hl,bc
    ld a,(hl)
    and 080h
    or c
    ret p
    ld d,a
    ld a,e
    rlca
    rlca
    and 3
    cp c
    jr nz,.mirror
    ld a,(0FFFFh)
    cpl
    jr .subslot
.mirror:
    inc hl
    inc hl
    inc hl
    inc hl
    ld a,(hl)
.subslot:
    ld e,a
    ld a,(v_slot_rotations)
    cp 4
    ld a,e
    jr nz,.page1
    rrca
    rrca
.page1:
    and 00Ch
    or d
    ret
v_restore:
    ld a,5
    call set_page1
    ld a,(v_return_slot)
    ld h,040h
    call 0024h
    di
    ret

; Sequential score reader across mapper segments. Preserves BC/DE/HL.
v_get:
    push hl
    ld hl,(v_src)
    ld a,(hl)
    inc hl
    bit 7,h
    jr z,.normal
    push af
    ld hl,04000h
    ld a,(v_src_bank)
    inc a
    ld (v_src_bank),a
    call set_page1
    pop af
.normal:
    ld (v_src),hl
    pop hl
    ret

v_cache_address:
    ld hl,(v_unit)
    add hl,hl
    add hl,hl
    ld de,0E000h
    add hl,de
    ld a,03Fh
    jp v_address
v_cache_lookup:
    call v_cache_address
    in a,(07Fh)
    ld (v_core),a
    in a,(07Fh)
    ld (v_core+1),a
    in a,(07Fh)
    ld (v_core+2),a
    in a,(07Fh)
    ld hl,v_generation
    cp (hl)
    ret
v_cache_store:
    call v_cache_address
    ld a,(v_core)
    out (07Fh),a
    ld a,(v_core+1)
    out (07Fh),a
    ld a,(v_core+2)
    out (07Fh),a
    ld a,(v_generation)
    out (07Fh),a
    ret

; Decode one independently initialized IMA block directly into sample RAM.
; The predictor is biased by 8000h, making signed saturation unsigned carry.
v_decode:
    ld hl,(v_free)
    ld a,(v_free+2)
    call v_address
    ld hl,(v_free)
    ld de,8
    add hl,de
    ld (v_core),hl
    ld a,(v_free+2)
    adc a,0
    ld (v_core+2),a
    ld hl,(v_unit)
    ld a,h
    or l
    jr nz,.load
    ld b,32
    call v_zeroes
    jr .loaded
.load:
    xor a
    ld (io_file),a
    ld (io_mode),a
    ld hl,v_file_offset
    ld de,pcm_position
    ld bc,4
    ldir
    ld hl,(v_samples)
    ld de,16
    add hl,de
    ld (pcm_remaining),hl
    call read_pcm_cached
    ld a,(io_error)
    or a
    jr z,.loaded
    xor a
    ld (v_enabled),a
    ld a,0E4h
    ld (v_status),a
    ret
.loaded:
    ld hl,(v_samples)
    ld de,16
    add hl,de
    ld de,(v_free)
    add hl,de
    ld (v_free),hl
    ld a,(v_free+2)
    adc a,0
    ld (v_free+2),a
    jp v_cache_store
v_zeroes:
    xor a
.loop:
    out (07Fh),a
    djnz .loop
    ret

v_header:
    ld e,(ix+4)
    ld d,0
    ld hl,(v_core)
    or a
    sbc hl,de
    ld a,(v_core+2)
    sbc a,0
    ld (v_header_buf),a       ; PCM8: top format bits are zero
    ld a,h
    ld (v_header_buf+1),a
    ld a,l
    ld (v_header_buf+2),a
    ld hl,(v_samples)
    add hl,de
    ld a,h
    ld (v_header_buf+3),a
    ld a,l
    ld (v_header_buf+4),a
    ld de,8
    add hl,de
    ex de,hl
    ld hl,0
    or a
    sbc hl,de
    ld a,h
    ld (v_header_buf+5),a
    ld a,l
    ld (v_header_buf+6),a
    ld a,(v_tone)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,de                ; twelve bytes per local header
    ld a,020h
    call v_address
    ld hl,v_header_buf
    ld b,12
.byte:
    ld a,(hl)
    out (07Fh),a
    inc hl
    djnz .byte
    ret

v_play:
    xor a
    ld (v_channel),a
    ld (v_skip),a
    ld a,0A2h
    ld (v_status),a
    ld a,2
    ld d,244
    call v_fm
    ld a,4
    ld d,080h
    call v_fm
    ld a,4
    ld d,001h             ; poll FT1 unmasked; CPU stays DI until stop/reset
    call v_fm
    ld ix,VSEQ
    di                       ; DOS player owns timing; BIOS IRQs cannot lose ticks
.event:
    ld c,(ix+0)
    ld b,(ix+1)
.wait:
    ld a,b
    or c
    jr z,.dispatch
    call v_tick
    ld a,(v_skip)
    or a
    jr nz,v_finished
    dec bc
    jr .wait
.dispatch:
    ld a,(ix+2)
    cp 255
    jr z,v_finished
    ld a,(v_channel)
    add a,068h
    ld d,0
    call v_wave
    ld a,(v_channel)
    add a,038h
    ld d,0E3h              ; octave -2, FNUM 462: 7999.585 samples/second
    call v_wave
    ld a,(v_channel)
    add a,020h
    ld d,09Dh
    call v_wave
    ld a,(ix+2)
    add a,128
    ld d,a
    ld a,(v_channel)
    add a,8
    call v_wave
.loaded:
    in a,(0C4h)
    and 3
    jr nz,.loaded
    ld a,(v_channel)
    add a,050h
    ld d,1
    call v_wave
    ld a,(v_channel)
    add a,068h
    ld d,080h
    call v_wave
    ld a,(v_channel)
    xor 1
    ld (v_channel),a
    ld de,6
    add ix,de
    jr .event
v_finished:
    ld a,4
    ld d,060h             ; stop both timers with IRQs masked before clearing
    call v_fm
    ld a,4
    ld d,080h
    call v_fm
    ld a,068h
    ld d,0
    call v_wave
    ld a,069h
    call v_wave
    ld a,(v_enabled)
    or a
    ret z                   ; preserve a hardware timeout status
    ld a,0A3h
    ld (v_status),a
    ret
v_tick:
    push hl
    ld hl,0
.poll:
    in a,(0C4h)
    and 040h
    jr nz,.ready
    dec hl
    ld a,h
    or l
    jr nz,.poll
    pop hl
    xor a
    ld (v_enabled),a
    ld a,0E5h               ; timer did not advance: return to game silently
    ld (v_status),a
    ld a,1
    ld (v_skip),a
    ret
.ready:
    pop hl
    ld a,4
    ld d,080h
    call v_fm
    push bc
    in a,(0AAh)
    and 0F0h
    or 7
    out (0AAh),a
    in a,(0A9h)              ; direct keyboard row 7, no BIOS IRQ during speech
    bit 2,a                 ; ESC skips the current spoken message
    jr z,.pressed
    ld a,1
    ld (v_escape_armed),a
    jr .ok
.pressed:
    ld a,(v_escape_armed)
    or a
    jr z,.ok
    xor a
    ld (v_escape_armed),a
    ld a,1
    ld (v_skip),a
.ok:
    pop bc
    ret

v_address:
    ld d,a
    ld a,3
    call v_wave
    ld d,h
    ld a,4
    call v_wave
    ld d,l
    ld a,5
    call v_wave
    call v_busy
    ld a,6
    out (07Eh),a
    ret
v_wave:
    push af
    call v_busy
    pop af
    out (07Eh),a
    call v_busy
    ld a,d
    out (07Fh),a
    ret
v_fm:
    push af
    call v_busy
    pop af
    out (0C4h),a
    call v_busy
    ld a,d
    out (0C5h),a
    ret
v_busy:
    in a,(0C4h)
    and 1
    jr nz,v_busy
    ret

v_enabled: db 0
v_status: db 0
v_text: dw 0
v_hash: dw 0
v_length: dw 0
v_return_slot: db 0
v_return_slot2: db 0
v_slot_rotations: db 0
v_src: dw 0
v_src_bank: db 0
v_generation: db 0
v_free: dw 00800h
    db 020h
v_core: ds 3,0
v_unit: dw 0
v_samples: dw 0
v_format: db 0
v_file_offset: ds 4,0
v_predictor: dw 0
v_index: db 0
v_code: db 0
v_half: db 0
v_packed: db 0
v_tone: db 0
v_channel: db 0
v_skip: db 0
v_escape_armed: db 1
v_header_buf: db 0,0,0,0,0,0,0,0,0F0h,0,0FFh,0
