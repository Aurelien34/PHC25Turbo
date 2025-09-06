    include inc/rammap.inc
    include inc/inputs.inc

    section	code,text

    global update_inputs

; Mapping is here: https://github.com/mamedev/mame/blob/master/src/mame/sanyo/phc25.cpp (line 323...)
; Joystick ports (registers for ports A and B) are here: https://github.com/mamedev/mame/blob/master/src/devices/sound/ay8910.h
update_inputs:
    push bc

    ; Player 1 / s, d, f
    ld b,0 ; b <- 0

    ;  Joystick
    if JOYSTICK = 1
    ld a,$0e
    out ($c1),a
    in a,($c0)
    bit 4,a
    jr nz,.jp1notfire
    set INPUT_BIT_FIRE,b
.jp1notfire
    bit 2,a
    jr nz,.jp1notleft
    set INPUT_BIT_LEFT,b
.jp1notleft
    bit 3,a
    jr nz,.jp1notright
    set INPUT_BIT_RIGHT,b
.jp1notright
    endif

    ; Keyboard
    in a,($80)
    bit 2,a
    jr nz,.p1notfire
    set INPUT_BIT_FIRE,b
.p1notfire
    in a,($83)
    bit 2,a
    jr nz,.p1notleft
    set INPUT_BIT_LEFT,b
.p1notleft
    in a,($82)
    bit 2,a
    jr nz,.p1notright
    set INPUT_BIT_RIGHT,b
.p1notright
    in a,($80)
    bit 0,a
    jr nz,.p1notstart
    set INPUT_BIT_START,b
.p1notstart
    in a,($80)
    bit 3,a
    jr nz,.p1notesc
    set INPUT_BIT_ESC,b
.p1notesc
    in a,($85)
    bit 2,a
    jr nz,.p1nogreetings
    set INPUT_BIT_GREETINGS,b
.p1nogreetings
    ld a,b
    ld (RAM_MAP_CONTROLLERS_VALUES),a ; store values


    ; Player 2 / j, k, l
    ld b,0 ; b <- 0

    ;  Joystick
    if JOYSTICK = 1
    ld a,$0f
    out ($c1),a
    in a,($c0)
    bit 4,a
    jr nz,.jp2notfire
    set INPUT_BIT_FIRE,b
.jp2notfire
    bit 2,a
    jr nz,.jp2notleft
    set INPUT_BIT_LEFT,b
.jp2notleft
    bit 3,a
    jr nz,.jp2notright
    set INPUT_BIT_RIGHT,b
.jp2notright
    endif

    in a,($86)
    bit 2,a
    jr nz,.p2notfire
    set INPUT_BIT_FIRE,b
.p2notfire
    in a,($87)
    bit 2,a
    jr nz,.p2notleft
    set INPUT_BIT_LEFT,b
.p2notleft
    in a,($87)
    bit 6,a
    jr nz,.p2notright
    set INPUT_BIT_RIGHT,b
.p2notright
    in a,($83)
    bit 0,a
    jr nz,.p2notstart
    set INPUT_BIT_START,b
.p2notstart
    ld a,b
    ld (RAM_MAP_CONTROLLERS_VALUES+1),a ; store values

    pop bc
    ret
