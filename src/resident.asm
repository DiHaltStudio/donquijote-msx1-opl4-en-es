; Resident cartridge bridge. E000..F2FF is above both games' CLEAR limits.
; ROM is visible in page 1 only during copies, with interrupts disabled.
; Original program/data remain in their original RAM addresses.
JOINED equ 1
VOICE equ 1
BRAND_DOS equ 1
ENGLISH equ 0
BANK_MAP equ 0F100h           ; logical -> allocated physical mapper segments
    org 0E000h
    jp boot
cart_slot: db 0
bios_slot: db 0
part: db 0
rom_bank: db 0
descriptor: dw 0
    if VOICE
    jp voice_text             ; E009: complete table/object text
    jp voice_basic            ; E00C: BASIC string output
    jp voice_input            ; E00F: normalize keyboard letters for the parser
    jp draw_room              ; E012: complete picture from SD
    jp room_picture_first     ; E015: picture precedes room text and speech
    jp clear_picture          ; E018: preserve original clear and invalidate cache
    endif

boot:
    di
    ld sp,0F380h
    ; DOS remains in its original mapper segments; game owns 4..7.
    ld a,15
    call set_page1
    ld hl,05020h
    ld de,read_banks
    ld bc,12
    ldir
    ld a,(05030h)
    ld (read_cache_count),a
    ld a,(05031h)
    ld (runtime_dos_version),a
    ld hl,0500Ch
    ld de,runtime_dos_pages
    ld bc,4
    ldir
    ld a,5
    call set_page1
    ld a,(cart_slot)
    ld (0F341h),a
    ld (0F342h),a
    ld (0F343h),a
    ld (0F344h),a
    ; Remove DOS/disk hooks from the GAME workspace only.
    ld hl,0FD9Ah
    ld de,0FD9Bh
    ld bc,022Fh
    ld (hl),0C9h
    ldir
    ld hl,0F380h
    ld (0FC4Ah),hl
    ; DOS2 leaves BASIC's former stack top inside E000..EFFF. RUN uses it
    ; before the game's CLEAR executes, overwriting the speech resident.
    ld (0F672h),hl           ; MEMSIZ
    ld (0F674h),hl           ; STKTOP
    ; DOS occupied the former Disk BASIC file blocks. Recreate two closed
    ; entries before BASIC RUN's close-all pass; CLEAR later reallocates them.
    ld a,1
    ld (0F85Fh),a
    ld hl,0D600h
    ld (0F860h),hl
    ld hl,0D604h
    ld (0D600h),hl
    ld hl,0D70Dh
    ld (0D602h),hl
    xor a
    ld (0D604h),a
    ld (0D70Dh),a
    ld (0F87Ch),a
    ld hl,0
    ld (0F864h),hl
    ld hl,0D60Dh
    ld (0F862h),hl
    ld a,0C9h
    ld (0FEDAh),a
    ; Full slot ID of BIOS in page zero.
    in a,(0A8h)
    and 3
    ld c,a
    ld b,0
    ld hl,0FCC1h
    add hl,bc
    ld a,(hl)
    and 080h
    or c
    ld c,a
    jp p,.bios
    inc hl
    inc hl
    inc hl
    inc hl
    ld a,(hl)
    and 3
    rlca
    rlca
    or c
.bios:
    ld (bios_slot),a
    ld h,040h
    call 0024h
    di
    xor a
    ld (part),a
    ld (0F3DBh),a
    ld a,15
    ld (0F3E9h),a
    ld a,1
    ld (0F3EAh),a
    ld (0F3EBh),a
    ld a,2
    call 005Fh
    if VOICE
    call voice_init
    call branding_start
    endif
    xor a
    ld (0F3DBh),a
    call startup_select
    ld (descriptor),hl
next_file:
    di
    ld hl,(descriptor)
    ld a,(hl)
    inc hl
    ld (rom_bank),a
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    push bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    push bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    ld (descriptor),hl
    ; descriptor: bank, ROM pointer, count, destination, entry.
    ld (entry_operand+1),bc
    ex de,hl
    pop de
    pop bc
    call copy_rom
entry_operand:
    call 0
    call cover_after_entry
    ; SLOT's return is followed by the exact equivalent of loader BASIC line 3.
    ld hl,(entry_operand+1)
    ld de,09000h
    or a
    sbc hl,de
    call z,setup_game_slots
    jp next_file

return_only:
    ret

setup_game_slots:
    ld a,(cart_slot)
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
    ld (0DFCCh),a
    in a,(0A8h)
    ld (0DFCBh),a
    ld c,a
    rrca
    rrca
    and 00Ch
    or c
    ld (0DFC9h),a
    ld a,(0FFFFh)
    cpl
    and 0C0h
    ld c,a
    rrca
    rrca
    or c
    ld c,a
    rrca
    rrca
    or c
    ld c,a
    rrca
    rrca
    or c
    ld (0DFCAh),a
    ld (0FFFFh),a
    ret

; A bank in rom_bank; HL 4000..7FFF, DE >=8000 destination, BC count.
; Switch with BIOS ENASLT, preserving transfer registers across BIOS calls.
copy_rom:
    push hl
    push de
    push bc
    ld a,(cart_slot)
    ld h,040h
    call 0024h
    di
    ld a,(rom_bank)
    call set_page1
    pop bc
    pop de
    pop hl
.byte:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    dec bc
    ld a,b
    or c
    jr z,.done
    bit 7,h
    jr z,.byte
    ld hl,04000h
    ld a,(rom_bank)
    inc a
    ld (rom_bank),a
    call set_page1
    jr .byte
.done:
    ld a,5
    call set_page1
    ld a,(bios_slot)
    ld h,040h
    call 0024h
    di
    ret

    assert $<=0E1C0h
    defs 0E1C0h-$,0
io_return:
    ld a,(05013h)
    ld (io_error),a
    ; Leave the shared page-1 stack before a CALL changes that page's bank.
    ld sp,(io_saved_sp)
    ; DOS may change a secondary slot hidden behind the current RAM slot.
    ; On turbo R, DOS2 leaves MSX-MUSIC (0.2) in page 1 of primary 0.
    ; The original USR return only writes A8, assuming BASIC is still there.
    ; Restore that hidden BIOS/BASIC selection through ENASLT, then put the
    ; shared RAM slot back before restoring the caller's mapper segment.
    ld a,(bios_slot)
    ld h,040h
    call 0024h
    di
    ld a,(cart_slot)
    ld h,040h
    call 0024h
    di
    ld a,(io_saved_bank)
    call set_page1
    exx
    pop hl
    pop de
    pop bc
    exx
    ex af,af'
    pop af
    ex af,af'
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ret

    if JOINED
    assert $ <= 0E200h
    defs 0E200h-$,0
; Replaces USR2's first three bytes in part A only. Other messages follow
; the original DF67 -> 7694 -> DF73 call chain. Numeric BASIC result remains
; in the original DAC. Message 83 is the natural completion predicate.
response_bridge:
    ld a,(0F7F8h)
    push af
    call 0DF67h
    call 07694h
    call 0DF73h
    pop af
    cp 83
    ret nz
    ; Keep the ending visible and use the original "press a key" message.
    ld a,243
    ld (0F7F8h),a
    call 0DF67h
    call 07694h
    call 0DF73h
    ei
    call 009Fh
transition_b:
    di
    ld sp,0F380h
    ld a,(bios_slot)
    ld h,040h
    call 0024h
    di
    ; The tape bootstrap runs SCREEN 2 before SCREEN. Its picture loader
    ; leaves names 1A00..1AFF untouched, so restore their canonical mapping
    ; instead of reusing the final text rows from part A.
    ld a,2
    call 005Fh
    di
    ld a,1
    ld (part),a
    ld hl,part_b
    ld (descriptor),hl
    jp next_file
    endif

    if VOICE
    include "voice.asm"
    include "disk.asm"
    include "../../common/branding.asm"
    include "../../common/startup_select.asm"
runtime_dos_version: db 1
runtime_dos_pages: ds 4,0
    endif
COVER_ENTRY equ 08800h
    include "../../common/cover_wait.asm"
    include "../build/files.inc"
    assert $ <= 0F000h
