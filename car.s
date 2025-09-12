    include inc/rammap.inc
    include inc/screen.inc
    include inc/inputs.inc
    include inc/car.inc
    include inc/ay8910.inc
    include inc/circuit.inc

    section	code,text

    global data_car0, data_car1
    global precalc_shifted_cars
    global prepare_draw_car, draw_car, erase_car, update_car_position, update_car_angle_and_throttle, update_car_speed, update_car_engine_sound
    global compute_engine_enveloppe
    global car_set_lap_count

THROTTLE_INCREMENT equ 2
THROTTLE_DECREMENT equ 4

data_engine_enveloppe:
    dc.b $10
    dc.b $43
    dc.b $76
    dc.b $a9
    dc.b $dc
    dc.b $bf
    dc.b $48
    dc.b $02

car_set_lap_count:
    ld (data_car0+CAR_OFFSET_REMAINING_LAPS),a
    ld (data_car1+CAR_OFFSET_REMAINING_LAPS),a
    ret

data_car0:
    dc.w $ffff ; x
    dc.w $ffff ; y
    dc.b $ff ; angle
    dc.b $ff ; throttle
    dc.w $ffff ; speed x
    dc.w $ffff ; speed y
    dc.w RAM_MAP_PRECALC_VEHICLE_0; precalc sprites base address
    dc.b AY8910_REGISTER_FREQUENCY_A_LOWER ; AY8910 sound frequency register
    dc.b AY8910_REGISTER_VOLUME_A ; AY8910 sound frequency register
    dc.w $ffff ; engine sound enveloppe counter
    dc.b 1 ; remaining laps + finish line status
    dc.w 0 ; sprite VRAM address (precomp)
    dc.w 0 ; shifted sprite data address (precomp) => lower bit says we have to use mirror display
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
    dc.b AY8910_REGISTER_FREQUENCY_B_LOWER ; AY8910 sound frequency register
    dc.b AY8910_REGISTER_VOLUME_B ; AY8910 sound frequency register
    dc.w $ffff ; engine sound enveloppe counter
    dc.b 1 ; remaining laps + finish line status
    dc.w 0 ; sprite VRAM address (precomp)
    dc.w 0 ; shifted sprite data address (precomp)
    dc.w 0 ; background VRAM address (precomp)
    dc.w .background_data ; background backup data address (constant)
.background_data:
    dc.w 0, 0, 0, 0, 0, 0, 0, 0 ; background backup data

compute_engine_enveloppe:
    ; load enveloppe counter
    ld c,(ix+CAR_OFFSET_ENGINE_SOUND_ENVELOPPE_COUNTER)
    ld b,(ix+CAR_OFFSET_ENGINE_SOUND_ENVELOPPE_COUNTER+1)
    ; add some variations to avoir resonance
    ld a,r
    add a
    add c
    ld c,a
    ; load throttle
    ld a,(ix+CAR_OFFSET_THROTTLE)
    or $70 ; ensure throttle is not null
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    ; add throttle to counter
    add hl,bc
    ; save counter value
    ld (ix+CAR_OFFSET_ENGINE_SOUND_ENVELOPPE_COUNTER),l
    ld (ix+CAR_OFFSET_ENGINE_SOUND_ENVELOPPE_COUNTER+1),h
    ; Compute enveloppe index (0-7)
    ld a,h
    ld d,a ; backup the "index"
    rra
    and $07
    ld l,a
    ld h,0
    ld bc,data_engine_enveloppe
    add hl,bc
    ; prepare audio channel
    ld a,(ix+CAR_OFFSET_AY8910_SOUND_VOLUME_REGISTER)
    AY_PUSH_REG
    ; load corresponding enveloppe level
    ld a,(hl)
    bit 0,d
    jr z,.no_rotation
    rra    
    rra    
    rra    
    rra    
.no_rotation:
    and $0f
    AY_PUSH_VAL
    ret

precalc_shifted_cars:
    ; First, decompress the sprite to its target RAM area
    ld hl,rlh_car0 ; compressed image in hl
    ld de,RAM_MAP_PRECALC_VEHICLE_0 ; target shifter car data memory area
    call decompress_rlh
    ld hl,RAM_MAP_PRECALC_VEHICLE_0
    ld (.ram_precalc_address),hl
    call .shiftcompute

    ld hl,rlh_car1 ; compressed image in hl
    ld de,RAM_MAP_PRECALC_VEHICLE_1 ; target shifter car data memory area
    call decompress_rlh
    ld hl,RAM_MAP_PRECALC_VEHICLE_1
    ld (.ram_precalc_address),hl
    call .shiftcompute
    ret

.ram_precalc_address
    dc.w 0

.shiftcompute
    ; target memory map is (all addresses are actually offsets based on .ram_precalc_address,
    ; which is actually RAM_MAP_PRECALC_VEHICLE_0 or RAM_MAP_PRECALC_VEHICLE_1)
    ; I will thank myself later for writing down this map
    ; + $0000 : sprite 0 with angle 12, no shifting, 2 bytes per row => 16 bytes total
    ; + $0010 : sprite 0 with angle 12, 1 shift
    ; + $0020 : sprite 0 with angle 12, 2 shifts
    ; ...
    ; + $0070 : sprite 0 with angle 12, 7 shifts
    ; + $0080 : sprite 1 with angle 11, no shifting
    ; + $0090 : sprite 1 with angle 11, 1 shift
    ; ....
    ; + $00f0 : sprite 1 with angle 11, 7 shifts
    ; ...
    ; + $047f : sprite 8 with angle 4, 7 shifts
    ; + $0480 : nohing more here
    ; sprites are all decompressed in the working area
    ; we need to first split them and send them to their own area

    ; First, let's spread sprites data to their location and make 16 bits data from 8 bits.
    ; this will be shift 0 data
    ; we need to insert a white byte ($ff) between each byte to make each row 2 bytes wide
    ; we have to start at sprite 8 and go backward, to avoid overwriting the initial decompressed piece of data
    ; Compute target address => de
    ld hl,(.ram_precalc_address)
    ld bc,128*9-16 ;(16 sprite bytes times 8 shifts times 9 sprites, beginning of last sprite data (unshifted))
    add hl,bc
    ex de,hl
    ; Compute source address => hl
    ld hl,(.ram_precalc_address)
    ld bc,8*9-1 ;(8 bytes times 9 sprites, end of last sprite data)
    add hl,bc
    ld iyh,9 ; 9 sprites
.loop_spread_sprites
    ld iyl,8 ; 8 shifts
.loop_spread_1_sprite
        ld a,(hl)
        dec hl
        ld (de),a
        inc de        
        ld a,$ff
        ld (de),a

        ; compute next value of de => move to previous sprite unshifted data
        ex de,hl
        ld bc,$ffef ; -17
        add hl,bc
        ex de,hl
        dec iyl
        jr nz,.loop_spread_1_sprite
    ; recompute next value for de
    dec iyh
    jr nz,.loop_spread_sprites
    
    ; now compute 7 remaining shifts for all sprites
    ld hl,(.ram_precalc_address)
    ld de,(.ram_precalc_address)
    inc de
    inc de
    ld b,9*8 ; 9 sprites times 8 rows
.loop_shift_sprites:
    ld c,7 ; 7 shifts
.loop_shift_1_sprite:
        ld a,(hl)
        inc hl ; move to next source byte
        scf ; set carry flag, as we want white to appear on the left
        rra ; rotate right. The carry will get the lost bit 0
        ld (de),a
        inc de ; move to next target byte, does not change carry state as it is a 16 bit register
        ld a,(hl) ; still don't touch the carry state
        inc hl ; move to next source byte, still don't touch the carry state
        rra ; inject the carry on the left
        ld (de),a
        inc de
        dec c
        jr nz,.loop_shift_1_sprite
    ; skip unshifted sprite, get ready for the next one!
    inc hl
    inc hl
    inc de
    inc de
    djnz .loop_shift_sprites
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
    ; de will hold the miroring offset and activation bit
    ld de,0 ; no mirroring for now
    ; Store new sprite VRAM address
    ld (ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS),l
    ld (ix+CAR_OFFSET_SPRITE_VRAM_ADDRESS+1),h
    ld a,(ix+CAR_OFFSET_ANGLE)
    and a,$f0
    ; determine sprite index and potential mirroring
    cp $d0
    jr nc,.no_mirroring
    cp $50
    jr c,.no_mirroring
    ; between 5 and 12, need mirroring
    ld b,a
    ld a,$c0
    sub b
    ; need to display the image backwards and set the lower bit
    ld de,128-16+1 ; end of shifted sprite data + 1 byte as a marker
    jr .index_computed
.no_mirroring
    add $40
.index_computed
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    ld c,(ix+CAR_OFFSET_PRECALC_SPRITES_BASE_ADDRESS)
    ld b,(ix+CAR_OFFSET_PRECALC_SPRITES_BASE_ADDRESS+1)
    add hl,bc

    ; Determine the sprite shifting to be done
    ld a,(ix+CAR_OFFSET_X+1)
    and 7
    add a
    ld b,0
    ld c,a
    add hl,bc

    ; Add potential mirroring offset
    add hl,de

    ld (ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS),l
    ld (ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS+1),h
    ret

erase_car:
    ; hl = target screen address
    ; de = source background backup
    ld l,(ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS)
    ld h,(ix+CAR_OFFSET_BACKGROUND_VRAM_ADDRESS+1)
    ld e,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS)
    ld d,(ix+CAR_OFFSET_BACKGROUND_BACKUP_DATA_ADDRESS+1)
    
    ld iyl,8
    ld bc,31
.eraseloop:
    ld a,(de)
    ld (hl),a
    inc de
    inc hl
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec iyl
    jr nz,.eraseloop

    ret

draw_car:
    ; de = target screen address
    ; hl = source sprite data
    ; bc = target background backup
    ; bc' will hold the next line offset, depending on the potential sprite miroring
    bit 0,(ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS)
    jr z,.no_mirroring
    ld bc,$ffef; -17
    jr .ok_mirroring
.no_mirroring:
    ld bc,15
.ok_mirroring:
    res 0,(ix+CAR_OFFSET_SHIFTED_SPRITES_DATA_ADDRESS)
    push bc
    exx
    pop bc
    exx

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
    
    push bc
    ; Get bc' using the stack
    exx
    push bc
    exx
    pop bc
    add hl,bc
    pop bc

    ; Move screen pointer on the next line (31 byte to the right)
    push hl
    ld hl,31
    add hl,de
    ex de,hl
    pop hl

    dec iyl
    jr nz,.drawloop

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

update_car_angle_and_throttle:
    ; [a] contains keyboard state for this car
    bit INPUT_BIT_LEFT,a
    jr z,.noturnleft
    dec (ix+CAR_OFFSET_ANGLE)
    dec (ix+CAR_OFFSET_ANGLE)
    dec (ix+CAR_OFFSET_ANGLE)
.noturnleft
    bit INPUT_BIT_RIGHT,a
    jr z,.noturnright
    inc (ix+CAR_OFFSET_ANGLE)
    inc (ix+CAR_OFFSET_ANGLE)
    inc (ix+CAR_OFFSET_ANGLE)
.noturnright
    bit INPUT_BIT_FIRE,a
    ld a,(ix+CAR_OFFSET_THROTTLE) ; does not change flags
    jr z,.nothrottle
    add THROTTLE_INCREMENT
    jr c,.end
    jr .savethrottle
.nothrottle
    sub THROTTLE_DECREMENT
    jr nc,.savethrottle
    xor a
.savethrottle
    ld (ix+CAR_OFFSET_THROTTLE),a
.end
    ret

update_car_speed:
    ; Compute speed vector address => [hl]
    ld a,(ix+CAR_OFFSET_THROTTLE) ; does not change flags
    or a ; update flags => equivalent to cp 0
    jr nz,.not_braking
    ; Here, the car is braking
    ; Speed vectors should be 0,0
    ld (ix+CAR_OFFSET_SPEED_X),0
    ld (ix+CAR_OFFSET_SPEED_X+1),0
    ld (ix+CAR_OFFSET_SPEED_Y),0
    ld (ix+CAR_OFFSET_SPEED_Y+1),0
    jr .end
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
    ld a,(RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_CIRCUIT_OPTIONS)
    and 1<<CIRCUIT_OPTION_BIT_ICE
    ex af,af' ;'

    ;; Times 63 (x64-1)
    push bc
    ld h,b
    ld l,c
    call neg_hl
    ex (sp),hl
    ex af,af' ;'
    jr z,.times31
    add hl,hl
.times31
    ex af,af' ;'
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    pop bc
    add hl,bc
    add hl,de
    ; hl contains 63 x bc + de
    ; Divide by 64 (easy :/)
    sra h
    rr l
    ex af,af' ;'
    jr z,.divide_32
    sra h
    rr l
.divide_32
    sra h
    rr l
    sra h
    rr l
    sra h
    rr l
    sra h
    rr l
    ret

update_car_engine_sound:
    ld c,(ix+CAR_OFFSET_THROTTLE)
    ld a,255
    sub c
    ld c,a
    ld a,(ix+CAR_OFFSET_AY8910_SOUND_FREQUENCY_REGISTER)
    AY_PUSH_REG
    ld a,c
    AY_PUSH_VAL
    ret

; xx yy - one row for each 4 bits orientation value (2+2 bytes x 16 = 64 bytes)
speed_vectors:
; 4 groups of 64 bytes, one for each speed range
; Radius $40
    dc.w $0000, $FFC0
    dc.w $0018, $FFC4
    dc.w $002D, $FFD2
    dc.w $003B, $FFE7
    dc.w $0040, $0000
    dc.w $003B, $0018
    dc.w $002D, $002D
    dc.w $0018, $003B
    dc.w $0000, $0040
    dc.w $FFE7, $003B
    dc.w $FFD2, $002D
    dc.w $FFC4, $0018
    dc.w $FFC0, $0000
    dc.w $FFC4, $FFE7
    dc.w $FFD2, $FFD2
    dc.w $FFE7, $FFC4
; Radius $80
    dc.w $0000, $FF80
    dc.w $0030, $FF89
    dc.w $005A, $FFA5
    dc.w $0076, $FFCF
    dc.w $0080, $0000
    dc.w $0076, $0030
    dc.w $005A, $005A
    dc.w $0030, $0076
    dc.w $0000, $0080
    dc.w $FFCF, $0076
    dc.w $FFA5, $005A
    dc.w $FF89, $0030
    dc.w $FF80, $0000
    dc.w $FF89, $FFCF
    dc.w $FFA5, $FFA5
    dc.w $FFCF, $FF89
; Radius $c0
    dc.w $0000, $FF40
    dc.w $0049, $FF4E
    dc.w $0087, $FF78
    dc.w $00B1, $FFB6
    dc.w $00C0, $0000
    dc.w $00B1, $0049
    dc.w $0087, $0087
    dc.w $0049, $00B1
    dc.w $0000, $00C0
    dc.w $FFB6, $00B1
    dc.w $FF78, $0087
    dc.w $FF4E, $0049
    dc.w $FF40, $0000
    dc.w $FF4E, $FFB6
    dc.w $FF78, $FF78
    dc.w $FFB6, $FF4E
; Radius $100
    dc.w $0000, $FF00
    dc.w $0061, $FF13
    dc.w $00B5, $FF4A
    dc.w $00EC, $FF9E
    dc.w $0100, $0000
    dc.w $00EC, $0061
    dc.w $00B5, $00B5
    dc.w $0061, $00EC
    dc.w $0000, $0100
    dc.w $FF9E, $00EC
    dc.w $FF4A, $00B5
    dc.w $FF13, $0061
    dc.w $FF00, $0000
    dc.w $FF13, $FF9E
    dc.w $FF4A, $FF4A
    dc.w $FF9E, $FF13
