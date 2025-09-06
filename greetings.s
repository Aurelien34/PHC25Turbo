    include inc/rammap.inc
    include inc/screen.inc
    include inc/music.inc

    section	code,text

    global show_greetings

show_greetings:
    call ay8910_mute

.wait_for_no_inputs
    ; wait for keys release
    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    or a
    jr nz,.wait_for_no_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
    or a
    jr nz,.wait_for_no_inputs


    call clear_screen

    ; switch to text mode
    ld a,%00000110
    out ($40),a

    ; load text
    ld hl,rlh_greetingstext
    ld de,VRAM_ADDRESS
    call decompress_rlh

    ; Fill half of the screen in red
    call half_fill_screen

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
    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    or a
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
    or a
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM

    jr .loop

    ret

half_fill_screen:

    ld hl,$6800+16
    ld de,$6800+17
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
    ld de,$6800+16-3
    ld iyl,16
.loopy:
    ld a,ixh
    ld hl,wavedata
    ld b,0
    ld c,a
    add hl,bc

    ld bc,6
    ldir

    ex de,hl
    ld bc,32-6
    add hl,bc
    ex de,hl

    call increment_wave_index

    dec iyl
    jr nz,.loopy
    ret

wavedata:
    dc.b 4,4,4,4,4,4
    dc.b 0,4,4,4,4,4
    dc.b 0,0,4,4,4,4
    dc.b 0,0,0,4,4,4
    dc.b 0,0,0,0,4,4
    dc.b 0,0,0,0,4,4
    dc.b 0,0,0,0,0,4
    dc.b 0,0,0,0,0,0
    dc.b 0,0,0,0,0,0
    dc.b 0,0,0,0,0,4
    dc.b 0,0,0,0,4,4
    dc.b 0,0,0,4,4,4
    dc.b 0,0,4,4,4,4
    dc.b 0,0,4,4,4,4
    dc.b 0,4,4,4,4,4
    dc.b 4,4,4,4,4,4

increment_wave_index:
    ld a,ixh
    add 6
    cp 96
    jr nz,.continue
    xor a
.continue
    ld ixh,a
    ret