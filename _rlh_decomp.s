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
;Decompression algorithm takes 865 bytes

.n:
	call get_next_bit
	jp c,.n1 ; Jump size: 260
.n0:
	call get_next_bit
	jp c,.n01 ; Jump size: 219
.n00:
	call get_next_bit
	jr c,.n001 ; Jump size: 3
.n000:
	ld a,$ff
	ret
.n001:
	call get_next_bit
	jr c,.n0011 ; Jump size: 91
.n0010:
	call get_next_bit
	jr c,.n00101 ; Jump size: 3
.n00100:
	ld a,$54
	ret
.n00101:
	call get_next_bit
	jr c,.n001011 ; Jump size: 3
.n001010:
	ld a,$f0
	ret
.n001011:
	call get_next_bit
	jr c,.n0010111 ; Jump size: 27
.n0010110:
	call get_next_bit
	jr c,.n00101101 ; Jump size: 11
.n00101100:
	call get_next_bit
	jr c,.n001011001 ; Jump size: 3
.n001011000:
	ld a,$10
	ret
.n001011001:
	ld a,$f8
	ret
.n00101101:
	call get_next_bit
	jr c,.n001011011 ; Jump size: 3
.n001011010:
	ld a,$7f
	ret
.n001011011:
	ld a,$d4
	ret
.n0010111:
	call get_next_bit
	jr c,.n00101111 ; Jump size: 11
.n00101110:
	call get_next_bit
	jr c,.n001011101 ; Jump size: 3
.n001011100:
	ld a,$35
	ret
.n001011101:
	ld a,$5c
	ret
.n00101111:
	call get_next_bit
	jr c,.n001011111 ; Jump size: 11
.n001011110:
	call get_next_bit
	jr c,.n0010111101 ; Jump size: 3
.n0010111100:
	ld a,$14
	ret
.n0010111101:
	ld a,$31
	ret
.n001011111:
	call get_next_bit
	jr c,.n0010111111 ; Jump size: 3
.n0010111110:
	ld a,$44
	ret
.n0010111111:
	ld a,$ac
	ret
.n0011:
	call get_next_bit
	jr c,.n00111 ; Jump size: 3
.n00110:
	ld a,$a8
	ret
.n00111:
	call get_next_bit
	jr c,.n001111 ; Jump size: 99
.n001110:
	call get_next_bit
	jr c,.n0011101 ; Jump size: 67
.n0011100:
	call get_next_bit
	jr c,.n00111001 ; Jump size: 27
.n00111000:
	call get_next_bit
	jr c,.n001110001 ; Jump size: 11
.n001110000:
	call get_next_bit
	jr c,.n0011100001 ; Jump size: 3
.n0011100000:
	ld a,$af
	ret
.n0011100001:
	ld a,$8b
	ret
.n001110001:
	call get_next_bit
	jr c,.n0011100011 ; Jump size: 3
.n0011100010:
	ld a,$83
	ret
.n0011100011:
	ld a,$95
	ret
.n00111001:
	call get_next_bit
	jr c,.n001110011 ; Jump size: 11
.n001110010:
	call get_next_bit
	jr c,.n0011100101 ; Jump size: 3
.n0011100100:
	ld a,$5a
	ret
.n0011100101:
	ld a,$d5
	ret
.n001110011:
	call get_next_bit
	jr c,.n0011100111 ; Jump size: 3
.n0011100110:
	ld a,$17
	ret
.n0011100111:
	call get_next_bit
	jr c,.n00111001111 ; Jump size: 3
.n00111001110:
	ld a,$51
	ret
.n00111001111:
	ld a,$19
	ret
.n0011101:
	call get_next_bit
	jr c,.n00111011 ; Jump size: 11
.n00111010:
	call get_next_bit
	jr c,.n001110101 ; Jump size: 3
.n001110100:
	ld a,$0e
	ret
.n001110101:
	ld a,$52
	ret
.n00111011:
	call get_next_bit
	jr c,.n001110111 ; Jump size: 3
.n001110110:
	ld a,$a3
	ret
.n001110111:
	ld a,$12
	ret
.n001111:
	ld a,$40
	ret
.n01:
	call get_next_bit
	jr c,.n011 ; Jump size: 27
.n010:
	call get_next_bit
	jr c,.n0101 ; Jump size: 11
.n0100:
	call get_next_bit
	jr c,.n01001 ; Jump size: 3
.n01000:
	ld a,$0f
	ret
.n01001:
	ld a,$fc
	ret
.n0101:
	call get_next_bit
	jr c,.n01011 ; Jump size: 3
.n01010:
	ld a,$80
	ret
.n01011:
	ld a,$1b
	ret
.n011:
	ld a,$02
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 421
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 356
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 115
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 107
.n10000:
	call get_next_bit
	jr c,.n100001 ; Jump size: 3
.n100000:
	ld a,$07
	ret
.n100001:
	call get_next_bit
	jr c,.n1000011 ; Jump size: 27
.n1000010:
	call get_next_bit
	jr c,.n10000101 ; Jump size: 11
.n10000100:
	call get_next_bit
	jr c,.n100001001 ; Jump size: 3
.n100001000:
	ld a,$d1
	ret
.n100001001:
	ld a,$96
	ret
.n10000101:
	call get_next_bit
	jr c,.n100001011 ; Jump size: 3
.n100001010:
	ld a,$a6
	ret
.n100001011:
	ld a,$1f
	ret
.n1000011:
	call get_next_bit
	jr c,.n10000111 ; Jump size: 27
.n10000110:
	call get_next_bit
	jr c,.n100001101 ; Jump size: 11
.n100001100:
	call get_next_bit
	jr c,.n1000011001 ; Jump size: 3
.n1000011000:
	ld a,$1c
	ret
.n1000011001:
	ld a,$bf
	ret
.n100001101:
	call get_next_bit
	jr c,.n1000011011 ; Jump size: 3
.n1000011010:
	ld a,$42
	ret
.n1000011011:
	ld a,$34
	ret
.n10000111:
	call get_next_bit
	jr c,.n100001111 ; Jump size: 11
.n100001110:
	call get_next_bit
	jr c,.n1000011101 ; Jump size: 3
.n1000011100:
	ld a,$d2
	ret
.n1000011101:
	ld a,$b3
	ret
.n100001111:
	call get_next_bit
	jr c,.n1000011111 ; Jump size: 3
.n1000011110:
	ld a,$fa
	ret
.n1000011111:
	call get_next_bit
	jr c,.n10000111111 ; Jump size: 3
.n10000111110:
	ld a,$1e
	ret
.n10000111111:
	ld a,$20
	ret
.n10001:
	ld a,$06
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$2a
	ret
.n10011:
	call get_next_bit
	jr c,.n100111 ; Jump size: 3
.n100110:
	ld a,$50
	ret
.n100111:
	call get_next_bit
	jp c,.n1001111 ; Jump size: 139
.n1001110:
	call get_next_bit
	jr c,.n10011101 ; Jump size: 59
.n10011100:
	call get_next_bit
	jr c,.n100111001 ; Jump size: 27
.n100111000:
	call get_next_bit
	jr c,.n1001110001 ; Jump size: 11
.n1001110000:
	call get_next_bit
	jr c,.n10011100001 ; Jump size: 3
.n10011100000:
	ld a,$fd
	ret
.n10011100001:
	ld a,$bc
	ret
.n1001110001:
	call get_next_bit
	jr c,.n10011100011 ; Jump size: 3
.n10011100010:
	ld a,$2c
	ret
.n10011100011:
	ld a,$62
	ret
.n100111001:
	call get_next_bit
	jr c,.n1001110011 ; Jump size: 11
.n1001110010:
	call get_next_bit
	jr c,.n10011100101 ; Jump size: 3
.n10011100100:
	ld a,$56
	ret
.n10011100101:
	ld a,$cd
	ret
.n1001110011:
	call get_next_bit
	jr c,.n10011100111 ; Jump size: 3
.n10011100110:
	ld a,$3d
	ret
.n10011100111:
	ld a,$ab
	ret
.n10011101:
	call get_next_bit
	jr c,.n100111011 ; Jump size: 27
.n100111010:
	call get_next_bit
	jr c,.n1001110101 ; Jump size: 11
.n1001110100:
	call get_next_bit
	jr c,.n10011101001 ; Jump size: 3
.n10011101000:
	ld a,$16
	ret
.n10011101001:
	ld a,$c4
	ret
.n1001110101:
	call get_next_bit
	jr c,.n10011101011 ; Jump size: 3
.n10011101010:
	ld a,$13
	ret
.n10011101011:
	ld a,$53
	ret
.n100111011:
	call get_next_bit
	jr c,.n1001110111 ; Jump size: 11
.n1001110110:
	call get_next_bit
	jr c,.n10011101101 ; Jump size: 3
.n10011101100:
	ld a,$57
	ret
.n10011101101:
	ld a,$47
	ret
.n1001110111:
	call get_next_bit
	jr c,.n10011101111 ; Jump size: 11
.n10011101110:
	call get_next_bit
	jr c,.n100111011101 ; Jump size: 3
.n100111011100:
	ld a,$21
	ret
.n100111011101:
	ld a,$da
	ret
.n10011101111:
	call get_next_bit
	jr c,.n100111011111 ; Jump size: 3
.n100111011110:
	ld a,$bd
	ret
.n100111011111:
	ld a,$22
	ret
.n1001111:
	call get_next_bit
	jr c,.n10011111 ; Jump size: 3
.n10011110:
	ld a,$1a
	ret
.n10011111:
	call get_next_bit
	jr c,.n100111111 ; Jump size: 59
.n100111110:
	call get_next_bit
	jr c,.n1001111101 ; Jump size: 27
.n1001111100:
	call get_next_bit
	jr c,.n10011111001 ; Jump size: 11
.n10011111000:
	call get_next_bit
	jr c,.n100111110001 ; Jump size: 3
.n100111110000:
	ld a,$4a
	ret
.n100111110001:
	ld a,$6a
	ret
.n10011111001:
	call get_next_bit
	jr c,.n100111110011 ; Jump size: 3
.n100111110010:
	ld a,$d6
	ret
.n100111110011:
	ld a,$28
	ret
.n1001111101:
	call get_next_bit
	jr c,.n10011111011 ; Jump size: 11
.n10011111010:
	call get_next_bit
	jr c,.n100111110101 ; Jump size: 3
.n100111110100:
	ld a,$45
	ret
.n100111110101:
	ld a,$b0
	ret
.n10011111011:
	call get_next_bit
	jr c,.n100111110111 ; Jump size: 3
.n100111110110:
	ld a,$84
	ret
.n100111110111:
	ld a,$81
	ret
.n100111111:
	ld a,$e0
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 19
.n1010:
	call get_next_bit
	jr c,.n10101 ; Jump size: 3
.n10100:
	ld a,$04
	ret
.n10101:
	call get_next_bit
	jr c,.n101011 ; Jump size: 3
.n101010:
	ld a,$0a
	ret
.n101011:
	ld a,$3f
	ret
.n1011:
	call get_next_bit
	jr c,.n10111 ; Jump size: 11
.n10110:
	call get_next_bit
	jr c,.n101101 ; Jump size: 3
.n101100:
	ld a,$05
	ret
.n101101:
	ld a,$55
	ret
.n10111:
	call get_next_bit
	jr c,.n101111 ; Jump size: 11
.n101110:
	call get_next_bit
	jr c,.n1011101 ; Jump size: 3
.n1011100:
	ld a,$c0
	ret
.n1011101:
	ld a,$0b
	ret
.n101111:
	ld a,$a0
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 2
.n110:
	xor a
	ret
.n111:
	call get_next_bit
	jp c,.n1111 ; Jump size: 140
.n1110:
	call get_next_bit
	jp c,.n11101 ; Jump size: 131
.n11100:
	call get_next_bit
	jr c,.n111001 ; Jump size: 51
.n111000:
	call get_next_bit
	jr c,.n1110001 ; Jump size: 11
.n1110000:
	call get_next_bit
	jr c,.n11100001 ; Jump size: 3
.n11100000:
	ld a,$82
	ret
.n11100001:
	ld a,$08
	ret
.n1110001:
	call get_next_bit
	jr c,.n11100011 ; Jump size: 11
.n11100010:
	call get_next_bit
	jr c,.n111000101 ; Jump size: 3
.n111000100:
	ld a,$46
	ret
.n111000101:
	ld a,$fe
	ret
.n11100011:
	call get_next_bit
	jr c,.n111000111 ; Jump size: 3
.n111000110:
	ld a,$c3
	ret
.n111000111:
	call get_next_bit
	jr c,.n1110001111 ; Jump size: 3
.n1110001110:
	ld a,$0d
	ret
.n1110001111:
	ld a,$18
	ret
.n111001:
	call get_next_bit
	jr c,.n1110011 ; Jump size: 35
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
	ld a,$0c
	ret
.n1110010001:
	ld a,$2f
	ret
.n111001001:
	call get_next_bit
	jr c,.n1110010011 ; Jump size: 3
.n1110010010:
	ld a,$c5
	ret
.n1110010011:
	ld a,$33
	ret
.n11100101:
	ld a,$41
	ret
.n1110011:
	call get_next_bit
	jr c,.n11100111 ; Jump size: 19
.n11100110:
	call get_next_bit
	jr c,.n111001101 ; Jump size: 11
.n111001100:
	call get_next_bit
	jr c,.n1110011001 ; Jump size: 3
.n1110011000:
	ld a,$23
	ret
.n1110011001:
	ld a,$8c
	ret
.n111001101:
	ld a,$c1
	ret
.n11100111:
	call get_next_bit
	jr c,.n111001111 ; Jump size: 3
.n111001110:
	ld a,$11
	ret
.n111001111:
	ld a,$09
	ret
.n11101:
	ld a,$03
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 3
.n11110:
	ld a,$aa
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
