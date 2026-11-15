; Shared mapper bank 15, page 1. Interrupts stay disabled while changing
; mapper contexts. DOS can span internal RAM and MFR; game RAM is in the MFR.
    org 06000h
io_enter:
    di
    ld sp,05FF0h
    ld a,(0500Ch)
    out (0FCh),a
    ld a,(0500Eh)
    out (0FEh),a
    ld a,(0500Fh)
    out (0FFh),a
    ld a,(05019h)
    out (0A8h),a
    ld a,(0500Bh)
    bit 7,a
    jr z,.dos_unexpanded
    ld a,(0501Ah)
    ld (0FFFFh),a
.dos_unexpanded:
    ld sp,(05017h)           ; disk ROMs need a stack outside page 1
    call 0103h
    ld sp,05FF0h
    di
    ld a,(05044h)
    out (0FCh),a
    ld a,(05046h)
    out (0FEh),a
    ld a,(05047h)
    out (0FFh),a
    ld a,(05014h)
    and 0FCh               ; original BIOS in primary 0
    out (0A8h),a
    ld a,0AAh
    ld (0FFFFh),a
    jp 0E1C0h
    assert $<=06100h
    defs 06100h-$,0
boot_game:
    di
    ld a,(05044h)
    out (0FCh),a
    ld a,(05046h)
    out (0FEh),a
    ld a,(05047h)
    out (0FFh),a
    ld a,(05014h)
    and 0FCh
    out (0A8h),a
    ld a,0AAh
    ld (0FFFFh),a
    ld sp,0F380h
    jp 0E000h
