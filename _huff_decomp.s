    section	code,text

    global decompress_huffman

; Input registers:
;-----------------
; interrupts should be disabled
; registers assignment:
; hl => source buffer pointer
; de => target buffer pointer

; Work registers:
;----------------
; c => current byte
; b => bits left to process in current byte
; ix => output bytes left to be decoded

decompress_huffman:
	push af
	push bc
	push ix
	call decompress_huffman_unsafe
	pop ix
	pop bc
	pop af
	ret

decompress_huffman_unsafe:
    ;di ; disable interrupts

    ; initialization
    ; load target size and compress flag in ix
    ld a,(hl)
    ld ixl,a
    inc hl
    ld a,(hl)
    ld ixh,a
    inc hl

	; decode compression flag
	bit 7,a
	jr nz,.decomp

	; data is not compressed
	; load data size in bc
	ld b,ixh
	ld c,ixl
	; copy uncompressed data
	ldir
	ret

.decomp:
	; data is compressed
	; clear compression flag
	res 7,a
	ld ixh,a

    ; load current byte
    ld c,(hl)
    ; 8 bits to be processed
    ld b,8
    ;ei ; enable interrupts

    ; now we can loop on decoding code
.loopDecomp
    ld a,0
    cp ixl
    jr nz,.continue
    cp ixh
    jr z,.endLoopDecomp
.continue
    call decompress_huffman_byte
    ld (de),a
    inc de
    dec ix
    jr .loopDecomp
.endLoopDecomp

    ret

; result in C flag
get_next_bit:
    sll c; shift left and store bit of interest in carry flag
    ex af,af' ; '; backup status flags to shadow registers
    dec b ; point to the next bit
    jp nz,.end ; still some bits to process

    ld b,8 ; back to first bit
    inc hl ; point to next byte
	; load next byte
    ld c,(hl)
.end
    ex af,af' ; '; restore carry flag
    ret

decompress_huffman_byte:
;BEGIN_UNCOMPRESS_GENERATION
;Decompression algorithm takes 703 bytes

.n:
	call get_next_bit
	jr c,.n1 ; Jump size: 3
.n0:
	ld a,$00
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 292
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 155
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 91
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 83
.n10000:
	call get_next_bit
	jr c,.n100001 ; Jump size: 75
.n100000:
	call get_next_bit
	jr c,.n1000001 ; Jump size: 67
.n1000000:
	call get_next_bit
	jr c,.n10000001 ; Jump size: 59
.n10000000:
	call get_next_bit
	jr c,.n100000001 ; Jump size: 27
.n100000000:
	call get_next_bit
	jr c,.n1000000001 ; Jump size: 11
.n1000000000:
	call get_next_bit
	jr c,.n10000000001 ; Jump size: 3
.n10000000000:
	ld a,$6a
	ret
.n10000000001:
	ld a,$d6
	ret
.n1000000001:
	call get_next_bit
	jr c,.n10000000011 ; Jump size: 3
.n10000000010:
	ld a,$28
	ret
.n10000000011:
	ld a,$45
	ret
.n100000001:
	call get_next_bit
	jr c,.n1000000011 ; Jump size: 11
.n1000000010:
	call get_next_bit
	jr c,.n10000000101 ; Jump size: 3
.n10000000100:
	ld a,$b0
	ret
.n10000000101:
	ld a,$84
	ret
.n1000000011:
	call get_next_bit
	jr c,.n10000000111 ; Jump size: 3
.n10000000110:
	ld a,$81
	ret
.n10000000111:
	ld a,$51
	ret
.n10000001:
	ld a,$46
	ret
.n1000001:
	ld a,$c0
	ret
.n100001:
	ld a,$f0
	ret
.n10001:
	ld a,$ff
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$a8
	ret
.n10011:
	call get_next_bit
	jr c,.n100111 ; Jump size: 3
.n100110:
	ld a,$02
	ret
.n100111:
	call get_next_bit
	jr c,.n1001111 ; Jump size: 19
.n1001110:
	call get_next_bit
	jr c,.n10011101 ; Jump size: 3
.n10011100:
	ld a,$11
	ret
.n10011101:
	call get_next_bit
	jr c,.n100111011 ; Jump size: 3
.n100111010:
	ld a,$c3
	ret
.n100111011:
	ld a,$c5
	ret
.n1001111:
	call get_next_bit
	jr c,.n10011111 ; Jump size: 11
.n10011110:
	call get_next_bit
	jr c,.n100111101 ; Jump size: 3
.n100111100:
	ld a,$33
	ret
.n100111101:
	ld a,$23
	ret
.n10011111:
	ld a,$c1
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 19
.n1010:
	call get_next_bit
	jr c,.n10101 ; Jump size: 11
.n10100:
	call get_next_bit
	jr c,.n101001 ; Jump size: 3
.n101000:
	ld a,$03
	ret
.n101001:
	ld a,$3f
	ret
.n10101:
	ld a,$54
	ret
.n1011:
	call get_next_bit
	jr c,.n10111 ; Jump size: 91
.n10110:
	call get_next_bit
	jr c,.n101101 ; Jump size: 3
.n101100:
	ld a,$fc
	ret
.n101101:
	call get_next_bit
	jr c,.n1011011 ; Jump size: 27
.n1011010:
	call get_next_bit
	jr c,.n10110101 ; Jump size: 11
.n10110100:
	call get_next_bit
	jr c,.n101101001 ; Jump size: 3
.n101101000:
	ld a,$8c
	ret
.n101101001:
	ld a,$12
	ret
.n10110101:
	call get_next_bit
	jr c,.n101101011 ; Jump size: 3
.n101101010:
	ld a,$d4
	ret
.n101101011:
	ld a,$35
	ret
.n1011011:
	call get_next_bit
	jr c,.n10110111 ; Jump size: 19
.n10110110:
	call get_next_bit
	jr c,.n101101101 ; Jump size: 3
.n101101100:
	ld a,$5c
	ret
.n101101101:
	call get_next_bit
	jr c,.n1011011011 ; Jump size: 3
.n1011011010:
	ld a,$18
	ret
.n1011011011:
	ld a,$31
	ret
.n10110111:
	call get_next_bit
	jr c,.n101101111 ; Jump size: 11
.n101101110:
	call get_next_bit
	jr c,.n1011011101 ; Jump size: 3
.n1011011100:
	ld a,$44
	ret
.n1011011101:
	ld a,$ac
	ret
.n101101111:
	call get_next_bit
	jr c,.n1011011111 ; Jump size: 3
.n1011011110:
	ld a,$af
	ret
.n1011011111:
	ld a,$8b
	ret
.n10111:
	call get_next_bit
	jr c,.n101111 ; Jump size: 3
.n101110:
	ld a,$0a
	ret
.n101111:
	ld a,$40
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 27
.n110:
	call get_next_bit
	jr c,.n1101 ; Jump size: 19
.n1100:
	call get_next_bit
	jr c,.n11001 ; Jump size: 3
.n11000:
	ld a,$2a
	ret
.n11001:
	call get_next_bit
	jr c,.n110011 ; Jump size: 3
.n110010:
	ld a,$80
	ret
.n110011:
	ld a,$05
	ret
.n1101:
	ld a,$aa
	ret
.n111:
	call get_next_bit
	jp c,.n1111 ; Jump size: 332
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 75
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 67
.n111000:
	call get_next_bit
	jr c,.n1110001 ; Jump size: 35
.n1110000:
	call get_next_bit
	jr c,.n11100001 ; Jump size: 27
.n11100000:
	call get_next_bit
	jr c,.n111000001 ; Jump size: 11
.n111000000:
	call get_next_bit
	jr c,.n1110000001 ; Jump size: 3
.n1110000000:
	ld a,$83
	ret
.n1110000001:
	ld a,$95
	ret
.n111000001:
	call get_next_bit
	jr c,.n1110000011 ; Jump size: 3
.n1110000010:
	ld a,$5a
	ret
.n1110000011:
	ld a,$d5
	ret
.n11100001:
	ld a,$82
	ret
.n1110001:
	call get_next_bit
	jr c,.n11100011 ; Jump size: 11
.n11100010:
	call get_next_bit
	jr c,.n111000101 ; Jump size: 3
.n111000100:
	ld a,$52
	ret
.n111000101:
	ld a,$a3
	ret
.n11100011:
	call get_next_bit
	jr c,.n111000111 ; Jump size: 3
.n111000110:
	ld a,$d1
	ret
.n111000111:
	ld a,$96
	ret
.n111001:
	ld a,$50
	ret
.n11101:
	call get_next_bit
	jr c,.n111011 ; Jump size: 99
.n111010:
	call get_next_bit
	jr c,.n1110101 ; Jump size: 27
.n1110100:
	call get_next_bit
	jr c,.n11101001 ; Jump size: 19
.n11101000:
	call get_next_bit
	jr c,.n111010001 ; Jump size: 3
.n111010000:
	ld a,$a6
	ret
.n111010001:
	call get_next_bit
	jr c,.n1110100011 ; Jump size: 3
.n1110100010:
	ld a,$17
	ret
.n1110100011:
	ld a,$bf
	ret
.n11101001:
	ld a,$41
	ret
.n1110101:
	call get_next_bit
	jr c,.n11101011 ; Jump size: 27
.n11101010:
	call get_next_bit
	jr c,.n111010101 ; Jump size: 11
.n111010100:
	call get_next_bit
	jr c,.n1110101001 ; Jump size: 3
.n1110101000:
	ld a,$42
	ret
.n1110101001:
	ld a,$34
	ret
.n111010101:
	call get_next_bit
	jr c,.n1110101011 ; Jump size: 3
.n1110101010:
	ld a,$d2
	ret
.n1110101011:
	ld a,$2f
	ret
.n11101011:
	call get_next_bit
	jr c,.n111010111 ; Jump size: 11
.n111010110:
	call get_next_bit
	jr c,.n1110101101 ; Jump size: 3
.n1110101100:
	ld a,$b3
	ret
.n1110101101:
	ld a,$10
	ret
.n111010111:
	call get_next_bit
	jr c,.n1110101111 ; Jump size: 3
.n1110101110:
	ld a,$fa
	ret
.n1110101111:
	call get_next_bit
	jr c,.n11101011111 ; Jump size: 3
.n11101011110:
	ld a,$fd
	ret
.n11101011111:
	ld a,$bc
	ret
.n111011:
	call get_next_bit
	jp c,.n1110111 ; Jump size: 139
.n1110110:
	call get_next_bit
	jr c,.n11101101 ; Jump size: 59
.n11101100:
	call get_next_bit
	jr c,.n111011001 ; Jump size: 27
.n111011000:
	call get_next_bit
	jr c,.n1110110001 ; Jump size: 11
.n1110110000:
	call get_next_bit
	jr c,.n11101100001 ; Jump size: 3
.n11101100000:
	ld a,$2c
	ret
.n11101100001:
	ld a,$0c
	ret
.n1110110001:
	call get_next_bit
	jr c,.n11101100011 ; Jump size: 3
.n11101100010:
	ld a,$62
	ret
.n11101100011:
	ld a,$56
	ret
.n111011001:
	call get_next_bit
	jr c,.n1110110011 ; Jump size: 11
.n1110110010:
	call get_next_bit
	jr c,.n11101100101 ; Jump size: 3
.n11101100100:
	ld a,$cd
	ret
.n11101100101:
	ld a,$3d
	ret
.n1110110011:
	call get_next_bit
	jr c,.n11101100111 ; Jump size: 3
.n11101100110:
	ld a,$04
	ret
.n11101100111:
	ld a,$ab
	ret
.n11101101:
	call get_next_bit
	jr c,.n111011011 ; Jump size: 27
.n111011010:
	call get_next_bit
	jr c,.n1110110101 ; Jump size: 11
.n1110110100:
	call get_next_bit
	jr c,.n11101101001 ; Jump size: 3
.n11101101000:
	ld a,$16
	ret
.n11101101001:
	ld a,$c4
	ret
.n1110110101:
	call get_next_bit
	jr c,.n11101101011 ; Jump size: 3
.n11101101010:
	ld a,$53
	ret
.n11101101011:
	ld a,$57
	ret
.n111011011:
	call get_next_bit
	jr c,.n1110110111 ; Jump size: 11
.n1110110110:
	call get_next_bit
	jr c,.n11101101101 ; Jump size: 3
.n11101101100:
	ld a,$47
	ret
.n11101101101:
	ld a,$1c
	ret
.n1110110111:
	call get_next_bit
	jr c,.n11101101111 ; Jump size: 11
.n11101101110:
	call get_next_bit
	jr c,.n111011011101 ; Jump size: 3
.n111011011100:
	ld a,$da
	ret
.n111011011101:
	ld a,$bd
	ret
.n11101101111:
	call get_next_bit
	jr c,.n111011011111 ; Jump size: 3
.n111011011110:
	ld a,$22
	ret
.n111011011111:
	ld a,$4a
	ret
.n1110111:
	ld a,$0f
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 11
.n11110:
	call get_next_bit
	jr c,.n111101 ; Jump size: 3
.n111100:
	ld a,$a0
	ret
.n111101:
	ld a,$55
	ret
.n11111:
	call get_next_bit
	jr c,.n111111 ; Jump size: 3
.n111110:
	ld a,$15
	ret
.n111111:
	ld a,$01
	ret

;END_UNCOMPRESS_GENERATION
