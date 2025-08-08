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
;Decompression algorithm takes 107 bytes

.n:
	call get_next_bit
	jr c,.n1 ; Jump size: 3
.n0:
	ld a,$00
	ret
.n1:
	call get_next_bit
	jr c,.n11 ; Jump size: 3
.n10:
	ld a,$0c
	ret
.n11:
	call get_next_bit
	jr c,.n111 ; Jump size: 83
.n110:
	call get_next_bit
	jr c,.n1101 ; Jump size: 19
.n1100:
	call get_next_bit
	jr c,.n11001 ; Jump size: 3
.n11000:
	ld a,$14
	ret
.n11001:
	call get_next_bit
	jr c,.n110011 ; Jump size: 3
.n110010:
	ld a,$18
	ret
.n110011:
	ld a,$04
	ret
.n1101:
	call get_next_bit
	jr c,.n11011 ; Jump size: 19
.n11010:
	call get_next_bit
	jr c,.n110101 ; Jump size: 3
.n110100:
	ld a,$10
	ret
.n110101:
	call get_next_bit
	jr c,.n1101011 ; Jump size: 3
.n1101010:
	ld a,$30
	ret
.n1101011:
	ld a,$91
	ret
.n11011:
	call get_next_bit
	jr c,.n110111 ; Jump size: 27
.n110110:
	call get_next_bit
	jr c,.n1101101 ; Jump size: 11
.n1101100:
	call get_next_bit
	jr c,.n11011001 ; Jump size: 3
.n11011000:
	ld a,$28
	ret
.n11011001:
	ld a,$20
	ret
.n1101101:
	call get_next_bit
	jr c,.n11011011 ; Jump size: 3
.n11011010:
	ld a,$e6
	ret
.n11011011:
	ld a,$d9
	ret
.n110111:
	ld a,$1c
	ret
.n111:
	ld a,$08
	ret

;END_UNCOMPRESS_GENERATION
