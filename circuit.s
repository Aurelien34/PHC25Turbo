    include inc/rammap.inc
    include inc/screen.inc
    include inc/circuit.inc

    section	code,text

    global load_circuit, dispatch_circuit_info, draw_circuit
    global circuit_mirror_mode


tilesets_list:
    dc.w rlh_circuit_tiles_0
    dc.w rlh_circuit_tiles_1
    dc.w rlh_circuit_tiles_2

circuit_tileset_address:
    dc.w 0

circuit_mirror_mode:
    dc.b 0

load_circuit:
    ; hl points to compressed circuit data
    ld de,RAM_MAP_CIRCUIT_DATA+16
    call decompress_rlh
    ; Offset for last row
    ld hl,RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_DATA_END-1-16
    ld de,RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_DATA_END-1
    ld bc,CIRCUIT_OFFSET_DATA_END-CIRCUIT_OFFSET_DATA_START
    lddr
    ; Walls on first row
    ld hl,RAM_MAP_CIRCUIT_DATA
    call .generate_horizontal_wall
    ; Walls on last row
    ld hl,RAM_MAP_CIRCUIT_DATA+16*11
    call .generate_horizontal_wall
    ; Configure tile set
    ld b,0
    ld a,(RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_DATA_TILESET)
    add a
    ld c,a
    ld hl,tilesets_list
    add hl,bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld (circuit_tileset_address),bc
    call mirror_circuit
    ret
.generate_horizontal_wall:
    ld d,h
    ld e,l
    inc de
    ld bc,15
    ld (hl),3<<3
    ldir
    ret

mirror_circuit:
    ld a,(circuit_mirror_mode)
    or a
	dc.b $c8 ; "ret z" not assembled correctly by VASM!
    ; compute circuit mirror version
    ld hl,RAM_MAP_CIRCUIT_DATA+16
    ld de,RAM_MAP_CIRCUIT_DATA+16+15
    ld iyl,10
.loopy
    ld ixl,8
    push hl
    push de
.loopx
    ld a,(hl)
    call mirror_tile
    ld c,a
    ld a,(de)
    call mirror_tile
    ld (hl),a
    ld a,c
    ld (de),a
    inc hl
    dec de
    dec ixl
    jr nz,.loopx
    pop hl ; reverse order on purpose
    pop de
    ld bc,16
    add hl,bc
    ex de,hl
    add hl,bc
    dec iyl
    jr nz,.loopy
    ret

    ;dc.b "            BREAKPOINT              "
mirror_tile:
    push hl
    push bc
    push af
    ld hl,.tile_data
    ld b,0
    srl a
    srl a
    srl a
    ld c,a
    add hl,bc
    ld b,(hl)
    pop af
    and %111
    ld c,a
    ld a,8
    sub c
    and %111
    add b
    pop bc
    pop hl
    ret
.tile_data:
    dc.b 0<<3,1<<3,2<<3,3<<3,5<<3,4<<3,7<<3,6<<3,10<<3,9<<3,8<<3,11<<3,12<<3


dispatch_circuit_info:
    ; now load car positions in circuit
    ld hl,RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_CAR_0_DATA
    ld de,data_car0
    call copy_car_characteristics
    ld hl,RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_CAR_1_DATA
    ld de,data_car1
    call copy_car_characteristics

    ; Load lap count
    ld a,(RAM_MAP_CIRCUIT_DATA+CIRCUIT_OFFSET_CIRCUIT_LAPS_TOTAL)
    inc a ; increment count, as it will be decremented when the cars will cross the line the first time
    ld (current_laps_to_go),a
    call car_set_lap_count
    ret

copy_car_characteristics
    xor a
    ld (de),a   ; x lower
    inc de
    ld c,(hl)   ; x upper

    inc hl
    ld a,(circuit_mirror_mode)
    or a
    ld a,c
    jr z,.no_mirror
    ld a,255-8
    sub c
.no_mirror:
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
    djnz .loopclear
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
.loopy ; 11 rows
    ld b,0
.loopx ; 16 columns
    ld a,(hl) ; load current tile in the circuit map
    inc hl  ; move the pointer to the next one
    and a,%11111000 ; remove the autodrive markers
    cp ixl ; compare the circuit tile with the current one
    jr nz,.tile_done ; if not the same, then it will be drawnduring another cycle
    call draw_circuit_tile ; tile number is in register [a]
.tile_done:
    inc b
    bit 4,b
    jr z,.loopx
    inc c
    ld a,c
    cp 11 ; skip the last row, as it will be ocupied by the hdd
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
    djnz .loop
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
    ld hl,(circuit_tileset_address)
    ld de,RAM_MAP_DECOMPRESSION_BUFFER_32
    push bc
    call decompress_rlh_advanced
    pop bc
.tile_decompressed:
    ld hl,RAM_MAP_DECOMPRESSION_BUFFER_32
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

    djnz .loop

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

