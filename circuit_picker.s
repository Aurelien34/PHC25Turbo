    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc

    section	code,text

    global circuit_picker_circuit_index, circuit_picker_circuit_data_address, circuit_picker_circuits_names
    global circuit_picker_show

CURSOR_VRAM_ADDRESS equ 1+80*32+VRAM_ADDRESS

CIRCUIT_VRAM_ADDRESS equ 19+20*32+VRAM_ADDRESS
CIRCUIT_WIDTH equ 16
CIRCUIT_HEIGHT equ 12

circuits_list:
    dc.w rlh_circuit_monaco
    dc.w rlh_circuit_daytono
    dc.w rlh_circuit_take_it_easy
circuits_list_end:

circuit_picker_circuits_names:
    dc.w text_name_monaco
    dc.w text_name_daytono
    dc.w text_name_take_it_easy

block_texts_to_display:
    ; x is in 8 pixels increments, 32 increments for one row
    ; y is pixel perfect
    ; should end with a $0000 value
    ; Room for 32x9 characters
    dc.w 2+13*32+VRAM_ADDRESS, text_title_0
    dc.w 2+25*32+VRAM_ADDRESS, text_title_1
    dc.w 6+80*32+VRAM_ADDRESS, text_name_monaco
    dc.w 6+96*32+VRAM_ADDRESS, text_name_daytono
    dc.w 6+112*32+VRAM_ADDRESS, text_name_take_it_easy
    dc.w $0000

CIRCUIT_COUNT equ (circuits_list_end-circuits_list)/2

text_title_0:
    dc.b "Select your", 0
text_title_1:
    dc.b "circuit", 0

text_name_monaco:
    dc.b "Monaco",0
text_name_daytono:
    dc.b "Daytonneaux Speedway",0
text_name_take_it_easy:
    dc.b "Take it easy",0

circuit_picker_circuit_data_address:
    dc.w $ffff

circuit_picker_circuit_index:
    dc.b 0

previous_input_value:
    dc.b 0

circuit_picker_show:
    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd

    ; decompress round borders
    ld hl,rlh_round_borders
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32
    call decompress_rlh

    ; draw rectangles
    ; top left
    ld hl,0+1*32+VRAM_ADDRESS
    ld ix,16+53<<8
    call draw_black_rectangle
    
    ; top right
    ld hl,18+11*32+VRAM_ADDRESS
    ld ix,10+54<<8
    call draw_black_rectangle

    ; bottom
    ld hl,4+71*32+VRAM_ADDRESS
    ld ix,27+118<<8
    call draw_black_rectangle

    ; load "cursor"
    ld hl,rlh_car1
    ld de,RAM_MAP_PRECALC_VEHICLE_0
    call decompress_rlh

    ; Write text
    call wait_for_vbl
    ld ix,block_texts_to_display
    call write_text_block

    ; Show cursor for current position
    call show_cursor

    ; Draw current circuit miniature
    call select_circuit
.loop

    ; Wait for VBL
    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    ; Read inputs
    ld a,(previous_input_value)
    ld b,a
    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    cp b
    jr z,.no_input_change
    ld (previous_input_value),a

    bit INPUT_BIT_LEFT,a
    jp z,.not_left
    ; Left
    ld a,(circuit_picker_circuit_index)
    or a
    jr z,.inputs_end
    call erase_cursor
    dec a
    ld (circuit_picker_circuit_index),a
    call show_cursor
    call select_circuit
    jr .inputs_end
.not_left:
    bit INPUT_BIT_RIGHT,a
    jp z,.not_right
    ; Right
    ld a,(circuit_picker_circuit_index)
    cp CIRCUIT_COUNT-1
    jp z,.inputs_end
    call erase_cursor
    inc a
    ld (circuit_picker_circuit_index),a
    call show_cursor
    call select_circuit
    jr .inputs_end
.not_right:
    bit INPUT_BIT_FIRE,a
    jp z,.not_fire
    ; Fire
    ;call select_circuit
    ret
.not_fire:
.inputs_end:
.no_input_change:

    if DEBUG = 1
    call emulator_security_idle;
    endif

    ; Black on white
    ld a,%11110110
    out ($40),a

    jr .loop

select_circuit:
    ; Point circuit_picker_circuit_data_address to the correct circuit tile address
    ld b,0
    ld a,(circuit_picker_circuit_index)
    add a
    ld c,a
    ld hl,circuits_list
    add hl,bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld (circuit_picker_circuit_data_address),bc
    call draw_circuit_miniature
    ret

; Cursor position in [a]
compute_cursor_address:
    add a
    add a
    add a
    add a
    add a
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ex de,hl
    ld hl,CURSOR_VRAM_ADDRESS
    add hl,de
    ret

; Previous cursor position in [a]
erase_cursor:
    push af
    call compute_cursor_address
    ld bc,32
    ld d,8
    ld a,$ff
.loop
    ld (hl),a
    add hl,bc
    dec d
    jr nz,.loop
    pop af
    ret

show_cursor:
    ld a,(circuit_picker_circuit_index)
    call compute_cursor_address
    ld de,RAM_MAP_PRECALC_VEHICLE_0+64
    call copy_8x8_image
    ret

; source in [de]
; target in [hl]
copy_8x8_image:
    push hl
    push de
    push bc
    push ix

    ld bc,32
    ld ixl,8
.loop
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec ixl
    jr nz,.loop

    pop ix
    pop bc
    pop de
    pop hl
    ret

; start offset in [hl]
; expected width in [ixl]
; expected height in [ixh]
draw_black_rectangle:
    xor a
    dec ixl
    push hl
    push hl
.yloop:
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    ld b,0
    ld c,ixl
    ldir

    pop hl
    ld bc,32
    add hl,bc
    push hl

    dec ixh
    jr nz,.yloop
    pop hl

    ; bottom left
    ld bc,$ff00 ; (-32*8)
    add hl,bc
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32+16
    call copy_8x8_image

    ; bottom right
    ld b,0
    ld c,ixl
    add hl,bc
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32+24
    call copy_8x8_image

    ; top left
    pop hl
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32
    call copy_8x8_image

    ; top right
    ld b,0
    ld c,ixl
    add hl,bc
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32+8
    call copy_8x8_image

    ret

    dc.b "                    BREAKPOINT1                     "
draw_circuit_miniature:
    ; top right rectangle (todo: remove this!)
    ld hl,18+11*32+VRAM_ADDRESS
    ld ix,10+54<<8
    call draw_black_rectangle

    ; load the circuit
    ld hl,(circuit_picker_circuit_data_address)
    call load_circuit

    ; initialize circuit and screen pointers
    ld hl,RAM_MAP_CIRCUIT_DATA
    ld de,CIRCUIT_VRAM_ADDRESS

    ; loop on rows
    ld iyl,CIRCUIT_HEIGHT
.loopy:
    ; loop on groups of columns
    ld ixl,0
.loopx:
    ; load circuit tile info
    ld b,0
    ld c,(hl)
    srl c
    srl c
    srl c
    push hl
    ld hl,minitiles_data
    add hl,bc
    ld a,(hl)
    pop hl
    call draw_tile
    
    inc hl
    inc ixl
    ld a,ixl
    and %11
    jp nz,.continue
    inc de ; x is a multiple of 4, move to next 8 bits area
.continue
    ld a,ixl
    cp CIRCUIT_WIDTH
    jp nz,.loopx
    ex de,hl
    ld b,0
    ld c,32*2-4
    add hl,bc
    ex de,hl
    dec iyl
    jp nz,.loopy
    ret


; [a] = tile data
; [de] = mem destination
; [ixl] = x
; [iyl] = y
    dc.b "                    BREAKPOINT2                     "
draw_tile:
    push hl
    push bc
    push de
    
    ld c,a ; backup tile data

    ld a,ixl
    inc a
    neg
    and %11
    ld b,a ; b contains shift count

    ld a,c
    call .common_processing

    push bc
    ex de,hl
    ld bc,32
    add hl,bc
    pop bc
    ex de,hl

    ld a,ixl
    inc a
    neg
    and %11
    ld b,a ; b contains shift count

    ld a,c
    srl a
    srl a
    call .common_processing

    pop de
    pop bc
    pop hl
    ret

.common_processing:
    and %11 ; keep top row data
.shiftloop:
    dec b
    jp m,.shiftloop_end
    add a
    add a
    jr .shiftloop
.shiftloop_end:
    ld b,a
    ld a,(de)
    or b
    ld (de),a
    ret

minitiles_data:
    ; 1 first bits are image data for even rows. 2 next bits are for odd rows. 4 next bits are unused :(
    dc.b %1111 ; empty
    dc.b %0000 ; full
    dc.b %0000 ; vertical
    dc.b %0000 ; horizontal
    dc.b %0100 ; angle top-left
    dc.b %1000 ; angle top-right
    dc.b %0010 ; angle bottom-right
    dc.b %0001 ; angle bottom-left
    dc.b %0101 ; wall left
    dc.b %1100 ; wall top
    dc.b %1010 ; wall right
    dc.b %0011 ; wall bottom
    dc.b %1001 ; flag
    