    include inc/rammap.inc
    include inc/inputs.inc
    include inc/car.inc

    section	code,text

    global autodrive_current_car

    dc.b "                  Breakpoint!!!                    "
; returns input byte value in register [a]
autodrive_current_car:
    ; Determine most representative tile based on car position
    ld a,(ix+CAR_OFFSET_X+1)
    add 3 ; center of the car
    ; Divide by 16
    and $f0
    rrca
    rrca
    rrca
    rrca
    ld b,a ; backup i coordinate
    ld a,(ix+CAR_OFFSET_Y+1)
    add 3 ; center of the car
    and $f0
    add b ; a was y=j*16 so no need to multiply it
    ; Compute circuit tile address
    ld b,0
    ld c,a
    ld hl,RAM_MAP_CIRCUIT_DATA
    add hl,bc
    ; hl points to the current tile
    ld a,(hl) ; load tile info
    and %111 ; keep lower bits to target next tile
    ; 701
    ; 6X2
    ; 543
    add a
    add a
    add a
    add a
    ; compute target orientation   
    add a ; times 2 to match 4 bits car angle definition
    ld b,a ; backup target orientation
    ld c,INPUT_VALUE_FIRE ; controler value to be returned
    ; Load current orientation
    ld a,(ix+CAR_OFFSET_ANGLE)
    ld d,a ; backup current orientation
    ; Anti-vibrations    
    sub b
    cp $02
    jp c,.ok ; Don't move if less than 2 increments away
    ; Compare current orientation with target orientation
    ld a,d ; restore a
    sub b
    jp z,.ok
    jp nc,.positive
    ; negative
    cp $80
    jp nc,.negative_indirect
    set INPUT_BIT_LEFT,c
    jp .ok
.negative_indirect
    set INPUT_BIT_RIGHT,c
    jp .ok
.positive:
    cp $80
    jp nc,.positive_indirect
    set INPUT_BIT_LEFT,c
    jp .ok
.positive_indirect:
    set INPUT_BIT_RIGHT,c
.ok:
    ld a,c
    ret ; returns input byte value in register a