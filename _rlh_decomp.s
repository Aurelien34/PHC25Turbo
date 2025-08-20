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
	push bc
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
	pop bc
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
	jp c,.n1 ; Jump size: 392
.n0:
	call get_next_bit
	jp c,.n01 ; Jump size: 164
.n00:
	call get_next_bit
	jp c,.n001 ; Jump size: 147
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 11
.n0000:
	call get_next_bit
	jr c,.n00001 ; Jump size: 3
.n00000:
	ld a,$40
	ret
.n00001:
	ld a,$03
	ret
.n0001:
	call get_next_bit
	jr c,.n00011 ; Jump size: 3
.n00010:
	ld a,$0a
	ret
.n00011:
	call get_next_bit
	jr c,.n000111 ; Jump size: 43
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
	jr c,.n00011011 ; Jump size: 11
.n00011010:
	call get_next_bit
	jr c,.n000110101 ; Jump size: 3
.n000110100:
	ld a,$17
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
	ld a,$1e
	ret
.n0001111101:
	ld a,$fe
	ret
.n000111111:
	call get_next_bit
	jr c,.n0001111111 ; Jump size: 3
.n0001111110:
	ld a,$20
	ret
.n0001111111:
	ld a,$fd
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
	jp c,.n011 ; Jump size: 189
.n010:
	call get_next_bit
	jr c,.n0101 ; Jump size: 11
.n0100:
	call get_next_bit
	jr c,.n01001 ; Jump size: 3
.n01000:
	ld a,$80
	ret
.n01001:
	ld a,$50
	ret
.n0101:
	call get_next_bit
	jp c,.n01011 ; Jump size: 164
.n01010:
	call get_next_bit
	jp c,.n010101 ; Jump size: 147
.n010100:
	call get_next_bit
	jr c,.n0101001 ; Jump size: 59
.n0101000:
	call get_next_bit
	jr c,.n01010001 ; Jump size: 27
.n01010000:
	call get_next_bit
	jr c,.n010100001 ; Jump size: 11
.n010100000:
	call get_next_bit
	jr c,.n0101000001 ; Jump size: 3
.n0101000000:
	ld a,$bc
	ret
.n0101000001:
	ld a,$2c
	ret
.n010100001:
	call get_next_bit
	jr c,.n0101000011 ; Jump size: 3
.n0101000010:
	ld a,$62
	ret
.n0101000011:
	ld a,$56
	ret
.n01010001:
	call get_next_bit
	jr c,.n010100011 ; Jump size: 11
.n010100010:
	call get_next_bit
	jr c,.n0101000101 ; Jump size: 3
.n0101000100:
	ld a,$cd
	ret
.n0101000101:
	ld a,$3d
	ret
.n010100011:
	call get_next_bit
	jr c,.n0101000111 ; Jump size: 3
.n0101000110:
	ld a,$ab
	ret
.n0101000111:
	ld a,$16
	ret
.n0101001:
	call get_next_bit
	jr c,.n01010011 ; Jump size: 27
.n01010010:
	call get_next_bit
	jr c,.n010100101 ; Jump size: 11
.n010100100:
	call get_next_bit
	jr c,.n0101001001 ; Jump size: 3
.n0101001000:
	ld a,$c4
	ret
.n0101001001:
	ld a,$13
	ret
.n010100101:
	call get_next_bit
	jr c,.n0101001011 ; Jump size: 3
.n0101001010:
	ld a,$53
	ret
.n0101001011:
	ld a,$57
	ret
.n01010011:
	call get_next_bit
	jr c,.n010100111 ; Jump size: 19
.n010100110:
	call get_next_bit
	jr c,.n0101001101 ; Jump size: 3
.n0101001100:
	ld a,$47
	ret
.n0101001101:
	call get_next_bit
	jr c,.n01010011011 ; Jump size: 3
.n01010011010:
	ld a,$e0
	ret
.n01010011011:
	ld a,$da
	ret
.n010100111:
	call get_next_bit
	jr c,.n0101001111 ; Jump size: 11
.n0101001110:
	call get_next_bit
	jr c,.n01010011101 ; Jump size: 3
.n01010011100:
	ld a,$bd
	ret
.n01010011101:
	ld a,$22
	ret
.n0101001111:
	call get_next_bit
	jr c,.n01010011111 ; Jump size: 3
.n01010011110:
	ld a,$4a
	ret
.n01010011111:
	ld a,$6a
	ret
.n010101:
	call get_next_bit
	jr c,.n0101011 ; Jump size: 3
.n0101010:
	ld a,$07
	ret
.n0101011:
	ld a,$08
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
	ld a,$fc
	ret
.n01111:
	ld a,$55
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 204
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 179
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
	ld a,$d6
	ret
.n10000000001:
	ld a,$0b
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
	ld a,$82
	ret
.n100001:
	ld a,$0f
	ret
.n10001:
	ld a,$a0
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 75
.n10010:
	call get_next_bit
	jr c,.n100101 ; Jump size: 27
.n100100:
	call get_next_bit
	jr c,.n1001001 ; Jump size: 3
.n1001000:
	ld a,$41
	ret
.n1001001:
	call get_next_bit
	jr c,.n10010011 ; Jump size: 3
.n10010010:
	ld a,$c3
	ret
.n10010011:
	call get_next_bit
	jr c,.n100100111 ; Jump size: 3
.n100100110:
	ld a,$0c
	ret
.n100100111:
	ld a,$0e
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
	ld a,$2f
	ret
.n100101001:
	ld a,$c5
	ret
.n10010101:
	call get_next_bit
	jr c,.n100101011 ; Jump size: 3
.n100101010:
	ld a,$33
	ret
.n100101011:
	ld a,$23
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
	ld a,$ff
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
	ld a,$01
	ret
.n10111:
	ld a,$15
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
	jr c,.n11100111 ; Jump size: 11
.n11100110:
	call get_next_bit
	jr c,.n111001101 ; Jump size: 3
.n111001100:
	ld a,$8c
	ret
.n111001101:
	ld a,$d4
	ret
.n11100111:
	ld a,$1b
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
	jr c,.n111111 ; Jump size: 107
.n111110:
	call get_next_bit
	jr c,.n1111101 ; Jump size: 43
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
	call get_next_bit
	jr c,.n1111100111 ; Jump size: 3
.n1111100110:
	ld a,$31
	ret
.n1111100111:
	ld a,$44
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
	ld a,$ac
	ret
.n1111101001:
	ld a,$af
	ret
.n111110101:
	call get_next_bit
	jr c,.n1111101011 ; Jump size: 3
.n1111101010:
	ld a,$8b
	ret
.n1111101011:
	ld a,$83
	ret
.n11111011:
	call get_next_bit
	jr c,.n111110111 ; Jump size: 11
.n111110110:
	call get_next_bit
	jr c,.n1111101101 ; Jump size: 3
.n1111101100:
	ld a,$1a
	ret
.n1111101101:
	ld a,$95
	ret
.n111110111:
	call get_next_bit
	jr c,.n1111101111 ; Jump size: 3
.n1111101110:
	ld a,$5a
	ret
.n1111101111:
	ld a,$d5
	ret
.n111111:
	call get_next_bit
	jr c,.n1111111 ; Jump size: 3
.n1111110:
	ld a,$c0
	ret
.n1111111:
	call get_next_bit
	jr c,.n11111111 ; Jump size: 11
.n11111110:
	call get_next_bit
	jr c,.n111111101 ; Jump size: 3
.n111111100:
	ld a,$52
	ret
.n111111101:
	ld a,$a3
	ret
.n11111111:
	call get_next_bit
	jr c,.n111111111 ; Jump size: 3
.n111111110:
	ld a,$12
	ret
.n111111111:
	ld a,$d1
	ret

;END_UNCOMPRESS_GENERATION
