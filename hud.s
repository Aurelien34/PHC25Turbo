    include inc/rammap.inc
    include inc/car.inc
    include inc/screen.inc
    section	code,text

    global show_hud, hud_refresh_lap_count




block_texts_to_display:
    ; x is in 8 pixels increments, 32 increments for one row
    ; y is pixel perfect
    ; should end with a $0000 value
    ; Room for 32x2 characters
    ;dc.w 1+4*32+VRAM_ADDRESS, sz_line_0
    ;dc.w 32-13-1+4*32+VRAM_ADDRESS, sz_line_1
    ;dc.w $0000

txt_1_player:
    dc.b "You vs ",0
txt_2_players:
    dc.b "P1 vs P2",0
txt_laps_to_go:
    dc.b "LAPS TO GO:",0


show_hud:
    ; Decompress header
    ld hl,rlh_hud
    ld de,VRAM_ADDRESS
    call decompress_rlh

    ; Write laps to go text
    ld bc,txt_laps_to_go
    ld de,32-12-1+4*32+VRAM_ADDRESS
    call write_string

    ; Display config related text
    ld de,1+4*32+VRAM_ADDRESS
    ld a,(players_count)
    cp 2
    jr nz,.single_player
    ld bc,txt_2_players
    call write_string
    jr .players_names_done
.single_player
    ld bc,txt_1_player
    call write_string
    ld de,1+7+4*32+VRAM_ADDRESS
    call get_opponent_name
    call write_string
    jr .players_names_done
.players_names_done
    call get_lap_count
    dec a ; show 1 less, as the cars will have to cross the line for the real countdown to stard
    call hud_refresh_lap_count
    ret

; Lap count in [a]
hud_refresh_lap_count:
    push hl
    push bc
    push de
    push ix
    ; now [A] contains the lowest number
    add '0'
    ld de,32-1-1+4*32+VRAM_ADDRESS
    call write_character
    pop ix
    pop de
    pop bc
    pop hl
    ret
