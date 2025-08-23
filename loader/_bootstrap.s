TARGET_ADDRESS equ $c100

    section	startup,text

    ; thank you Tnufuto!
    ; https://github.com/inufuto/Cate_examples/blob/main/phc25/mazy2/Loader.asm

    di

    call $454e; => Motor ON
    call $445f; 
    call $41d4;  

    ; target address
    ld de,TARGET_ADDRESS

    ; load file size (first word of the file)
    call read
    ld c,a
    ld (de),a
    inc de
    call read
    ld b,a
    ld (de),a
    inc de
    dec bc ; there seems be a lost byte at the end of the file, so we have put additional content and we will stop loading 1 byte earlier

    ; now read the file
.read_loop
    call read
    ld (de),a
    inc de

    dec bc
    ld a,b
    or c
    jr nz,.read_loop

    ; and jump to its startup routine
    jp TARGET_ADDRESS+2

; Result in A
read:
    push hl
    push bc
    push de

    call $413e

    pop de
    pop bc
    pop hl

    ret

