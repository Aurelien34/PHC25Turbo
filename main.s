    include inc/rammap.inc
    include inc/inputs.inc
    section	code,text

    global start, players_count

    if DEBUG = 1
    global emulator_security_idle
    endif

players_count:
    dc.b 0

start:
    di ; Disable interrupts
    
    ld sp,RAM_MAP_STACK_END

    call init_joysticks

.loop

    call show_intro
    call start_race

    jp .loop

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