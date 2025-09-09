    include inc/rammap.inc
    include inc/screen.inc
    include inc/music.inc

    section	code,text

    global show_greetings

VRAM_TEXT equ VRAM_ADDRESS ; $6000
VRAM_ATTRIBUTES equ $6800
WAVE_DATA equ RAM_MAP_CIRCUIT_DATA


show_greetings:
    call ay8910_mute

.wait_for_no_inputs
    ; wait for keys release
    call keyboard_update_key_pressed
    jr c,.wait_for_no_inputs

    call clear_screen

    ; switch to text mode
    ld a,%00000110
    out ($40),a

    ; load text
    ld hl,rlh_greetingstext
    ld de,VRAM_TEXT
    call decompress_rlh

    ; Fill half of the screen in red
    call half_fill_screen

    ; uncompress wave data
    ld hl,rlh_greetingsdata
    ld de,WAVE_DATA
    call decompress_rlh

    ; wave index
    ld ixh,0

    ; Init music
    ld a,MUSIC_NUMBER_GREETINGS
    call music_init

.loop:

    call wait_for_vbl
    call wave
    call increment_wave_index

    if DEBUG = 1
    ; detect "out of VBL" VRAM accesses
    in a,($40)
    bit 4,a
.stop
    jr z,.stop
    endif

    ; Play music!
    call music_loop

    ; Read inputs
    call keyboard_update_key_pressed
	jr nc,.end_loop
    ; A key has been pressed
    ; check Konami code state
    ld hl,(konami_code_ptr)
    ld a,(keyboard_last_key_pressed_port)
    cp (hl)
    jr nz,reset_code
    inc hl
    ld a,(keyboard_last_key_pressed_bitmask)
    cp (hl)
    jr nz,reset_code
    inc hl
    ld (konami_code_ptr),hl
    ld a,(hl)
    or a
    jr z,konami_done
.wait_for_no_inputs_after_1_konami_key_press
    ; wait for keys release
    call keyboard_update_key_pressed
    jr c,.wait_for_no_inputs_after_1_konami_key_press
.end_loop:
    jr .loop

reset_code:
    ld hl,konami_code_data
    ld (konami_code_ptr),hl
    ret


half_fill_screen:

    ld hl,VRAM_ATTRIBUTES+16
    ld de,VRAM_ATTRIBUTES+17
    ld a,%100
    ld iyl,16
.loopy
    ld (hl),a
    ld bc,15
    ldir
    ld bc,17
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    dec iyl
    jr nz,.loopy
    ret

wave:
    ld de,VRAM_ATTRIBUTES+16-3
    ld iyl,16
.loopy:
    ld hl,WAVE_DATA
    ld b,0
    ld c,ixh
    add hl,bc

    ld c,6 ; b is already 0 !
    ldir

    ex de,hl
    ld bc,32-6
    add hl,bc
    ex de,hl

    call increment_wave_index

    dec iyl
    jr nz,.loopy
    ret

increment_wave_index:
    ld a,ixh
    add 6
    cp 96
    jr nz,.continue
    xor a
.continue
    ld ixh,a
    ret

konami_code_ptr:
    dc.w konami_code_data

konami_code_data:
    dc.b $80,~$10,$80,~$10,$81,~$10,$81,~$10,$82,~$10,$83,~$10,$82,~$10,$83,~$10,$85,~$08,$81,~$04,$00

konami_done:
    ; activate mirror mode
    ld hl,circuit_mirror_mode
    ld a,(hl)
    cpl
    ld (hl),a

    jr reset_code
    ret