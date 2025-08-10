    include inc/screen.inc
    section	code,text

    global clear_screen
    global switch_to_mode_graphics_hd, switch_to_mode_graphics_sd_green, switch_to_mode_graphics_sd_white
    global wait_for_vbl, wait_for_vbl_count

; Switch to graphics mode 128x192
switch_to_mode_graphics_sd_green:
    ld a,%10010110
    out ($40),a
    ret

switch_to_mode_graphics_sd_white:
    ld a,%11010110
    out ($40),a
    ret

; Switch to graphics mode 256x192
switch_to_mode_graphics_hd:
    ld a,%11110110
    out ($40),a
    ret

; [a] contains the byte to be copied
clear_screen:
    ld hl,VRAM_ADDRESS
    ld de,VRAM_ADDRESS+1
    ld (hl),a
    ld bc,256/8*192-1
    ldir
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
