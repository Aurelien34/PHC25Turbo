    include inc/rammap.inc
    section	code,text

    global start, players_count

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
    ; Accueil en couleur et qui bouge!

players_count:
    dc.b 0

start:
    di ; Disable interrupts
    
    ld sp,RAM_MAP_STACK_END

    call init_joysticks

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
    
    ld ix,data_car0 ; current car is number 0
    call compute_circuit_interactions
    ld ix,data_car1 ; current car is number 1
    call compute_circuit_interactions

    ld ix,data_car0 ; current car is number 0
    call update_car_position
    ld ix,data_car1 ; current car is number 1
    call update_car_position

    ld ix,data_car0 ; current car is number 0
    call prepare_draw_car
    ld ix,data_car1 ; current car is number 1
    call prepare_draw_car

    ; Black on white
    ;ld a,%11110110
    ;out ($40),a

    call wait_for_vbl

    ; Black on green
    ld a,%10110110
    out ($40),a

    ;call emulator_security_idle;

    ld ix,data_car1 ; ; current car is number 1
    call erase_car
    ld ix,data_car0 ; current car is number 0
    call erase_car

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
    ; wait for a known amount of cycles to mimic the real hardware => 29 lines
    ld b,2
    ld c,125
.innerloop
    dec c
    jr nz,.innerloop
    dec b
    jr nz,.innerloop
    ret