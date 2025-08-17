    include inc/rammap.inc
    include inc/inputs.inc
    section	code,text

    global start_race, laps_count, set_laps_count

laps_count_car_0:
    dc.b 0
laps_count_car_1:
    dc.b 0

start_race:

    call ay8910_mute

    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd;

    ; load the circuit
    ld hl,rlh_circuitdata
    call load_circuit

    ; draw the circuit
    call draw_circuit

    ; precompute car positions
    call precalc_shifted_cars

    call ay8910_init_cars

    ld ix,data_car0 ; current car is number 0
    call prepare_draw_car
    call draw_car

    ld ix,data_car1 ; current car is number 1
    call prepare_draw_car
    call draw_car

.loop

    call update_inputs;
    call ay8910_loop

    ; Compute car speed vector
    ld ix,data_car0 ; current car is number 0
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    call update_car_angle_and_throttle
    call update_car_speed
    call update_car_engine_sound
    ld ix,data_car1 ; current car is number 1
    ld a,(players_count)
    cp 2
    jp z,.realplayer2
    call autodrive_current_car
    jp .common_player2
.realplayer2:
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
.common_player2
    call update_car_angle_and_throttle
    call update_car_speed
    call update_car_engine_sound
    
    ; Compute circuit tiles interactions
    ld ix,data_car0 ; current car is number 0
    call compute_circuit_interactions
    ld ix,data_car1 ; current car is number 1
    call compute_circuit_interactions

    ; Update car position
    ld ix,data_car0 ; current car is number 0
    call update_car_position
    ld ix,data_car1 ; current car is number 1
    call update_car_position

    ; Prepare to draw the car
    ld ix,data_car0 ; current car is number 0
    call prepare_draw_car
    ld ix,data_car1 ; current car is number 1
    call prepare_draw_car

    ; check [back to menu] key    
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    bit INPUT_BIT_ESC,a
    jp nz,escape

    ; Black on white
    ;ld a,%11110110
    ;out ($40),a

    ; Wait until the end of the frame
    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    ; Erase the car sprites
    ld ix,data_car1 ; ; current car is number 1
    call erase_car
    ld ix,data_car0 ; current car is number 0
    call erase_car

    ; Draw the cars
    ld ix,data_car0 ; current car is number 0
    call draw_car
    ld ix,data_car1 ; current car is number 1
    call draw_car

    if DEBUG = 1
    call emulator_security_idle;
    endif

    ; Black on white
    ld a,%11110110
    out ($40),a

    jp .loop

    ret

escape:
    ; back to intro!
    ret

; laps count in [a]
set_laps_count:
    ld (laps_count_car_0),a
    ld (laps_count_car_1),a
    ret

refresh_lap_count:
    ld a,(laps_count_car_0)
    ld b,a
    ld a,(laps_count_car_1)
    cp b
    jp nc,.b_geater
    ld a,b
.b_geater
    ; now [A] contains the lowest number
    ; display it whenever we have a font!

    ret