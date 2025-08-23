MEMORY {
	HEADER: org=0xbff1, len=0x0010
	BASIC: org=0xc001, len=0x0008
	CODE: org=0xc009, len=0x00f7
}

SECTIONS {
	.header: {
		*(header)
	} >HEADER
	.basic: {
		*(basic)
	} >BASIC
	.startup: {
		*(startup)
	} >CODE
	.footer: {
		*(footer)
	} >CODE
}
