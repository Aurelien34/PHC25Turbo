; memory map
; $C000... : Bootstrapper + program code

RAM_MAP_PRECALC_AREA equ RAM_MAP_PRECALC_VEHICLE_1
RAM_MAP_STACK equ RAM_MAP_STACK_END+255
 
; $FF00-$FFFF : Stack (256 bytes)
; $FA80-$FEFF : Precalc vehicle 0 (1152 bytes)
; $F600-$FA7F : Precalc vehicle 1 (1152 bytes)
; $F5F8-$F5FF : Input controllers values (8 bytes)
; $F530-$F5F7 : Decompressed circuit data (200 bytes)
; $F510-$F52F : Decompression area, only 32 bytes (32 bytes)

RAM_MAP_STACK_END equ $FF00
RAM_MAP_PRECALC_VEHICLE_0 equ $FA80
RAM_MAP_PRECALC_VEHICLE_1 equ $F600
RAM_MAP_CONTROLLERS_VALUES equ $F5F8
RAM_MAP_CIRCUIT_DATA equ $F530
RAM_MAP_DECOMPRESSION_BUFFER_32 equ $F510
