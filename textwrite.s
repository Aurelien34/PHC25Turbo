    include inc/rammap.inc
    include inc/screen.inc

    section	code,text

smallfont_res:
    incbin res_raw/smallfont.raw

    global decompress_font, write_character, write_string, write_text_block

; Font generator config: W7 H8 O1 Lucida Console 7
; Font contains 0123456789:!/'>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz

; Screen address in [de]
; Character in [a]
write_character:
    push de
    push bc
    
    cp a,' '
    jp z,.end
    sub $30
    ld h,0
    ld l,a
    add hl,hl
    add hl,hl
    add hl,hl
    ld b,h
    ld c,l
    ld hl,smallfont_res
    add hl,bc
    ld bc,32
    ld iyl,8
    ex de,hl
.copy_loop
    ld a,(de)
    ld (hl),a
    add hl,bc
    inc de
    dec iyl
    jp nz,.copy_loop
.end
    pop bc
    pop de
    ret

; Screen address in [de]
; String address in [bc]
write_string:
    ld a,(bc)
    or a
    jp z,.end
    cp $60
    jp c,.ok_write
    sub 6
.ok_write:
    call write_character
    inc de
    inc bc
    jr write_string
.end
    ret

; Message block in ix
write_text_block:
    call wait_for_vbl
    ld e,(ix)
    inc ix
    ld d,(ix)
    inc ix
    ld a,d
    or e
    jr z,.end
    ld c,(ix)
    inc ix
    ld b,(ix)
    inc ix
    call write_string
    jr write_text_block
.end:
    ret