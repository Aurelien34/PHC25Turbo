    section	startup,text

; Should only unmask the code and jump to its startup label
    
    ; Point hl to the beginning of the code section
    ld hl,code_mask_byte+1
    ;inc hl
    ; Point de to the end of the code
    ld de,phc_file_footer
    ; Load he mask to be applied
    ld a,(code_mask_byte)
    ld c,a
.unmaskloop:
    or a ; clear Carry flag
    sbc hl,de ; compare hl and de
    add hl,de ; restore hl (but keep status flags)
    jr z,.endloop
    ld a,(hl)
    xor c
    ld (hl),a
    inc hl
    jr .unmaskloop

.endloop:
    jp start

; Should be the last byte in the section (will be overwritten at build time)
code_mask_byte:
    dc.b $00