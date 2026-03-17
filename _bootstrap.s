    section	startup,text

    global background_data_0

; Should only unmask the code and jump to its startup label

background_data_0: ; label used for car data at run time - 16 bytes
    ; Point to the mask byte    
    ld hl,code_mask_byte
    ; Load he mask to be applied
    ld c,(hl)
    ; Point hl to the beginning of the code section
    inc hl
    ; Point de to the end of the code
    ld de,phc_file_footer
.unmaskloop:
    or a ; clear Carry flag
    sbc hl,de ; compare hl and de
    add hl,de ; restore hl (but keep status flags)
    jr z,.endloop
    ld a,(hl)
    xor c
    ; end of 16 bytes bloc for background data
    ld (hl),a
    inc hl
    jr .unmaskloop

.endloop:
    jp start

; Should be the last byte in the section (will be overwritten at build time)
code_mask_byte:
    dc.b $00