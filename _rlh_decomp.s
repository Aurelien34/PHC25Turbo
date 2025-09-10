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
	jr nz,.not_over_yet
	ld b,1
.not_over_yet:
	ex af,af' ;'
	; shadow
	djnz .loop_multi_instances
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
    djnz .end ; still some bits to process

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
;Decompression algorithm takes 825 bytes

.n:
	call get_next_bit
	jp c,.n1 ; Jump size: 399
.n0:
	call get_next_bit
	jp c,.n01 ; Jump size: 131
.n00:
	call get_next_bit
	jr c,.n001 ; Jump size: 67
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 3
.n0000:
	ld a,$06
	ret
.n0001:
	call get_next_bit
	jr c,.n00011 ; Jump size: 51
.n00010:
	call get_next_bit
	jr c,.n000101 ; Jump size: 19
.n000100:
	call get_next_bit
	jr c,.n0001001 ; Jump size: 3
.n0001000:
	ld a,$1b
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
	ld a,$0a
	ret
.n001:
	call get_next_bit
	jr c,.n0011 ; Jump size: 51
.n0010:
	call get_next_bit
	jr c,.n00101 ; Jump size: 43
.n00100:
	call get_next_bit
	jr c,.n001001 ; Jump size: 3
.n001000:
	ld a,$c0
	ret
.n001001:
	call get_next_bit
	jr c,.n0010011 ; Jump size: 27
.n0010010:
	call get_next_bit
	jr c,.n00100101 ; Jump size: 11
.n00100100:
	call get_next_bit
	jr c,.n001001001 ; Jump size: 3
.n001001000:
	ld a,$17
	ret
.n001001001:
	ld a,$0c
	ret
.n00100101:
	call get_next_bit
	jr c,.n001001011 ; Jump size: 3
.n001001010:
	ld a,$1c
	ret
.n001001011:
	ld a,$bf
	ret
.n0010011:
	ld a,$08
	ret
.n00101:
	ld a,$03
	ret
.n0011:
	ld a,$2a
	ret
.n01:
	call get_next_bit
	jp c,.n011 ; Jump size: 229
.n010:
	call get_next_bit
	jp c,.n0101 ; Jump size: 212
.n0100:
	call get_next_bit
	jp c,.n01001 ; Jump size: 203
.n01000:
	call get_next_bit
	jr c,.n010001 ; Jump size: 67
.n010000:
	call get_next_bit
	jr c,.n0100001 ; Jump size: 27
.n0100000:
	call get_next_bit
	jr c,.n01000001 ; Jump size: 11
.n01000000:
	call get_next_bit
	jr c,.n010000001 ; Jump size: 3
.n010000000:
	ld a,$42
	ret
.n010000001:
	ld a,$34
	ret
.n01000001:
	call get_next_bit
	jr c,.n010000011 ; Jump size: 3
.n010000010:
	ld a,$18
	ret
.n010000011:
	ld a,$d2
	ret
.n0100001:
	call get_next_bit
	jr c,.n01000011 ; Jump size: 11
.n01000010:
	call get_next_bit
	jr c,.n010000101 ; Jump size: 3
.n010000100:
	ld a,$b3
	ret
.n010000101:
	ld a,$10
	ret
.n01000011:
	call get_next_bit
	jr c,.n010000111 ; Jump size: 3
.n010000110:
	ld a,$fa
	ret
.n010000111:
	call get_next_bit
	jr c,.n0100001111 ; Jump size: 3
.n0100001110:
	ld a,$1e
	ret
.n0100001111:
	ld a,$fe
	ret
.n010001:
	call get_next_bit
	jr c,.n0100011 ; Jump size: 59
.n0100010:
	call get_next_bit
	jr c,.n01000101 ; Jump size: 27
.n01000100:
	call get_next_bit
	jr c,.n010001001 ; Jump size: 11
.n010001000:
	call get_next_bit
	jr c,.n0100010001 ; Jump size: 3
.n0100010000:
	ld a,$20
	ret
.n0100010001:
	ld a,$fd
	ret
.n010001001:
	call get_next_bit
	jr c,.n0100010011 ; Jump size: 3
.n0100010010:
	ld a,$bc
	ret
.n0100010011:
	ld a,$2c
	ret
.n01000101:
	call get_next_bit
	jr c,.n010001011 ; Jump size: 11
.n010001010:
	call get_next_bit
	jr c,.n0100010101 ; Jump size: 3
.n0100010100:
	ld a,$62
	ret
.n0100010101:
	ld a,$56
	ret
.n010001011:
	call get_next_bit
	jr c,.n0100010111 ; Jump size: 3
.n0100010110:
	ld a,$cd
	ret
.n0100010111:
	ld a,$3d
	ret
.n0100011:
	call get_next_bit
	jr c,.n01000111 ; Jump size: 27
.n01000110:
	call get_next_bit
	jr c,.n010001101 ; Jump size: 11
.n010001100:
	call get_next_bit
	jr c,.n0100011001 ; Jump size: 3
.n0100011000:
	ld a,$ab
	ret
.n0100011001:
	ld a,$16
	ret
.n010001101:
	call get_next_bit
	jr c,.n0100011011 ; Jump size: 3
.n0100011010:
	ld a,$c4
	ret
.n0100011011:
	ld a,$09
	ret
.n01000111:
	call get_next_bit
	jr c,.n010001111 ; Jump size: 11
.n010001110:
	call get_next_bit
	jr c,.n0100011101 ; Jump size: 3
.n0100011100:
	ld a,$53
	ret
.n0100011101:
	ld a,$57
	ret
.n010001111:
	call get_next_bit
	jr c,.n0100011111 ; Jump size: 3
.n0100011110:
	ld a,$47
	ret
.n0100011111:
	call get_next_bit
	jr c,.n01000111111 ; Jump size: 3
.n01000111110:
	ld a,$da
	ret
.n01000111111:
	ld a,$bd
	ret
.n01001:
	ld a,$80
	ret
.n0101:
	call get_next_bit
	jr c,.n01011 ; Jump size: 3
.n01010:
	ld a,$50
	ret
.n01011:
	ld a,$02
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
	ld a,$3f
	ret
.n0111:
	call get_next_bit
	jr c,.n01111 ; Jump size: 3
.n01110:
	ld a,$a0
	ret
.n01111:
	ld a,$55
	ret
.n1:
	call get_next_bit
	jp c,.n11 ; Jump size: 220
.n10:
	call get_next_bit
	jp c,.n101 ; Jump size: 147
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 3
.n1000:
	ld a,$aa
	ret
.n1001:
	call get_next_bit
	jr c,.n10011 ; Jump size: 3
.n10010:
	ld a,$fc
	ret
.n10011:
	call get_next_bit
	jr c,.n100111 ; Jump size: 75
.n100110:
	call get_next_bit
	jr c,.n1001101 ; Jump size: 67
.n1001100:
	call get_next_bit
	jr c,.n10011001 ; Jump size: 59
.n10011000:
	call get_next_bit
	jr c,.n100110001 ; Jump size: 27
.n100110000:
	call get_next_bit
	jr c,.n1001100001 ; Jump size: 11
.n1001100000:
	call get_next_bit
	jr c,.n10011000001 ; Jump size: 3
.n10011000000:
	ld a,$22
	ret
.n10011000001:
	ld a,$4a
	ret
.n1001100001:
	call get_next_bit
	jr c,.n10011000011 ; Jump size: 3
.n10011000010:
	ld a,$6a
	ret
.n10011000011:
	ld a,$d6
	ret
.n100110001:
	call get_next_bit
	jr c,.n1001100011 ; Jump size: 11
.n1001100010:
	call get_next_bit
	jr c,.n10011000101 ; Jump size: 3
.n10011000100:
	ld a,$0b
	ret
.n10011000101:
	ld a,$28
	ret
.n1001100011:
	call get_next_bit
	jr c,.n10011000111 ; Jump size: 3
.n10011000110:
	ld a,$13
	ret
.n10011000111:
	ld a,$1d
	ret
.n10011001:
	ld a,$46
	ret
.n1001101:
	ld a,$82
	ret
.n100111:
	call get_next_bit
	jr c,.n1001111 ; Jump size: 43
.n1001110:
	call get_next_bit
	jr c,.n10011101 ; Jump size: 35
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
	ld a,$45
	ret
.n10011100001:
	ld a,$b0
	ret
.n1001110001:
	call get_next_bit
	jr c,.n10011100011 ; Jump size: 3
.n10011100010:
	ld a,$84
	ret
.n10011100011:
	ld a,$81
	ret
.n100111001:
	ld a,$2f
	ret
.n10011101:
	ld a,$c3
	ret
.n1001111:
	ld a,$41
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 51
.n1010:
	call get_next_bit
	jr c,.n10101 ; Jump size: 43
.n10100:
	call get_next_bit
	jr c,.n101001 ; Jump size: 3
.n101000:
	ld a,$0f
	ret
.n101001:
	call get_next_bit
	jr c,.n1010011 ; Jump size: 27
.n1010010:
	call get_next_bit
	jr c,.n10100101 ; Jump size: 11
.n10100100:
	call get_next_bit
	jr c,.n101001001 ; Jump size: 3
.n101001000:
	ld a,$c5
	ret
.n101001001:
	ld a,$33
	ret
.n10100101:
	call get_next_bit
	jr c,.n101001011 ; Jump size: 3
.n101001010:
	ld a,$23
	ret
.n101001011:
	ld a,$8c
	ret
.n1010011:
	ld a,$04
	ret
.n10101:
	ld a,$15
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
	jr c,.n1111 ; Jump size: 67
.n1110:
	call get_next_bit
	jr c,.n11101 ; Jump size: 59
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
	ld a,$c1
	ret
.n11100001:
	ld a,$11
	ret
.n1110001:
	call get_next_bit
	jr c,.n11100011 ; Jump size: 27
.n11100010:
	call get_next_bit
	jr c,.n111000101 ; Jump size: 19
.n111000100:
	call get_next_bit
	jr c,.n1110001001 ; Jump size: 11
.n1110001000:
	call get_next_bit
	jr c,.n11100010001 ; Jump size: 3
.n11100010000:
	ld a,$51
	ret
.n11100010001:
	ld a,$1a
	ret
.n1110001001:
	ld a,$e0
	ret
.n111000101:
	ld a,$0e
	ret
.n11100011:
	ld a,$07
	ret
.n111001:
	ld a,$f0
	ret
.n11101:
	ld a,$a8
	ret
.n1111:
	call get_next_bit
	jr c,.n11111 ; Jump size: 3
.n11110:
	ld a,$54
	ret
.n11111:
	call get_next_bit
	jr c,.n111111 ; Jump size: 99
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
	ld a,$d4
	ret
.n111110001:
	ld a,$35
	ret
.n11111001:
	call get_next_bit
	jr c,.n111110011 ; Jump size: 3
.n111110010:
	ld a,$5c
	ret
.n111110011:
	call get_next_bit
	jr c,.n1111100111 ; Jump size: 3
.n1111100110:
	ld a,$0d
	ret
.n1111100111:
	ld a,$31
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
	ld a,$44
	ret
.n1111101001:
	ld a,$ac
	ret
.n111110101:
	call get_next_bit
	jr c,.n1111101011 ; Jump size: 3
.n1111101010:
	ld a,$af
	ret
.n1111101011:
	ld a,$8b
	ret
.n11111011:
	call get_next_bit
	jr c,.n111110111 ; Jump size: 11
.n111110110:
	call get_next_bit
	jr c,.n1111101101 ; Jump size: 3
.n1111101100:
	ld a,$83
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
	ld a,$40
	ret

;END_UNCOMPRESS_GENERATION
