    include inc/rammap.inc
    include inc/screen.inc

    section	code,text

    global load_circuit, draw_circuit

TILE_DATA_SIZE equ 16*12
CAR_DATA_SIZE equ 3
OFFSET_CAR_0_DATA equ TILE_DATA_SIZE
OFFSET_CAR_1_DATA equ OFFSET_CAR_0_DATA+CAR_DATA_SIZE
OFFSSET_CIRCUIT_LAPS_TOTAL equ OFFSET_CAR_1_DATA+CAR_DATA_SIZE


load_circuit:
    ; hl points to compressed circuit data
    ld de,RAM_MAP_CIRCUIT_DATA
    call decompress_rlh

    ; now load car positions in circuit
    ld hl,RAM_MAP_CIRCUIT_DATA+OFFSET_CAR_0_DATA
    ld de,data_car0
    call copy_car_characteristics
    ld hl,RAM_MAP_CIRCUIT_DATA+OFFSET_CAR_1_DATA
    ld de,data_car1
    call copy_car_characteristics

    ; Load lap count
    ld a,(RAM_MAP_CIRCUIT_DATA+OFFSSET_CIRCUIT_LAPS_TOTAL)
    inc a ; increment count, as it will be decremented when the cars will cross the line the first time
    ld (current_laps_to_go),a
    call car_set_lap_count
    ret

copy_car_characteristics
    xor a
    ld (de),a   ; x lower
    inc de
    ld a,(hl)   ; x upper
    inc hl
    ld (de),a
    inc de
    xor a
    ld (de),a   ; y lower
    inc de
    ld a,(hl)   ; y upper
    inc hl
    ld (de),a
    inc de
    ld a,(hl)   ; angle
    ld (de),a
    ; clear throttle and speed
    xor a
    ld b,5
.loopclear
    ld (de),a
    inc de
    dec b
    jr nz,.loopclear
    ret

last_tile_drawn:
    dc.b 0

draw_circuit:

    ; tile number for the previous tile in the cache => set it to an invalid number in order to force the cache
    ld a,$ff
    ld (last_tile_drawn),a

    ; iterate through possible tiles
    call get_max_tile_index;
    ld ixl,a ; loop on tile number => max number
.loop_tile
    ld hl,RAM_MAP_CIRCUIT_DATA+16 ; skip the first row
    ld c,1 ; ignore the first raw, as we will display the HUD
.loopy ; 12 rows
    ld b,0
.loopx ; 16 columns
    ld a,(hl) ; load current tile in the circuit map
    inc hl  ; move the pointer to the next one
    and a,%11111000 ; remove the autodrive markers
    cp ixl ; compare the circuit tile with the current one
    jp nz,.tile_done ; if not the same, then it will be drawnduring another cycle
    call draw_circuit_tile ; tile number is in register [a]
.tile_done:
    inc b
    bit 4,b
    jp z,.loopx
    inc c
    ld a,c
    cp 12
    jr nz,.loopy

    ld a,ixl
    sub 8 ; tile number is shifted 3 time to fit the autopilot instructions
    ld ixl,a
    jr nz,.loop_tile ; nz, as we don't draw tile #0 anyway
    ret

; return the highest tile value in [a] for the current circuit
get_max_tile_index:
    ld hl,RAM_MAP_CIRCUIT_DATA
    ld b,16*12 ; iterate on all tiles
    ld c,0 ; keeps the currently highest value
.loop
    ld a,(hl)
    inc hl
    and %11111000 ; mask autodrive bits
    cp c
    jr c,.lower
    ld c,a
.lower:
    dec b
    jr nz,.loop
    ld a,c ; transfer result to [a] register
    ret

; b = x
; c = y
draw_circuit_tile:
    push hl
    push bc
    push de

    ; check if the tile should be drawn
    or a
    jr z,.enddraw
    sub 8; decrement tile number, as we skip blank tile (#0)

    ld hl,last_tile_drawn
    cp (hl)
    jr z,.tile_decompressed
    ld (last_tile_drawn),a

    ; compute circuit bitmap address
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ; we need the address of the tile
    ld (rlh_param_offset_start),hl
    ld hl,32
    ld (rlh_param_extract_length),hl
    ld hl,rlh_circuit_tiles_0
    ld de,RAM_MAP_PRECALC_VEHICLE_0
    push bc
    call decompress_rlh_advanced
    pop bc
.tile_decompressed:
    ld hl,RAM_MAP_PRECALC_VEHICLE_0
    call compute_screen_address ; get screen address in [de]
    ld b,16
.loop ; 16 lines
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    inc hl
    ; Add 31 to [de]
    push hl
    ld hl,31
    add hl,de
    ex de,hl
    pop hl

    dec b
    jr nz,.loop

.enddraw:
    pop de
    pop bc
    pop hl
    ret

compute_screen_address:
; b = x
; c = y
; returns screen address in [de]
    push hl
    push bc

    ; compute circuit tile address
    ; y offset (in c) x 512
    ld h,c
    ld l,0
    add hl,hl
    ; x offset (in b)
    ld c,b
    ld b,0
    ; sum x/y offsets (x*2)
    add hl,bc
    add hl,bc
    ; add VRAM base address
    ld de,VRAM_ADDRESS
    add hl,de ; [hl] now points to the tile address in VRAM
    ex de,hl

    pop bc
    pop hl
    ret

