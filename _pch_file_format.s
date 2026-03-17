; PHC file should not exceed 14208 bytes - linker script is configured to limit code to this size

    global phc_file_footer
    global background_data_1

    section	header,data

    ; --- [1] Header : 10 × $A5
    dc.b $A5,$A5,$A5,$A5,$A5,$A5,$A5,$A5,$A5,$A5

    ; --- [2] Nom du fichier BASIC (6 caractères ASCII)
    dc.b "ST2000"

    section basic,data

; --- [3] Token etc pour 10 EXEC&HC009 
	dc.b $a5,$26,$48,$43,$30,$30,$39,$00

    section	footer,text

phc_file_footer:

    ; --- [6] Footer PHC (20 octets)
    dc.b $00, $00
    dc.b $01, $c0
background_data_1: ; label used for car data at run time - 16 bytes
    dc.b $01, $00
    dc.b $00
    dc.b $ff, $ff, $ff, $ff
    dc.b $00, $00, $00, $00
    dc.b $00, $00, $00, $00
    dc.b $00, $00

    ; Fin du fichier