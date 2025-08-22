    include inc/rammap.inc
    include inc/inputs.inc
    include inc/screen.inc
    include inc/car.inc
    
    section	code,text

RES_GUYS_IMAGE_HEIGHT equ 13
res_guys:
res_guy_win_1:
    incbin res_raw/guy_win_1.raw
res_guy_win_2:
    incbin res_raw/guy_win_2.raw
res_guy_loose_1:
    incbin res_raw/guy_loose_1.raw
res_guy_loose_2:
    incbin res_raw/guy_loose_2.raw

    global start_race, get_lap_count
    global current_laps_to_go, race_winner_id, startup_count_down_counter

; duration in VBL count for the race to end after a player crosses the line
END_OF_RACE_EXIT_DURATION equ 60*7+30 ; 60*n seconds
STARTUP_COUNT_DOWN_SPEED equ 2


RACE_STATE_STARTUP_COUNTDOWN        equ 1
RACE_STATE_RACE_STARTED             equ 2
RACE_STATE_RACE_OVER                equ 3
RACE_STATE_LOADING_WINNER_LOOSER    equ 4
RACE_STATE_ANIMATE_GUYS             equ 5

race_state:
    dc.b 0

frame_count:
    dc.b 0

current_laps_to_go:
    dc.b 0

race_winner_id:
    dc.b 0

race_exit_counter;
    dc.w 0

startup_count_down_counter:
    dc.w 0

image_winner_screen_address:
    dc.w 0

image_looser_screen_address:
    dc.w 0

winner_looser_loading_counter:
    dc.b 0

start_race:

    ; shut the audio chip
    call ay8910_mute

    ; clear the screen
    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd;

    ; init the startup countdown
    ld hl,$43c ; 3 seconds and 60 1/60 seconds
    ld (startup_count_down_counter),hl

    ; initial state is count down
    ld a,1<<RACE_STATE_STARTUP_COUNTDOWN
    ld (race_state),a

    ; No winner, yet => set image addresses to 0
    xor a
    ld (race_winner_id),a
    ld b,a
    ld c,a
    ld (image_winner_screen_address),bc
    ld (image_looser_screen_address),bc
    ld bc,END_OF_RACE_EXIT_DURATION
    ld (race_exit_counter),bc

    ; first frame
    xor a;
    ld (frame_count),a

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
    call update_car_speed

    ld ix,data_car1 ; current car is number 1
    call prepare_draw_car
    call draw_car
    call update_car_speed

.loop
    ld a,(frame_count)
    inc a
    ld (frame_count),a

    ld a,(race_state)
    and a,1<<RACE_STATE_RACE_OVER
    jp z,.not_finished
    ; Play victory music loop
    call music_loop
.not_finished:
    ; play engine sounds
    call ay8910_loop
.continue_state_tests:

    call check_for_end_of_race
    dc.b $d0 ; "ret nc" not assembled correctly by VASM!
    ; Back to parent screen

    call update_inputs;

    ; Compute car speed vector
    ld ix,data_car0 ; current car is number 0

    ld a,(race_state)
    and a,1<<RACE_STATE_RACE_OVER
    jr z,.player_1_did_not_win_yet
    call autodrive_current_car
    jp .common_player1
.player_1_did_not_win_yet
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
.common_player1
    call update_car_angle_and_throttle

    ld a,(race_state)
    and a,1<<RACE_STATE_STARTUP_COUNTDOWN
    jp nz,.coutdown_running_skip_p1_move
    call update_car_speed
.coutdown_running_skip_p1_move:
    call update_car_engine_sound

    ld ix,data_car1 ; current car is number 1
    ld a,(players_count)
    cp 2
    jp z,.realplayer2
    call autodrive_current_car
    jp .common_player2
.realplayer2:

    ld a,(race_state)
    and a,1<<RACE_STATE_RACE_OVER
    jr z,.player_2_did_not_win_yet
    call autodrive_current_car
    jp .common_player2
.player_2_did_not_win_yet
    ld a,(RAM_MAP_CONTROLLERS_VALUES+1)
.common_player2
    call update_car_angle_and_throttle

    ld a,(race_state)
    and a,1<<RACE_STATE_STARTUP_COUNTDOWN
    jp nz,.coutdown_running_skip_p2_move
    call update_car_speed
.coutdown_running_skip_p2_move:
    call update_car_engine_sound
    
    ; Compute circuit tiles interactions
    ld ix,data_car0 ; current car is number 0
    call compute_circuit_interactions
    call handle_collision_noises
    ld ix,data_car1 ; current car is number 1
    call compute_circuit_interactions
    call handle_collision_noises

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

    ; Prepare winner / user image
    ld a,(race_state)
    and a,1<<RACE_STATE_LOADING_WINNER_LOOSER
    jr z,.no_winner_looser_image
    call prepare_winner_looser_image
.no_winner_looser_image:

    ; Load guys animations
    ld a,(race_state)
    and a,1<<RACE_STATE_ANIMATE_GUYS
    jp z,.no_animate_guys
    call animate_guys
.no_animate_guys:

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

    ; Draw winner / user image
    ld a,(race_state)
    and a,1<<RACE_STATE_LOADING_WINNER_LOOSER
    jr z,.no_winner_looser_image_draw
    call draw_winner_looser_image
.no_winner_looser_image_draw:

    ; Draw the cars
    ld ix,data_car0 ; current car is number 0
    call draw_car
    ld ix,data_car1 ; current car is number 1
    call draw_car

    ; Update laps to go (if needed)
    call update_laps_to_go

    ; Update countdown (if needed)
    ld a,(race_state)
    and a,1<<RACE_STATE_STARTUP_COUNTDOWN
    jp z,.no_countdown
    call update_startup_countdown
.no_countdown:

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

draw_winner_looser_image:
    ld a,(winner_looser_loading_counter)
    cp 32
    jp nc,.nothing_to_do
    cp 16 ; displaying the winner image?
    jr nc,.looser_image
    ld de,(image_winner_screen_address)
    jp .continue
.looser_image:
    ld de,(image_looser_screen_address)
.continue:
    and $f
    ld h,0
    add a
    add a
    add a
    add a
    ld l,a
    add hl,hl
    add hl,de
    ex de,hl
    ld hl,RAM_MAP_DECOMPRESSION_BUFFER_32
    ld bc,8
    ldir
    ; increment loading counter
    ld hl,winner_looser_loading_counter
    inc (hl)
    ret
.nothing_to_do:
    ld a,(race_state)
    and ~(1<<RACE_STATE_LOADING_WINNER_LOOSER)
    or 1<<RACE_STATE_ANIMATE_GUYS
    ld (race_state),a
    ret

prepare_winner_looser_image:
    ; Check if we have already computed the addresses
    ld hl,(image_winner_screen_address)
    ld a,h
    or l
    jp nz,.initial_address_already_computed
    ; now compute the initial addresses
    xor a
    ld (winner_looser_loading_counter),a
    ld bc,5+80*32+VRAM_ADDRESS
    ld hl,19+80*32+VRAM_ADDRESS
    ld a,(race_winner_id)
    cp 2
    jp z,.player_2_won
    ; player 1 won
    ld (image_winner_screen_address),bc
    ld (image_looser_screen_address),hl
    jp .initial_address_already_computed
.player_2_won:
    ld (image_looser_screen_address),bc
    ld (image_winner_screen_address),hl
.initial_address_already_computed
    ; load the loading counter and prepare images display depending on its value
    ld a,(winner_looser_loading_counter)
    cp 32 ; already displayed both images?
    jr z,.end
    ; We need to decompress one row an an image
    ld bc,8
	ld (rlh_param_extract_length),bc
    and $0f ; line in current image => ignore image1/image2 counter bit
    add a
    add a
    add a
    ld b,0
    ld c,a
	ld (rlh_param_offset_start),bc
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32
    ; now determine what image we want to decompress
    ld a,(winner_looser_loading_counter)
    cp 16 ; displaying the winner image?
    jr nc,.looser_image
    ld hl,rlh_you_win
    jp .load_image_line
.looser_image:
    ld hl,rlh_you_loose
.load_image_line:
	call decompress_rlh_advanced
.done:
.end:
    ret

update_startup_countdown:
    ; Decrement counter
    ld hl,(startup_count_down_counter)
    ld a,l
    cp 0
	dc.b $c8 ; "ret z" not assembled correctly by VASM!
    dec l
    jp nz,.no_carry
    ld l,60
    dec h
.no_carry:
    ld (startup_count_down_counter),hl
    jp z,.end_reached

    ; Test lower byte
    ld a,l
    cp 60
    ; return if not a round count
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM
    ; the lower byte is 60
    call ay8910_queue_sequence_start_beep_1
    ; Black on green
    ld a,%10110110
    out ($40),a
    call hud_show_countdown_digit
    ld c,2
    call wait_for_vbl_count
    ret
.end_reached:
    xor a
    ld (startup_count_down_counter),a
    call ay8910_queue_sequence_start_beep_2
    ; Black on green
    ld a,%10110110
    out ($40),a
    call hud_show_countdown_digit
    ld a,(race_state)
    and a,~(1<<RACE_STATE_STARTUP_COUNTDOWN)
    or a,1<<RACE_STATE_RACE_STARTED
    ld (race_state),a
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
    ; race is over
    ld a,(race_state)
    and a,~(1<<RACE_STATE_RACE_STARTED)
    or a,1<<RACE_STATE_RACE_OVER
    or a,1<<RACE_STATE_LOADING_WINNER_LOOSER
    ld (race_state),a
.still_some_laps:
.continue:
    scf ; set carry
    ret

handle_collision_noises:
    dc.b $d0 ; "ret nc" not assembled correctly by VASM!
    ; Send call collision sound
    ld a,(race_state)
    and a,1<<RACE_STATE_RACE_OVER
    dc.b $c0 ; "ret nz" not assembled correctly by VASM!
    call ay8910_randomize_crash_sound
    call ay8910_queue_sequence_wall_collision
    ret


animate_guys:
    ld a,(frame_count)
    ld b,a
    and 7 ; animate every x frames only
    dc.b $c0 ; "ret nz" is not assembled correctly by VASM
    ld a,b
    ld bc,6+32*2
    srl a
    srl a
    srl a
    bit 0,a
    jp z,.show_guy_loose
    ld de,res_guys
    ld hl,(image_winner_screen_address)
    jp .show_guy
.show_guy_loose
    ld de,res_guys+RES_GUYS_IMAGE_HEIGHT*2
    ld hl,(image_looser_screen_address)
.show_guy
    add hl,bc
    bit 1,a
    jp nz,.anim2
    ld bc,RES_GUYS_IMAGE_HEIGHT
    ex de,hl
    add hl,bc
    ex de,hl
.anim2:
    ld bc,32
    ld iyl,RES_GUYS_IMAGE_HEIGHT
.loop:
    ld a,(de)
    ld (hl),a
    inc de
    add hl,bc
    dec iyl
    jp nz,.loop

    ret