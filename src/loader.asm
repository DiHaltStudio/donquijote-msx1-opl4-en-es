; One COM for DOS1 and DOS2/Nextor. Bank numbers 4..31 are logical; DOS2
; obtains their physical segments from ALL_SEG instead of occupying DOS RAM.
    org 0100h
    jp start
    jp disk_service           ; 0103h, called by the shared-bank trampoline
start:
    ld (dos_sp),sp
    ld bc,006Fh
    call bdos
    ld a,b
    ld (dos_version),a
.dos1:
    xor a
    ld (0F3DBh),a
    ld de,banner
    ld c,9
    call bdos
    ; Record the original mapper pages and complete RAM slot identity.
    in a,(0FCh)
    ld (dos_pages),a
    in a,(0FDh)
    ld (dos_pages+1),a
    in a,(0FEh)
    ld (dos_pages+2),a
    in a,(0FFh)
    ld (dos_pages+3),a
    ld b,0
.slot_loop:
    push bc
    call get_slot
    pop bc
    ld hl,dos_slots
    ld e,b
    ld d,0
    add hl,de
    ld (hl),a
    inc b
    ld a,b
    cp 4
    jr nz,.slot_loop
    ; Some Panasonic machines expose only two mapper read-back bits. Locate
    ; the actual DOS banks by temporary tags in unused TPA, not IN FC..FF.
    ld a,(dos_version)
    cp 2
    call c,detect_dos_pages
    ld a,(dos_version)
    cp 2
    call nc,init_dos2_mapper
    in a,(0A8h)
    ld (dos_primary),a
    ld a,(0FFFFh)
    cpl
    ld (dos_secondary),a
    ld b,0
.find_mfr:
    push bc
    ld e,b
    ld d,0
    ld hl,0FCC1h
    add hl,de
    bit 7,(hl)
    jr z,.not_mfr
    ld a,b
    or 088h
    ld (game_slot),a
    ld h,040h
    call 0024h
    di
    xor a
    out (0FDh),a
    ld a,(04000h)
    ld (probe31),a
    ld a,055h
    ld (04000h),a
    ld a,16
    out (0FDh),a
    ld a,(04000h)
    ld (probe30),a
    ld a,0AAh
    ld (04000h),a
    xor a
    out (0FDh),a
    ld a,(04000h)
    cp 055h
    ld a,0
    jr nz,.probed
    inc a
.probed:
    ld (probe_ok),a
    ld a,16
    out (0FDh),a
    ld a,(probe30)
    ld (04000h),a
    xor a
    out (0FDh),a
    ld a,(probe31)
    ld (04000h),a
    call restore_page1
    ld a,(probe_ok)
    or a
    jr nz,.mfr_found
.not_mfr:
    pop bc
    inc b
    ld a,b
    cp 4
    jr c,.find_mfr
    jp failure
.mfr_found:
    pop bc
    ld a,(dos_version)
    cp 2
    jp nc,allocate_dos2_segments
    ld hl,dos_pages
    ld de,dos_slots
    ld b,4
.check_private:
    ld a,(de)
    ld c,a
    ld a,(game_slot)
    cp c
    jr nz,.page_safe
    ld a,(hl)
    and 31
    cp 4
    jr c,.page_safe
    cp 20
    jp c,failure
.page_safe:
    inc hl
    inc de
    djnz .check_private
.private_safe:
    ; Exclude the four detected DOS bank numbers conservatively, including
    ; when some DOS pages actually live in internal RAM rather than the MFR.
    ld b,0
.cache_candidate:
    ld a,b
    cp 4
    jr c,.check_dos
    cp 20
    jr c,.used
.check_dos:
    ld hl,dos_pages
    ld c,4
.check_page:
    ld a,(hl)
    and 31
    cp b
    jr z,.used
    inc hl
    dec c
    jr nz,.check_page
.cache_free:
    ld a,(cache_bank_count)
    cp 12
    jr z,.used
    ld a,(cache_bank_count)
    ld e,a
    ld d,0
    ld hl,cache_banks
    add hl,de
    ld (hl),b
    inc a
    ld (cache_bank_count),a
.used:
    inc b
    ld a,b
    cp 32
    jr nz,.cache_candidate
    ld a,(cache_bank_count)
    cp 12
    jp nz,failure
    jp load_files

init_dos2_mapper:
    xor a
    ld de,0402h
    call 0FFCAh
    or a
    jp z,failure
    ld (mapper_alloc+1),hl
    ld de,01Bh
    add hl,de
    ld (mapper_get0+1),hl
    ld de,3
    add hl,de
    ld (mapper_put1+1),hl
    add hl,de
    ld (mapper_get1+1),hl
    ld de,6
    add hl,de
    ld (mapper_get2+1),hl
    add hl,de
    ld (mapper_get3+1),hl
    call mapper_get0
    ld (dos_pages),a
    call mapper_get1
    ld (dos_pages+1),a
    call mapper_get2
    ld (dos_pages+2),a
    call mapper_get3
    ld (dos_pages+3),a
    ret
mapper_alloc: jp 0
mapper_get0: jp 0
mapper_get1: jp 0
mapper_get2: jp 0
mapper_get3: jp 0
mapper_put1: jp 0

allocate_dos2_segments:
    ld hl,bank_map+4
    ld a,4
.next:
    ld (alloc_logical),a
    ld a,(game_slot)
    ld b,a                   ; select only this mapper, including secondary RAM
    xor a                    ; user segment, released automatically on exit
    call mapper_alloc
    jr c,.exhausted
    ld (hl),a
    inc hl
    ld a,(alloc_logical)
    cp 20
    jr c,.advance
    push hl
    sub 20
    ld e,a
    ld d,0
    ld hl,cache_banks
    add hl,de
    ld a,(alloc_logical)
    ld (hl),a
    ld hl,cache_bank_count
    inc (hl)
    pop hl
.advance:
    ld a,(alloc_logical)
    inc a
    cp 32
    jr c,.next
    jr load_files
.exhausted:
    ld a,(alloc_logical)
    cp 20
    jp c,failure             ; sixteen mandatory segments, cache is optional

load_files:
    ; Load immutable files to independent mapper banks.
    ld ix,load_table
.file:
    ld e,(ix+0)
    ld d,(ix+1)
    ld (load_fcb),de
    ld c,00Fh
    call bdos
    or a
    jp nz,failure
    ld hl,(load_fcb)
    ld de,14
    add hl,de
    ld (hl),1
    inc hl
    ld (hl),0
    ld hl,(load_fcb)
    ld de,33
    add hl,de
    ld b,4
.zero:
    ld (hl),0
    inc hl
    djnz .zero
    ld a,(ix+2)
    ld (load_bank),a
    ld a,(ix+3)
    ld (load_count),a
.chunk:
    ld de,08000h
    ld c,01Ah
    call bdos
    ld de,(load_fcb)
    ld hl,04000h
    ld c,027h
    call bdos
    ; Files in the load table are padded to complete 16 KiB blocks.
    or a
    jp nz,failure
    ld a,(game_slot)
    ld h,040h
    call 0024h
    di
    ld a,(load_bank)
    call map_loader_page1
    ld hl,08000h
    ld de,04000h
    ld bc,04000h
    ldir
    call restore_page1
    ld hl,load_bank
    inc (hl)
    ld hl,load_count
    dec (hl)
    jr nz,.chunk
    ld de,(load_fcb)
    ld c,010h
    call bdos
    ld de,4
    add ix,de
    ld a,(ix+0)
    or (ix+1)
    jp nz,.file
    ld de,voice_fcb
    ld c,00Fh
    call bdos
    or a
    jp nz,failure
    ld de,picture_fcb
    ld c,00Fh
    call bdos
    or a
    jp nz,failure
    ld hl,1
    ld (voice_fcb+14),hl
    ld (picture_fcb+14),hl
    ; Install the shared trampoline and its immutable context parameters.
    ld a,(game_slot)
    ld h,040h
    call 0024h
    di
    ld a,15
    call map_loader_page1
    ld hl,trampoline_blob
    ld de,06000h
    ld bc,trampoline_end-trampoline_blob
    ldir
    ld hl,dos_slots
    ld de,05008h
    ld bc,8
    ldir
    ld a,(game_slot)
    ld (05010h),a
    and 3
    ld c,a
    rlca
    rlca
    or c
    ld c,a
    rlca
    rlca
    rlca
    rlca
    or c
    ld (05014h),a
    ld a,(dos_primary)
    and 0F3h
    ld c,a
    ld a,(game_slot)
    and 3
    rlca
    rlca
    or c
    ld (05019h),a
    ld a,(dos_secondary)
    ld (0501Ah),a
    ld hl,(dos_sp)
    ld (05017h),hl
    ld hl,cache_banks
    ld de,05020h
    ld bc,12
    ldir
    ld a,(cache_bank_count)
    ld (05030h),a
    ld a,(dos_version)
    ld (05031h),a
    ld hl,bank_map
    ld de,05040h
    ld bc,32
    ldir
    ; Copy the initial BIOS/BASIC workspace to private game segment 7.
    ld a,7
    call map_loader_page1
    ld hl,0C000h
    ld de,04000h
    ld bc,04000h
    ldir
    ld hl,resident_blob
    ld de,06000h             ; E000 within game segment 7, mapped at page 1
    ld bc,resident_end-resident_blob
    ldir
    ld a,(game_slot)
    ld (06003h),a
    ld hl,bank_map
    ld de,07100h             ; resident BANK_MAP at F100 in logical segment 7
    ld bc,32
    ldir
    ; Boot trampoline is copied to segment 15, away from changed pages.
    ld a,15
    call map_loader_page1
    jp 06100h

map_loader_page1:
    push hl
    push de
    ld l,a
    ld h,0
    ld de,bank_map
    add hl,de
    ld a,(hl)
    out (0FDh),a
    pop de
    pop hl
    ret

; Slot B (0..3), from primary register and BIOS secondary mirrors.
get_slot:
    in a,(0A8h)
    ld c,b
    inc c
.rotate:
    dec c
    jr z,.primary
    rrca
    rrca
    jr .rotate
.primary:
    and 3
    ld e,a
    ld d,0
    ld hl,0FCC1h
    add hl,de
    ld a,(hl)
    and 080h
    or e
    ret p
    ld c,a
    in a,(0A8h)
    rlca
    rlca
    and 3
    cp e
    jr nz,.mirror
    ld a,(0FFFFh)
    cpl
    jr .actual
.mirror:
    ld hl,0FCC5h
    add hl,de
    ld a,(hl)
.actual:
    ld e,b
.shift:
    dec e
    jp m,.secondary
    rrca
    rrca
    jr .shift
.secondary:
    and 3
    rlca
    rlca
    or c
    ret
detect_dos_pages:
    di
    ld ix,dos_tags
    ld iy,tag_original
    ld b,4
.tag:
    push bc
    ld l,(ix+0)
    ld h,(ix+1)
    push hl
    push iy
    pop de
    ld bc,8
    ldir
    push ix
    pop hl
    ld de,6
    add hl,de
    pop de
    ld bc,8
    ldir
    ld de,14
    add ix,de
    ld de,8
    add iy,de
    pop bc
    djnz .tag
    ld ix,dos_tags
    ld iy,tag_slots
    ld a,4
    ld (tag_remaining),a
.page:
    ; DOS can put its TPA in external RAM and its kernel in internal RAM.
    ; Search each tag in the physical slot that actually owns that page.
    ld l,(iy+0)
    ld h,(iy+1)
    ld a,(hl)
    ld h,080h
    call 0024h
    di
    ld b,0
.candidate:
    ld a,b
    out (0FEh),a
    ld l,(ix+2)
    ld h,(ix+3)
    push ix
    pop de
    inc de
    inc de
    inc de
    inc de
    inc de
    inc de
    ld c,8
.compare:
    ld a,(de)
    cp (hl)
    jr nz,.different
    inc de
    inc hl
    dec c
    jr nz,.compare
    ld l,(ix+4)
    ld h,(ix+5)
    ld (hl),b
    ld de,14
    add ix,de
    inc iy
    inc iy
    ld hl,tag_remaining
    dec (hl)
    jr nz,.page
    jr .restore
.different:
    inc b
    ld a,b
    cp 32
    jr c,.candidate
    ; No mapper in the DOS RAM slot: unsupported boot arrangement.
    jp 0
.restore:
    ld a,(dos_slots+2)
    ld h,080h
    call 0024h
    di
    ld a,(dos_pages+2)
    out (0FEh),a
    ld ix,dos_tags
    ld hl,tag_original
    ld b,4
.untag:
    push bc
    ld e,(ix+0)
    ld d,(ix+1)
    ld bc,8
    ldir
    ld de,14
    add ix,de
    pop bc
    djnz .untag
    ei
    ret

restore_page1:
    ld a,(dos_pages+1)
    out (0FDh),a
    ld a,(dos_slots+1)
    ld h,040h
    call 0024h
    ei
    ret
bdos:
    push ix
    push iy
    call 5
    pop iy
    pop ix
    ret
failure:
    call restore_page1
    ld de,error_message
    ld c,9
    call bdos
    ld sp,(dos_sp)
    jp 0

; Runs in the original DOS page 0. Page 1 is scratch bank 15; pages 0/2/3
; and their slots/mapper segments are restored before entering here.
disk_service:
    ; DOS2 restores page 1 from its software mapper shadow on BDOS return.
    ; Publish the allocated shared segment as the caller's page while doing
    ; I/O, then restore DOS's shadow without losing the return trampoline.
    ld a,(dos_version)
    cp 2
    jr c,.ready
    ld a,(bank_map+15)
    call mapper_put1
.ready:
    call disk_service_body
    di
    ld a,(dos_version)
    cp 2
    ret c
    ld a,(dos_pages+1)
    call mapper_put1
    ld a,(bank_map+15)
    out (0FDh),a
    ret
disk_service_body:
    ld a,(05000h)
    or a
    ld de,picture_fcb
    jr nz,.fcb
    ld a,(05003h)
    rrca
    rrca
    rrca
    rrca
    and 15
    ld (requested_voice),a
    ld hl,voice_bank
    cp (hl)
    jr z,.voice_ready
    ld de,voice_fcb
    ld c,010h
    call bdos
    ld a,(requested_voice)
    ld (voice_bank),a
    add a,'0'
    ld (voice_fcb+6),a
    xor a
    ld hl,voice_fcb+12
    ld b,25
.clear:
    ld (hl),a
    inc hl
    djnz .clear
    ld de,voice_fcb
    ld c,00Fh
    call bdos
    inc a
    jp z,service_error
    ld hl,1
    ld (voice_fcb+14),hl
.voice_ready:
    ld de,voice_fcb
.fcb:
    ld (active_fcb),de
    push de
    ld hl,33
    add hl,de
    ex de,hl
    ld hl,05001h
    ld bc,4
    ldir
    pop de
    ld a,(05000h)
    or a
    jr nz,.offset_ready
    ld a,(voice_fcb+35)
    and 15
    ld (voice_fcb+35),a
    xor a
    ld (voice_fcb+36),a
.offset_ready:
    push de
    ld de,08000h
    ld c,01Ah
    call bdos
    pop de
    ld hl,(05005h)
    ld c,027h
    call bdos
    di
    push af
    ld a,(bank_map+15)
    out (0FDh),a
    ld a,(game_slot)
    ld h,040h
    call 0024h
    di
    pop af
    or a
    jr nz,service_error
    xor a
    ld (05013h),a
    ld a,(05007h)
    cp 2
    jr z,.mapper_cache
    or a
    jr nz,.vram
    ld hl,08000h
    ld de,(05005h)
    ld c,07Fh
.pcm:
    ld a,d
    or e
    ret z
    ld a,d
    or a
    jr z,.last
    ld b,0
    otir
    dec d
    jr .pcm
.last:
    ld b,e
    otir
    ret
.mapper_cache:
    ; No calls, stack access or interrupts while page 1 is replaced.
    ld a,(05016h)
    out (0FDh),a
    ld hl,08000h
    ld de,04000h
    ld bc,04000h
    ldir
    ld a,(bank_map+15)
    out (0FDh),a
    ret
.vram:
    xor a
    out (099h),a
    ld a,040h
    out (099h),a
    ld hl,08000h
    ld de,01000h
    call vram_block
    xor a
    out (099h),a
    ld a,060h
    out (099h),a
    ld de,01000h
vram_block:
    ld c,098h
.loop:
    ld b,0
.byte:
    outi
    jr nz,.byte             ; safe spacing for original TMS9918, including M1 waits
    dec d
    jr nz,.loop
    ret
service_error:
    ; An open failure may leave the DOS page-1 slot selected. Restore the
    ; shared bank before writing the result read by the trampoline.
    ld a,(bank_map+15)
    out (0FDh),a
    ld a,(game_slot)
    ld h,040h
    call 0024h
    di
    ld a,1
    ld (05013h),a
    ret

dos_version: db 0
banner: db 'DON QUIJOTE - MSX-DOS + OPL4',13,10,'Cargando datos...',13,10,'$'
error_message: db 13,10,'Error de disco o mapper de 512 KiB no disponible.',13,10,'$'
dos_sp: dw 0
dos_slots: ds 4,0
dos_pages: ds 4,0
game_slot: db 0
dos_primary: db 0
dos_secondary: db 0
probe_ok: db 0
cache_bank_count: db 0
cache_banks: ds 12,0
alloc_logical: db 0
bank_map: db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
          db 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
probe31: db 0
probe30: db 0
load_fcb: dw 0
load_bank: db 0
load_count: db 0
active_fcb: dw 0
voice_bank: db 0
requested_voice: db 0
load_table:
    dw branding_fcb
    db 4,3
    dw game_fcb
    db 8,7
    dw index_fcb
    db 16,1
    dw scores_fcb
    db 17,2
    dw vram_index_fcb
    db 19,1
    dw 0
    db 0,0
game_fcb: db 0,'GAME    DAT'
    ds 25,0
branding_fcb: db 0,'BRAND   DAT'
    ds 25,0
index_fcb: db 0,'INDEX   DAT'
    ds 25,0
scores_fcb: db 0,'SCORES  DAT'
    ds 25,0
vram_index_fcb: db 0,'VRAM    IDX'
    ds 25,0
voice_fcb: db 0,'VOICE0  PCM'
    ds 25,0
picture_fcb: db 0,'VRAM    DAT'
    ds 25,0
tag_slots: dw dos_slots+2,dos_slots,dos_slots+1,dos_slots+3
dos_tags:
    dw 0B000h,0B000h,dos_pages+2
    db 'QJ2DOS!!'
    dw 03000h,0B000h,dos_pages+0
    db 'QJ0DOS!!'
    dw 07000h,0B000h,dos_pages+1
    db 'QJ1DOS!!'
    dw 0C800h,08800h,dos_pages+3
    db 'QJ3DOS!!'
tag_original: ds 32,0
tag_remaining: db 0
trampoline_blob:
    incbin "../build/trampoline.bin"
trampoline_end:
resident_blob:
    incbin "../build/resident.bin"
resident_end:
    assert $<04000h
