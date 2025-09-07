    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc
    include inc/music.inc
    
    section	code,text

    global show_intro

INTRO_RAM_MAP_IMAGE_0_A equ RAM_MAP_PRECALC_VEHICLE_1
INTRO_RAM_MAP_IMAGE_0_B equ INTRO_RAM_MAP_IMAGE_0_A+81
INTRO_RAM_MAP_IMAGE_0_C equ INTRO_RAM_MAP_IMAGE_0_B+81
INTRO_RAM_MAP_IMAGE_HELMET_A equ INTRO_RAM_MAP_IMAGE_0_C+81
INTRO_RAM_MAP_IMAGE_HELMET_B equ INTRO_RAM_MAP_IMAGE_HELMET_A+20
INTRO_RAM_MAP_FONT equ INTRO_RAM_MAP_IMAGE_HELMET_B+20


block_texts_to_display:
    ; x is in 8 pixels increments, 32 increments for one row
    ; y is pixel perfect
    ; should end with a $0000 value
    ; Room for 32x9 characters
    dc.w 0+98*32+VRAM_ADDRESS, sz_line_0
    dc.w 10+109*32+VRAM_ADDRESS, sz_line_1
    dc.w 0+118*32+VRAM_ADDRESS, sz_line_2
    dc.w 0+127*32+VRAM_ADDRESS, sz_line_3
    dc.w 0+136*32+VRAM_ADDRESS, sz_line_4
    dc.w 0+145*32+VRAM_ADDRESS, sz_line_5
    dc.w 0+160*32+VRAM_ADDRESS, sz_line_6
    dc.w 4+184*32+VRAM_ADDRESS, sz_line_7
    dc.w 10+85*32+VRAM_ADDRESS, sz_line_ready
    dc.w $0000

sz_line_0:
    dc.b "Keys are:",0
sz_line_1:
    dc.b "P1     P2",0
sz_line_2:
    dc.b "> Left:   D      K",0
sz_line_3:
    dc.b "> Right:  F      L",0
sz_line_4:
    dc.b "> Accel:  S      J",0
sz_line_5:
    dc.b "> Back to menu: RETURN",0
sz_line_6:
    dc.b "Accelerate to start;;;",0
sz_line_7:
    dc.b "PHC25 < Bouz 2025 for RPUFOS",0
sz_line_ready:
    dc.b "Ignite your engines;;;",0

DIGIT_COUNT equ 3
DIGIT_IMAGE_SEQUENCE_COUNT equ 3

digit_image_sequences: ; 3 is the empty image
    dc.b (1<<2)+2
    dc.b (0<<2)+1
    dc.b (0<<2)+2

digit_positions:
    dc.w 20/4+51*32+VRAM_ADDRESS
    dc.w 32/4+50*32+VRAM_ADDRESS
    dc.w 44/4+49*32+VRAM_ADDRESS

digit_color_bitmaps_addresses:
    dc.w INTRO_RAM_MAP_IMAGE_0_A
    dc.w INTRO_RAM_MAP_IMAGE_0_B
    dc.w INTRO_RAM_MAP_IMAGE_0_C

helmets_compressed_bitmaps_addresses:
    dc.w rlh_intro_helmet_a
    dc.w rlh_intro_helmet_b
    dc.w rlh_intro_helmet_c
    dc.w rlh_intro_helmet_a
    dc.w rlh_intro_helmet_b

WHEELS_UP_BIT equ 0
WHEELS_SWAPPED_BIT equ 1
WHEELS_MOVED_BIT equ 2

IMAGE_SWAP_BIT equ 3

WHEEL_HEIGHT equ 11
WHEELS_ANIMATION_STEP equ 200
DIGIT_IMAGE_HEIGHT equ 27
DIGIT_ANIMATION_STEP equ 4
IMAGE_ANIMATION_STEP equ 8

HELMET_POSITION equ 84/4+48*32+VRAM_ADDRESS
HELMET_IMAGE_HEIGHT equ 10

digit_animation_counter:
    dc.w 0
image_animation_counter:
    dc.w 0
wheels_animation_counter:
    dc.w 0
anim_status:
    dc.b 0
wheel1_address_up:
    dc.w 72/4+65*32+VRAM_ADDRESS     ; wheel 1 coordinates in the image
wheel2_address_up:
    dc.w 96/4+65*32+VRAM_ADDRESS    ; wheel 2 coordinates in the image
wheel1_address_down:
    dc.w 72/4+66*32+VRAM_ADDRESS
wheel2_address_down:
    dc.w 96/4+66*32+VRAM_ADDRESS

show_intro:
    call ay8910_mute

    xor a
    call clear_screen ; clear whole screen, but we don't have the color we want for the bottom of the screen
    call switch_to_mode_graphics_sd_white

    ; Initialize variables
    ld a,1<<WHEELS_UP_BIT
    ld (anim_status),a

    ; Decompress top image
    ld hl,rlh_introscreen
    ld de,VRAM_ADDRESS
    call decompress_rlh

    ; Write text
    ld ix,block_texts_to_display
    call write_text_block

    ; Decompress 0 digits
    ld hl,rlh_intro_0
    ld de,INTRO_RAM_MAP_IMAGE_0_A
    call decompress_rlh

    ; Decompress helmets
    ld a,r ; a bit of random here
    and %11
    add a
    ld b,0
    ld c,a
    ld hl,helmets_compressed_bitmaps_addresses
    add hl,bc
    ex de,hl
    ld a,(de)
    ld l,a
    inc de
    ld a,(de)
    ld h,a
    inc de
    push de
    ld de,INTRO_RAM_MAP_IMAGE_HELMET_A
    call decompress_rlh
    pop de
    ld a,(de)
    ld l,a
    inc de
    ld a,(de)
    ld h,a
    ld de,INTRO_RAM_MAP_IMAGE_HELMET_B
    call decompress_rlh

    ld a,MUSIC_NUMBER_INTRO
    call music_init

.intro_loop:

    call wait_for_vbl
    call switch_to_mode_graphics_sd_green

    call animate_wheels
    call animate_digits
    call animate_helmet

    if DEBUG = 1
    call emulator_security_idle
    endif
    
    call switch_to_mode_graphics_sd_white

    call update_animation
    call music_loop

    ; Read inputs
    call update_inputs
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    bit INPUT_BIT_FIRE,a
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM
    bit INPUT_BIT_GREETINGS,a
    jr nz,.greetings
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
    bit INPUT_BIT_FIRE,a
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM
    jr .end_controls

.greetings:
    call show_greetings
    jp show_intro

.end_controls:

    jr .intro_loop

animate_wheels:
    ld hl,wheels_animation_counter+1
    ld a,(hl)
    ld hl,anim_status
    bit 0,a
    jr z,.clear_swapped
    bit WHEELS_SWAPPED_BIT,(hl)
    jr nz,.introscreenwheels_swap_end
    jr .go_swap

.clear_swapped:
    res WHEELS_SWAPPED_BIT,(hl)
    jr .introscreenwheels_swap_end
    
.go_swap:
    ; Need to swap wheels
    ; Update status
    set WHEELS_SWAPPED_BIT,(hl)
    ; Determine the addresses to use for data transfer
    call .load_wheels_positions
    ld de,31
    exx
    ld de,31
    exx
    ld b,WHEEL_HEIGHT
.copy_loop:
    ld a,(hl)
    exx
    ld c,(hl)
    ld (hl),a
    ld a,c
    inc hl
    exx
    ld (hl),a
    inc hl
    ld a,(hl)
    exx
    ld c,(hl)
    ld (hl),a
    ld a,c
    add hl,de
    exx
    ld (hl),a
    add hl,de
    dec b
    jr nz,.copy_loop

.introscreenwheels_swap_end:

    ; Time to animate wheels vertically
    ld hl,wheels_animation_counter+1
    ld a,(hl)
    ld hl,anim_status
    and %11
    jr nz,.clear_moved
    bit WHEELS_MOVED_BIT,(hl)
    jr nz,.introscreenwheels_move_end
    jr .go_move
.clear_moved:
    res WHEELS_MOVED_BIT,(hl)
    jr .introscreenwheels_move_end
.go_move:
    ; need to move wheels
    ; Update status
    set WHEELS_MOVED_BIT,(hl)
    ; Determine the addresses to use for data transfer
    call .load_wheels_positions
    bit WHEELS_UP_BIT,c ; up or down?
    jr nz,.move_down
    ; move up
    call .do_move_up
    exx 
    call .do_move_up
    jr .update_position_status
.move_down:
    call .do_move_down    
    exx
    call .do_move_down
.update_position_status:
    ; Update status
    ld a,(anim_status)
    bit WHEELS_UP_BIT,a
    jr z,.position_to_1
    res WHEELS_UP_BIT,a
    jr .ok_position_bit
.position_to_1:
    set WHEELS_UP_BIT,a
.ok_position_bit:
    ld (anim_status),a
.introscreenwheels_move_end:
    ; Increment animation counter
    ld hl,(wheels_animation_counter)
    ld bc,WHEELS_ANIMATION_STEP
    add hl,bc
    ld (wheels_animation_counter),hl
    ret

; status in [C]
.load_wheels_positions:
    ld hl,anim_status
    ld c,(hl) ; status in [c]
     bit WHEELS_UP_BIT,c
    jr z,.wheels_down
    ; wheels are up
    ld hl,(wheel1_address_up)
    exx
    ld hl,(wheel2_address_up)
    exx
    ret
.wheels_down:
    ; wheels are down
    ld hl,(wheel1_address_down)
    exx
    ld hl,(wheel2_address_down)
    exx
    ret

; [hl] contains top of the wheel
.do_move_down:
    ; Point to the correct rows
    ld d,h
    ld e,l
    ld bc,32*(WHEEL_HEIGHT-1)
    add hl,bc
    ld bc,32*(WHEEL_HEIGHT)
    ex de,hl
    add hl,bc
    ex de,hl
    ld bc,$ffdf ; -33
    ld ixl,WHEEL_HEIGHT
.do_move_down_loop:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    dec ixl
    jr nz,.do_move_down_loop
    xor a
    ld (de),a
    inc de
    ld (de),a
    ret

; [hl] contains top of the wheel
.do_move_up:
    ; Point to the correct rows
    ld d,h
    ld e,l
    ld bc,$ffe0 ; -32
    add hl,bc
    ex de,hl
    ld bc,31
    ld ixl,WHEEL_HEIGHT
.do_move_up_loop:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    add hl,bc
    ex de,hl
    add hl,bc
    ex de,hl
    dec ixl
    jr nz,.do_move_up_loop
    xor a
    ld (de),a
    inc de
    ld (de),a
    ret

animate_digits:
    ; determine the target digit
    ld a,(digit_animation_counter+1)
    add a ; times 2 as we will read a VRAM address
    ld h,0
    ld l,a
    ld bc,digit_positions
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a ; hl nowpoints to the screen
    ex de,hl ; back it up in de
    ; Now we whe to decide what image to show
    ld hl,digit_image_sequences
    ld b,0
    ld a,(image_animation_counter+1)
    ld c,a
    add hl,bc
    ld b,(hl) ; [b] now contains the sequence
    ; Decide on what part of the sequence to point to
    ld a,(anim_status)
    bit IMAGE_SWAP_BIT,a
    ld a,b
    jr z,.show_second
    ; show first
    srl a
    srl a
.show_second:
    and %11 ; a now points to the bitmap index to be displayed
    cp 3
    jr nz,.continue_with_an_image
    ; We need to clear the digit on the screen
    call .clear_digit
    jr .flip_anim_bit
.continue_with_an_image:
    add a
    ld b,0
    ld c,a
    ld hl,digit_color_bitmaps_addresses
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a ; hl now points to the bitmap data
    ex de,hl
    call .show_0_bloc ; Show the digit
.flip_anim_bit
    ; Now flip the animation bit
    ld a,(anim_status)
    bit IMAGE_SWAP_BIT,a
    jr z,.flipTo1
    ; flip to 0
    res IMAGE_SWAP_BIT,a
    jr .end
.flipTo1
    set IMAGE_SWAP_BIT,a
.end
    ld (anim_status),a
    ret

; source in de, target in hl (to be able to quickly add bc to target)
.show_0_bloc
    ld bc,32-2
    ld iyl,DIGIT_IMAGE_HEIGHT
.show_0_bloc_loop
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
    jr nz,.show_0_bloc_loop
    ret

; de points to the area to be cleared
.clear_digit
    ex de,hl
    ld bc,32-2
    xor a
    ld d,DIGIT_IMAGE_HEIGHT
.clear_digit_loop
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    add hl,bc
    dec d
    jr nz,.clear_digit_loop
    ret

update_animation:
    ; Increment image animation counter
    ld hl,image_animation_counter
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld hl,IMAGE_ANIMATION_STEP
    add hl,bc
    ld b,h
    ld c,l
    ld a,b ; the high byte is now in a
    cp DIGIT_IMAGE_SEQUENCE_COUNT ; reached the maximum number of sequences
    jr nz,.ok_image_sequence
    xor a
    ld b,a
    ld c,a
.ok_image_sequence    
    ld hl,image_animation_counter
    ld (hl),c
    inc hl
    ld (hl),b

    ; Now increment digit animation counter
    ld hl,digit_animation_counter
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld hl,DIGIT_ANIMATION_STEP
    add hl,bc
    ld b,h
    ld c,l
    ld a,b ; th high byte is in a
    cp 3 ; reached the maximum number of sequences
    jr c,.ok_digit
    xor a
    ld b,a
    ld c,a
.ok_digit
    ld hl,digit_animation_counter
    ld (hl),c
    inc hl
    ld (hl),b


    ret

animate_helmet:
    ld hl,anim_status
    bit IMAGE_SWAP_BIT,(hl)
    jr z,.image_a
    ld de,INTRO_RAM_MAP_IMAGE_HELMET_B
    jr .go
.image_a
    ld de,INTRO_RAM_MAP_IMAGE_HELMET_A
.go
    ld hl,HELMET_POSITION
    ld bc,32-1
    ld iyl,HELMET_IMAGE_HEIGHT
.row_loop
    ld a,(de)
    ld (hl),a
    inc hl
    inc de
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec iyl
    jr nz,.row_loop
    ret
