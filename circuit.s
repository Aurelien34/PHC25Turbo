    include inc/rammap.inc
    include inc/screen.inc

    section	code,text

    global load_circuit, draw_circuit, compute_tile_address

TILE_DATA_SIZE equ 16*12
CAR_DATA_SIZE equ 3
OFFSET_CAR_0_DATA equ TILE_DATA_SIZE
OFFSET_CAR_1_DATA equ OFFSET_CAR_0_DATA+CAR_DATA_SIZE
OFFSSET_CIRCUIT_LAPS_TOTAL equ OFFSET_CAR_1_DATA+CAR_DATA_SIZE


load_circuit:
    ; hl points to compressed circuit data
    ld de,RAM_MAP_CIRCUIT_DATA
    call decompress_rlh
    ld hl,rlh_circuit_tiles_0
    ld de,RAM_MAP_PRECALC_AREA
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
    call set_laps_count ; store in race info

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
    ret

draw_circuit:
    ld bc,0
.loopy ; 12 rows
    call wait_for_vbl
    ld b,0
.loopx ; 16 columns
    call draw_circuit_tile
    inc b
    bit 4,b
    jp z,.loopx
    inc c
    ld a,c
    cp 12
    jr nz,.loopy

; b = x
; c = y
draw_circuit_tile:
    push hl
    push bc

    call compute_tile_address ; get tile address in [de]
    ; load tile number
    ld a,(de)
    and %11111000
    ; check if the tile should be drawn
    or a
    jr z,.enddraw
    sub 8; decrement tile number, as we skip blank tile (#0)
    ; compute circuit bitmap address
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    ld de,RAM_MAP_PRECALC_AREA
    add hl,de ; we now have tile bitmap address in [hl]

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
    pop bc
    pop hl
    ret

; b = x
; c = y
; returns tile address in [de]
compute_tile_address:
    push hl
    push bc

    ; compute circuit tile address
    ; y offset (in c) x 16
    ld h,0
    ld l,c
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ; x offset (in b)
    ld c,b
    ld b,0
    ; sum x/y offsets
    add hl,bc
    ; add circuit base address
    ld de,RAM_MAP_CIRCUIT_DATA
    add hl,de
    ex de,hl ; de now points to the tile address

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

