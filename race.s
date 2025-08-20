    include inc/rammap.inc
    include inc/inputs.inc
    include inc/car.inc
    section	code,text

    global start_race, get_lap_count
    global current_laps_to_go, race_winner_id

; duration in VBL count ffor the race to end after a player crosses the line
END_OF_RACE_EXIT_DURATION equ 60*4

current_laps_to_go:
    dc.b 0

race_winner_id:
    dc.b 0

race_exit_counter;
    dc.w 0

start_race:

    call ay8910_mute

    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd;

    ; No winner, yet
    xor a
    ld (race_winner_id),a
    ld bc,END_OF_RACE_EXIT_DURATION
    ld (race_exit_counter),bc

    ; load the circuit
    ld hl,rlh_circuitdata
    call load_circuit

    ; draw the HUD
    call show_hud

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

    call ay8910_queue_sequence_start_beep

.loop

    call check_for_end_of_race
    jr c,.not_finished
    ; Back to parent screen
    ret

.not_finished:
    ; Should be play music or SFX?
    ld a,(race_winner_id)
    or a
    jp z,.play_sfx
    call music_loop
    jr .done_sound
.play_sfx:
    call ay8910_loop
.done_sound:

    call update_inputs;

    ; Compute car speed vector
    ld ix,data_car0 ; current car is number 0
    ld a,(race_winner_id)
    cp 1
    jp nz,.player_1_did_not_win_yet
    call autodrive_current_car
    jp .common_player1
.player_1_did_not_win_yet
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
.common_player1
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
    ld a,(race_winner_id)
    cp 2
    jp nz,.player_2_did_not_win_yet
    call autodrive_current_car
    jp .common_player2
.player_2_did_not_win_yet
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

    ; Compute engine sound enveloppe
    ld ix,data_car0 ; current car is number 0
    call compute_engine_enveloppe
    ld ix,data_car1 ; current car is number 1
    call compute_engine_enveloppe

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

    ; Update laps to go (if needed)
    call update_laps_to_go

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

; result in [a]
get_lap_count:
    push bc
    ld a,(data_car0+CAR_OFFSET_REMAINING_LAPS)
    and %00111111 ; remove flag tile status bits
    ld b,a
    ld a,(data_car1+CAR_OFFSET_REMAINING_LAPS)
    and %00111111 ; remove flag tile status bits
    cp b
    jp c,.b_geater
    ld a,b
.b_geater
    ; now [A] contains the lowest number
    pop bc
    ret

update_laps_to_go:
    ld a,(current_laps_to_go)
    ld b,a
    call get_lap_count
    cp b
	dc.b $c8 ; "ret z" not assembled correctly by VASM!
    ; lap count has changed
    ld (current_laps_to_go),a
    call hud_refresh_lap_count
    ret

check_for_end_of_race:
    ; check if we have already detected a winner
    ld a,(race_winner_id)
    or a
    jp z,.check_laps
    ; we already have a winner
    ; Check race exit counter
    ld bc,(race_exit_counter)
    dec bc
    ld (race_exit_counter),bc
    ld a,b
    or c
    jp nz,.continue
    ; we have to stop
    xor a ; clear carry
    ret
.check_laps
    ; still some laps to go?
    ld a,(current_laps_to_go)
    or a
    jp nz,.still_some_laps
    ; No more laps, we have a winner
    ; init music engine as we want to play winner's music
    call music_init
    ld a,(data_car0+CAR_OFFSET_REMAINING_LAPS)
    and %00111111 ; remove flag tile status bits
    ld a,1
    jr z,.winner_id_in_reg_a
    ld a,2
.winner_id_in_reg_a:
    ld (race_winner_id),a
.still_some_laps:
.continue:
    scf ; set carry
    ret
