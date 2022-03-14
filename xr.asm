; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#define PICOELF

#ifdef PICOELF
#define SERP    bn2
#define SERN    b2
#define SERSEQ     req
#define SERREQ     seq
#else
#define SERP    b2
#define SERN    bn2
#define SERSEQ     seq
#define SERREQ     req
#endif

include    bios.inc
include    kernel.inc

           org     8000h
           lbr     0ff00h
#ifdef XRB
           db      'xrb',0
#else
#ifdef XRU
           db      'xru',0
#else
           db      'xr',0
#endif
#endif
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0

           org     2000h
           br      start

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

dta:       equ     7000h
dtapage:   equ     070h
stack:     equ     7fffh

start:     lda     ra                  ; move past any spaces
           smi     ' '
           lbz     start
           dec     ra                  ; move back to non-space character
           ldn     ra                  ; get byte
           lbnz    start1              ; jump if argument given
           sep     scall               ; otherwise display usage message
           dw      o_inmsg
           db      'Usage: xr filename',10,13,0
           sep     sret                ; and return to os

start1:    ghi     ra                  ; copy argument address to rf
           phi     rf
           glo     ra
           plo     rf
loop1:     lda     ra                  ; look for first less <= space
           smi     33
           lbdf    loop1
           dec     ra                  ; backup to char
           ldi     0                   ; need proper termination
           str     ra
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     3                   ; create/truncate file
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           lbnf    opened              ; jump if file opened
           ldi     high errmsg         ; point to error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; display error message
           dw      o_msg
           lbr     o_wrmboot           ; return to Elf/OS
errmsg:    db      'file error',10,13,0
opened:    sep     scall               ; open XMODEM channel
           dw      xopenr
filelp:    ldi     high rxbuffer       ; point to buffer
           phi     rf
           ldi     low  rxbuffer
           plo     rf
           mov     rc,128              ; 128 bytes to read
           sep     scall               ; read a block 
           dw      xread
           lbdf    filedn              ; jump if done
           ldi     high rxbuffer       ; point to buffer
           phi     rf
           ldi     low rxbuffer
           plo     rf
           sep     scall               ; write buffer to file
           dw      o_write
           lbr     filelp              ; loop back for more
filedn:    sep     scall               ; close file
           dw      o_close
           sep     scall               ; close XMODEM channel
           dw      xcloser
           lbr     o_wrmboot           ; and return to os

; *******************************************
; ***** Open XMODEM channel for reading *****
; *******************************************
xopenr:    push    rf                 ; save consumed registers
           mov     rf,baud            ; point to baud constant
           ghi     re                 ; get baud constant
           str     rf                 ; save it
           ani     0feh               ; turn off echo
           phi     re                 ; put it back
           inc     rf                 ; point to init block
           ldi     nak                ; need to send initial nak
           str     rf                 ; store it
           inc     rf                 ; point to block number
           ldi     1                  ; expect 1
           str     rf                 ; store it
           inc     rf                 ; point to count
           ldi     128                ; mark as no bytes in buffer
           str     rf                 ; store it
           inc     rf                 ; point to done
           ldi     0                  ; mark as not done
           str     rf

           ldi 0                      ; setup inner delay loop
           plo rf
           phi rf
           ldi 010h                   ; setup outer delay loop
           plo re
xopenr1:   dec     rf
           glo     rf
           lbnz    xopenr1
           ghi     rf
           lbnz    xopenr1
           dec     re
           glo     re
           lbnz    xopenr1
           pop     rf                 ; recover consumed register
           sep     sret               ; and return

; ************************************
; ***** Read from XMODEM channel *****
; ***** RF - pointer to data     *****
; ***** RC - Count of data       *****
; ***** Returns: RC - bytes read *****
; *****               DF=1 EOT   *****
; ************************************
xread:     push    ra                 ; save consumed registers
           push    r9
           push    r8
           mov     r8,0               ; set received count to zero
           mov     ra,count           ; need current read count
           ldn     ra                 ; get read count
           plo     r9                 ; store it here
           str     r2                 ; store for add
           ldi     txrx.0             ; low byte of buffer address
           add                        ; add count
           plo     ra                 ; store into ra
           ldi     txrx.01            ; high byte of buffer address
           adci    0                  ; propagate carry
           phi     ra                 ; ra now has address
xreadlp:   glo     r9                 ; get count
           ani     080h               ; need to see if bytes to read
           lbz     xread1             ; jump if so
           sep     scall              ; receive another block
           dw      xrecv
           lbdf    xreadeot           ; jump if eot was received
           mov     ra,txrx            ; back to beginning of buffer
           ldi     0                  ; zero count
           plo     r9
xread1:    lda     ra                 ; read byte from receive buffer
           str     rf                 ; store into output
           inc     rf
           inc     r9                 ; increment buffer count
           inc     r8                 ; increment received count
           dec     rc                 ; decrement read count
           glo     rc                 ; get low of count
           lbnz    xreadlp            ; loop back if more to read
           ghi     rc                 ; need to check high byte
           lbnz    xreadlp            ; loop back if more
           mov     ra,count           ; need to store buffer count
           glo     r9                 ; get it
           str     ra                 ; and store it
           mov     rc,r8              ; get bytes received
           pop     r8                 ; recover used registers
           pop     r9
           pop     ra
           ldi     0                  ; signal not EOT
xreaddn:   shr                        ; shift into df
           sep     sret               ; and return to caller
xreadeot:  mov     rc,r8              ; move received count
           pop     r8                 ; recover consumed registers
           pop     r9
           pop     ra
           ldi     1                  ; signal EOT received
           lbr     xreaddn            ; and return

; ********************************
; ***** Receive XMODEM block *****
; ********************************
xrecv:     push    rf                 ; save consumed registers
           push    rc
xrecvnak:
xrecvlp:   sep     scall              ; receive a byte
           dw      readblk
           lbdf    xrecveot           ; jump if EOT received
           mov     rf,h2              ; point to received block number
           ldn     rf                 ; get it
           str     r2                 ; store for comparison
           mov     rf,block           ; get expected block number
           ldn     rf                 ; retrieve it
           sm                         ; check against received block number
           lbnz    xrecvnak1          ; jump if bad black number
           mov     rf,txrx            ; point to first data byte
           ldi     0                  ; checksum starts at zero
           phi     rc
           ldi     128                ; 131 bytes need to be added to checksum
           plo     rc
xrecv1:    lda     rf                 ; next byte from buffer
           str     r2                 ; store for add
           ghi     rc                 ; get checksum
           add                        ; add in byte
           phi     rc                 ; put checksum back
           dec     rc                 ; decrement byte count
           glo     rc                 ; see if done
           lbnz    xrecv1             ; jump if more to add up
           ldn     rf                 ; get received checksum
           str     r2                 ; store for comparison
           ghi     rc                 ; get computed checksum
           sm                         ; and compare
           lbnz    xrecvnak1          ; jump if bad

           mov     rf,init            ; point to init number
           ldi     ack                ; need to send an ack
           str     rf
           inc     rf                 ; point to block number
           ldn     rf                 ; get block number
           adi     1                  ; increment block number
           str     rf                 ; put it back
           inc     rf                 ; point to count
           ldi     0                  ; no bytes read from this block
           str     rf
           shr                        ; mark not EOT
xrecvret:  pop     rc                 ; recover consumed registers
           pop     rf
           sep     sret               ; return to caller
xrecvnak1: mov     rf,init            ; point to init byte
           ldi     nak                ; need a nak
           str     rf                 ; store it
           lbr     xrecvnak           ; need to have packet resent

xrecveot:  ldi     ack                ; send an ack
           sep     scall
#ifdef XRB
           dw      f_tty
#else
#ifdef XRU
           dw      f_utype
#else
           dw      tty
#endif
#endif
           mov     rf,xdone           ; need to mark EOT received
           ldi     1
           str     rf
           shr
           lbr     xrecvret           ; jump to return

; *************************************
; ***** Close XMODEM read channel *****
; *************************************
;xcloser:   sep     scall              ; read next block
;           dw      readblk
;           lbnf    xcloser            ; jump if EOT not received
xcloser:   mov     rf,baud            ; need to restore baud constant
           ldn     rf                 ; get it
           phi     re                 ; put it back
           sep     scall              ; display complete message
           dw      o_inmsg
           db      10,13,'XMODEM receive complete',10,13,10,13,0
           sep     sret               ; return to caller

           org     2300h
readblk:   push    rc                 ; save consumed registers
           push    ra
           push    rd
           push    r9
           ldi     132                ; 132 bytes to receive
           plo     ra
           ldi     1                  ; first character flag
           phi     ra
           mov     rf,init            ; get byte to send
           ldn     rf                 ; retrieve it

#ifdef XRB
           sep     scall              ; output the byte
           dw      f_tty
#else
#ifdef XRU
           sep     scall              ; output the byte
           dw      f_utype
#else
           phi     r9                 ; Place for transmit
           mov     rd,delay           ; address of bit delay routine
type:      ldi     9                   ; 9 bits to send
           plo     r9
           ldi     0
           shr
sendlp:    bdf     sendnb              ; jump if no bit
           SERSEQ                      ; set output
           br      sendct
sendnb:    SERREQ                      ; reset output
           br      sendct
sendct:    sep     rd                  ; perform bit delay
           sex r2
           sex r2
           ghi     r9
           shrc
           phi     r9
           dec     r9
           glo     r9
           bnz     sendlp
           SERREQ                      ; set stop bits
#endif
#endif

           mov     rf,h1              ; point to input buffer

#ifdef XRB
readblk1:  sep     scall               ; read byte from serial port
           dw      f_read
           phi     rc                  ; put character into rc.1
#else
#ifdef XRU
readblk1:  sep     scall               ; read byte from serial port
           dw      f_uread
           phi     rc                  ; put character into rc.1
#else
readblk1:  ldi     8                   ; 8 bits to receive
           plo     rc
           ghi     re                  ; first delay is half bit size
           phi     rc
           shr
           shr
           phi     re
           SERP    $                   ; wait for transmission
           sep     rd                  ; wait half the pulse width
           ghi     rc                  ; recover baud constant
           phi     re
           sep     rd                  ; move past start bit
           br      recvlp
recvlp0:   br      recvlp1             ; equalize between 0 and 1
recvlp:    ghi     rc
           shr                         ; shift right
           SERN    recvlp0             ; jump if zero bi
           ori     128                 ; set bit
recvlp1:   phi     rc
           sep     rd                  ; perform bit delay
           dec     rc                  ; decrement bit count
           nop
           nop
           glo     rc                  ; check for zero
           bnz     recvlp              ; loop if not
#endif
#endif

recvdone:  ghi     rc                  ; get character
           str     rf                  ; store into buffer
           inc     rf                  ; increment buffer
           ghi     ra                  ; get first character flag
           shr                         ; shift into df
           phi     ra                  ; and put it back
           bnf     recvgo              ; jump if not first character
           ghi     rc                  ; get character
           smi     04h                 ; check for EOT
           bnz     recvgo              ; jump if not EOT
           ldi     1                   ; indicate EOT received
           br      recvret
recvgo:    dec     ra                  ; decrement receive count
           glo     ra                  ; see if done
           lbnz    readblk1            ; jump if more bytes to read
           ldi     0                   ; clear df flag for full block read
recvret:   shr
           pop     r9
           pop     rd                  ; recover consumed registers
           pop     ra
           pop     rc
           sep     sret                ; and return to caller
           sep     r3

#ifndef XRB
#ifndef XRU
delay:     ghi     re                  ; get baud constant
           shr                         ; remove echo flag
           plo     re                  ; put into counter
           sex     r2                  ; waste a cycle
delay1:    dec     re                  ; decrement counter
           glo     re                  ; get count
           bz      delay-1             ; return if zero
           br      delay1              ; otherwise keep going

tty:       plo     re
           push    rf                  ; save consumed registers
           push    rd
           glo     re
           phi     rf
           ldi     9                   ; 9 bits to send
           plo     rf
           mov     rd,delay            ; point RD to delay routine
           ldi     0
           shr
typelp:    bdf     typenb              ; jump if no bit
           SERSEQ                      ; set output
           br      typect
typenb:    SERREQ                      ; reset output
           br      typect
typect:    sep     rd                  ; perform bit delay
           sex r2
           sex r2
           ghi     rf
           shrc
           phi     rf
           dec     rf
           glo     rf
           bnz     typelp
           SERREQ                      ; set stop bits
           sep     rd
           sep     rd
           pop     rd                  ; recover consumed registers
           pop     rf
           sep     sret
#endif
#endif

endrom:    equ     $

base:      equ     $                 ; XMODEM data segment
baud:      equ     base+0
init:      equ     base+1
block:     equ     base+2            ; current block
count:     equ     base+3            ; byte send/receive count
xdone:     equ     base+4
h1:        equ     base+5
h2:        equ     base+6
h3:        equ     base+7
txrx:      equ     base+8            ; buffer for tx/rx
temp1:     equ     base+150
temp2:     equ     base+152
buffer:    equ     base+154          ; address for input buffer
ack:       equ     06h
nak:       equ     15h
soh:       equ     01h
etx:       equ     03h
eot:       equ     04h
can:       equ     18h
csub:      equ     1ah

rxbuffer:  equ     base+200h

