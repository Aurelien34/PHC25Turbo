    include inc/rammap.inc

    section	code,text

    global circuit_picker_circuit_index, circuit_picker_circuit_data_address
    global circuit_picker_show

CIRCUIT_COUNT equ (circuits_list_end-circuits_list)/2

circuits_list:
    dc.w rlh_circuit_monaco
    dc.w rlh_circuit_daytono
circuits_list_end

circuit_picker_circuit_data_address:
    dc.w $ffff

circuit_picker_circuit_index:
    dc.b 0

circuit_picker_show:

    call select_circuit

    ret

select_circuit:
    ; Point circuit_picker_circuit_data_address to the correct circuit tile address
    ld b,0
    ld a,(circuit_picker_circuit_index)
    add a
    ld c,a
    ld hl,circuits_list
    add hl,bc
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld (circuit_picker_circuit_data_address),bc
    ret