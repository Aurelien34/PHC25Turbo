; memory map
; $C000... : Bootstrapper + program code

RAM_MAP_PRECALC_AREA equ RAM_MAP_PRECALC_VEHICLE_1
RAM_MAP_STACK equ $FFFF
 
; $FFC0-$FFFF : Stack (64 bytes)
; $FB40-$FFBF : Precalc vehicle 0 (1152 bytes)
; $F6C0-$FB3F : Precalc vehicle 1 (1152 bytes)
; $F6B8-$F6BF : Input controllers values (8 bytes)
; $F5EF-$F6B7 : Decompressed circuit data (201 bytes)
; $F5CF-$F5EE : Decompression area, only 32 bytes (32 bytes)

RAM_MAP_STACK_END equ $FFC0
RAM_MAP_PRECALC_VEHICLE_0 equ $FB40
RAM_MAP_PRECALC_VEHICLE_1 equ $F6C0
RAM_MAP_CONTROLLERS_VALUES equ $F6B8
RAM_MAP_CIRCUIT_DATA equ $F5EF
RAM_MAP_DECOMPRESSION_BUFFER_32 equ $F5CF
