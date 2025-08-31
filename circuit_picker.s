    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc
    include inc/car.inc

    section	code,text

    global circuit_picker_circuit_index, circuit_picker_circuit_data_address, circuit_picker_circuits_names
    global circuit_picker_show

CURSOR_POSITION_BASE_X equ 10
CURSOR_POSITION_BASE_Y equ 60

CIRCUIT_FRAME_VRAM_ADDRESS equ 25+6*32+VRAM_ADDRESS
CIRCUIT_VRAM_ADDRESS equ CIRCUIT_FRAME_VRAM_ADDRESS+1+5*32
CIRCUIT_WIDTH equ 16
CIRCUIT_HEIGHT equ 12

circuits_list:
    dc.w rlh_circuit_take_it_easy
    dc.w rlh_circuit_you_turn
    dc.w rlh_circuit_daytono
    dc.w rlh_circuit_monaco
circuits_list_end:

circuit_picker_circuits_names:
    dc.w text_name_take_it_easy
    dc.w text_name_you_turn
    dc.w text_name_daytono
    dc.w text_name_monaco

block_texts_to_display:
    ; x is in 8 pixels increments, 32 increments for one row
    ; y is pixel perfect
    ; should end with a $0000 value
    ; Room for 32x9 characters
    dc.w 2+9*32+VRAM_ADDRESS, text_title_0
    dc.w 1+23*32+VRAM_ADDRESS, text_title_1
    dc.w 6+(CURSOR_POSITION_BASE_Y)*32+VRAM_ADDRESS, text_name_take_it_easy
    dc.w 6+(CURSOR_POSITION_BASE_Y+16)*32+VRAM_ADDRESS, text_name_you_turn
    dc.w 6+(CURSOR_POSITION_BASE_Y+32)*32+VRAM_ADDRESS, text_name_daytono
    dc.w 6+(CURSOR_POSITION_BASE_Y+48)*32+VRAM_ADDRESS, text_name_monaco
    dc.w $0000

CIRCUIT_COUNT equ (circuits_list_end-circuits_list)/2

text_title_0:
    dc.b "SELECT YOUR CIRCUIT", 0
text_title_1:
    dc.b "=1= for 1P =2= for 2P", 0

text_name_take_it_easy:
    dc.b "Take it easy",0
text_name_you_turn:
    dc.b "You turn",0
text_name_daytono:
    dc.b "Daytonneaux Speedway",0
text_name_monaco:
    dc.b "Monaco",0

circuit_picker_circuit_data_address:
    dc.w $ffff

circuit_picker_circuit_index:
    dc.b 0

previous_input_value:
    dc.b 0

circuit_picker_show:

    ; shut the audio chip
    call ay8910_mute

    ; Clear the screen
    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd

    ; decompress round borders
    ld hl,rlh_round_borders
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32
    call decompress_rlh

    ; draw rectangles
    ; top left
    ld hl,0+2*32+VRAM_ADDRESS
    ld ix,23+38<<8
    call draw_black_rectangle
    
    ; top right
    ld hl,24+0*32+VRAM_ADDRESS
    ld ix,8+45<<8
    call draw_black_rectangle

    ; circuit frame
    ld de,CIRCUIT_FRAME_VRAM_ADDRESS
    call draw_circuit_frame

    ; bottom
    ld hl,4+50*32+VRAM_ADDRESS
    ld ix,27+(192-50)<<8
    call draw_black_rectangle

    ; load "cursor"
    call precalc_shifted_cars
        
    ; Write text
    ld ix,block_texts_to_display
    call write_text_block

    ; Show cursor for current position
    ld ix,data_car0 ; current car is number 0
    ld (ix+CAR_OFFSET_X+1),CURSOR_POSITION_BASE_X
    ld a,(circuit_picker_circuit_index)
    call compute_car_position
    call prepare_draw_car
    call draw_car

    ; Draw current circuit miniature
    call select_circuit
.loop
    ; Compute car/cursor display
    ld ix,data_car0 ; current car is number 0
    call compute_car_position
    call prepare_draw_car

    ; Wait for VBL
    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    ; Erase and redraw the car/cursor sprite
    ld ix,data_car0 ; current car is number 0
    call erase_car
    call draw_car

    ; Read inputs
    ld a,(previous_input_value)
    ld b,a
    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    cp b
    jr z,.check_2p_start
    ld (previous_input_value),a

    bit INPUT_BIT_LEFT,a
    jp z,.not_left
    ; Left
    ld a,(circuit_picker_circuit_index)
    or a
    jr z,.inputs_end
    dec a
    ld (circuit_picker_circuit_index),a
    call select_circuit
    jr .inputs_end
.not_left:
    bit INPUT_BIT_RIGHT,a
    jp z,.not_right
    ; Right
    ld a,(circuit_picker_circuit_index)
    cp CIRCUIT_COUNT-1
    jp z,.inputs_end
    inc a
    ld (circuit_picker_circuit_index),a
    call select_circuit
    jr .inputs_end
.not_right:
    bit INPUT_BIT_ESC,a
    jp z,.not_esc
    xor a
    ld (players_count),a
    ret
.not_esc:
    bit INPUT_BIT_START,a
    jp z,.not_start1
    ld a,1
    ld (players_count),a
    ret
.check_2p_start:
.not_start1:
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
    bit INPUT_BIT_START,a
    jp z,.not_start2
    ld a,2
    ld (players_count),a
    ret
.not_start2:
.inputs_end:

    if DEBUG = 1
    call emulator_security_idle;
    endif

    ; Black on white
    ld a,%11110110
    out ($40),a

    jp .loop

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

compute_car_position:
    ld a,(circuit_picker_circuit_index)
    add a
    add a
    add a
    add a
    ld d,CURSOR_POSITION_BASE_Y
    add d
    ld (IX+CAR_OFFSET_Y+1),a

    ld hl,data_car0+CAR_OFFSET_ANGLE
    inc (hl)
    inc (hl)
    inc (hl)

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

draw_circuit_miniature:

    ; Black on white
    ld a,%11110110
    out ($40),a

    ; load the circuit
    ld hl,(circuit_picker_circuit_data_address)
    call load_circuit

    ; clear targer area
    ld hl,RAM_MAP_PRECALC_VEHICLE_1
    ld de,RAM_MAP_PRECALC_VEHICLE_1+1
    ld bc,4*CIRCUIT_HEIGHT*2-1
    ld (hl),0
    ldir

    ; initialize circuit and target pointers
    ld hl,RAM_MAP_CIRCUIT_DATA
    ld de,RAM_MAP_PRECALC_VEHICLE_1

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
    inc de
    inc de
    inc de
    inc de
    dec iyl
    jp nz,.loopy

    ; Wait for VBL
    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    if DEBUG = 1
    call emulator_security_idle;
    endif

    ; now copy the buffer to the screen
    ld de,RAM_MAP_PRECALC_VEHICLE_1
    ld hl,CIRCUIT_VRAM_ADDRESS
    ld bc,32-3
    ld iyl,CIRCUIT_HEIGHT*2
.loopyfinal
    ld a,(de)
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec iyl
    jr nz,.loopyfinal

    ; Black on white
    ld a,%11110110
    out ($40),a

    ret


; [a] = tile data
; [de] = mem destination
; [ixl] = x
; [iyl] = y
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

    inc de
    inc de
    inc de
    inc de

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

; video target in [hl]
draw_circuit_frame:
    push de
    ld hl,rlh_circuit_frame
    ld de,RAM_MAP_PRECALC_VEHICLE_1
    call decompress_rlh
    ld hl,RAM_MAP_PRECALC_VEHICLE_1
    pop de
    ld bc,32-6
    ld iyl,30
.loopy
    ld bc,6
    ldir

    ld bc,32-6
    ex de,hl
    add hl,bc
    ex de,hl

    dec iyl
    jr nz,.loopy
    ret