    include inc/rammap.inc

    section	code,text

    global circuit_picker_circuit_data_address, circuit_picker_circuit_tileset_address
    global circuit_picker_show

circuit_picker_circuit_data_address:
    dc.w rlh_circuit_monaco

circuit_picker_circuit_tileset_address:
    dc.w rlh_circuit_tiles_0

circuit_picker_index:
    dc.b $ff

CIRCUIT_COUNT equ 2

circuits_list:
    dc.w rlh_circuit_monaco
    dc.w rlh_circuit_daytono

tilesets_list:
    dc.w rlh_circuit_tiles_0
    dc.w rlh_circuit_tiles_1

circuit_picker_show:
    ret