; memory map
; $C000... : Bootstrapper + program code

RAM_MAP_PRECALC_AREA equ RAM_MAP_PRECALC_VEHICLE_1
RAM_MAP_STACK equ RAM_MAP_STACK_END+255
 
; $FE00-$FF00 : Stack (256 bytes)
; $F600-$FA80 : Precalc vehicle 0 (1152 bytes)
; $F180-$F600 : Precalc vehicle 1 (1152 bytes)
; $F5F0-$F5F8 : Input controllers values (8 bytes)
; $F478-$F538 : decompressed circuit data (192 bytes)

RAM_MAP_STACK_END equ $FF00
RAM_MAP_PRECALC_VEHICLE_0 equ $FA80
RAM_MAP_PRECALC_VEHICLE_1 equ $F600
RAM_MAP_CONTROLLERS_VALUES equ $F5F8
RAM_MAP_CIRCUIT_DATA equ $F538
