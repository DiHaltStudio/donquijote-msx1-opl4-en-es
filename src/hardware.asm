; Preflight in DOS context, before any game resource is opened.
; Probe only page 1 under DI; restore every RAM byte before BIOS/BDOS.
hw_probe_mapper:
    di
    ld a,(game_slot)
    ld h,040h
    call 0024h
    di
    ld hl,hw_saved
    ld b,0
.save:
    ld a,b
    out (0FDh),a
    ld a,(05234h)
    ld (hl),a
    inc hl
    ld a,(06A55h)
    ld (hl),a
    inc hl
    inc b
    ld a,b
    cp 32
    jr nz,.save
    ld b,0
.write:
    ld a,b
    out (0FDh),a
    xor 05Ah
    ld (05234h),a
    cpl
    ld (06A55h),a
    inc b
    ld a,b
    cp 32
    jr nz,.write
    ld bc,0
.read:
    ld a,b
    out (0FDh),a
    xor 05Ah
    ld d,a
    ld a,(05234h)
    cp d
    jr nz,.next
    ld a,d
    cpl
    ld d,a
    ld a,(06A55h)
    cp d
    jr nz,.next
    inc c
.next:
    inc b
    ld a,b
    cp 32
    jr nz,.read
    ld a,c
    ld (hw_mapper_segments),a
    ld hl,hw_saved
    ld b,0
.restore:
    ld a,b
    out (0FDh),a
    ld a,(hl)
    ld (05234h),a
    inc hl
    ld a,(hl)
    ld (06A55h),a
    inc hl
    inc b
    ld a,b
    cp 32
    jr nz,.restore
    jp restore_page1

hw_check:
    call hw_probe_opl4
    ld de,hw_heading
    call hw_print
    ld de,hw_ram_label
    call hw_print
    ld a,(hw_mapper_segments)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    call hw_number
    ld de,hw_ram_need
    call hw_print
    ld de,hw_opl_label
    call hw_print
    ld a,(hw_opl_timeout)
    or a
    jr nz,.absent
    ld a,(hw_opl_present)
    or a
    jr z,.absent
    ld a,(hw_opl_pages)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    call hw_number
    ld de,hw_opl_need
    call hw_print
    jr .result
.absent:
    ld de,hw_no_opl
    call hw_print
.result:
    ld a,(hw_opl_timeout)
    or a
    jr nz,hw_reject
    ld a,(hw_mapper_segments)
    cp 32
    jr nz,hw_reject
    ld a,(hw_opl_pages)
    cp 32
    jr nz,hw_reject
    ld a,(hw_opl_present)
    cp 1
    jr nz,hw_reject
    ret
hw_ready:
    call hw_print_reserved
    ld de,hw_ok
    call hw_print
hw_confirm:
    ld c,8
    call bdos
    cp 13
    jr nz,hw_confirm
    ret
hw_print_reserved:
    ld de,hw_free_label
    call hw_print
    ld a,(hw_reserved)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    call hw_number
    ld de,hw_free_need
    jp hw_print
hw_alloc_failed:
    call hw_print_reserved
    ld de,hw_alloc_error
    call hw_print
    ld sp,(dos_sp)
    jp 0
hw_reject:
    ld a,(hw_mapper_segments)
    or a
    ld de,hw_slot_missing
    call z,hw_print
    ld de,hw_failed
    call hw_print
    ; All probes restored the original DOS context; no game banks reserved.
    ld sp,(dos_sp)
    jp 0
hw_print:
    ld c,9
    jp bdos
hw_number:
    ld de,hw_digits+5
    xor a
    ld (de),a
.next_digit:
    ld bc,10
    ; HL / 10, DE buffer cursor, B remainder. Small bounded subtraction.
    push de
    ld de,0
.divide:
    or a
    sbc hl,bc
    jr c,.remainder
    inc de
    jr .divide
.remainder:
    add hl,bc
    ld a,l
    add a,'0'
    ex de,hl
    pop de
    dec de
    ld (de),a
    ld a,h
    or l
    jr nz,.next_digit
    ; Decimal buffer terminator is DOS's '$'.
    ld a,'$'
    ld (hw_digits+5),a
    jp hw_print

; Status wait is bounded, including when a non-OPL4 device drives BUSY high.
hw_busy:
    push bc
    ld bc,0
.loop:
    in a,(0C4h)
    bit 0,a
    jr z,.ready
    dec bc
    ld a,b
    or c
    jr nz,.loop
    pop bc
    ld a,1
    ld (hw_opl_timeout),a
    scf
    ret
.ready:
    pop bc
    or a
    ret
hw_wave:
    push af
    call hw_busy
    jr c,.failed
    pop af
    out (07Eh),a
    call hw_busy
    ret c
    ld a,d
    out (07Fh),a
    jp hw_busy
.failed:
    pop af
    scf
    ret
hw_address:
    ld d,a
    ld a,3
    call hw_wave
    ld a,4
    ld d,0
    call hw_wave
    ld a,5
    call hw_wave
    ld a,6
    out (07Eh),a
    jp hw_busy
hw_probe_opl4:
    ld a,5
    out (0C6h),a
    call hw_busy
    ret c
    ld a,3
    out (0C5h),a
    call hw_busy
    ret c
    ld a,2
    out (07Eh),a
    call hw_busy
    ret c
    in a,(07Fh)
    and 0E0h
    cp 020h
    ret nz
    ld a,1
    ld (hw_opl_present),a
    ld a,2
    ld d,011h
    call hw_wave
    ; Tag all thirty-two 64 KiB pages before reading any. Mirrored pages
    ; retain only the last tag and cannot masquerade as additional RAM.
    ld b,0
.write:
    ld a,b
    add a,020h
    call hw_address
    ld a,b
    xor 05Ah
    out (07Fh),a
    cpl
    out (07Fh),a
    inc b
    ld a,b
    cp 32
    jr nz,.write
    ld bc,0
.read:
    ld a,b
    add a,020h
    call hw_address
    in a,(07Fh)
    ld e,a
    ld a,b
    xor 05Ah
    cp e
    jr nz,.next
    cpl
    ld e,a
    in a,(07Fh)
    cp e
    jr nz,.next
    inc c
.next:
    inc b
    ld a,b
    cp 32
    jr nz,.read
    ld a,c
    ld (hw_opl_pages),a
    ; Return to read-only memory mode; the player initializes it afterwards.
    ld a,2
    ld d,010h
    jp hw_wave

hw_reserved: db 0
hw_error: dw hw_mapper_error
hw_mapper_segments: db 0
hw_opl_timeout: db 0
hw_opl_present: db 0
hw_opl_pages: db 0
hw_saved: ds 64,0
hw_digits: ds 6,0
    if ENGLISH
hw_mapper_error: db 'Mapper unavailable or required banks in use.',13,10,'$'
hw_heading: db 13,10,'MEMORY REQUIREMENTS',13,10,'$'
hw_ram_label: db 'Compatible mapper RAM: $'
hw_ram_need: db ' KiB addressable (required: 512).',13,10,'$'
hw_opl_label: db 'OPL4 sample RAM: $'
hw_opl_need: db ' KiB (minimum: 2048 KiB).',13,10,'$'
hw_no_opl: db 'OPL4 not detected or not responding.',13,10,'$'
hw_ok: db 'Memory OK. Press ENTER to start.',13,10,'$'
hw_slot_missing: db 'No compatible RAM slot found by this loader.',13,10,'RAM may exist in another slot/interface.',13,10,'$'
hw_free_label: db 'RAM reserved for game: $'
hw_free_need: db ' KiB (minimum: 256).',13,10,'$'
hw_disk_error: db 'Cannot open/read game data file: $'
hw_alloc_error: db 'Not enough free RAM segments for game.',13,10,'$'
hw_failed: db 'Cannot start: a requirement is missing.',13,10,'$'
    else
hw_mapper_error: db 'Mapper no disponible o bancos ocupados.',13,10,'$'
hw_heading: db 13,10,'REQUISITOS DE MEMORIA',13,10,'$'
hw_ram_label: db 'RAM mapper compatible: $'
hw_ram_need: db ' KiB accesibles (minimo: 512).',13,10,'$'
hw_opl_label: db 'RAM de muestras OPL4: $'
hw_opl_need: db ' KiB (minimo: 2048 KiB).',13,10,'$'
hw_no_opl: db 'OPL4 ausente o no responde.',13,10,'$'
hw_ok: db 'Memoria OK. Pulsa ENTER para empezar.',13,10,'$'
hw_slot_missing: db 'Cargador: no hay slot RAM compatible.',13,10,'Puede haber RAM en otra interfaz o slot.',13,10,'$'
hw_free_label: db 'RAM reservada para el juego: $'
hw_free_need: db ' KiB (minimo: 256).',13,10,'$'
hw_disk_error: db 'No se puede abrir/leer archivo de datos: $'
hw_alloc_error: db 'Faltan segmentos RAM libres para juego.',13,10,'$'
hw_failed: db 'No se puede iniciar: falta un requisito.',13,10,'$'
    endif
