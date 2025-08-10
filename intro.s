    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc
    
    section	code,text

    global show_intro

block_texts_to_display:
    ; x is in 8 pixels increments, 32 increments for one row
    ; y is pixel perfect
    ; should end with a $0000 value
    ; Room for 32x9 characters
    dc.w 0+98*32+VRAM_ADDRESS, sz_line_0
    dc.w 0+109*32+VRAM_ADDRESS, sz_line_1
    dc.w 0+118*32+VRAM_ADDRESS, sz_line_2
    dc.w 0+129*32+VRAM_ADDRESS, sz_line_3
    dc.w 0+141*32+VRAM_ADDRESS, sz_line_4
    dc.w 0+151*32+VRAM_ADDRESS, sz_line_5
    dc.w 0+161*32+VRAM_ADDRESS, sz_line_6
    dc.w 0+184*32+VRAM_ADDRESS, sz_line_7
    dc.w 23+104*32+VRAM_ADDRESS, sz_joy_0
    dc.w 23+114*32+VRAM_ADDRESS, sz_joy_1
    dc.w 23+124*32+VRAM_ADDRESS, sz_joy_2

    dc.w $0000

sz_line_0:
    dc.b "Keys are:",0
sz_line_1:
    dc.b "> 1 player start  : 1",0
sz_line_2:
    dc.b "> 2 players start : 2",0
sz_line_3:
    dc.b "          P1     P2",0
sz_line_4:
    dc.b "> Left:   Left   d",0
sz_line_5:
    dc.b "> Right:  Right  f",0
sz_line_6:
    dc.b "> Accel:  Space  s",0
sz_line_7:
    dc.b "Bouz<@AurelienBricole for RPUFOS",0
sz_joy_0:
    dc.b "Joysticks",0
sz_joy_1:
    dc.b "supported",0
sz_joy_2:
    dc.b "soon;",0

cycle_count_half_screen:
    dc.w 0

show_intro:

    call switch_to_mode_graphics_sd_white
    ld a,$00
    call clear_screen ; clear whole screen, but we don't have the color we want for the bottom of the screen

    call count_screen_cycles

    ; Decompress font
    ld hl,huf_smallfont
    ld de,RAM_MAP_PRECALC_AREA
    call decompress_huffman

    ; Write text
    ld hl,RAM_MAP_PRECALC_AREA
    ld ix,block_texts_to_display
    call write_text_block

    ; Decompress top image
    ld hl,huf_introscreen
    ld de,VRAM_ADDRESS
    call decompress_huffman

.intro_loop:

    call wait_half_screen
    call switch_to_mode_graphics_hd

    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    bit INPUT_BIT_START,a
    jp z,.notStart1
    ld a,1
    ld (players_count),a
    ret
.notstart1:
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
    bit INPUT_BIT_START,a
    jp z,.notStart2
    ld a,2
    ld (players_count),a
    ret
.notstart2:


    call wait_for_vbl
    call switch_to_mode_graphics_sd_white
    jr .intro_loop

    ret

count_screen_cycles:
    ld bc,0 ; loop counter in [bc]
    ; wait for vbl
.vbl:
    in a,($40)
    bit 4,a
    jr z,.vbl
    ; wait for end of VBL => top of the screen
.novbl:
    in a,($40)
    bit 4,a
    jr nz,.novbl
    ; now we count until next VBL => bottom of the screen
.count_loop
    inc bc              ; 6 cycles
    in a,($40)          ; 11 cycles
    bit 4,a             ; 8 cycles
    jr z,.count_loop   ; 12 cycles => Total 37 cycles

.end_count
    srl b ; divide by 2
    rr c
    ; Add security margin (argl) due to differences between emulator and real machine
    ld hl,50
    add hl,bc
    ld b,h
    ld c,l
    ld hl,cycle_count_half_screen
    ld (hl),c
    inc hl
    ld (hl),b
    ret

wait_half_screen:
    ld hl,cycle_count_half_screen
    ld c,(hl)
    inc hl
    ld b,(hl)
    ; wait for end of VBL => top of the screen
.novblwait:
    in a,($40)
    bit 4,a
    jr nz,.novblwait
.half_wait_loop
    in a,($40)              ; 11 cycles (only here to consume cycles)
    dec bc                  ; 6 cycles
    ld a,b                  ; 4 cycles
    or c                    ; 4 cycles
    jr nz,.half_wait_loop   ; 12 cycles

    ret

clear_screen_bottom:
    ld hl,VRAM_ADDRESS+6144/2
    ld de,VRAM_ADDRESS+6144/2+1
    ld (hl),$ff
    ld bc,256/8*192/2-1
    ldir
    ret