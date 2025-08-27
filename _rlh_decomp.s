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
;Decompression algorithm takes 818 bytes

.n:
	call get_next_bit
	jp c,.n1 ; Jump size: 440
.n0:
	call get_next_bit
	jp c,.n01 ; Jump size: 204
.n00:
	call get_next_bit
	jp c,.n001 ; Jump size: 187
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 43
.n0000:
	call get_next_bit
	jr c,.n00001 ; Jump size: 35
.n00000:
	call get_next_bit
	jr c,.n000001 ; Jump size: 27
.n000000:
	call get_next_bit
	jr c,.n0000001 ; Jump size: 11
.n0000000:
	call get_next_bit
	jr c,.n00000001 ; Jump size: 3
.n00000000:
	ld a,$52
	ret
.n00000001:
	ld a,$a3
	ret
.n0000001:
	call get_next_bit
	jr c,.n00000011 ; Jump size: 3
.n00000010:
	ld a,$12
	ret
.n00000011:
	ld a,$d1
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
	jr c,.n000111 ; Jump size: 51
.n000110:
	call get_next_bit
	jr c,.n0001101 ; Jump size: 11
.n0001100:
	call get_next_bit
	jr c,.n00011001 ; Jump size: 3
.n00011000:
	ld a,$96
	ret
.n00011001:
	ld a,$a6
	ret
.n0001101:
	call get_next_bit
	jr c,.n00011011 ; Jump size: 19
.n00011010:
	call get_next_bit
	jr c,.n000110101 ; Jump size: 11
.n000110100:
	call get_next_bit
	jr c,.n0001101001 ; Jump size: 3
.n0001101000:
	ld a,$51
	ret
.n0001101001:
	ld a,$1e
	ret
.n000110101:
	ld a,$1c
	ret
.n00011011:
	call get_next_bit
	jr c,.n000110111 ; Jump size: 3
.n000110110:
	ld a,$bf
	ret
.n000110111:
	ld a,$42
	ret
.n000111:
	call get_next_bit
	jr c,.n0001111 ; Jump size: 27
.n0001110:
	call get_next_bit
	jr c,.n00011101 ; Jump size: 11
.n00011100:
	call get_next_bit
	jr c,.n000111001 ; Jump size: 3
.n000111000:
	ld a,$34
	ret
.n000111001:
	ld a,$d2
	ret
.n00011101:
	call get_next_bit
	jr c,.n000111011 ; Jump size: 3
.n000111010:
	ld a,$b3
	ret
.n000111011:
	ld a,$09
	ret
.n0001111:
	call get_next_bit
	jr c,.n00011111 ; Jump size: 11
.n00011110:
	call get_next_bit
	jr c,.n000111101 ; Jump size: 3
.n000111100:
	ld a,$10
	ret
.n000111101:
	ld a,$fa
	ret
.n00011111:
	call get_next_bit
	jr c,.n000111111 ; Jump size: 11
.n000111110:
	call get_next_bit
	jr c,.n0001111101 ; Jump size: 3
.n0001111100:
	ld a,$fe
	ret
.n0001111101:
	ld a,$20
	ret
.n000111111:
	call get_next_bit
	jr c,.n0001111111 ; Jump size: 3
.n0001111110:
	ld a,$fd
	ret
.n0001111111:
	ld a,$bc
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
	jp c,.n011 ; Jump size: 197
.n010:
	call get_next_bit
	jp c,.n0101 ; Jump size: 180
.n0100:
	call get_next_bit
	jr c,.n01001 ; Jump size: 3
.n01000:
	ld a,$50
	ret
.n01001:
	call get_next_bit
	jp c,.n010011 ; Jump size: 155
.n010010:
	call get_next_bit
	jr c,.n0100101 ; Jump size: 59
.n0100100:
	call get_next_bit
	jr c,.n01001001 ; Jump size: 27
.n01001000:
	call get_next_bit
	jr c,.n010010001 ; Jump size: 11
.n010010000:
	call get_next_bit
	jr c,.n0100100001 ; Jump size: 3
.n0100100000:
	ld a,$2c
	ret
.n0100100001:
	ld a,$62
	ret
.n010010001:
	call get_next_bit
	jr c,.n0100100011 ; Jump size: 3
.n0100100010:
	ld a,$56
	ret
.n0100100011:
	ld a,$cd
	ret
.n01001001:
	call get_next_bit
	jr c,.n010010011 ; Jump size: 11
.n010010010:
	call get_next_bit
	jr c,.n0100100101 ; Jump size: 3
.n0100100100:
	ld a,$3d
	ret
.n0100100101:
	ld a,$ab
	ret
.n010010011:
	call get_next_bit
	jr c,.n0100100111 ; Jump size: 3
.n0100100110:
	ld a,$16
	ret
.n0100100111:
	ld a,$c4
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
	ld a,$57
	ret
.n0100101011:
	ld a,$47
	ret
.n01001011:
	call get_next_bit
	jr c,.n010010111 ; Jump size: 27
.n010010110:
	call get_next_bit
	jr c,.n0100101101 ; Jump size: 11
.n0100101100:
	call get_next_bit
	jr c,.n01001011001 ; Jump size: 3
.n01001011000:
	ld a,$da
	ret
.n01001011001:
	ld a,$bd
	ret
.n0100101101:
	call get_next_bit
	jr c,.n01001011011 ; Jump size: 3
.n01001011010:
	ld a,$22
	ret
.n01001011011:
	ld a,$4a
	ret
.n010010111:
	call get_next_bit
	jr c,.n0100101111 ; Jump size: 11
.n0100101110:
	call get_next_bit
	jr c,.n01001011101 ; Jump size: 3
.n01001011100:
	ld a,$6a
	ret
.n01001011101:
	ld a,$d6
	ret
.n0100101111:
	call get_next_bit
	jr c,.n01001011111 ; Jump size: 3
.n01001011110:
	ld a,$0b
	ret
.n01001011111:
	ld a,$28
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
	ld a,$02
	ret
.n01101:
	ld a,$05
	ret
.n0111:
	call get_next_bit
	jr c,.n01111 ; Jump size: 3
.n01110:
	ld a,$55
	ret
.n01111:
	ld a,$fc
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 180
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 155
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 91
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 3
.n10000:
	ld a,$a0
	ret
.n10001:
	call get_next_bit
	jr c,.n100011 ; Jump size: 51
.n100010:
	call get_next_bit
	jr c,.n1000101 ; Jump size: 43
.n1000100:
	call get_next_bit
	jr c,.n10001001 ; Jump size: 3
.n10001000:
	ld a,$46
	ret
.n10001001:
	call get_next_bit
	jr c,.n100010011 ; Jump size: 27
.n100010010:
	call get_next_bit
	jr c,.n1000100101 ; Jump size: 11
.n1000100100:
	call get_next_bit
	jr c,.n10001001001 ; Jump size: 3
.n10001001000:
	ld a,$45
	ret
.n10001001001:
	ld a,$b0
	ret
.n1000100101:
	call get_next_bit
	jr c,.n10001001011 ; Jump size: 3
.n10001001010:
	ld a,$84
	ret
.n10001001011:
	ld a,$81
	ret
.n100010011:
	ld a,$0c
	ret
.n1000101:
	ld a,$07
	ret
.n100011:
	call get_next_bit
	jr c,.n1000111 ; Jump size: 3
.n1000110:
	ld a,$41
	ret
.n1000111:
	call get_next_bit
	jr c,.n10001111 ; Jump size: 3
.n10001110:
	ld a,$c3
	ret
.n10001111:
	call get_next_bit
	jr c,.n100011111 ; Jump size: 3
.n100011110:
	ld a,$0e
	ret
.n100011111:
	ld a,$2f
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
	jr c,.n10010101 ; Jump size: 11
.n10010100:
	call get_next_bit
	jr c,.n100101001 ; Jump size: 3
.n100101000:
	ld a,$c5
	ret
.n100101001:
	ld a,$33
	ret
.n10010101:
	call get_next_bit
	jr c,.n100101011 ; Jump size: 3
.n100101010:
	ld a,$23
	ret
.n100101011:
	ld a,$8c
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
	jr c,.n1111 ; Jump size: 43
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 35
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
	jr c,.n11100111 ; Jump size: 3
.n11100110:
	ld a,$1b
	ret
.n11100111:
	call get_next_bit
	jr c,.n111001111 ; Jump size: 3
.n111001110:
	ld a,$d4
	ret
.n111001111:
	ld a,$35
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
	jr c,.n111111 ; Jump size: 115
.n111110:
	call get_next_bit
	jr c,.n1111101 ; Jump size: 51
.n1111100:
	call get_next_bit
	jr c,.n11111001 ; Jump size: 19
.n11111000:
	call get_next_bit
	jr c,.n111110001 ; Jump size: 3
.n111110000:
	ld a,$5c
	ret
.n111110001:
	call get_next_bit
	jr c,.n1111100011 ; Jump size: 3
.n1111100010:
	ld a,$e0
	ret
.n1111100011:
	ld a,$0d
	ret
.n11111001:
	call get_next_bit
	jr c,.n111110011 ; Jump size: 11
.n111110010:
	call get_next_bit
	jr c,.n1111100101 ; Jump size: 3
.n1111100100:
	ld a,$18
	ret
.n1111100101:
	ld a,$31
	ret
.n111110011:
	call get_next_bit
	jr c,.n1111100111 ; Jump size: 3
.n1111100110:
	ld a,$44
	ret
.n1111100111:
	ld a,$ac
	ret
.n1111101:
	call get_next_bit
	jr c,.n11111011 ; Jump size: 27
.n11111010:
	call get_next_bit
	jr c,.n111110101 ; Jump size: 11
.n111110100:
	call get_next_bit
	jr c,.n1111101001 ; Jump size: 3
.n1111101000:
	ld a,$af
	ret
.n1111101001:
	ld a,$8b
	ret
.n111110101:
	call get_next_bit
	jr c,.n1111101011 ; Jump size: 3
.n1111101010:
	ld a,$83
	ret
.n1111101011:
	ld a,$1a
	ret
.n11111011:
	call get_next_bit
	jr c,.n111110111 ; Jump size: 11
.n111110110:
	call get_next_bit
	jr c,.n1111101101 ; Jump size: 3
.n1111101100:
	ld a,$95
	ret
.n1111101101:
	ld a,$5a
	ret
.n111110111:
	call get_next_bit
	jr c,.n1111101111 ; Jump size: 3
.n1111101110:
	ld a,$d5
	ret
.n1111101111:
	ld a,$17
	ret
.n111111:
	ld a,$40
	ret

;END_UNCOMPRESS_GENERATION
