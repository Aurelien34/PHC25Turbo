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
;Decompression algorithm takes 203 bytes

.n:
	call get_next_bit
	jr c,.n1 ; Jump size: 115
.n0:
	call get_next_bit
	jr c,.n01 ; Jump size: 83
.n00:
	call get_next_bit
	jr c,.n001 ; Jump size: 35
.n000:
	call get_next_bit
	jr c,.n0001 ; Jump size: 11
.n0000:
	call get_next_bit
	jr c,.n00001 ; Jump size: 3
.n00000:
	ld a,$ba
	ret
.n00001:
	ld a,$33
	ret
.n0001:
	call get_next_bit
	jr c,.n00011 ; Jump size: 3
.n00010:
	ld a,$cc
	ret
.n00011:
	call get_next_bit
	jr c,.n000111 ; Jump size: 3
.n000110:
	ld a,$df
	ret
.n000111:
	ld a,$bf
	ret
.n001:
	call get_next_bit
	jr c,.n0011 ; Jump size: 27
.n0010:
	call get_next_bit
	jr c,.n00101 ; Jump size: 11
.n00100:
	call get_next_bit
	jr c,.n001001 ; Jump size: 3
.n001000:
	ld a,$bd
	ret
.n001001:
	ld a,$db
	ret
.n00101:
	call get_next_bit
	jr c,.n001011 ; Jump size: 3
.n001010:
	ld a,$fb
	ret
.n001011:
	ld a,$fd
	ret
.n0011:
	call get_next_bit
	jr c,.n00111 ; Jump size: 3
.n00110:
	ld a,$76
	ret
.n00111:
	ld a,$6e
	ret
.n01:
	call get_next_bit
	jr c,.n011 ; Jump size: 11
.n010:
	call get_next_bit
	jr c,.n0101 ; Jump size: 3
.n0100:
	ld a,$dd
	ret
.n0101:
	ld a,$bb
	ret
.n011:
	call get_next_bit
	jr c,.n0111 ; Jump size: 3
.n0110:
	ld a,$7f
	ret
.n0111:
	ld a,$fe
	ret
.n1:
	call get_next_bit
	jr c,.n11 ; Jump size: 75
.n10:
	call get_next_bit
	jr c,.n101 ; Jump size: 35
.n100:
	call get_next_bit
	jr c,.n1001 ; Jump size: 27
.n1000:
	call get_next_bit
	jr c,.n10001 ; Jump size: 19
.n10000:
	call get_next_bit
	jr c,.n100001 ; Jump size: 11
.n100000:
	call get_next_bit
	jr c,.n1000001 ; Jump size: 3
.n1000000:
	ld a,$f6
	ret
.n1000001:
	ld a,$6f
	ret
.n100001:
	ld a,$ef
	ret
.n10001:
	ld a,$00
	ret
.n1001:
	ld a,$77
	ret
.n101:
	call get_next_bit
	jr c,.n1011 ; Jump size: 3
.n1010:
	ld a,$ee
	ret
.n1011:
	call get_next_bit
	jr c,.n10111 ; Jump size: 11
.n10110:
	call get_next_bit
	jr c,.n101101 ; Jump size: 3
.n101100:
	ld a,$f7
	ret
.n101101:
	ld a,$5d
	ret
.n10111:
	call get_next_bit
	jr c,.n101111 ; Jump size: 3
.n101110:
	ld a,$dc
	ret
.n101111:
	ld a,$3b
	ret
.n11:
	ld a,$ff
	ret

;END_UNCOMPRESS_GENERATION
