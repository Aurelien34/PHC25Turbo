    section	startup,text

startup:
    dc.w eof-(startup+2) ; don't count the size mark in the total size!

    jp start

    section	eof,text

    dc.b 0,0,0,0

eof: