    section	code,text

    global decompress_rlh, decompress_rlh_advanced
	global rlh_param_offset_start, rlh_param_extract_length

FLAG_COMPRESSION_HUFFMAN equ 7
FLAG_COMPRESSION_RLE equ 6
FLAG_CLEAR_MASK equ %00111111
FLAG_CLEAR_COMPRESSION_RLE_MASK equ %10111111

rlh_param_offset_start:
	dc.w 0
rlh_param_extract_length:
	dc.w 0

; Compression is made in 2 optional layers:
; - Layer 1 is RLE or RAW
; - Layer 2 is Huffman or RAW

; Input registers:
;-----------------
; interrupts should be disabled
; registers assignment:
; hl => source buffer pointer
; de => target buffer pointer
decompress_rlh:
	; Indicate we want to extract the whole data
	push bc
	ld bc,0
	ld (rlh_param_extract_length),bc
	ld (rlh_param_offset_start),bc
	pop bc
	jr decompress_rlh_advanced
	

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
; iyh => Huffman compression flag (for mixed huffman / RLE compression)
; iyl => RLE compression key

decompress_rlh_advanced:
	push hl
	push bc
	push de
	push ix
	push iy
    ; initialization
	; see if we have a user defined size limit
	; rlh_param_extract_length should not be null
	ld bc,(rlh_param_extract_length)
	ld a,c
	or b
	jr z,.load_target_size_from_stream
	; we still need to load size and compression flags in ix
	ld ixl,c
	; point hl to upper byte
	inc hl
	ld a,(hl) ; load upper byte
	and %11000000 ; extract compression flags
	or b ; apply mask to our upper byte of stream length
	ld ixh,a
	jr .target_size_loaded
.load_target_size_from_stream:
    ; load target size and compress flag in ix
    ld a,(hl)
    ld ixl,a
    inc hl
    ld a,(hl)
    ld ixh,a
.target_size_loaded:
    inc hl
	; decode RLE compression flag
	bit FLAG_COMPRESSION_RLE,a
	jr z,.no_decomp_rle
	call decomp_rle
	jr .end
.no_decomp_rle:
	; decode compression flag
	bit FLAG_COMPRESSION_HUFFMAN,a
	jr z,.no_decomp_huffman
	call decomp_huffman
	jr .end
.no_decomp_huffman:
	; data is not compressed
	; compute starting address in hl
	ld bc,(rlh_param_offset_start)
	add hl,bc
	; load data size in bc
	push ix
	pop bc
	; copy uncompressed data
	ldir
.end
	pop iy
	pop ix
	pop de
	pop bc
	pop hl
	ret

decomp_rle:
	; data is RLE compressed
	ld b,a ; backup a
	and 1<<FLAG_COMPRESSION_HUFFMAN
	ld iyh,a ; iyh contains the Huffman compression flag
	ld a,b
	; clear compression flags
	and FLAG_CLEAR_MASK
	ld ixh,a

	; Init for potential Huffman decomp
    ; load current byte
    ld c,(hl)
    ; 8 bits to be processed
    ld b,8

    ; load current as the key => iyl
	call rle_read_one_byte
	ld iyl,a ; key in iyl

	; iterate on bytes
.loopDecomp
	; check if the decompression is complete
	ld a,ixl ; ix is 0?
	or ixh	; OR between high and low bytes and see if it is zero
	dc.b $c8 ; "ret z" not assembled correctly by VASM!

	call rle_read_one_byte
	cp iyl
	jr z,.byte_is_compressed
	; byte is not compressed
	call store_reg_a_to_output_stream_or_not
	jr .loopDecomp

.byte_is_compressed
	; regular
	call rle_read_one_byte ; a <- move to count to replicate
	exx
	; shadow
	ld c,a ; backup a
	exx
	; regular
	call rle_read_one_byte ; counter in b
	push de
	exx
	; shadow
	ld b,a  
	pop de
	ld a,c
.loop_multi_instances
	call store_reg_a_to_output_stream_or_not
	ex af,af' ;'
	ld a,ixh
	or ixl
	jp nz,.not_over_yet
	ld b,1
.not_over_yet:
	ex af,af' ;'
	; shadow
	dec b
	jr nz,.loop_multi_instances
	push de
	exx
	; Regular
	pop de
	jr .loopDecomp

rle_read_one_byte:
	; Check if data is Huffman compressed
	ld a,iyh
	or a
	jr nz,decompress_huffman_byte 	; ; Huffman data, decompress it warning here: optimization => jump instead of call to skip the expected RET
	; raw data, read it
	ld a,(hl)
	inc hl
	ret

decomp_huffman:
	; data is huffman compressed
	; clear compression flags
	and FLAG_CLEAR_MASK
	ld ixh,a

    ; load current byte
    ld c,(hl)
    ; 8 bits to be processed
    ld b,8

    ; now we can loop on decoding code
.loopDecomp
    call decompress_huffman_byte
    call store_reg_a_to_output_stream_or_not
	ld a,ixl ; ix is 0?
	or ixh
    jr nz,.loopDecomp
.endLoopDecomp
    ret

; result in C flag
get_next_bit:
    sll c; shift left and store bit of interest in carry flag
    ex af,af' ; '; backup status flags to shadow registers
    dec b ; point to the next bit
    jr nz,.end ; still some bits to process

    ld b,8 ; back to first bit
    inc hl ; point to next byte
	; load next byte
    ld c,(hl)
.end
    ex af,af' ; '; restore carry flag
    ret

store_reg_a_to_output_stream_or_not:
	; determine if we have reached the offset
	push af
	push bc
	; load the offset
	ld bc,(rlh_param_offset_start)
	; check if it is 0
	ld a,b
	or c
	jr z,.store_value ; no offset or offset aleady reached
	; the offset is non zero
	; decrement it
	dec bc
	ld (rlh_param_offset_start),bc
	pop bc
	pop af
	ret
.store_value;
	pop bc
	pop af
	ld (de),a
	inc de
    dec ix
.end
	ret

decompress_huffman_byte:
;BEGIN_UNCOMPRESS_GENERATION
;Decompression algorithm takes 823 bytes

.n:
	call get_next_bit
	jp c,.n1 ; Jump size: 469
.n0:
	call get_next_bit
	jp c,.n01 ; Jump size: 324
.n00:
	call get_next_bit
	jp c,.n001 ; Jump size: 307
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 59
.n0000:
	call get_next_bit
	jr c,.n00001 ; Jump size: 51
.n00000:
	call get_next_bit
	jr c,.n000001 ; Jump size: 43
.n000000:
	call get_next_bit
	jr c,.n0000001 ; Jump size: 11
.n0000000:
	call get_next_bit
	jr c,.n00000001 ; Jump size: 3
.n00000000:
	ld a,$a3
	ret
.n00000001:
	ld a,$12
	ret
.n0000001:
	call get_next_bit
	jr c,.n00000011 ; Jump size: 19
.n00000010:
	call get_next_bit
	jr c,.n000000101 ; Jump size: 3
.n000000100:
	ld a,$17
	ret
.n000000101:
	call get_next_bit
	jr c,.n0000001011 ; Jump size: 3
.n0000001010:
	ld a,$57
	ret
.n0000001011:
	ld a,$47
	ret
.n00000011:
	ld a,$52
	ret
.n000001:
	ld a,$c0
	ret
.n00001:
	ld a,$0a
	ret
.n0001:
	call get_next_bit
	jr c,.n00011 ; Jump size: 3
.n00010:
	ld a,$03
	ret
.n00011:
	call get_next_bit
	jr c,.n000111 ; Jump size: 83
.n000110:
	call get_next_bit
	jr c,.n0001101 ; Jump size: 19
.n0001100:
	call get_next_bit
	jr c,.n00011001 ; Jump size: 3
.n00011000:
	ld a,$a6
	ret
.n00011001:
	call get_next_bit
	jr c,.n000110011 ; Jump size: 3
.n000110010:
	ld a,$09
	ret
.n000110011:
	ld a,$10
	ret
.n0001101:
	call get_next_bit
	jr c,.n00011011 ; Jump size: 27
.n00011010:
	call get_next_bit
	jr c,.n000110101 ; Jump size: 11
.n000110100:
	call get_next_bit
	jr c,.n0001101001 ; Jump size: 3
.n0001101000:
	ld a,$2c
	ret
.n0001101001:
	ld a,$62
	ret
.n000110101:
	call get_next_bit
	jr c,.n0001101011 ; Jump size: 3
.n0001101010:
	ld a,$fd
	ret
.n0001101011:
	ld a,$bc
	ret
.n00011011:
	call get_next_bit
	jr c,.n000110111 ; Jump size: 11
.n000110110:
	call get_next_bit
	jr c,.n0001101101 ; Jump size: 3
.n0001101100:
	ld a,$3d
	ret
.n0001101101:
	ld a,$ab
	ret
.n000110111:
	call get_next_bit
	jr c,.n0001101111 ; Jump size: 3
.n0001101110:
	ld a,$56
	ret
.n0001101111:
	ld a,$cd
	ret
.n000111:
	call get_next_bit
	jr c,.n0001111 ; Jump size: 115
.n0001110:
	call get_next_bit
	jr c,.n00011101 ; Jump size: 59
.n00011100:
	call get_next_bit
	jr c,.n000111001 ; Jump size: 27
.n000111000:
	call get_next_bit
	jr c,.n0001110001 ; Jump size: 11
.n0001110000:
	call get_next_bit
	jr c,.n00011100001 ; Jump size: 3
.n00011100000:
	ld a,$28
	ret
.n00011100001:
	ld a,$45
	ret
.n0001110001:
	call get_next_bit
	jr c,.n00011100011 ; Jump size: 3
.n00011100010:
	ld a,$d6
	ret
.n00011100011:
	ld a,$0b
	ret
.n000111001:
	call get_next_bit
	jr c,.n0001110011 ; Jump size: 11
.n0001110010:
	call get_next_bit
	jr c,.n00011100101 ; Jump size: 3
.n00011100100:
	ld a,$81
	ret
.n00011100101:
	ld a,$51
	ret
.n0001110011:
	call get_next_bit
	jr c,.n00011100111 ; Jump size: 3
.n00011100110:
	ld a,$b0
	ret
.n00011100111:
	ld a,$84
	ret
.n00011101:
	call get_next_bit
	jr c,.n000111011 ; Jump size: 19
.n000111010:
	call get_next_bit
	jr c,.n0001110101 ; Jump size: 11
.n0001110100:
	call get_next_bit
	jr c,.n00011101001 ; Jump size: 3
.n00011101000:
	ld a,$66
	ret
.n00011101001:
	ld a,$da
	ret
.n0001110101:
	ld a,$fe
	ret
.n000111011:
	call get_next_bit
	jr c,.n0001110111 ; Jump size: 11
.n0001110110:
	call get_next_bit
	jr c,.n00011101101 ; Jump size: 3
.n00011101100:
	ld a,$4a
	ret
.n00011101101:
	ld a,$6a
	ret
.n0001110111:
	call get_next_bit
	jr c,.n00011101111 ; Jump size: 3
.n00011101110:
	ld a,$bd
	ret
.n00011101111:
	ld a,$22
	ret
.n0001111:
	call get_next_bit
	jr c,.n00011111 ; Jump size: 11
.n00011110:
	call get_next_bit
	jr c,.n000111101 ; Jump size: 3
.n000111100:
	ld a,$1c
	ret
.n000111101:
	ld a,$bf
	ret
.n00011111:
	call get_next_bit
	jr c,.n000111111 ; Jump size: 3
.n000111110:
	ld a,$20
	ret
.n000111111:
	ld a,$e0
	ret
.n001:
	call get_next_bit
	jr c,.n0011 ; Jump size: 3
.n0010:
	ld a,$06
	ret
.n0011:
	ld a,$2a
	ret
.n01:
	call get_next_bit
	jr c,.n011 ; Jump size: 107
.n010:
	call get_next_bit
	jr c,.n0101 ; Jump size: 91
.n0100:
	call get_next_bit
	jr c,.n01001 ; Jump size: 3
.n01000:
	ld a,$50
	ret
.n01001:
	call get_next_bit
	jr c,.n010011 ; Jump size: 67
.n010010:
	call get_next_bit
	jr c,.n0100101 ; Jump size: 27
.n0100100:
	call get_next_bit
	jr c,.n01001001 ; Jump size: 11
.n01001000:
	call get_next_bit
	jr c,.n010010001 ; Jump size: 3
.n010010000:
	ld a,$d2
	ret
.n010010001:
	ld a,$b3
	ret
.n01001001:
	call get_next_bit
	jr c,.n010010011 ; Jump size: 3
.n010010010:
	ld a,$42
	ret
.n010010011:
	ld a,$34
	ret
.n0100101:
	call get_next_bit
	jr c,.n01001011 ; Jump size: 27
.n01001010:
	call get_next_bit
	jr c,.n010010101 ; Jump size: 11
.n010010100:
	call get_next_bit
	jr c,.n0100101001 ; Jump size: 3
.n0100101000:
	ld a,$13
	ret
.n0100101001:
	ld a,$53
	ret
.n010010101:
	call get_next_bit
	jr c,.n0100101011 ; Jump size: 3
.n0100101010:
	ld a,$16
	ret
.n0100101011:
	ld a,$c4
	ret
.n01001011:
	ld a,$46
	ret
.n010011:
	call get_next_bit
	jr c,.n0100111 ; Jump size: 3
.n0100110:
	ld a,$08
	ret
.n0100111:
	ld a,$82
	ret
.n0101:
	call get_next_bit
	jr c,.n01011 ; Jump size: 3
.n01010:
	ld a,$80
	ret
.n01011:
	ld a,$3f
	ret
.n011:
	call get_next_bit
	jr c,.n0111 ; Jump size: 11
.n0110:
	call get_next_bit
	jr c,.n01101 ; Jump size: 3
.n01100:
	ld a,$05
	ret
.n01101:
	ld a,$55
	ret
.n0111:
	call get_next_bit
	jr c,.n01111 ; Jump size: 3
.n01110:
	ld a,$fc
	ret
.n01111:
	ld a,$a0
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 172
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 147
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 83
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 3
.n10000:
	ld a,$02
	ret
.n10001:
	call get_next_bit
	jr c,.n100011 ; Jump size: 11
.n100010:
	call get_next_bit
	jr c,.n1000101 ; Jump size: 3
.n1000100:
	ld a,$07
	ret
.n1000101:
	ld a,$41
	ret
.n100011:
	call get_next_bit
	jr c,.n1000111 ; Jump size: 27
.n1000110:
	call get_next_bit
	jr c,.n10001101 ; Jump size: 11
.n10001100:
	call get_next_bit
	jr c,.n100011001 ; Jump size: 3
.n100011000:
	ld a,$0c
	ret
.n100011001:
	ld a,$0e
	ret
.n10001101:
	call get_next_bit
	jr c,.n100011011 ; Jump size: 3
.n100011010:
	ld a,$fa
	ret
.n100011011:
	ld a,$1e
	ret
.n1000111:
	call get_next_bit
	jr c,.n10001111 ; Jump size: 11
.n10001110:
	call get_next_bit
	jr c,.n100011101 ; Jump size: 3
.n100011100:
	ld a,$33
	ret
.n100011101:
	ld a,$23
	ret
.n10001111:
	call get_next_bit
	jr c,.n100011111 ; Jump size: 3
.n100011110:
	ld a,$2f
	ret
.n100011111:
	ld a,$c5
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 51
.n10010:
	call get_next_bit
	jr c,.n100101 ; Jump size: 3
.n100100:
	ld a,$0f
	ret
.n100101:
	call get_next_bit
	jr c,.n1001011 ; Jump size: 27
.n1001010:
	call get_next_bit
	jr c,.n10010101 ; Jump size: 3
.n10010100:
	ld a,$c3
	ret
.n10010101:
	call get_next_bit
	jr c,.n100101011 ; Jump size: 3
.n100101010:
	ld a,$8c
	ret
.n100101011:
	call get_next_bit
	jr c,.n1001010111 ; Jump size: 3
.n1001010110:
	ld a,$5a
	ret
.n1001010111:
	ld a,$d5
	ret
.n1001011:
	call get_next_bit
	jr c,.n10010111 ; Jump size: 3
.n10010110:
	ld a,$c1
	ret
.n10010111:
	ld a,$11
	ret
.n10011:
	ld a,$15
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 3
.n1010:
	ld a,$aa
	ret
.n1011:
	call get_next_bit
	jr c,.n10111 ; Jump size: 3
.n10110:
	ld a,$ff
	ret
.n10111:
	ld a,$01
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 2
.n110:
	xor a
	ret
.n111:
	call get_next_bit
	jr c,.n1111 ; Jump size: 83
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 75
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 3
.n111000:
	ld a,$f0
	ret
.n111001:
	call get_next_bit
	jr c,.n1110011 ; Jump size: 3
.n1110010:
	ld a,$04
	ret
.n1110011:
	call get_next_bit
	jr c,.n11100111 ; Jump size: 27
.n11100110:
	call get_next_bit
	jr c,.n111001101 ; Jump size: 11
.n111001100:
	call get_next_bit
	jr c,.n1110011001 ; Jump size: 3
.n1110011000:
	ld a,$ac
	ret
.n1110011001:
	ld a,$af
	ret
.n111001101:
	call get_next_bit
	jr c,.n1110011011 ; Jump size: 3
.n1110011010:
	ld a,$31
	ret
.n1110011011:
	ld a,$44
	ret
.n11100111:
	call get_next_bit
	jr c,.n111001111 ; Jump size: 11
.n111001110:
	call get_next_bit
	jr c,.n1110011101 ; Jump size: 3
.n1110011100:
	ld a,$1a
	ret
.n1110011101:
	ld a,$95
	ret
.n111001111:
	call get_next_bit
	jr c,.n1110011111 ; Jump size: 3
.n1110011110:
	ld a,$8b
	ret
.n1110011111:
	ld a,$83
	ret
.n11101:
	ld a,$54
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 3
.n11110:
	ld a,$a8
	ret
.n11111:
	call get_next_bit
	jr c,.n111111 ; Jump size: 59
.n111110:
	call get_next_bit
	jr c,.n1111101 ; Jump size: 35
.n1111100:
	call get_next_bit
	jr c,.n11111001 ; Jump size: 11
.n11111000:
	call get_next_bit
	jr c,.n111110001 ; Jump size: 3
.n111110000:
	ld a,$35
	ret
.n111110001:
	ld a,$5c
	ret
.n11111001:
	call get_next_bit
	jr c,.n111110011 ; Jump size: 11
.n111110010:
	call get_next_bit
	jr c,.n1111100101 ; Jump size: 3
.n1111100100:
	ld a,$0d
	ret
.n1111100101:
	ld a,$18
	ret
.n111110011:
	ld a,$d4
	ret
.n1111101:
	call get_next_bit
	jr c,.n11111011 ; Jump size: 3
.n11111010:
	ld a,$1b
	ret
.n11111011:
	call get_next_bit
	jr c,.n111110111 ; Jump size: 3
.n111110110:
	ld a,$d1
	ret
.n111110111:
	ld a,$96
	ret
.n111111:
	ld a,$40
	ret

;END_UNCOMPRESS_GENERATION
