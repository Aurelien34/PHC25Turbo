    include inc/rammap.inc
    include inc/inputs.inc
    section	code,text

    global start, players_count, get_opponent_name

    if DEBUG = 1
    global emulator_security_idle
    endif

opponent_names:
    dc.w opponent_name_0
    dc.w opponent_name_1    
    dc.w opponent_name_2
    dc.w opponent_name_3    
    dc.w opponent_name_4
    dc.w opponent_name_5    
    dc.w opponent_name_6
    dc.w opponent_name_7    

opponent_name_0:
    dc.b "Cody",0
opponent_name_1:
    dc.b "Axel",0
opponent_name_2:
    dc.b "Mitch",0
opponent_name_3:
    dc.b "Dusty",0
opponent_name_4:
    dc.b "Blake",0
opponent_name_5:
    dc.b "Nikki",0
opponent_name_6:
    dc.b "Roxy",0
opponent_name_7:
    dc.b "Daisy",0

; returns opponent name in [bc]
get_opponent_name:
    push hl
    ;ld hl,(opponent_number)

    ; random for now
    ld h,0
    ld a,r
    and $7
    ld l,a

    add hl,hl
    ld bc,opponent_names
    add hl,bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    pop hl 
    ret

opponent_number:
    dc.w 2

players_count:
    dc.b 0

opponent_name_pointer:
    

start:
    di ; Disable interrupts
    
    ld sp,RAM_MAP_STACK

    call ay8910_init

.loop

    call show_intro

    call circuit_picker_show
    ; Ensure a circuit has been selected
    ld a,(circuit_picker_circuit_index)
    cp $ff
    jr z,.loop

    call start_race

    jr .loop

    ret

    if DEBUG = 1
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
    endif