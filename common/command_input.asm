; Shared command editor boundary. One 32-column row includes the live cursor.
COMMAND_MAX_CHARS equ 31
voice_input:
.read:
    call 009Fh
    cp 8                    ; deletion and submission remain available at limit
    ret z
    cp 13
    ret z
    cp 32                   ; discard cursor/control keys instead of printing them
    jr c,.read
    cp 'a'
    jr c,.upper
    cp 'z'+1
    jr nc,.upper
    sub 32
.upper:
    cp 'Z'+1                ; same printable range as the original command loop
    jr nc,.read
    push af
    push hl
    push de
    ld hl,(0738Ch)          ; next write address
    ld de,(0738Eh)          ; original command-buffer base
    or a
    sbc hl,de
    ld de,COMMAND_MAX_CHARS
    or a
    sbc hl,de               ; reject length >= limit independently of screen wrap
    jr nc,.full
    pop de
    pop hl
    pop af
    ret
.full:
    pop de
    pop hl
    pop af
    jr .read
