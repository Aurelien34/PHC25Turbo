    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc
    include inc/car.inc

    section	code,text

    global data_car0, data_car1
    global precalc_shifted_cars
    global prepare_draw_car, draw_car, erase_car, update_car_position, update_car_angle_and_throttle, update_car_speed
    global temp_compute_bounce

THROTTLE_INCREMENT equ 2
THROTTLE_DECREMENT equ 4

data_car0:
    dc.w $ffff ; x
    dc.w $ffff ; y
    dc.b $ff ; angle
    dc.b $ff ; throttle
    dc.w $ffff ; speed x
    dc.w $ffff ; speed y
    dc.w RAM_MAP_PRECALC_VEHICLE_0; precalc sprites base address
    dc.w 0 ; sprite VRAM address (precomp)
    dc.w 0 ; shifted sprite data address (precomp)
    dc.w 0 ; background VRAM address (precomp)
    dc.w .background_data ; background backup data address (constant)
.background_data:
    dc.w 0, 0, 0, 0, 0, 0, 0, 0 ; background backup data

data_car1:
    dc.w $ffff ; x
    dc.w $ffff ; y
    dc.b $ff ; angle
    dc.b $ff ; throttle
    dc.w $ffff ; speed x
    dc.w $ffff ; speed y
    dc.w RAM_MAP_PRECALC_VEHICLE_1; precalc sprites base address
    dc.w 0 ; sprite VRAM address (precomp)
    dc.w 0 ; shifted sprite data address (precomp)
    dc.w 0 ; background VRAM address (precomp)
    dc.w .background_data ; background backup data address (constant)
.background_data:
    dc.w 0, 0, 0, 0, 0, 0, 0, 0 ; background backup data

precalc_shifted_cars:
    ; First, decompress the sprite to its target RAM area
    ld hl,huf_car0 ; compressed image in hl
    ld de,RAM_MAP_PRECALC_VEHICLE_0 ; target shifter car data memory area
    call decompress_huffman
    ld hl,RAM_MAP_PRECALC_VEHICLE_0
    ld (.ram_precalc_address),hl
    ld hl,RAM_MAP_PRECALC_VEHICLE_0+127
    ld (.ram_precalc_address_127),hl
    ld hl,RAM_MAP_PRECALC_VEHICLE_0+255
    ld (.ram_precalc_address_255),hl
    call .shiftcompute

    ld hl,huf_car1 ; compressed image in hl
    ld de,RAM_MAP_PRECALC_VEHICLE_1 ; target shifter car data memory area
    call decompress_huffman
    ld hl,RAM_MAP_PRECALC_VEHICLE_1
    ld (.ram_precalc_address),hl
    ld hl,RAM_MAP_PRECALC_VEHICLE_1+127
    ld (.ram_precalc_address_127),hl
    ld hl,RAM_MAP_PRECALC_VEHICLE_1+255
    ld (.ram_precalc_address_255),hl
    call .shiftcompute
    ret

.ram_precalc_address
    dc.w 0
.ram_precalc_address_127
    dc.w 0
.ram_precalc_address_255
    dc.w 0

.shiftcompute
    ; [de] points to precalc area
    ld de,(.ram_precalc_address_127)
    inc de
    ; backup an precompute the addresses

    ; Now, compute all right shifts
    ld ixh,1 ; current shift count
    ; [de] should now point 128 bytes farther
    ld hl,128
    ex de,hl
    add hl,de
    ex de,hl

.precalcloop
    ld hl,(.ram_precalc_address)
    ld iyh,128 ; rows to process
.rowloop:
    ld ixl,ixh ; shift counter
    ld b,(hl)
    ld a,$ff
.shiftloop:
    srl a
    srl b
    jr nc,.nocarry
    set 7,a
.nocarry:
    set 7,b
    dec ixl
    jr nz,.shiftloop

    ld c,a
    ld a,b
    ld (de),a
    inc de
    ld a,c
    ld (de),a
    inc de
    inc hl

    dec iyh
    jr nz,.rowloop

    inc ixh
    ld a,ixh
    cp 8
    jr nz,.precalcloop

    ; Double byte size for no shift (1 byte => 2 bytes)
    ld hl,(.ram_precalc_address_127)
    ld de,(.ram_precalc_address_255)
    ld b,128
.noshiftloop
    ld a,$ff
    ld (de),a
    dec de
    ld a,(hl)
    ld (de),a
    dec hl
    dec de
    dec b
    jr nz,.noshiftloop

    ret

prepare_draw_car:

    ; store previous sprite address as next background address for background restoration
    ld l,(ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS)
    ld h,(ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS+1)
    ld (ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS),l
    ld (ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS+1),h

    ; determine screen address => [hl]
    ; Y coordinate
    ld h,0
    ld l,(ix+CAR_OFFSET_Y+1)
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ; X coordinate
    ld b,0
    ld c,(ix+CAR_OFFSET_X+1)
    srl c
    srl c
    srl c
    add hl,bc
    ; And final result with base address
    ld bc,VRAM_ADDRESS ; base address
    add hl,bc
    ; Store new sprite VRAM address
    ld (ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS),l
    ld (ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS+1),h

    ; Determine the sprite shifting to be done
    ld a,(ix+CAR_OFFSET_X+1)
    ld b,7
    and b
    ld b,(ix+CAR_OFFSET_PRECALC_SPRITES_BASE_ADDRESS+1)
    add a,b ; Update high byte to point to the expected strip!
    ld (ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS+1),a
    ld a,(ix+CAR_OFFSET_ANGLE)
    and a,$f0
    ld b,(ix+CAR_OFFSET_PRECALC_SPRITES_BASE_ADDRESS)
    add a,b ; update the low byte to point to the correct angle
    ld (ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS),a

    ret

erase_car:
    ; hl = target screen address
    ; de = source background backup
    ld l,(ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS)
    ld h,(ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS+1)
    ld e,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS)
    ld d,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS+1)
    
    ld iyl,8
.eraseloop:
    ld bc,31
    ld a,(de)
    ld (hl),a
    inc de
    inc hl
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec iyl
    jp nz,.eraseloop

    ret

draw_car:
    ; de = target screen address
    ; hl = source sprite data
    ; bc = target background backup
    ld l,(ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS)
    ld h,(ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS+1)
    ld e,(ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS)
    ld d,(ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS+1)
    ld c,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS)
    ld b,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS+1)

    ld iyl,8
.drawloop:
    ; load and backup screen data
    ld a,(de)
    ld (bc),a
    ; load and display sprite
    and (hl)
    ld (de),a
    ; Move 1 byte right
    inc de
    inc bc
    inc hl
    ; load and backup screen data
    ld a,(de)
    ld (bc),a
    ; load and display sprite
    and (hl)
    ld (de),a
    ; Move 1 byte right
    inc bc
    inc hl
    ; Move screen pointer on the next line (31 byte to the right)
    push hl
    ld hl,31
    add hl,de
    ex de,hl
    pop hl

    dec iyl
    jp nz,.drawloop

    ret

update_car_position:
    ld c,(ix+CAR_OFFSET_SPEED_X)
    ld b,(ix+CAR_OFFSET_SPEED_X+1)
    ld l,(ix+CAR_OFFSET_X)
    ld h,(ix+CAR_OFFSET_X+1)
    add hl,bc
    ld (ix+CAR_OFFSET_X),l
    ld (ix+CAR_OFFSET_X+1),h

    ld c,(ix+CAR_OFFSET_SPEED_Y)
    ld b,(ix+CAR_OFFSET_SPEED_Y+1)
    ld l,(ix+CAR_OFFSET_Y)
    ld h,(ix+CAR_OFFSET_Y+1)
    add hl,bc
    ld (ix+CAR_OFFSET_Y),l
    ld (ix+CAR_OFFSET_Y+1),h
    ret

temp_compute_bounce:
.testleft:
    ld a,(ix+CAR_OFFSET_X+1)
    cp 16
    jp nc,.okleft
    add 2
    jp .swapx
.okleft:
    cp 232
    jp c,.okh
.koright:
    sub 2
.swapx:
    ld (ix+CAR_OFFSET_X+1),a
    ld l,(ix+CAR_OFFSET_SPEED_X)
    ld h,(ix+CAR_OFFSET_SPEED_X+1)
    ; neg hl
    xor a
    sub l
    ld l,a
    sbc a,a
    sub h
    ld h,a
    ld (ix+CAR_OFFSET_SPEED_X),l
    ld (ix+CAR_OFFSET_SPEED_X+1),h
.okh
.testtop:
    ld a,(ix+CAR_OFFSET_Y+1)
    cp 16
    jp nc,.oktop
    add 2
    jp .swapy
.oktop:
    cp 168
    jp c,.okv
.kobottom:
    sub 2
.swapy:
    ld (ix+CAR_OFFSET_Y+1),a
    ld l,(ix+CAR_OFFSET_SPEED_Y)
    ld h,(ix+CAR_OFFSET_SPEED_Y+1)

    ; neg hl
    xor a
    sub l
    ld l,a
    sbc a,a
    sub h
    ld h,a

    ld (ix+CAR_OFFSET_SPEED_Y),l
    ld (ix+CAR_OFFSET_SPEED_Y+1),h
.okv
    ret

update_car_angle_and_throttle:
    ; [a] contains keyboard state for this car
    bit INPUT_BIT_LEFT,a
    jp z,.noturnleft
    dec (ix+CAR_OFFSET_ANGLE)
    dec (ix+CAR_OFFSET_ANGLE)
    dec (ix+CAR_OFFSET_ANGLE)
.noturnleft
    bit INPUT_BIT_RIGHT,a
    jp z,.noturnright
    inc (ix+CAR_OFFSET_ANGLE)
    inc (ix+CAR_OFFSET_ANGLE)
    inc (ix+CAR_OFFSET_ANGLE)
.noturnright
    bit INPUT_BIT_FIRE,a
    ld a,(ix+CAR_OFFSET_THROTTLE) ; does not change flags
    jp z,.nothrottle
    add THROTTLE_INCREMENT
    jp c,.end
    jp .savethrottle
.nothrottle
    sub THROTTLE_DECREMENT
    jp nc,.savethrottle
    xor a
.savethrottle
    ld (ix+CAR_OFFSET_THROTTLE),a
.end
    ret

update_car_speed:
    ; Compute speed vector address => [hl]
    ld a,(ix+CAR_OFFSET_THROTTLE) ; does not change flags
    or a ; update flags => equivalent to cp 0
    jp nz,.not_braking
    ; Here, the car is braking
    ; Speed vectors should be 0,0
    ld (ix+CAR_OFFSET_SPEED_X),0
    ld (ix+CAR_OFFSET_SPEED_X+1),0
    ld (ix+CAR_OFFSET_SPEED_Y),0
    ld (ix+CAR_OFFSET_SPEED_Y+1),0
    jp .end
.not_braking:
    and %11000000 ; clear low 6 bits
    ld b,0
    ld c,a
    ld hl,speed_vectors
    add hl,bc

    ld a,(ix+CAR_OFFSET_ANGLE) ; load angle
    and $f0 ; clear low bits
    srl a
    srl a
    ld d,0 ; load speed address
    ld e,a
    add hl,de
    ; Load new vector in [de]
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    push hl ; store new vectors position
    
    ; Load old vector in [bc]
    ld c,(ix+CAR_OFFSET_SPEED_X)
    ld b,(ix+CAR_OFFSET_SPEED_X+1)

    call .add_vectors

    ; Update speed vector
    ld (ix+CAR_OFFSET_SPEED_X),l
    ld (ix+CAR_OFFSET_SPEED_X+1),h

    ; Same for Y axis
    pop hl
    ld e,(hl)
    inc hl
    ld d,(hl)

    ; Load old vector in [bc]
    ld c,(ix+CAR_OFFSET_SPEED_Y)
    ld b,(ix+CAR_OFFSET_SPEED_Y+1)

    call .add_vectors

    ; Update speed vector
    ld (ix+CAR_OFFSET_SPEED_Y),l
    ld (ix+CAR_OFFSET_SPEED_Y+1),h

.end:
    ret

; hl <- (3 x bc + de)/4
.add_vectors
    ;; Times 15
    ;ld h,b
    ;ld l,c
    ;push de
    ;ld d,h
    ;ld e,l
    ;; de contains 1 x bc
    ;add hl,hl
    ;ex de,hl
    ;add hl,de
    ;ex de,hl
    ;; de contains 3x bc
    ;add hl,hl
    ;ex de,hl
    ;add hl,de
    ;ex de,hl
    ;; de contains 7x bc
    ;add hl,hl
    ;ex de,hl
    ;add hl,de
    ;; hl contains 15x bc
    ;pop de
    ;add hl,de
    ;; hl contains 15 x bc + de
    ;; Divide by 16 (easy :/)
    ;sra h
    ;rr l
    ;sra h
    ;rr l
    ;sra h
    ;rr l
    ;sra h
    ;rr l
    ;ret



    ; Times 31
    ld h,b
    ld l,c
    push de
    ld d,h
    ld e,l
    ; de contains 1 x bc
    add hl,hl
    ex de,hl
    add hl,de
    ex de,hl
    ; de contains 3x bc
    add hl,hl
    ex de,hl
    add hl,de
    ex de,hl
    ; de contains 7x bc
    add hl,hl
    ex de,hl
    add hl,de
    ex de,hl
    ; de contains 15x bc
    add hl,hl
    ex de,hl
    add hl,de
    ; hl contains 31x bc
    pop de
    add hl,de
    ; hl contains 31 x bc + de
    ; Divide by 32 (easy :/)
    sra h
    rr l
    sra h
    rr l
    sra h
    rr l
    sra h
    rr l
    sra h
    rr l
    ret

    ; Times 3!
    ;ld h,b
    ;ld l,c
    ;add hl,hl
    ;add hl,bc
    ; Add new vector
    ;add hl,de
    ; Divide by 4 (easy :/)
    ;sra h
    ;rr l
    ;sra h
    ;rr l
    ;ret

; xx yy - one row for each 4 bits orientation value (2+2 bytes x 16 = 64 bytes)
speed_vectors:
; 4 groups of 64 bytes, one for each speed range
; Radius $40
    dc.w $0000, $ffc0
    dc.w $0019, $ffc5
    dc.w $002d, $ffd3
    dc.w $003b, $ffe7
    dc.w $0040, $0000
    dc.w $003b, $0019
    dc.w $002d, $002d
    dc.w $0019, $003b
    dc.w $0000, $0040
    dc.w $ffe7, $003b
    dc.w $ffd3, $002d
    dc.w $ffc5, $0019
    dc.w $ffc0, $0000
    dc.w $ffc5, $ffe7
    dc.w $ffd3, $ffd3
    dc.w $ffe7, $ffc5
; Radius $80
    dc.w $0000, $ff80
    dc.w $0031, $ff8a
    dc.w $005b, $ff45
    dc.w $0076, $ffcf
    dc.w $0080, $0000
    dc.w $0076, $0031
    dc.w $005b, $005b
    dc.w $0031, $0076
    dc.w $0000, $0080
    dc.w $ffcf, $0076
    dc.w $ff45, $005b
    dc.w $ff8a, $0031
    dc.w $ff80, $0000
    dc.w $ff8a, $ffcf
    dc.w $ff45, $ff45
    dc.w $ffcf, $ff8a
; Radius $c0
    dc.w $0000, $ff40
    dc.w $0049, $ff4f
    dc.w $0088, $ff78
    dc.w $00b1, $ffb7
    dc.w $00c0, $0000
    dc.w $00b1, $0049
    dc.w $0088, $0088
    dc.w $0049, $00b1
    dc.w $0000, $00c0
    dc.w $ffb7, $00b1
    dc.w $ff78, $0088
    dc.w $ff4f, $0049
    dc.w $ff40, $0000
    dc.w $ff4f, $ffb7
    dc.w $ff78, $ff78
    dc.w $ffb7, $ff4f
; Radius $100
    dc.w $0000, $ff00
    dc.w $0062, $ff13
    dc.w $00b5, $ff4b
    dc.w $00ec, $ff9e
    dc.w $0100, $0000
    dc.w $00ec, $0062
    dc.w $00b5, $00b5
    dc.w $0062, $00ec
    dc.w $0000, $0100
    dc.w $ff9e, $00ec
    dc.w $ff4b, $00b5
    dc.w $ff13, $0062
    dc.w $ff00, $0000
    dc.w $ff13, $ff9e
    dc.w $ff4b, $ff4b
    dc.w $ff9e, $ff13
