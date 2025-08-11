    include inc/rammap.inc
    include inc/inputs.inc
    section	code,text

    global start, players_count
    global emulator_security_idle

    ; sound ?
    ; nouveaux circuits enchaînes
    ; détection des tours
    ; affichage de stats (tours restants, temps?)
    ; taches d'huile
    ; profils de voitures (vitesse de rotation, profil d'accélération, dérapages)
    ; dérapage en fonction de la vitesse?
    ; photos des voitures
    ; images en niveaux de gris
    ; collisions entre voitures
    ; Gérer le security idle mode par constante d'assemblage / mode release
    ; Compression RLE
    ; Editeur: grouper les dalles par 2 par couleurs

players_count:
    dc.b 0

start:
    di ; Disable interrupts
    
    ld sp,RAM_MAP_STACK_END

    call init_joysticks

.show_intro
    call show_intro

    ld a,$ff
    call clear_screen
    call switch_to_mode_graphics_hd;

    ; load the circuit
    ld hl,huf_circuitdata
    call load_circuit

    ; draw the circuit
    call draw_circuit

    ; precompute car positions
    call precalc_shifted_cars

    ld ix,data_car0 ; current car is number 0
    call prepare_draw_car
    call draw_car

    ld ix,data_car1 ; current car is number 1
    call prepare_draw_car
    call draw_car

.loop

    call update_inputs;

    ; Compute car speed vector
    ld ix,data_car0 ; current car is number 0
    ld a,(RAM_MAP_CONTROLLERS_VALUES)
    call update_car_angle_and_throttle
    call update_car_speed
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
    jp nz,.show_intro

    ; Black on white
    ;ld a,%11110110
    ;out ($40),a

    ; Wait until the end of the frame
    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    call emulator_security_idle;

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

    ; Black on white
    ld a,%11110110
    out ($40),a

    jp .loop

    ret

emulator_security_idle:
    ret
    ; wait for a known amount of cycles to mimic the real hardware => 29 lines
    ld b,2
    ld c,125
.innerloop
    dec c
    jr nz,.innerloop
    dec b
    jr nz,.innerloop
    ret