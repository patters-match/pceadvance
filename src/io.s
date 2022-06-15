	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE vdc.h
	INCLUDE sound.h
	INCLUDE cdrom.h
	INCLUDE arcadecard.h
	INCLUDE cart.h
	INCLUDE h6280.h

	EXPORT IO_reset_
	EXPORT IO_R
	EXPORT IO_W
	EXPORT psg_write_ptr
;	EXPORT joypad_write_ptr
	EXPORT joycfg
	EXPORT timermask
	EXPORT spriteinit
	EXPORT suspend
	EXPORT refreshPCEjoypads
	EXPORT serialinterrupt
	EXPORT resetSIO
	EXPORT thumbcall_r1
	EXPORT gettime
	EXPORT vbaprint
	EXPORT waitframe
	EXPORT LZ77UnCompVram
	EXPORT CheckGBAVersion


 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

vbaprint
	swi 0xFF0000		;!!!!!!! Doesn't work on hardware !!!!!!!
	bx lr
LZ77UnCompVram
	swi 0x120000
	bx lr
waitframe
VblWait
	mov r0,#0				;don't wait if not necessary
	mov r1,#1				;VBL wait
	swi 0x040000			; Turn of CPU until VBLIRQ if not too late allready.
	bx lr
CheckGBAVersion
	ldr r0,=0x5AB07A6E		;Fool proofing
	mov r12,#0
	swi 0x0D0000			;GetBIOSChecksum
	ldr r1,=0xABBE687E		;Proto GBA
	cmp r0,r1
	moveq r12,#1
	ldr r1,=0xBAAE187F		;Normal GBA
	cmp r0,r1
	moveq r12,#2
	ldr r1,=0xBAAE1880		;Nintendo DS
	cmp r0,r1
	moveq r12,#4
	mov r0,r12
	bx lr

joycode
	orr r0,r0,#0x80		;CD-ROM
	orr r0,r0,#0xC0		;CD-ROM & US

scaleparms;	   NH     FH     NV     FV
	DCD 0x0000,0x0100,0xff01,0x0150,0xfeb6,OAM_BUFFER1+6,AGB_OAM+518
;----------------------------------------------------------------------------
IO_reset_
;----------------------------------------------------------------------------
	adr r6,scaleparms		;set sprite scaling params
	ldmia r6,{r0-r6}

	mov r7,#3
scaleloop
	strh r1,[r5],#8				;buffer1, buffer2, buffer3
	strh r0,[r5],#8
	strh r0,[r5],#8
	strh r3,[r5],#232
		strh r2,[r5],#8
		strh r0,[r5],#8
		strh r0,[r5],#8
		strh r3,[r5],#232
	subs r7,r7,#1
	bne scaleloop

	strh r1,[r6],#8				;7000200
	strh r0,[r6],#8
	strh r0,[r6],#8
	strh r4,[r6],#232
		strh r2,[r6],#8
		strh r0,[r6],#8
		strh r0,[r6],#8
		strh r4,[r6]

	ldr r2,=joyreadptr
	ldrb r0,emuflags
	tst r0,#USCOUNTRY
	ldreq r1,joycode
	ldrne r1,joycode+4
	str r1,[r2]

	ldr r1,=joyselect
	mov r0,#0
	strb r0,[r1],#1
	strb r0,[r1]

	ldr r0,ACC_RAMp
	cmp r0,#0
	ldreq r1,=empty_R
	ldreq r2,=empty_W
	ldrne r1,=ARCADE_R
	ldrne r2,=ARCADE_W
	ldr r0,=arcade_read_ptr
	str r1,[r0]
	ldr r0,=arcade_write_ptr
	str r2,[r0]

	ldrb r0,emuflags+1
	;..to spriteinit
;----------------------------------------------------------------------------
spriteinit	;build yscale_lookup tbl (called by ui.c) r0=scaletype
;called by ui.c:  void spriteinit(char scaletype) (pass scaletype in r0 because globals ptr isn't set up to read it)
;----------------------------------------------------------------------------
	ldr r3,=flipsizeTable
	add r2,r3,#0x400
	mov r12,#0
	cmp r0,#SCALED
	movhi r12,#0x100

si6	ldr r1,[r3]
	bic r1,r1,#0x100		;disable rot/scale sprites
	orr r1,r1,r12			;enable rot/scale sprites
	str r1,[r3],#4
	cmp r2,r3
	bne si6
	ldr r3,=YSCALE_LOOKUP
	cmp r0,#SCALED
	bpl si1

;------------------ unscaled
si5
	sub r2,r3,#80
	mov r0,#164
si2	strb r0,[r2],#1
	cmp r2,r3
	bne si2

	add r2,r3,#256+64
	mov r0,#-64
si3	strb r0,[r3],#1
	add r0,r0,#1
	cmp r0,#164
	movpl r0,#164
	cmp r2,r3
	bne si3
	bx lr

;------------------ scaled
si1
	sub r3,r3,#16			;(256-224)/2=16
	mov r0,#0x0000c000		;0.75
	ldr r1,=0x00c28000		;-(16+64)*0.75
si4	mov r2,r1,lsr#16
	strb r2,[r3],#1
	add r1,r1,r0
	cmp r2,#0x1e0
	bne si4
	bx lr
;----------------------------------------------------------------------------
suspend	;called from ui.c and h6280.s
;-------------------------------------------------
	mov r3,#REG_BASE

	ldr r1,=REG_P1CNT
	ldr r0,=0xc00c			;interrupt on start+sel
	strh r0,[r3,r1]

	ldrh r1,[r3,#REG_SGCNT_L]
	strh r3,[r3,#REG_SGCNT_L]	;sound off

	ldrh r0,[r3,#REG_DISPCNT]
	orr r0,r0,#0x80
	strh r0,[r3,#REG_DISPCNT]	;LCD off

	swi 0x030000

	ldrh r0,[r3,#REG_DISPCNT]
	bic r0,r0,#0x80
	strh r0,[r3,#REG_DISPCNT]	;LCD on

	strh r1,[r3,#REG_SGCNT_L]	;sound on

	bx lr
;----------------------------------------------------------------------------
gettime	;called from ui.c
;----------------------------------------------------------------------------
	ldr r3,=0x080000c4		;base address for RTC
	mov r1,#1
	strh r1,[r3,#4]			;enable RTC
	mov r1,#7
	strh r1,[r3,#2]			;enable write

	mov r1,#1
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]			;State=Command

	mov r2,#0x65			;r2=Command, YY:MM:DD 00 hh:mm:ss
	mov addy,#8
RTCLoop1
	mov r1,#2
	and r1,r1,r2,lsr#6
	orr r1,r1,#4
	strh r1,[r3]
	mov r1,r2,lsr#6
	orr r1,r1,#5
	strh r1,[r3]
	mov r2,r2,lsl#1
	subs addy,addy,#1
	bne RTCLoop1

	mov r1,#5
	strh r1,[r3,#2]			;enable read
	mov r2,#0
	mov addy,#32
RTCLoop2
	mov r1,#4
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]
	ldrh r1,[r3]
	and r1,r1,#2
	mov r2,r2,lsr#1
	orr r2,r2,r1,lsl#30
	subs addy,addy,#1
	bne RTCLoop2

	mov r0,#0
	mov addy,#24
RTCLoop3
	mov r1,#4
	strh r1,[r3]
	mov r1,#5
	strh r1,[r3]
	ldrh r1,[r3]
	and r1,r1,#2
	mov r0,r0,lsr#1
	orr r0,r0,r1,lsl#22
	subs addy,addy,#1
	bne RTCLoop3

	bx lr
;----------------------------------------------------------------------------
serialinterrupt
;----------------------------------------------------------------------------
	mov r3,#REG_BASE
	add r3,r3,#0x100

	mov r0,#0x1
serWait	subs r0,r0,#1
	bne serWait
	mov r0,#0x100		;time to wait.
	ldrh r1,[r3,#REG_SIOCNT]
	tst r1,#0x80		;Still transfering?
	bne serWait

	tst r1,#0x40		;communication error? resend?
	bne sio_err

	ldr r0,[r3,#REG_SIOMULTI0]	;Both SIOMULTI0&1
	ldr r1,[r3,#REG_SIOMULTI2]	;Both SIOMULTI2&3

	and r2,r0,#0xff00	;From Master
	cmp r2,#0xaa00
	beq resetrequest	;$AAxx means Master GBA wants to restart

	ldr r2,sending
	tst r2,#0x10000
	beq sio_err
	strne r0,received0	;store only if we were expecting something
	strne r1,received1	;store only if we were expecting something
	eor r2,r2,r0		;Check if master sent what we expected
	ands r2,r2,#0xff00
	strne r0,received2	;otherwise print value.
	strne r1,received3	;otherwise print value.

sio_err
	strb r3,sending+2	;send completed, r3b=0
	bx lr

resetrequest
	ldr r2,joycfg
	strh r0,received0
	orr r2,r2,#0x01000000
	bic r2,r2,#0x08000000
	str r2,joycfg
	bx lr

sending DCD 0
lastsent DCD 0
received0 DCD 0
received1 DCD 0
received2 DCD 0
received3 DCD 0
;---------------------------------------------
xmit	;send byte in r0
;returns REG_SIOCNT in r1, received P1/P2 in r2, received P3/P4 in r3, Z set if successful, r4-r5 destroyed
;---------------------------------------------
	ldr r3,sending
	tst r3,#0x10000		;last send completed?
	movne pc,lr

	mov r5,#REG_BASE
	add r5,r5,#0x100
	ldrh r1,[r5,#REG_SIOCNT]
	tst r1,#0x80		;clear to send?
	movne pc,lr

	ldrb r4,frame
	eor r4,r4,#0x55
	bic r4,r4,#0x80
	orr r0,r0,r4,lsl#8	;r0=new data to send

	ldr r2,received0
	ldr r3,received1
	cmp r2,#-1			;Check for uninitialized
	eoreq r2,r2,#0xf00
	ldr r4,nrplayers
	cmp r4,#2
	beq players2
	cmp r4,#3
	beq players3
players4
	eor r4,r2,r3,lsr#16	;P1 & P4
	tst r4,#0xff00		;not in sync yet?
	beq players3
	ldr r1,lastsent
	eor r4,r1,r3,lsr#16	;Has P4 missed an interrupt?
	tst r4,#0xff00
	streq r1,sending	;Send the value before this.
	b iofail
players3
	eor r4,r2,r3		;P1 & P3
	tst r4,#0xff00		;not in sync yet?
	beq players2
	ldr r1,lastsent
	eor r4,r1,r3		;Has P3 missed an interrupt?
	tst r4,#0xff00
	streq r1,sending	;Send the value before this.
	b iofail
players2
	eor r4,r2,r2,lsr#16	;P1 & P2
	tst r4,#0xff00		;in sync yet?
	beq checkold
	ldr r1,lastsent
	eor r4,r1,r2,lsr#16	;Has P2 missed an interrupt?
	tst r4,#0xff00
	streq r1,sending	;Send the value before this.
	b iofail
checkold
	ldr r4,sending
	ldr r1,lastsent
	eor r4,r4,r1		;Did we send an old value last time?
	tst r4,#0xff00
	bne iogood		;bne
	ldr r1,sending
	str r0,sending
	str r1,lastsent
iofail	orrs r4,r4,#1		;Z=0 fail
	b notyet
iogood	ands r4,r4,#0		;Z=1 ok
notyet	ldr r1,sending
	streq r1,lastsent
	movne r0,r1			;resend last.

	orr r0,r0,#0x10000
	str r0,sending
	strh r0,[r5,#REG_SIOMLT_SEND]	;put data in buffer
	ldrh r1,[r5,#REG_SIOCNT]
	tst r1,#0x4			;Check if we're Master.
	bne endSIO

multip	ldrh r1,[r5,#REG_SIOCNT]
	tst r1,#0x8			;Check if all machines are in multi mode.
	beq multip

	orr r1,r1,#0x80			;Set send bit
	strh r1,[r5,#REG_SIOCNT]	;start send

endSIO
	teq r4,#0
	mov pc,lr
;----------------------------------------------------------------------------
resetSIO	;r0=joycfg
;----------------------------------------------------------------------------
	bic r0,r0,#0x0f000000
	str r0,joycfg

	mov r2,#2		;only 2 players.
	mov r1,r0,lsr#29
	cmp r1,#0x6
	moveq r2,#4		;all 4 players
	cmp r1,#0x5
	moveq r2,#3		;3 players.
	str r2,nrplayers

	mov r2,#REG_BASE
	add r2,r2,#0x100

	mov r1,#0
	strh r1,[r2,#REG_RCNT]

	tst r0,#0x80000000
	moveq r1,#0x2000
	movne r1,   #0x6000
	addne r1,r1,#0x0002	;16bit multiplayer, 57600bps
	strh r1,[r2,#REG_SIOCNT]

	bx lr
;----------------------------------------------------------------------------
refreshPCEjoypads	;call every frame
;exits with Z flag clear if update incomplete (waiting for other player)
;is my multiplayer code butt-ugly?  yes, I thought so.
;i'm not trying to win any contests here.
;----------------------------------------------------------------------------
	mov r6,lr		;return with this..

;	ldr r0,received0
;	mov r1,#4
;	bl debug_
;	ldr r0,received1
;	mov r1,#5
;	bl debug_
;	ldr r0,received2
;	mov r1,#7
;	bl debug_
;	ldr r0,received3
;	mov r1,#8
;	bl debug_
;	ldr r0,sending
;	mov r1,#10
;	bl debug_
;	ldr r0,lastsent
;	mov r1,#11
;	bl debug_

		ldr r4,frame
		movs r0,r4,lsr#2 ;C=frame&2 (autofire alternates every other frame)
	ldr r1,PCEjoypad
	and r0,r1,#0xf0
		ldr r2,joycfg
		andcs r1,r1,r2
		movcss addy,r1,lsr#9	;R?
		andcs r1,r1,r2,lsr#16
	adr addy,dulr2ldru
	ldrb r0,[addy,r0,lsr#4]	;downupleftright
	and r1,r1,#0x0f
	tst r2,#0x400			;Swap A/B?
	adrne addy,ssba2rs12
	ldrneb r1,[addy,r1]	;startselectBA
	orr r0,r0,r1,lsl#4	;r0=joypad state

	tst r2,#0x80000000
	bne multi

;	tst r2,#0x40000000	; P3/P4
;	beq no4scr
;	tst r2,#0x20000000	; P3/P4
;	streqb r0,joy2state
;	strneb r0,joy3state
;	ands r0,r0,#0		;Z=1
;	mov pc,r6
	
no4scr	tst r2,#0x20000000
	streqb r0,joy0state
	strneb r0,joy1state
	ands r0,r0,#0		;Z=1
	mov pc,r6		;Return
multi				;r2=joycfg
	tst r2,#0x08000000	;link active?
	beq link_sync

	bl xmit			;send joypad data for NEXT frame
	movne pc,r6		;send was incomplete!

	strb r2,joy0state		;master is player 1
	mov r2,r2,lsr#16
	strb r2,joy1state		;slave1 is player 2
	ldr r4,nrplayers
	cmp r4,#2
	beq fin
	strb r3,joy2state
	mov r3,r3,asr#16
	cmp r4,#3
	strneb r3,joy3state
fin	ands r0,r0,#0		;Z=1
	mov pc,r6

link_sync
	mov r1,#0x8000
	str r1,lastsent
	tst r2,#0x03000000
	beq stage0
	tst r2,#0x02000000
	beq stage1
stage2
	mov r0,#0x2200
	bl xmit			;wait til other side is ready to go

	moveq r1,#0x8000
	streq r1,lastsent
	ldr r2,joycfg
	biceq r2,r2,#0x03000000
	orreq r2,r2,#0x08000000
	str r2,joycfg

	b badmonkey
stage1		;other GBA wants to reset
	bl sendreset		;one last time..
	bne badmonkey

	orr r2,r2,#0x02000000	;on to stage 2..
	str r2,joycfg

	ldr r0,romnumber
	tst r4,#0x4		;who are we?
	beq sg1
	ldrb r3,received0	;slaves uses master's timing flags
	bic r1,r1,#USEPPUHACK+NOCPUHACK+USCOUNTRY
	orr r1,r1,r3
sg1	bl loadcart		;game reset

	mov r1,#0
	str r1,sending		;reset sequence numbers
	str r1,received0
	str r1,received1
badmonkey
	orrs r0,r0,#1		;Z=0 (incomplete xfer)
	mov pc,r6
stage0	;self-initiated link reset
	bl sendreset		;keep sending til we get a reply
	b badmonkey
sendreset       ;exits with r1=emuflags, r4=REG_SIOCNT, Z=1 if send was OK
	mov r5,#REG_BASE
	add r5,r5,#0x100

        ldr r1,emuflags
	and r0,r1,#USEPPUHACK+NOCPUHACK+USCOUNTRY
	orr r0,r0,#0xaa00		;$AAxx, xx=timing flags

	ldrh r4,[r5,#REG_SIOCNT]
	tst r4,#0x80			;ok to send?
	movne pc,lr

	strh r0,[r5,#REG_SIOMLT_SEND]
	orr r4,r4,#0x80
	strh r4,[r5,#REG_SIOCNT]	;send!
	mov pc,lr

joycfg DCD 0x40ff01ff ;byte0=auto mask, byte1=(saves R), byte2=R auto mask
;bit 31=single/multi, 30,29=1P/2P, 27=(multi) link active, 24=reset signal received
nrplayers DCD 0		;Number of players in multilink.
joySerial DCB 0
joy0state DCB 0
joy1state DCB 0
joy2state DCB 0
joy3state DCB 0
joy4state DCB 0
joyempty  DCB 0xff
joyselect DCB 0
joywrite  DCB 0,0,0,0
ssba2rs12	DCB 0x00,0x02,0x01,0x03, 0x04,0x06,0x05,0x07, 0x08,0x0a,0x09,0x0b, 0x0c,0x0e,0x0d,0x0f
dulr2ldru	DCB 0x00,0x02,0x08,0x0a, 0x01,0x03,0x09,0x0b, 0x04,0x06,0x0c,0x0e, 0x05,0x07,0x0d,0x0f
;----------------------------------------------------------------------------
JOYP_W		;$1000-$13ff
;----------------------------------------------------------------------------
	strb r0,iobuffer
	and r0,r0,#3
	ldrb r1,joywrite
	strb r0,joywrite
	ldrb r2,joyselect
	cmp r1,#1
	cmpeq r0,#3		;Reset joyselect if going from 1 to 3.
	moveq r2,#0

	cmp r1,#0		;select next joypad if going from 0 to 1
	cmpeq r0,#1
	addeq r2,r2,#1

	cmp r2,#5
	movpl r2,#5
	strb r2,joyselect
	adr r1,joy0state
	ldrb r1,[r1,r2]

	tst r0,#2
	movne r1,#0xFF
	tst r0,#1
	moveq r1,r1,lsr#4
	and r1,r1,#0x0F
	strb r1,joySerial

	mov pc,lr
;----------------------------------------------------------------------------
;JOYP_Ws		;$1000-$13ff
;----------------------------------------------------------------------------
;	strb r0,iobuffer
;	ldr r1,joy0state
;	tst r0,#1
;	moveq r1,r1,lsr#4
;	and r1,r1,#0x0F
;	orr r1,r1,#0x80		;CD-ROM
;	strb r1,joySerial

;	mov pc,lr
;----------------------------------------------------------------------------
JOYP_R		;$1000-$13ff
;----------------------------------------------------------------------------
	ldrb r0,joySerial
joyreadptr
	orr r0,r0,#0x80		;CD-ROM (& US)
	eor r0,r0,#0xFF
	strb r0,iobuffer
	mov pc,lr

;----------------------------------------------------------------------------
;--------------------------------------------------
	INCLUDE visoly.s
 AREA wram_code1, CODE, READWRITE
;-- - - - - - - - - - - - - - - - - - - - - -

thumbcall_r1 bx r1

;----------------------------------------------------------------------------
IO_R		;I/O read
;----------------------------------------------------------------------------
	and r1,addy,#0x1e00
	ldr pc,[pc,r1,lsr#7]
;---------------------------
	DCD 0
;io_read_tbl
	DCD VDC_R		;0x0000-0x03FF
	DCD VDC_R		;0x0000-0x03FF
	DCD VCE_R		;0x0400-0x07FF
	DCD VCE_R		;0x0400-0x07FF
	DCD PSG_R		;0x0800-0x0BFF
	DCD PSG_R		;0x0800-0x0BFF
	DCD TIMER_R		;0x0C00-0x0FFF
	DCD TIMER_R		;0x0C00-0x0FFF
	DCD JOYP_R		;0x1000-0x13FF
	DCD JOYP_R		;0x1000-0x13FF
	DCD IRQ_R		;0x1400-0x17FF
	DCD IRQ_R		;0x1400-0x17FF
	DCD CDROM_R		;0x1800-0x19FF
arcade_read_ptr
	DCD empty_R		;0x1A00-0x1BFF, also ARCADE_R
	DCD empty_R		;0x1C00-0x1FFF
	DCD empty_R		;0x1C00-0x1FFF

;----------------------------------------------------------------------------
IO_W		;I/O write
;----------------------------------------------------------------------------
	and r1,addy,#0x1e00
	ldr pc,[pc,r1,lsr#7]
;---------------------------
	DCD 0
;io_write_tbl
	DCD VDC_W		;0x0000-0x03FF
	DCD VDC_W		;0x0000-0x03FF
	DCD VCE_W		;0x0400-0x07FF
	DCD VCE_W		;0x0400-0x07FF
psg_write_ptr
	DCD PSG_W_OFF	;0x0800-0x0BFF, can be PSG_W_OFF & PSG_W
	DCD PSG_W_OFF	;0x0800-0x0BFF, can be PSG_W_OFF & PSG_W
	DCD TIMER_W		;0x0C00-0x0FFF
	DCD TIMER_W		;0x0C00-0x0FFF
;joypad_write_ptr
	DCD JOYP_W		;0x1000-0x13FF
	DCD JOYP_W		;0x1000-0x13FF
	DCD IRQ_W		;0x1400-0x17FF
	DCD IRQ_W		;0x1400-0x17FF
	DCD CDROM_W		;0x1800-0x19FF
arcade_write_ptr
	DCD empty_W		;0x1A00-0x1BFF, also ARCADE_W
	DCD empty_W		;0x1C00-0x1FFF
	DCD empty_W		;0x1C00-0x1FFF

timermask DCD 1
;----------------------------------------------------------------------------
TIMER_R
;----------------------------------------------------------------------------
	ldr r0,timCycles
	and r0,r0,#0x3F800
	ldrb r1,iobuffer
	and r1,r1,#0x80
	orr r0,r1,r0,lsr#11
	strb r0,iobuffer
	mov pc,lr
;----------------------------------------------------------------------------
TIMER_W
;----------------------------------------------------------------------------
	strb r0,iobuffer
	tst addy,#1
	bne TIMER_W1
;----------------------------------------------------------------------------
TIMER_W0
;----------------------------------------------------------------------------
	and r0,r0,#0x7f
	strb r0,timerLatch
	mov pc,lr
;----------------------------------------------------------------------------
TIMER_W1
;----------------------------------------------------------------------------
	ldrb r1,timermask
	and r0,r0,r1
	ldrb r1,timerEnable
	strb r0,timerEnable
	bic r0,r0,r1
	tst r1,#0
	moveq pc,lr		;only reload counter if going from 0 -> 1

	ldrb r0,timerLatch
	add r0,r0,#1
	mov r0,r0,lsl#10		;x(1024)
	add r0,r0,r0,lsl#1		;x3
	sub r0,r0,cycles,lsr#CYC_SHIFT	;just cycles, no flags
	str r0,timCycles
	mov pc,lr

;----------------------------------------------------------------------------
IRQ_R
;----------------------------------------------------------------------------
	ldrb r0,iobuffer
	and r1,addy,#3
	cmp r1,#2
	ldreqb r1,irqDisable	;IRQ2_R
	ldrhib r1,irqPending	;IRQ3_R
	andpl r1,r1,#0x07
	bicpl r0,r0,#0x07
	orrpl r0,r0,r1
	strplb r0,iobuffer
	mov pc,lr
;----------------------------------------------------------------------------
IRQ_W
;----------------------------------------------------------------------------
	strb r0,iobuffer
	and r1,addy,#3
	cmp r1,#2
	beq _IRQ2W
	bhi _IRQ3W
	mov pc,lr
;----------------------------------------------------------------------------
_IRQ2W
;----------------------------------------------------------------------------
	strb r0,irqDisable	;check for pending IRQ's?
;------------------------
;	ldrb r1,irqPending
;	bic r0,r1,r0
;	ands r0,r0,#6
;	bne checkirqdisable	;either this or...
;	movne cycles,#0		;this.
;------------------------
	mov pc,lr
;----------------------------------------------------------------------------
_IRQ3W
;----------------------------------------------------------------------------
	ldrb r0,irqPending
	bic r0,r0,#4		;acknowledge Timer irq
	strb r0,irqPending
	mov pc,lr

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	END
