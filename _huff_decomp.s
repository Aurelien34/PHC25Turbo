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
;Decompression algorithm takes 704 bytes

.n:
	call get_next_bit
	jr c,.n1 ; Jump size: 3
.n0:
	ld a,$00
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 212
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 179
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 43
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 35
.n10000:
	call get_next_bit
	jr c,.n100001 ; Jump size: 27
.n100000:
	call get_next_bit
	jr c,.n1000001 ; Jump size: 3
.n1000000:
	ld a,$41
	ret
.n1000001:
	call get_next_bit
	jr c,.n10000011 ; Jump size: 3
.n10000010:
	ld a,$c3
	ret
.n10000011:
	call get_next_bit
	jr c,.n100000111 ; Jump size: 3
.n100000110:
	ld a,$c5
	ret
.n100000111:
	ld a,$33
	ret
.n100001:
	ld a,$f0
	ret
.n10001:
	ld a,$15
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$a8
	ret
.n10011:
	call get_next_bit
	jr c,.n100111 ; Jump size: 27
.n100110:
	call get_next_bit
	jr c,.n1001101 ; Jump size: 19
.n1001100:
	call get_next_bit
	jr c,.n10011001 ; Jump size: 11
.n10011000:
	call get_next_bit
	jr c,.n100110001 ; Jump size: 3
.n100110000:
	ld a,$23
	ret
.n100110001:
	ld a,$8c
	ret
.n10011001:
	ld a,$c1
	ret
.n1001101:
	ld a,$c0
	ret
.n100111:
	call get_next_bit
	jr c,.n1001111 ; Jump size: 27
.n1001110:
	call get_next_bit
	jr c,.n10011101 ; Jump size: 11
.n10011100:
	call get_next_bit
	jr c,.n100111001 ; Jump size: 3
.n100111000:
	ld a,$12
	ret
.n100111001:
	ld a,$d4
	ret
.n10011101:
	call get_next_bit
	jr c,.n100111011 ; Jump size: 3
.n100111010:
	ld a,$35
	ret
.n100111011:
	ld a,$5c
	ret
.n1001111:
	call get_next_bit
	jr c,.n10011111 ; Jump size: 27
.n10011110:
	call get_next_bit
	jr c,.n100111101 ; Jump size: 11
.n100111100:
	call get_next_bit
	jr c,.n1001111001 ; Jump size: 3
.n1001111000:
	ld a,$18
	ret
.n1001111001:
	ld a,$31
	ret
.n100111101:
	call get_next_bit
	jr c,.n1001111011 ; Jump size: 3
.n1001111010:
	ld a,$44
	ret
.n1001111011:
	ld a,$ac
	ret
.n10011111:
	call get_next_bit
	jr c,.n100111111 ; Jump size: 11
.n100111110:
	call get_next_bit
	jr c,.n1001111101 ; Jump size: 3
.n1001111100:
	ld a,$af
	ret
.n1001111101:
	ld a,$8b
	ret
.n100111111:
	call get_next_bit
	jr c,.n1001111111 ; Jump size: 3
.n1001111110:
	ld a,$83
	ret
.n1001111111:
	ld a,$95
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
	ld a,$02
	ret
.n101001:
	ld a,$0a
	ret
.n10101:
	ld a,$54
	ret
.n1011:
	ld a,$aa
	ret
.n11:
	call get_next_bit
	jp c,.n111 ; Jump size: 131
.n110:
	call get_next_bit
	jr c,.n1101 ; Jump size: 27
.n1100:
	call get_next_bit
	jr c,.n11001 ; Jump size: 11
.n11000:
	call get_next_bit
	jr c,.n110001 ; Jump size: 3
.n110000:
	ld a,$03
	ret
.n110001:
	ld a,$05
	ret
.n11001:
	call get_next_bit
	jr c,.n110011 ; Jump size: 3
.n110010:
	ld a,$40
	ret
.n110011:
	ld a,$80
	ret
.n1101:
	call get_next_bit
	jr c,.n11011 ; Jump size: 91
.n11010:
	call get_next_bit
	jr c,.n110101 ; Jump size: 83
.n110100:
	call get_next_bit
	jr c,.n1101001 ; Jump size: 35
.n1101000:
	call get_next_bit
	jr c,.n11010001 ; Jump size: 19
.n11010000:
	call get_next_bit
	jr c,.n110100001 ; Jump size: 11
.n110100000:
	call get_next_bit
	jr c,.n1101000001 ; Jump size: 3
.n1101000000:
	ld a,$5a
	ret
.n1101000001:
	ld a,$d5
	ret
.n110100001:
	ld a,$52
	ret
.n11010001:
	call get_next_bit
	jr c,.n110100011 ; Jump size: 3
.n110100010:
	ld a,$a3
	ret
.n110100011:
	ld a,$d1
	ret
.n1101001:
	call get_next_bit
	jr c,.n11010011 ; Jump size: 11
.n11010010:
	call get_next_bit
	jr c,.n110100101 ; Jump size: 3
.n110100100:
	ld a,$96
	ret
.n110100101:
	ld a,$a6
	ret
.n11010011:
	call get_next_bit
	jr c,.n110100111 ; Jump size: 11
.n110100110:
	call get_next_bit
	jr c,.n1101001101 ; Jump size: 3
.n1101001100:
	ld a,$17
	ret
.n1101001101:
	ld a,$bf
	ret
.n110100111:
	call get_next_bit
	jr c,.n1101001111 ; Jump size: 3
.n1101001110:
	ld a,$42
	ret
.n1101001111:
	ld a,$34
	ret
.n110101:
	ld a,$3f
	ret
.n11011:
	ld a,$2a
	ret
.n111:
	call get_next_bit
	jp c,.n1111 ; Jump size: 284
.n1110:
	call get_next_bit
	jp c,.n11101 ; Jump size: 267
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 3
.n111000:
	ld a,$fc
	ret
.n111001:
	call get_next_bit
	jr c,.n1110011 ; Jump size: 83
.n1110010:
	call get_next_bit
	jr c,.n11100101 ; Jump size: 27
.n11100100:
	call get_next_bit
	jr c,.n111001001 ; Jump size: 11
.n111001000:
	call get_next_bit
	jr c,.n1110010001 ; Jump size: 3
.n1110010000:
	ld a,$d2
	ret
.n1110010001:
	ld a,$2f
	ret
.n111001001:
	call get_next_bit
	jr c,.n1110010011 ; Jump size: 3
.n1110010010:
	ld a,$b3
	ret
.n1110010011:
	ld a,$10
	ret
.n11100101:
	call get_next_bit
	jr c,.n111001011 ; Jump size: 19
.n111001010:
	call get_next_bit
	jr c,.n1110010101 ; Jump size: 3
.n1110010100:
	ld a,$fa
	ret
.n1110010101:
	call get_next_bit
	jr c,.n11100101011 ; Jump size: 3
.n11100101010:
	ld a,$fd
	ret
.n11100101011:
	ld a,$bc
	ret
.n111001011:
	call get_next_bit
	jr c,.n1110010111 ; Jump size: 11
.n1110010110:
	call get_next_bit
	jr c,.n11100101101 ; Jump size: 3
.n11100101100:
	ld a,$2c
	ret
.n11100101101:
	ld a,$0c
	ret
.n1110010111:
	call get_next_bit
	jr c,.n11100101111 ; Jump size: 3
.n11100101110:
	ld a,$62
	ret
.n11100101111:
	ld a,$56
	ret
.n1110011:
	call get_next_bit
	jr c,.n11100111 ; Jump size: 59
.n11100110:
	call get_next_bit
	jr c,.n111001101 ; Jump size: 27
.n111001100:
	call get_next_bit
	jr c,.n1110011001 ; Jump size: 11
.n1110011000:
	call get_next_bit
	jr c,.n11100110001 ; Jump size: 3
.n11100110000:
	ld a,$cd
	ret
.n11100110001:
	ld a,$3d
	ret
.n1110011001:
	call get_next_bit
	jr c,.n11100110011 ; Jump size: 3
.n11100110010:
	ld a,$04
	ret
.n11100110011:
	ld a,$ab
	ret
.n111001101:
	call get_next_bit
	jr c,.n1110011011 ; Jump size: 11
.n1110011010:
	call get_next_bit
	jr c,.n11100110101 ; Jump size: 3
.n11100110100:
	ld a,$16
	ret
.n11100110101:
	ld a,$c4
	ret
.n1110011011:
	call get_next_bit
	jr c,.n11100110111 ; Jump size: 3
.n11100110110:
	ld a,$53
	ret
.n11100110111:
	ld a,$57
	ret
.n11100111:
	call get_next_bit
	jr c,.n111001111 ; Jump size: 43
.n111001110:
	call get_next_bit
	jr c,.n1110011101 ; Jump size: 11
.n1110011100:
	call get_next_bit
	jr c,.n11100111001 ; Jump size: 3
.n11100111000:
	ld a,$47
	ret
.n11100111001:
	ld a,$1c
	ret
.n1110011101:
	call get_next_bit
	jr c,.n11100111011 ; Jump size: 11
.n11100111010:
	call get_next_bit
	jr c,.n111001110101 ; Jump size: 3
.n111001110100:
	ld a,$da
	ret
.n111001110101:
	ld a,$bd
	ret
.n11100111011:
	call get_next_bit
	jr c,.n111001110111 ; Jump size: 3
.n111001110110:
	ld a,$22
	ret
.n111001110111:
	ld a,$4a
	ret
.n111001111:
	call get_next_bit
	jr c,.n1110011111 ; Jump size: 27
.n1110011110:
	call get_next_bit
	jr c,.n11100111101 ; Jump size: 11
.n11100111100:
	call get_next_bit
	jr c,.n111001111001 ; Jump size: 3
.n111001111000:
	ld a,$6a
	ret
.n111001111001:
	ld a,$d6
	ret
.n11100111101:
	call get_next_bit
	jr c,.n111001111011 ; Jump size: 3
.n111001111010:
	ld a,$28
	ret
.n111001111011:
	ld a,$45
	ret
.n1110011111:
	call get_next_bit
	jr c,.n11100111111 ; Jump size: 11
.n11100111110:
	call get_next_bit
	jr c,.n111001111101 ; Jump size: 3
.n111001111100:
	ld a,$b0
	ret
.n111001111101:
	ld a,$84
	ret
.n11100111111:
	call get_next_bit
	jr c,.n111001111111 ; Jump size: 3
.n111001111110:
	ld a,$81
	ret
.n111001111111:
	ld a,$51
	ret
.n11101:
	call get_next_bit
	jr c,.n111011 ; Jump size: 3
.n111010:
	ld a,$50
	ret
.n111011:
	ld a,$55
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 35
.n11110:
	call get_next_bit
	jr c,.n111101 ; Jump size: 27
.n111100:
	call get_next_bit
	jr c,.n1111001 ; Jump size: 19
.n1111000:
	call get_next_bit
	jr c,.n11110001 ; Jump size: 3
.n11110000:
	ld a,$82
	ret
.n11110001:
	call get_next_bit
	jr c,.n111100011 ; Jump size: 3
.n111100010:
	ld a,$46
	ret
.n111100011:
	ld a,$11
	ret
.n1111001:
	ld a,$0f
	ret
.n111101:
	ld a,$a0
	ret
.n11111:
	call get_next_bit
	jr c,.n111111 ; Jump size: 3
.n111110:
	ld a,$ff
	ret
.n111111:
	ld a,$01
	ret

;END_UNCOMPRESS_GENERATION
