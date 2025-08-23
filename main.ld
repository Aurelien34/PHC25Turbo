MEMORY {
	CODE: org=0xc100, len=0x3600
}

SECTIONS {
	.startup: {
		*(startup)
	} >CODE
	.code: {
		*(code)
	} >CODE
	.compressed: {
		*(compressed)
	} >CODE
	.eof: {
		*(eof)
	} >CODE
}
