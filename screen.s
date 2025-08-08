    section	code,text

    global clear_screen
    global switch_to_mode_graphics
    global wait_for_vbl
    global rotate_left
    global count_remaining_hbl
    global wait_for_hbl_count
    global wait_for_vbl_count

; Switch to graphics mode 128x96
switch_to_mode_graphics:
    push af
    ld a,%11110110
    out ($40),a
    pop af
    ret

rotate_left:

    ld de,$6000 ; target address
    ld ixh,192  ; row counter
.rowloop
    ld h,d      ; source address high
    ld l,e      ; source address low
    inc hl       ; source address low

    ld a,(de)
    ld ixl,a    ; backup data goes to ix 

    ld bc,31
    ldir        ; copy the row

    ld a,ixl
    ld (de),a
    inc de
    dec ixh
    jr nz,.rowloop

    ret

clear_screen:
    ld hl,$6000
    ld de,$6800
    ld b,$30
.loop1
    ld a,$80
.loop2
    ld (hl),$ff
    inc hl
    ld (de),$ff
    inc de
    dec a
    jr nz,.loop2
    dec b
    jr nz,.loop1

    ret

wait_for_vbl:

.stop
    in a,($40)
    bit 4,a
    jr nz,.stop

.start
    in a,($40)
    bit 4,a
    jr z,.start

    ret

; Count how many hbl occurred until vbl
; Return value in register a
count_remaining_hbl:
    push bc
    ld b,0
    
.wait_for_no_vbl:
    in a,($40)
    bit 4,a ; vbl?
    jr nz,.wait_for_no_vbl
.wait_for_no_hbl:
    in a,($40)
    bit 7,a ; hbl?
    jr nz,.wait_for_no_hbl
.wait_for_vbl_or_hbl:
    in a,($40)
    bit 4,a ; vbl?
    jr nz,.endwait
    in a,($40)
    bit 7,a ; hbl?
    jr z,.wait_for_vbl_or_hbl
    inc b ; hbl detected
    jr .wait_for_no_hbl
.endwait:
    ld a,b
    pop bc
    ret

; Expected count in register c
wait_for_hbl_count:
.waitForStop:
    ;in a,($40)
    ;bit 7,a
    ;jr nz,.waitForStop
.waitForStart:
    in a,($40)
    bit 7,a
    jr z,.waitForStart
    dec c
    jr nz,.waitForStop
    ret

; Expected count in register c
wait_for_vbl_count:
    push bc
    push af
.waitForStop:
    in a,($40)
    bit 4,a
    jr nz,.waitForStop
.waitForStart:
    in a,($40)
    bit 4,a
    jr z,.waitForStart
    dec c
    jr nz,.waitForStop
    pop af
    pop bc
    ret

wait_for_vbl_count_unsafe:
.waitForStop:
    in a,($40)
    bit 4,a
    jr nz,.waitForStop
.waitForStart:
    in a,($40)
    bit 4,a
    jr z,.waitForStart
    dec c
    jr nz,.waitForStop
    ret
