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
;Decompression algorithm takes 395 bytes

.n:
	call get_next_bit
	jr c,.n1 ; Jump size: 3
.n0:
	ld a,$00
	ret
.n1:
	call get_next_bit
	jr c,.n11 ; Jump size: 67
.n10:
	call get_next_bit
	jr c,.n101 ; Jump size: 27
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 11
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 3
.n10000:
	ld a,$a0
	ret
.n10001:
	ld a,$01
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$15
	ret
.n10011:
	ld a,$54
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 19
.n1010:
	call get_next_bit
	jr c,.n10101 ; Jump size: 3
.n10100:
	ld a,$55
	ret
.n10101:
	call get_next_bit
	jr c,.n101011 ; Jump size: 3
.n101010:
	ld a,$fc
	ret
.n101011:
	ld a,$f0
	ret
.n1011:
	call get_next_bit
	jr c,.n10111 ; Jump size: 3
.n10110:
	ld a,$50
	ret
.n10111:
	ld a,$ff
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 51
.n110:
	call get_next_bit
	jr c,.n1101 ; Jump size: 43
.n1100:
	call get_next_bit
	jr c,.n11001 ; Jump size: 35
.n11000:
	call get_next_bit
	jr c,.n110001 ; Jump size: 3
.n110000:
	ld a,$40
	ret
.n110001:
	call get_next_bit
	jr c,.n1100011 ; Jump size: 19
.n1100010:
	call get_next_bit
	jr c,.n11000101 ; Jump size: 3
.n11000100:
	ld a,$c1
	ret
.n11000101:
	call get_next_bit
	jr c,.n110001011 ; Jump size: 3
.n110001010:
	ld a,$96
	ret
.n110001011:
	ld a,$8d
	ret
.n1100011:
	ld a,$c0
	ret
.n11001:
	ld a,$2a
	ret
.n1101:
	ld a,$aa
	ret
.n111:
	call get_next_bit
	jr c,.n1111 ; Jump size: 59
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 43
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 3
.n111000:
	ld a,$0f
	ret
.n111001:
	call get_next_bit
	jr c,.n1110011 ; Jump size: 3
.n1110010:
	ld a,$3f
	ret
.n1110011:
	call get_next_bit
	jr c,.n11100111 ; Jump size: 19
.n11100110:
	call get_next_bit
	jr c,.n111001101 ; Jump size: 3
.n111001100:
	ld a,$ca
	ret
.n111001101:
	call get_next_bit
	jr c,.n1110011011 ; Jump size: 3
.n1110011010:
	ld a,$9a
	ret
.n1110011011:
	ld a,$d5
	ret
.n11100111:
	ld a,$82
	ret
.n11101:
	call get_next_bit
	jr c,.n111011 ; Jump size: 3
.n111010:
	ld a,$0a
	ret
.n111011:
	ld a,$80
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 59
.n11110:
	call get_next_bit
	jr c,.n111101 ; Jump size: 3
.n111100:
	ld a,$05
	ret
.n111101:
	call get_next_bit
	jr c,.n1111011 ; Jump size: 43
.n1111010:
	call get_next_bit
	jr c,.n11110101 ; Jump size: 19
.n11110100:
	call get_next_bit
	jr c,.n111101001 ; Jump size: 11
.n111101000:
	call get_next_bit
	jr c,.n1111010001 ; Jump size: 3
.n1111010000:
	ld a,$57
	ret
.n1111010001:
	ld a,$51
	ret
.n111101001:
	ld a,$41
	ret
.n11110101:
	call get_next_bit
	jr c,.n111101011 ; Jump size: 3
.n111101010:
	ld a,$5c
	ret
.n111101011:
	call get_next_bit
	jr c,.n1111010111 ; Jump size: 3
.n1111010110:
	ld a,$53
	ret
.n1111010111:
	ld a,$95
	ret
.n1111011:
	ld a,$03
	ret
.n11111:
	call get_next_bit
	jr c,.n111111 ; Jump size: 123
.n111110:
	call get_next_bit
	jr c,.n1111101 ; Jump size: 115
.n1111100:
	call get_next_bit
	jr c,.n11111001 ; Jump size: 35
.n11111000:
	call get_next_bit
	jr c,.n111110001 ; Jump size: 11
.n111110000:
	call get_next_bit
	jr c,.n1111100001 ; Jump size: 3
.n1111100000:
	ld a,$56
	ret
.n1111100001:
	ld a,$45
	ret
.n111110001:
	call get_next_bit
	jr c,.n1111100011 ; Jump size: 3
.n1111100010:
	ld a,$fa
	ret
.n1111100011:
	call get_next_bit
	jr c,.n11111000111 ; Jump size: 3
.n11111000110:
	ld a,$83
	ret
.n11111000111:
	ld a,$bf
	ret
.n11111001:
	call get_next_bit
	jr c,.n111110011 ; Jump size: 35
.n111110010:
	call get_next_bit
	jr c,.n1111100101 ; Jump size: 11
.n1111100100:
	call get_next_bit
	jr c,.n11111001001 ; Jump size: 3
.n11111001000:
	ld a,$d1
	ret
.n11111001001:
	ld a,$d4
	ret
.n1111100101:
	call get_next_bit
	jr c,.n11111001011 ; Jump size: 3
.n11111001010:
	ld a,$47
	ret
.n11111001011:
	call get_next_bit
	jr c,.n111110010111 ; Jump size: 3
.n111110010110:
	ld a,$28
	ret
.n111110010111:
	ld a,$14
	ret
.n111110011:
	call get_next_bit
	jr c,.n1111100111 ; Jump size: 27
.n1111100110:
	call get_next_bit
	jr c,.n11111001101 ; Jump size: 11
.n11111001100:
	call get_next_bit
	jr c,.n111110011001 ; Jump size: 3
.n111110011000:
	ld a,$ac
	ret
.n111110011001:
	ld a,$a3
	ret
.n11111001101:
	call get_next_bit
	jr c,.n111110011011 ; Jump size: 3
.n111110011010:
	ld a,$17
	ret
.n111110011011:
	ld a,$04
	ret
.n1111100111:
	ld a,$35
	ret
.n1111101:
	ld a,$02
	ret
.n111111:
	ld a,$a8
	ret

;END_UNCOMPRESS_GENERATION
