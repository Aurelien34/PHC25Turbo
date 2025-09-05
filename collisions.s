    include inc/rammap.inc
    include inc/car.inc

    section	code,text

    global compute_circuit_interactions, compute_cars_interactions, neg_hl


; ix points to current car
compute_circuit_interactions:
    ; clear status byte
    xor a
    ld (.status),a
    ; compute tile collision coordinates
    ld a,(ix+CAR_OFFSET_X+1)
    add 2 ; collision mask is a 4x4 square, so 2 pixels left margin
    ld b,a
    and $f0
    ld (.x1x16),a
    ld c,a
    ld a,b
    add 3 ; collision mask is 4x4, so 4 pixels wide
    and $f0
    ld (.x2x16),a
    cp c
    jr nz,.x2_is_different
    ld hl,.status
    set 6,(hl)
.x2_is_different:
    ld a,(ix+CAR_OFFSET_Y+1)
    add 2 ; collision mask is a 4x4 square, so 2 pixels left margin
    ld b,a
    and $f0
    ld (.y1x16),a
    ld c,a
    ld a,b
    add 3 ; collision mask is 4x4, so 4 pixels wide
    and $f0
    ld (.y2x16),a
    cp c
    jr nz,.y2_is_different
    ld hl,.status
    set 7,(hl)
.y2_is_different:

    ; compute collisions
    ; tile 0,0
    ld hl,.x1x16
    ld b,(hl)
    inc hl
    ld c,(hl)
    ld a,(ix+CAR_OFFSET_X+1)
    add 2
    and $0f
    add 16
    ld d,a
    ld a,(ix+CAR_OFFSET_Y+1)
    add 2
    and $0f
    add 16
    ld e,a
    call compute_collisions_xy
    jr c,.collision_occurred
    ld hl,.status
    bit 6,(hl)
    jr nz,.only_one_column1
    ; tile 1,0
    ld hl,.x2x16
    ld b,(hl)
    dec hl
    ld c,(hl)
    ld a,(ix+CAR_OFFSET_X+1)
    add 2
    and $0f
    ld d,a
    ld a,(ix+CAR_OFFSET_Y+1)
    add 2
    and $0f
    add 16
    ld e,a
    call compute_collisions_xy
    jr c,.collision_occurred
.only_one_column1:
    ld hl,.status
    bit 7,(hl)
    jr nz,.only_one_row
    ; tile 0,1
    ld hl,.x1x16
    ld b,(hl)
    ld hl,.y2x16
    ld c,(hl)
    ld a,(ix+CAR_OFFSET_X+1)
    add 2
    and $0f
    add 16
    ld d,a
    ld a,(ix+CAR_OFFSET_Y+1)
    add 2
    and $0f
    ld e,a
    call compute_collisions_xy
    jr c,.collision_occurred
    ld hl,.status
    bit 6,(hl)
    jr nz,.only_one_column2
    ; tile 1,1
    ld hl,.x2x16
    ld b,(hl)
    inc hl
    ld c,(hl)
    ld a,(ix+CAR_OFFSET_X+1)
    add 2
    and $0f
    ld d,a
    ld a,(ix+CAR_OFFSET_Y+1)
    add 2
    and $0f
    ld e,a
    call compute_collisions_xy
    jr c,.collision_occurred
.only_one_column2:
.only_one_row:
    xor a ; clear carry
    ret

.collision_occurred:
    ; divide throttle by 2
    ld a,(ix+CAR_OFFSET_THROTTLE)
    srl a
    ld (ix+CAR_OFFSET_THROTTLE),a
    scf ; set carry
    ret

.status:
    dc.b 0
.x1x16:
    dc.b 0
.y1x16:
    dc.b 0
.x2x16:
    dc.b 0
.y2x16:
    dc.b 0

; b <- xx16
; c <- yx16
compute_collisions_xy:
    ; compute tile address
    ; address is base + xx16 / 16 + yx16
    ld a,b
    and $f0
    rrca
    rrca
    rrca
    rrca
    add c
    ld h,0
    ld l,a
    push de
    ld de,RAM_MAP_CIRCUIT_DATA
    add hl,de ; hl contains the tile address
    pop de
    ld a,(hl); a contains the tile data
    ; read tile data
    ld iyl,a ; backup tile data to register [iyl]
    and %11111000
    srl a
    srl a
    ld h,0
    ld l,a
    ld bc,.tileJumps
    add hl,bc
    ; branch to tile
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)
    ; no need to ret, the tile management routine will return to our caller

    ; in tile routines,
    ; x,y in [de]
    ; iyl contains complete tile data
    ; x,y relative to the given tile
    ; should return potential collision event in flag C
    ; xor a => clear C
    ; scf => set C
.tileJumps
    dc.w tile00
    dc.w tile01
    dc.w tile02
    dc.w tile03
    dc.w tile04
    dc.w tile05
    dc.w tile06
    dc.w tile07
    dc.w tile08
    dc.w tile09
    dc.w tile10
    dc.w tile11
    dc.w tile12


tile00:
tile01:
    xor a ; clear carry
    ret
tile02:
    ; || vertical wall
    ld a,d
    cp 16
    jr nc,.collision_right
    cp 11
    jr nc,.collision_left
    ; no collision
    xor a ; clear carry
    ret
.collision_left:
    call dec_x
    call invert_x
    jr .collision_common
.collision_right:
    call inc_x
    call invert_x
.collision_common:
    scf ; set carry
    ret
tile03:
    ; = horizontal wall
    ld a,e
    cp 16
    jr nc,.collision_bottom
    cp 11
    jr nc,.collision_top
    ; no collision
    xor a ; clear carry
    ret
.collision_top:
    call dec_y
    call invert_y
    jr .collision_common
.collision_bottom:
    call inc_y
    call invert_y
.collision_common:
    scf ; set carry
    ret

tile04:
    ; diagonal wall x/<
    ld a,d
    add e
    cp 48
    jr c,.collision
    ; no collision
    xor a ; clear carry
    ret
.collision
    call inc_x
    call inc_y
    call swap_and_invert_vectors
    scf ; set carry
    ret

tile05:
    ; diagonal wall >\x
    ld a,d
    add 2
    cp e
    jr nc,.collision
    xor a ; clear carry
    ret
.collision:
    call dec_x
    call inc_y
    call swap_vectors
    scf ; set carry
    ret

tile06:
    ; diagonal wall >/x
    ld a,d
    add e
    cp 41
    jr nc,.collision
    xor a ; clear carry
    ret
.collision:
    call dec_x
    call dec_y
    call swap_and_invert_vectors
    scf ; set carry
    ret

tile07:
    ; diagonal wall x\<
    ld a,e
    add 3
    cp d
    jr nc,.collision
    xor a ; clear carry
    ret
.collision:
    call inc_x
    call dec_y
    call swap_vectors
    scf ; set carry
    ret

tile08:
    ; X|< vertical wall
    ld a,d
    cp 17
    jr c,.collision
    ; no collision
.no_collision
    xor a ; clear carry
    ret
.collision:
    call inc_x
    call invert_x
    scf ; set carry
    ret
tile09:
    ; -- /\ horizontal wall
    ld a,e
    cp 17
    jr c,.collision
    ; no collision
.no_collision
    xor a ; clear carry
    ret
.collision:
    call inc_y
    call invert_y
    scf ; set carry
    ret
tile10:
    ; >|x vertical wall
    ld a,d
    cp 28
    jr nc,.collision
    ; no collision
.no_collision
    xor a ; clear carry
    ret
.collision:
    call dec_x
    call invert_x
    scf ; set carry
    ret

tile11:
    ; _ \/ horizontal wall
    ld a,e
    cp 28
    jr nc,.collision
    ; no collision
.no_collision
    xor a ; clear carry
    ret
.collision:
    call dec_y
    call invert_y
    scf ; set carry
    ret


CHECKERED_FLAG_ZONE_WHITE_TOP equ 20
CHECKERED_FLAG_ZONE_TOP equ 23
CHECKERED_FLAG_ZONE_BOTTOM equ 26
CHECKERED_FLAG_ZONE_WHITE_BOTTOM equ 28

tile12: ; checkered flag
    ; x=d ; y=e
    ; load remaining laps and flags stored with them
    ld b,(ix+CAR_OFFSET_REMAINING_LAPS)
    ld a,e
    cp CHECKERED_FLAG_ZONE_WHITE_TOP
    jr c,.in_white_zone
    cp CHECKERED_FLAG_ZONE_WHITE_BOTTOM
    jr nc,.in_white_zone
    jr .check_position_in_flag
.in_white_zone:
    ; clear flags
    ld a,b
    and %00111111
    ld b,a
    jr .end
.check_position_in_flag
    ; on the bottom of the flag?
    ld a,e
    cp CHECKERED_FLAG_ZONE_BOTTOM
    jr c,.not_bottom
    set CAR_FINISH_LINE_STATUS_BIT_BOTTOM,b
    ld a,b
    ; bottom of the flag
    and 1<<CAR_FINISH_LINE_STATUS_BIT_TOP
    jr z,.entering_from_bottom
    ; Coming from the top
    ; clear flag, increment lap count and set both flags
    ld a,b
    and %00111111
    inc a
    or %10000000
    ld b,a
    jr .end
.entering_from_bottom:
    ; really entering flag from the bottom
    jr .end
.not_bottom:
    ; on the top of the flag?
    ld a,e
    cp CHECKERED_FLAG_ZONE_TOP
    jr nc,.not_top
    ; top of the flag
    set CAR_FINISH_LINE_STATUS_BIT_TOP,b
    ld a,b
    and 1<<CAR_FINISH_LINE_STATUS_BIT_BOTTOM
    jr z,.entering_top
    ; Coming from the bottom
    ; clear flags, decrement lap count and set flags
    ld a,b
    and %00111111
    dec a
    or %01000000
    ld b,a
.entering_top:
    ; entering flag from the top
.not_top:
    ; neither top nor bottom => center of the flag
.end:
    ld (ix+CAR_OFFSET_REMAINING_LAPS),b
    xor a ; clear carry
    ret



invert_x:
    ld l,(ix+CAR_OFFSET_SPEED_X)
    ld h,(ix+CAR_OFFSET_SPEED_X+1)
    ; neg hl
    call neg_hl
    ld (ix+CAR_OFFSET_SPEED_X),l
    ld (ix+CAR_OFFSET_SPEED_X+1),h
    ret

invert_y:
    ld l,(ix+CAR_OFFSET_SPEED_Y)
    ld h,(ix+CAR_OFFSET_SPEED_Y+1)
    ; neg hl
    call neg_hl
    ld (ix+CAR_OFFSET_SPEED_Y),l
    ld (ix+CAR_OFFSET_SPEED_Y+1),h
    ret

neg_hl:
    xor a
    sub l
    ld l,a
    sbc a,a
    sub h
    ld h,a
    ret

inc_x:
    ld a,(ix+CAR_OFFSET_X+1)
    inc a
    ld (ix+CAR_OFFSET_X+1),a
    ret

dec_x:
    ld a,(ix+CAR_OFFSET_X+1)
    dec a
    ld (ix+CAR_OFFSET_X+1),a
    ret

inc_y:
    ld a,(ix+CAR_OFFSET_Y+1)
    inc a
    ld (ix+CAR_OFFSET_Y+1),a
    ret

dec_y:
    ld a,(ix+CAR_OFFSET_Y+1)
    dec a
    ld (ix+CAR_OFFSET_Y+1),a
    ret

swap_vectors:
    ld e,(ix+CAR_OFFSET_SPEED_Y)
    ld d,(ix+CAR_OFFSET_SPEED_Y+1)
    ld l,(ix+CAR_OFFSET_SPEED_X)
    ld h,(ix+CAR_OFFSET_SPEED_X+1)
    ; store new x
    ld (ix+CAR_OFFSET_SPEED_X),e
    ld (ix+CAR_OFFSET_SPEED_X+1),d
    ; store new y
    ld (ix+CAR_OFFSET_SPEED_Y),l
    ld (ix+CAR_OFFSET_SPEED_Y+1),h
    ret

swap_and_invert_vectors:
    ld l,(ix+CAR_OFFSET_SPEED_Y)
    ld h,(ix+CAR_OFFSET_SPEED_Y+1)
    call neg_hl
    ex de,hl ; future x
    ld l,(ix+CAR_OFFSET_SPEED_X)
    ld h,(ix+CAR_OFFSET_SPEED_X+1)
    call neg_hl
    ; store new x
    ld (ix+CAR_OFFSET_SPEED_X),e
    ld (ix+CAR_OFFSET_SPEED_X+1),d
    ; store new y
    ld (ix+CAR_OFFSET_SPEED_Y),l
    ld (ix+CAR_OFFSET_SPEED_Y+1),h
    ret

compute_cars_interactions:
    ; compare X coordinates
    ld hl,data_car0+CAR_OFFSET_X+1 ; bc contains car 0 position address
    ld a,(hl)
    ld b,a
    ld de,data_car1+CAR_OFFSET_X+1 ; de contains car 1 position address
    ld a,(de)
    sub b
    jp p,.car_0_is_on_the_left_distance_is_positive
    ; car 0 is on the right
    neg ; get a positive distance
    ex de,hl
.car_0_is_on_the_left_distance_is_positive
    cp 4
    jp p,.no_collision
    ; potential horizontal collision
    push hl
    push de
    ; search for vertical collision
    ; compare Y coordinates
    ld hl,data_car0+CAR_OFFSET_Y+1 ; bc contains car 0 position address
    ld a,(hl)
    ld b,a
    ld de,data_car1+CAR_OFFSET_Y+1 ; de contains car 1 position address
    ld a,(de)
    sub b
    jp p,.car_0_is_on_top_distance_is_positive
    ; car 0 is on the bottom
    neg ; get a positive distance
    ex de,hl
.car_0_is_on_top_distance_is_positive
    cp 4
    jp p,.no_collision_after_vertical_check
    ; vertical collision

    ; We have a collision!
    ; separate cars
    dec (hl)
    ex de,hl
    inc (hl)
    pop hl
    inc (hl)
    pop hl
    dec (hl)

    ; reduce throttle
    ld hl,data_car0+CAR_OFFSET_THROTTLE
    call .throttle_times3_4
    ld hl,data_car1+CAR_OFFSET_THROTTLE
    call .throttle_times3_4

    scf ; set carry
    ret
.no_collision_after_vertical_check:
    pop de
    pop hl
.no_collision:
    xor a ; clear carry
    ret
.throttle_times3_4
    ld a,(hl)
    ld b,a
    srl b
    srl b
    sub b
    ld (hl),a
    ret