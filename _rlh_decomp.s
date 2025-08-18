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
;Decompression algorithm takes 791 bytes

.n:
	call get_next_bit
	jp c,.n1 ; Jump size: 510
.n0:
	call get_next_bit
	jr c,.n01 ; Jump size: 123
.n00:
	call get_next_bit
	jr c,.n001 ; Jump size: 99
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 11
.n0000:
	call get_next_bit
	jr c,.n00001 ; Jump size: 3
.n00000:
	ld a,$02
	ret
.n00001:
	ld a,$03
	ret
.n0001:
	call get_next_bit
	jr c,.n00011 ; Jump size: 75
.n00010:
	call get_next_bit
	jr c,.n000101 ; Jump size: 43
.n000100:
	call get_next_bit
	jr c,.n0001001 ; Jump size: 27
.n0001000:
	call get_next_bit
	jr c,.n00010001 ; Jump size: 11
.n00010000:
	call get_next_bit
	jr c,.n000100001 ; Jump size: 3
.n000100000:
	ld a,$95
	ret
.n000100001:
	ld a,$5a
	ret
.n00010001:
	call get_next_bit
	jr c,.n000100011 ; Jump size: 3
.n000100010:
	ld a,$d5
	ret
.n000100011:
	ld a,$17
	ret
.n0001001:
	call get_next_bit
	jr c,.n00010011 ; Jump size: 3
.n00010010:
	ld a,$52
	ret
.n00010011:
	ld a,$a3
	ret
.n000101:
	call get_next_bit
	jr c,.n0001011 ; Jump size: 11
.n0001010:
	call get_next_bit
	jr c,.n00010101 ; Jump size: 3
.n00010100:
	ld a,$12
	ret
.n00010101:
	ld a,$d1
	ret
.n0001011:
	call get_next_bit
	jr c,.n00010111 ; Jump size: 3
.n00010110:
	ld a,$96
	ret
.n00010111:
	ld a,$a6
	ret
.n00011:
	ld a,$40
	ret
.n001:
	call get_next_bit
	jr c,.n0011 ; Jump size: 11
.n0010:
	call get_next_bit
	jr c,.n00101 ; Jump size: 3
.n00100:
	ld a,$80
	ret
.n00101:
	ld a,$0a
	ret
.n0011:
	ld a,$06
	ret
.n01:
	call get_next_bit
	jr c,.n011 ; Jump size: 123
.n010:
	call get_next_bit
	jr c,.n0101 ; Jump size: 3
.n0100:
	ld a,$2a
	ret
.n0101:
	call get_next_bit
	jr c,.n01011 ; Jump size: 107
.n01010:
	call get_next_bit
	jr c,.n010101 ; Jump size: 35
.n010100:
	call get_next_bit
	jr c,.n0101001 ; Jump size: 27
.n0101000:
	call get_next_bit
	jr c,.n01010001 ; Jump size: 11
.n01010000:
	call get_next_bit
	jr c,.n010100001 ; Jump size: 3
.n010100000:
	ld a,$1c
	ret
.n010100001:
	ld a,$bf
	ret
.n01010001:
	call get_next_bit
	jr c,.n010100011 ; Jump size: 3
.n010100010:
	ld a,$42
	ret
.n010100011:
	ld a,$34
	ret
.n0101001:
	ld a,$07
	ret
.n010101:
	call get_next_bit
	jr c,.n0101011 ; Jump size: 27
.n0101010:
	call get_next_bit
	jr c,.n01010101 ; Jump size: 11
.n01010100:
	call get_next_bit
	jr c,.n010101001 ; Jump size: 3
.n010101000:
	ld a,$d2
	ret
.n010101001:
	ld a,$2f
	ret
.n01010101:
	call get_next_bit
	jr c,.n010101011 ; Jump size: 3
.n010101010:
	ld a,$b3
	ret
.n010101011:
	ld a,$1b
	ret
.n0101011:
	call get_next_bit
	jr c,.n01010111 ; Jump size: 11
.n01010110:
	call get_next_bit
	jr c,.n010101101 ; Jump size: 3
.n010101100:
	ld a,$09
	ret
.n010101101:
	ld a,$10
	ret
.n01010111:
	call get_next_bit
	jr c,.n010101111 ; Jump size: 3
.n010101110:
	ld a,$fa
	ret
.n010101111:
	call get_next_bit
	jr c,.n0101011111 ; Jump size: 3
.n0101011110:
	ld a,$fd
	ret
.n0101011111:
	ld a,$bc
	ret
.n01011:
	ld a,$50
	ret
.n011:
	call get_next_bit
	jp c,.n0111 ; Jump size: 237
.n0110:
	call get_next_bit
	jp c,.n01101 ; Jump size: 228
.n01100:
	call get_next_bit
	jp c,.n011001 ; Jump size: 147
.n011000:
	call get_next_bit
	jr c,.n0110001 ; Jump size: 59
.n0110000:
	call get_next_bit
	jr c,.n01100001 ; Jump size: 27
.n01100000:
	call get_next_bit
	jr c,.n011000001 ; Jump size: 11
.n011000000:
	call get_next_bit
	jr c,.n0110000001 ; Jump size: 3
.n0110000000:
	ld a,$2c
	ret
.n0110000001:
	ld a,$62
	ret
.n011000001:
	call get_next_bit
	jr c,.n0110000011 ; Jump size: 3
.n0110000010:
	ld a,$56
	ret
.n0110000011:
	ld a,$cd
	ret
.n01100001:
	call get_next_bit
	jr c,.n011000011 ; Jump size: 11
.n011000010:
	call get_next_bit
	jr c,.n0110000101 ; Jump size: 3
.n0110000100:
	ld a,$3d
	ret
.n0110000101:
	ld a,$0d
	ret
.n011000011:
	call get_next_bit
	jr c,.n0110000111 ; Jump size: 3
.n0110000110:
	ld a,$ab
	ret
.n0110000111:
	ld a,$16
	ret
.n0110001:
	call get_next_bit
	jr c,.n01100011 ; Jump size: 27
.n01100010:
	call get_next_bit
	jr c,.n011000101 ; Jump size: 11
.n011000100:
	call get_next_bit
	jr c,.n0110001001 ; Jump size: 3
.n0110001000:
	ld a,$c4
	ret
.n0110001001:
	ld a,$13
	ret
.n011000101:
	call get_next_bit
	jr c,.n0110001011 ; Jump size: 3
.n0110001010:
	ld a,$53
	ret
.n0110001011:
	ld a,$57
	ret
.n01100011:
	call get_next_bit
	jr c,.n011000111 ; Jump size: 19
.n011000110:
	call get_next_bit
	jr c,.n0110001101 ; Jump size: 3
.n0110001100:
	ld a,$47
	ret
.n0110001101:
	call get_next_bit
	jr c,.n01100011011 ; Jump size: 3
.n01100011010:
	ld a,$da
	ret
.n01100011011:
	ld a,$bd
	ret
.n011000111:
	call get_next_bit
	jr c,.n0110001111 ; Jump size: 11
.n0110001110:
	call get_next_bit
	jr c,.n01100011101 ; Jump size: 3
.n01100011100:
	ld a,$22
	ret
.n01100011101:
	ld a,$4a
	ret
.n0110001111:
	call get_next_bit
	jr c,.n01100011111 ; Jump size: 3
.n01100011110:
	ld a,$6a
	ret
.n01100011111:
	ld a,$d6
	ret
.n011001:
	call get_next_bit
	jr c,.n0110011 ; Jump size: 67
.n0110010:
	call get_next_bit
	jr c,.n01100101 ; Jump size: 59
.n01100100:
	call get_next_bit
	jr c,.n011001001 ; Jump size: 27
.n011001000:
	call get_next_bit
	jr c,.n0110010001 ; Jump size: 11
.n0110010000:
	call get_next_bit
	jr c,.n01100100001 ; Jump size: 3
.n01100100000:
	ld a,$0b
	ret
.n01100100001:
	ld a,$28
	ret
.n0110010001:
	call get_next_bit
	jr c,.n01100100011 ; Jump size: 3
.n01100100010:
	ld a,$45
	ret
.n01100100011:
	ld a,$b0
	ret
.n011001001:
	call get_next_bit
	jr c,.n0110010011 ; Jump size: 11
.n0110010010:
	call get_next_bit
	jr c,.n01100100101 ; Jump size: 3
.n01100100100:
	ld a,$84
	ret
.n01100100101:
	ld a,$81
	ret
.n0110010011:
	call get_next_bit
	jr c,.n01100100111 ; Jump size: 3
.n01100100110:
	ld a,$51
	ret
.n01100100111:
	ld a,$1e
	ret
.n01100101:
	ld a,$46
	ret
.n0110011:
	ld a,$82
	ret
.n01101:
	ld a,$3f
	ret
.n0111:
	call get_next_bit
	jr c,.n01111 ; Jump size: 3
.n01110:
	ld a,$05
	ret
.n01111:
	ld a,$fc
	ret
.n1:
	call get_next_bit
	jr c,.n11 ; Jump size: 58
.n10:
	call get_next_bit
	jr c,.n101 ; Jump size: 51
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 11
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 3
.n10000:
	ld a,$55
	ret
.n10001:
	ld a,$a0
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$ff
	ret
.n10011:
	call get_next_bit
	jr c,.n100111 ; Jump size: 3
.n100110:
	ld a,$0f
	ret
.n100111:
	call get_next_bit
	jr c,.n1001111 ; Jump size: 11
.n1001110:
	call get_next_bit
	jr c,.n10011101 ; Jump size: 3
.n10011100:
	ld a,$08
	ret
.n10011101:
	ld a,$c3
	ret
.n1001111:
	ld a,$41
	ret
.n101:
	xor a
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 19
.n110:
	call get_next_bit
	jr c,.n1101 ; Jump size: 11
.n1100:
	call get_next_bit
	jr c,.n11001 ; Jump size: 3
.n11000:
	ld a,$01
	ret
.n11001:
	ld a,$15
	ret
.n1101:
	ld a,$aa
	ret
.n111:
	call get_next_bit
	jp c,.n1111 ; Jump size: 171
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 43
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 35
.n111000:
	call get_next_bit
	jr c,.n1110001 ; Jump size: 27
.n1110000:
	call get_next_bit
	jr c,.n11100001 ; Jump size: 11
.n11100000:
	call get_next_bit
	jr c,.n111000001 ; Jump size: 3
.n111000000:
	ld a,$c5
	ret
.n111000001:
	ld a,$33
	ret
.n11100001:
	call get_next_bit
	jr c,.n111000011 ; Jump size: 3
.n111000010:
	ld a,$23
	ret
.n111000011:
	ld a,$8c
	ret
.n1110001:
	ld a,$04
	ret
.n111001:
	ld a,$f0
	ret
.n11101:
	call get_next_bit
	jr c,.n111011 ; Jump size: 19
.n111010:
	call get_next_bit
	jr c,.n1110101 ; Jump size: 11
.n1110100:
	call get_next_bit
	jr c,.n11101001 ; Jump size: 3
.n11101000:
	ld a,$c1
	ret
.n11101001:
	ld a,$11
	ret
.n1110101:
	ld a,$c0
	ret
.n111011:
	call get_next_bit
	jr c,.n1110111 ; Jump size: 35
.n1110110:
	call get_next_bit
	jr c,.n11101101 ; Jump size: 11
.n11101100:
	call get_next_bit
	jr c,.n111011001 ; Jump size: 3
.n111011000:
	ld a,$d4
	ret
.n111011001:
	ld a,$35
	ret
.n11101101:
	call get_next_bit
	jr c,.n111011011 ; Jump size: 3
.n111011010:
	ld a,$5c
	ret
.n111011011:
	call get_next_bit
	jr c,.n1110110111 ; Jump size: 3
.n1110110110:
	ld a,$0e
	ret
.n1110110111:
	ld a,$0c
	ret
.n1110111:
	call get_next_bit
	jr c,.n11101111 ; Jump size: 27
.n11101110:
	call get_next_bit
	jr c,.n111011101 ; Jump size: 11
.n111011100:
	call get_next_bit
	jr c,.n1110111001 ; Jump size: 3
.n1110111000:
	ld a,$18
	ret
.n1110111001:
	ld a,$31
	ret
.n111011101:
	call get_next_bit
	jr c,.n1110111011 ; Jump size: 3
.n1110111010:
	ld a,$44
	ret
.n1110111011:
	ld a,$ac
	ret
.n11101111:
	call get_next_bit
	jr c,.n111011111 ; Jump size: 11
.n111011110:
	call get_next_bit
	jr c,.n1110111101 ; Jump size: 3
.n1110111100:
	ld a,$af
	ret
.n1110111101:
	ld a,$8b
	ret
.n111011111:
	call get_next_bit
	jr c,.n1110111111 ; Jump size: 3
.n1110111110:
	ld a,$83
	ret
.n1110111111:
	ld a,$1a
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 3
.n11110:
	ld a,$54
	ret
.n11111:
	ld a,$a8
	ret

;END_UNCOMPRESS_GENERATION
