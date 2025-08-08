; memory map
; $C000... : Bootstrapper + program code
; 2048 bytes per vehicle for shift precompute (8 128 bytes strips twice the width)
; 
; $ee38-eefd : decompressed circuit data
; $eefe-eeff : input controllers values (2 bytes)
; $ef00-f6ff : precalc vehicle 1 (2048 bytes)
; $f700-feff : precalc vehicle 0 (2048 bytes)
; $ff00-ffff : Stack (256 bytes)

RAM_MAP_STACK_END equ $ffff
RAM_MAP_PRECALC_AREA equ $ef00
RAM_MAP_PRECALC_VEHICLE_0 equ $f700
RAM_MAP_PRECALC_VEHICLE_1 equ $ef00
RAM_MAP_CONTROLLERS_VALUES equ $eefe
RAM_MAP_CIRCUIT_DATA equ $ee38
