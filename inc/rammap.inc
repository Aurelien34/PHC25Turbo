; memory map
; $C000... : Bootstrapper + program code

RAM_MAP_PRECALC_AREA equ RAM_MAP_PRECALC_VEHICLE_1
RAM_MAP_STACK equ $FFFF

RAM_MAP_CONTROLLERS_VALUES equ $c000 ; use BASIC header segment as controllers status space


; $FFC0-$FFFF : Stack (64 bytes)
; $FB40-$FFBF : Precalc vehicle 0 (1152 bytes)
; $F6C0-$FB3F : Precalc vehicle 1 (1152 bytes)
; $F5F7-$F6BF : Decompressed circuit data (201 bytes)
; $F5D7-$F5F6 : Decompression area, only 32 bytes (32 bytes)

RAM_MAP_STACK_END equ $FFC0
RAM_MAP_PRECALC_VEHICLE_0 equ $FB40
RAM_MAP_PRECALC_VEHICLE_1 equ $F6C0
RAM_MAP_CIRCUIT_DATA equ $F5F7
RAM_MAP_DECOMPRESSION_BUFFER_32 equ $F5D7
