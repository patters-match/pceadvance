	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE io.h
	INCLUDE vdc.h

	EXPORT timer1interrupt
	EXPORT Sound_reset_
	EXPORT updatesound
	EXPORT soundmode
	EXPORT PSG_R
	EXPORT PSG_W_OFF
	EXPORT PSG_W
	EXPORT Vbl_Sound_1
	EXPORT Vbl_Sound_2

 AREA wram_code2, CODE, READWRITE
;----------------------------------------------------------------------------
; r0 = sample reg1.
; r1 = sample reg2/volume.
; r2 = mixer reg left.
; r3 = mixer reg right.
; r4 -> r9 = pos+freq.
; r10 = samplebuffers.
; r11 = mixerbuffer1.
; r12 = mixerbuffer2.
; r14 = mixerbuffer end.
;----------------------------------------------------------------------------
pcmmix
;----------------------------------------------------------------------------
pcmmixloop
	ldrb r0,[r10,r4,lsr#27]			;Channel 0
	add r4,r4,r4,lsl#16
	ldrb r1,[r10,r4,lsr#27]
	add r4,r4,r4,lsl#16
	orr r0,r1,r0,lsl#16
vol0_L
	movs r1,#0x00					;volume left
	mul r2,r0,r1
vol0_R
	movs r1,#0x00					;volume right
	mul r3,r0,r1


	add r10,r10,#0x20
	ldrb r0,[r10,r5,lsr#27]			;Channel 1
	add r5,r5,r5,lsl#16
	ldrb r1,[r10,r5,lsr#27]
	add r5,r5,r5,lsl#16
	orr r0,r1,r0,lsl#16
vol1_L
	movs r1,#0x00					;volume left
	mlane r2,r0,r1,r2
vol1_R
	movs r1,#0x00					;volume right
	mlane r3,r0,r1,r3


	add r10,r10,#0x20
	ldrb r0,[r10,r6,lsr#27]			;Channel 2
	add r6,r6,r6,lsl#16
	ldrb r1,[r10,r6,lsr#27]
	add r6,r6,r6,lsl#16
	orr r0,r1,r0,lsl#16
vol2_L
	movs r1,#0x00					;volume left
	mlane r2,r0,r1,r2
vol2_R
	movs r1,#0x00					;volume right
	mlane r3,r0,r1,r3


	add r10,r10,#0x20
	ldrb r0,[r10,r7,lsr#27]			;Channel 3
	add r7,r7,r7,lsl#16
	ldrb r1,[r10,r7,lsr#27]
	add r7,r7,r7,lsl#16
	orr r0,r1,r0,lsl#16
vol3_L
	movs r1,#0x00					;volume left
	mlane r2,r0,r1,r2
vol3_R
	movs r1,#0x00					;volume right
	mlane r3,r0,r1,r3


	add r10,r10,#0x20
	ldrb r0,[r10,r8,lsr#27]			;Channel 4
	add r8,r8,r8,lsl#16
	ldrb r1,[r10,r8,lsr#27]
	add r8,r8,r8,lsl#16
	orr r0,r1,r0,lsl#16
vol4_L
	movs r1,#0x00					;volume left
	mlane r2,r0,r1,r2
vol4_R
	movs r1,#0x00					;volume right
	mlane r3,r0,r1,r3


	add r10,r10,#0x20
	ldrb r0,[r10,r9,lsr#27]			;Channel 5
	add r9,r9,r9,lsl#16
	ldrb r1,[r10,r9,lsr#27]
	add r9,r9,r9,lsl#16
	orr r0,r1,r0,lsl#16
vol5_L
	movs r1,#0x00					;volume left
	mlane r2,r0,r1,r2
vol5_R
	movs r1,#0x00					;volume right
	mlane r3,r0,r1,r3


	sub r10,r10,#0xA0

	bic r2,r2,#0xff
	orr r2,r2,#0x80
	eor r2,r2,r2,ror#24
	strh r2,[r11],#2

	bic r3,r3,#0xff
	orr r3,r3,#0x80
	eor r3,r3,r3,ror#24
	strh r3,[r12],#2

	cmp r11,lr
	bne pcmmixloop

	ldr pc,[sp],#4
;----------------------------------------------------------------------------

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
Sound_reset_
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r7,lr}
	mov r1,#REG_BASE

;	ldrh r0,[r1,#REG_SGBIAS]
;	bic r0,r0,#0xc000				;just change bits we know about.
;	orr r0,r0,#0x8000				;PWM 7-bit 131.072kHz
;	strh r0,[r1,#REG_SGBIAS]

	ldr r2,soundmode				;if r2=0, no sound.
	cmp r2,#1
	ldr r3,=psg_write_ptr
	adrmi r0,PSG_W_OFF
	adrpl r0,PSG_W
	str r0,[r3],#4
	str r0,[r3]

	movmi r0,#0
	ldreq r0,=0x0b0a0077			;stop all channels, output ratio=full range.  use directsound A, timer 0
	ldrhi r0,=0x9a0c0077			;stop all channels, output ratio=1/4 range for noise.  use directsound A&B, timer 0
	str r0,[r1,#REG_SGCNT_L]

	movpl r0,#0x80
	strh r0,[r1,#REG_SGCNT_X]		;sound master enable

	mov r0,#0x08
	strh r0,[r1,#REG_SG1CNT_L]		;square1 sweep off

									;square1 & 2 reset
	strh r1,[r1,#REG_SG1CNT_H]		;set volume
	strh r1,[r1,#REG_SG2CNT_L]		;set volume

									;triangle reset
	mov r0,#0x0040					;write to waveform bank 0
	strh r0,[r1,#REG_SG3CNT_L]
	adr r6,trianglewav				;init triangle waveform
	ldmia r6,{r2-r5}
	add r7,r1,#REG_SGWR0_L
	stmia r7,{r2-r5}
	mov r0,#0x00000080
	str r0,[r1,#REG_SG3CNT_L]		;sound3 enable, mute, write bank 1
	mov r0,#0x8000
	strh r0,[r1,#REG_SG3CNT_X]		;sound3 init

									;Mixer channels
	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop, Left channel
	strh r1,[r1,#REG_DM2CNT_H]		;DMA2 stop, Right channel
	add r0,r1,#REG_FIFO_A_L			;DMA1 destination..
	str r0,[r1,#REG_DM1DAD]
	add r0,r1,#REG_FIFO_B_L			;DMA2 destination..
	str r0,[r1,#REG_DM2DAD]
	ldr r0,pcmptr0
	str r0,[r1,#REG_DM1SAD]			;DMA1 src=..
	add r0,r0,#PCMWAVSIZE*2
	str r0,[r1,#REG_DM2SAD]			;DMA2 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 start
	strh r0,[r1,#REG_DM2CNT_H]		;DMA2 start


	add r1,r1,#REG_TM0D				;timer 0 controls sample rate:
	mov r0,#0
	str r0,[r1],#4					;stop timer 0
	ldr r3,mixrate					; 924=Low, 532=High.
	mov r2,#0x10000					;frequency = 0
;	subhi r0,r2,#0x200				;frequency = 0x1000000/0x200 = 0x8000 = 32768Hz
;	subhi r0,r2,#532				;frequency = 0x1000000/532   = 0x7B30 = 31536.12Hz
;	subhi r0,r2,#924				;frequency = 0x1000000/924   = 0x46ED = 18157.16Hz
;	subhi r0,r2,#0x400				;frequency = 0x1000000/0x400 = 0x4000 = 16384Hz
	subhi r0,r2,r3					;frequency = 0x1000000/r3 Hz
	orrpl r0,r0,#0x800000			;timer 0 on
	strpl r0,[r1,#-4]

	sub r0,r2,#64					;timer 1 counts samples played:
	str r0,[r1],#2					;disable timer 1 before enabling it again.
	moveq r0,#0xc4					;enable+irq+count up
	streqh r0,[r1]

	ldr r5,=FREQTBL					;Destination
	ldr r7,soundmode				;if r2=0, no sound.
	cmp r7,#1
	bne frq1end
	ldr r2,=2400					;0x10000000/111860
	mov r4,#4096
	mov r1,#2048
frqloop
	mul r0,r2,r4
	subs r0,r1,r0,lsr#12
	movmi r0,#0
	subs r4,r4,#2
	strh r0,[r5,r4]
	bhi frqloop
frq1end

	cmp r7,#2
	bne frq2end
	mov r4,#8192
;	ldr r6,=0x6D40C					;(3580000/32768)*4096
;	ldr r6,=0x71854					;(3580000/31536)*4096
;	ldr r6,=0xC52AD					;(3580000/18157)*4096
;	ldr r6,=0xDA818					;(3580000/16384)*4096
	ldr r6,freqconv					;(3580000/mixrate)*4096
frqloop2							;(pce/gba)*4096
	mov r0,r6
	subs r1,r4,#2
	moveq r1,#8192
	swi 0x060000					;BIOS Div, r0/r1.
	subs r4,r4,#2
	strh r0,[r5,r4]
	bhi frqloop2
frq2end


	adrl r0,SoundVariables
	mov r1,#0
	mov r2,#24						;96/4=24
	bl memset_						;clear variables

	ldmfd sp!,{r3-r7,lr}
	bx lr

trianglewav				;Remember this is 4-bit
	DCB 0x76,0x54,0x32,0x10,0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF,0xFE,0xDC,0xBA,0x98
;----------------------------------------------------------------------------
timer1interrupt
;----------------------------------------------------------------------------

	mov r1,#REG_BASE
	add r2,r1,#REG_TM0D
	strh r1,[r2,#2]					;timer0 disable

	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop
	ldr r0,pcmptr0
	str r0,[r1,#REG_DM1SAD]			;DMA1 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 go

	mov r0,#0x80					;timer0 enable
	strh r0,[r2,#2]

	mov pc,lr

;----------------------------------------------------------------------------
Vbl_Sound_1
;----------------------------------------------------------------------------
	ldr r0,soundmode				;if r2=0, no sound.
	cmp r0,#2
	movne pc,lr


	mov r1,#REG_BASE
	strh r1,[r1,#REG_DM1CNT_H]		;DMA1 stop
	strh r1,[r1,#REG_DM2CNT_H]		;DMA2 stop
	ldr r0,pcmptr0
	str r0,[r1,#REG_DM1SAD]			;DMA1 src=..
	add r0,r0,#PCMWAVSIZE*2
	str r0,[r1,#REG_DM2SAD]			;DMA2 src=..
	ldr r0,=0xB640					;noIRQ fifo 32bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA1 go
	strh r0,[r1,#REG_DM2CNT_H]		;DMA2 go

	mov pc,lr
;----------------------------------------------------------------------------
Vbl_Sound_2
;----------------------------------------------------------------------------
	;update DMA buffer for PCM
	ldr r0,soundmode				;if r2=0, no sound.
	cmp r0,#2
	movne pc,lr

	stmfd sp!,{r3-r12,lr}
PSGMixer
	ldr r0,pcmptr0
	ldr r1,pcmptr1
	str r1,pcmptr0
	str r0,pcmptr1

	ldr r2,=0xE3B01000		;movs r1,#xx
;--------------------------
	ldrb r1,ch0balance
	ldrb r0,ch0control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldr r0,=vol0_L
	str r4,[r0],#8
	str r5,[r0]

	ldrb r1,ch1balance
	ldrb r0,ch1control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldr r0,=vol1_L
	str r4,[r0],#8
	str r5,[r0]

	ldrb r1,ch2balance
	ldrb r0,ch2control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldr r0,=vol2_L
	str r4,[r0],#8
	str r5,[r0]

	ldrb r1,ch3balance
	ldrb r0,ch3control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldr r0,=vol3_L
	str r4,[r0],#8
	str r5,[r0]

	ldrb r1,ch4balance
	ldrb r0,ch4control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldrb r0,noisectrl4
	tst r0,#0x80
	bicne r4,r4,#0xFF
	bicne r5,r5,#0xFF
	ldr r0,=vol4_L
	str r4,[r0],#8
	str r5,[r0]

	ldrb r1,ch5balance
	ldrb r0,ch5control
	bl getvolumeDS		;volume in r5, Z set if volume > 0.
	ldrb r0,noisectrl5
	tst r0,#0x80
	bicne r4,r4,#0xFF
	bicne r5,r5,#0xFF
	ldr r0,=vol5_L
	str r4,[r0],#8
	str r5,[r0]

	ldr r11,=FREQTBL
	adrl r0,pcm0currentaddr			;counters
	ldmia r0,{r4-r9}
;--------------------------
	ldr r10,ch0freq
	mov r4,r4,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r4,r0,r4,lsl#16
;--------------------------
	ldr r10,ch1freq
	mov r5,r5,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r5,r0,r5,lsl#16
;--------------------------
	ldr r10,ch2freq
	mov r6,r6,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r6,r0,r6,lsl#16
;--------------------------
	ldr r10,ch3freq
	mov r7,r7,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r7,r0,r7,lsl#16
;--------------------------
	ldr r10,ch4freq
	mov r8,r8,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r8,r0,r8,lsl#16
;--------------------------
	ldr r10,ch5freq
	mov r9,r9,lsr#16
	add r10,r10,r10
	ldrh r0,[r11,r10]
	orr r9,r0,r9,lsl#16

	ldr r10,=ch0waveform			;r10 = PCE wavebuffer
	ldr r11,pcmptr0					;r11 = GBA outbuffer
	add r12,r11,#PCMWAVSIZE*2
	ldr r0,mixlength
	adr lr,%f0
	str lr,[sp,#-4]!
	add lr,r11,r0
;	mov r11,r11						;no$gba break
	b pcmmix
0
;	mov r11,r11						;no$gba break
	adrl r0,pcm0currentaddr			;counters
	stmia r0,{r4-r9}

	ldmfd sp!,{r3-r12,pc}
;----------------------------------------------------------------------------
getvolumeDS
	and r5,r0,#0xc0
	cmp r5,#0x80			;should channel be played?

	and r0,r0,#0x1f			;channel master
	ldrb r6,globalbalance

	and r5,r1,#0xf			;channel right
	and r4,r6,#0xf			;main right
	mul r5,r4,r5
	mul r5,r0,r5

	mov r1,r1,lsr#4			;channel left
	mov r6,r6,lsr#4			;main left
	mul r4,r6,r1
	mul r4,r0,r4

;	mov r6,#103				;Maybe boost?
	mov r6,#126				;Boost.
	mul r4,r6,r4
	mul r5,r6,r5
	movne r4,#0
	movne r5,#0
	orr r4,r2,r4,lsr#12			;0 <= r4 <= 0xAF
	orr r5,r2,r5,lsr#12			;0 <= r5 <= 0xAF
	mov pc,lr
;----------------------------------------------------------------------------
getvolume
	and r5,r0,#0xc0
	cmp r5,#0x80			;should channel be played?
	and r5,r1,#0xf			;channel right
	add r1,r5,r1,lsr#4		;channel left
	add r1,r1,r1,lsr#4		;add upper bit
	orr r1,r1,r1,lsl#5
	and r0,r0,#0x1f			;channel master
	orr r0,r0,r0,lsl#5
	mul r5,r0,r1
	mov r5,r5,lsr#12			;0 <= r5 <= 0xff
	movne r5,#0
	mov pc,lr
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
PSG_R
	ldrb r0,iobuffer
	mov pc,lr
;----------------------------------------------------------------------------
PSG_W_OFF
	strb r0,iobuffer
	mov pc,lr
;----------------------------------------------------------------------------
PSG_W
	strb r0,iobuffer
	and r2,addy,#0xf
	ldr pc,[pc,r2,lsl#2]
;----------------------------------------------------------------------------
	DCD 0
PSG_W_table
	DCD _0800W
	DCD _0801W
	DCD _0802W
	DCD _0803W
	DCD _0804W
	DCD _0805W
	DCD _0806W
	DCD _0807W
	DCD _0808W
	DCD _0809W
	DCD void
	DCD void
	DCD void
	DCD void
	DCD void
	DCD void
;----------------------------------------------------------------------------
_0800W
;----------------------------------------------------------------------------
	and r0,r0,#0x7
	strb r0,psgchannel
	mov pc,lr
;----------------------------------------------------------------------------
_0801W;		Main Volume
;----------------------------------------------------------------------------
	strb r0,globalbalance
	mov pc,lr
;----------------------------------------------------------------------------
_0802W;		Frequency byte 0
;----------------------------------------------------------------------------
	adrl r2,ch0freq
	ldrb r1,psgchannel
	strb r0,[r2,r1,lsl#2]
	mov pc,lr
;----------------------------------------------------------------------------
_0803W;		Frequency byte 1
;----------------------------------------------------------------------------
	and r0,r0,#0xF
	adrl r2,ch0freq+1
	ldrb r1,psgchannel
	strb r0,[r2,r1,lsl#2]
	mov pc,lr
;----------------------------------------------------------------------------
_0804W;		Channel Enable, DDA & Volume
;----------------------------------------------------------------------------
	adr r2,ch0control
	ldrb r1,psgchannel
	strb r0,[r2,r1]
	tst r0,#0x40
	mov r0,#0
	adrne r2,ch0waveindx
	strneb r0,[r2,r1]
	mov pc,lr
;----------------------------------------------------------------------------
_0805W;		Channel Balance
;----------------------------------------------------------------------------
	adr r2,ch0balance
	ldrb r1,psgchannel
	strb r0,[r2,r1]
	mov pc,lr
;----------------------------------------------------------------------------
_0806W;		Waveform Data
;----------------------------------------------------------------------------
	ldrb r1,psgchannel
	cmp r1,#2
	streqb r1,ch3change
	ldr r2,=ch0waveform
	add r2,r2,r1,lsl#5
	adr addy,ch0waveindx
	ldrb r1,[addy,r1]!
	and r0,r0,#0x1f
	strb r0,[r2,r1,lsr#3]
	add r1,r1,#8
	strb r1,[addy]
	mov pc,lr
;----------------------------------------------------------------------------
_0807W;		Noise enable and frequency
;----------------------------------------------------------------------------
	ldrb r1,psgchannel
	cmp r1,#4
	streqb r0,noisectrl4
	cmp r1,#5
	streqb r0,noisectrl5
	mov pc,lr
;----------------------------------------------------------------------------
_0808W;		LFO frequency
;----------------------------------------------------------------------------
	strb r0,lfofreq
	mov pc,lr
;----------------------------------------------------------------------------
_0809W;		LFO trigger and control
;----------------------------------------------------------------------------
	strb r0,lfoctrl
	mov pc,lr
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
updatesound
;----------------------------------------------------------------------------
	ldrb r0,soundmode		;OFF/GB/DS
	cmp r0,#1
	movmi pc,lr			;movmi?
	stmfd sp!,{r3-r9,lr}
	mov r9,#REG_BASE
	bhi updatesoundDS

	ldrb r0,globalbalance
	mov r1,#0xff00
	orr r1,r1,r0,lsr#1
	strh r1,[r9,#REG_SGCNT_L]	;main volume.

	ldr r8,=FREQTBL
;-----------------------------
	ldrb r1,ch0balance
	ldrb r0,ch0control
	bl getvolume		;volume in r5, Z set if volume > 0.
	mov r5,r5,lsr#4			;0 <= r5 <= 0xf

	mov r0,r5,lsl#12
	orr r0,r0,#0x80			;waveform 50/50
	strh r0,[r9,#REG_SG1CNT_H]	;set channel volume

	ldr r0,ch0freq
	bic r0,r0,#1
	ldrh r0,[r8,r0]		;freq lookup
	orr r0,r0,#0x8000		;init

	strh r0,[r9,#REG_SG1CNT_X]	;set freq

;-----------------------------
	ldrb r1,ch1balance
	ldrb r0,ch1control
	bl getvolume		;volume in r5, Z set if volume > 0.
	mov r5,r5,lsr#4			;0 <= r5 <= 0xf

	mov r0,r5,lsl#12
	orr r0,r0,#0x80			;waveform 50/50
	strh r0,[r9,#REG_SG2CNT_L]	;set channel volume

	ldr r0,ch1freq
	bic r0,r0,#1
	ldrh r0,[r8,r0]		;freq lookup
	orr r0,r0,#0x8000		;init

	strh r0,[r9,#REG_SG2CNT_H]	;set freq

;-----------------------------
	ldrb r0,ch3change
	cmp r0,#0
	beq nowaveupdate
	mov r0,#0x0040			;write to waveform bank 0
	strh r0,[r9,#REG_SG3CNT_L]
	ldr r6,=ch0waveform+2*32		;init triangle waveform
	add r7,r9,#REG_SGWR0_L

	ldr r0,=0x0f0f0f0f
	ldr r4,=0x00ff00ff
	ldr r5,=0x0000ffff
	mov r1,#4
waveloop
	ldmia r6!,{r2,r3}
	and r2,r0,r2,lsr#1
	orr r2,r2,r2,lsr#4
	and r2,r4,r2
	orr r2,r2,r2,lsr#8
	and r2,r5,r2

	and r3,r0,r3,lsr#1
	orr r3,r3,r3,lsr#4
	and r3,r4,r3
	orr r3,r3,r3,lsr#8
	orr r2,r2,r3,lsl#16
	str r2,[r7],#4
	subs r1,r1,#1
	bne waveloop

	mov r0,#0x00000080
	str r0,[r9,#REG_SG3CNT_L]		;sound3 enable, mute, write bank 1
	mov r0,#0x8000
	strh r0,[r9,#REG_SG3CNT_X]		;sound3 init
	strb r0,ch3change
nowaveupdate

	ldr r0,ch2freq
	bic r0,r0,#1
	ldrh r0,[r8,r0]			;freq lookup

	strh r0,[r9,#REG_SG3CNT_X]	;set freq

	ldrb r1,ch2balance
	ldrb r0,ch2control
	bl getvolume			;volume in r5, Z set if volume > 0.
	mov r5,r5,lsr#4			;0 <= r5 <= 0xf

	adr r2,trivolume
	ldrb r5,[r2,r5]
	mov r0,r5,lsl#8
	strh r0,[r9,#REG_SG3CNT_H]	;set channel volume

;-----------------------------
	ldrb r1,ch3balance
	ldrb r0,ch3control
	bl getvolume			;volume in r5, Z set if volume > 0.

	ldr r7,pcmptr0
	add r4,r7,#32
	ldr r3,=ch0waveform+3*32
	mov r1,#64
pcm1
	ldrb r0,[r3],#1
	mul r0,r5,r0
	rsb r0,r1,r0,lsr#6		;now it's -64->64?
	strb r0,[r7],#1
	strb r0,[r7,#31]
	cmp r7,r4
	bne pcm1

	ldr r1,=307167
	ldr r0,ch3freq
	mul r0,r1,r0
	mov r0,r0,lsr#16
	cmp r5,#0
	moveq r0,r5
	cmp r0,#20
	movmi r0,#0
	movmi r2,#0
	movpl r2,#0x80			;timer 0 on
	mvnpl r0,r0
	add r1,r9,#REG_TM0D		;timer 0 controls sample rate:
	strh r2,[r1,#2]
	strh r0,[r1]

	mov r0,#-64				;timer 1 counts samples played:
	strh r0,[r1,#4]
;-----------------------------
donoise1
	ldrb r4,noisectrl4
	tst r4,#0x80
	beq donoise2

	ldrb r1,ch4balance
	ldrb r0,ch4control
	bl getvolume			;volume in r5, Z set if volume > 0.
	movs r5,r5,lsr#4		;0 <= r5 <= 0xf
	beq donoise2

	mov r0,r5,lsl#12
	strh r0,[r9,#REG_SG4CNT_L]	;set channel volume
	
	and r1,r4,#0x1f
	adr r2,noisefreqs
	ldrb r0,[r2,r1,lsr#1]
	orr r0,r0,#0x8000
	strh r0,[r9,#REG_SG4CNT_H]	;set freq

	ldmfd sp!,{r3-r9,pc}
;-----------------------------
donoise2
	ldrb r4,noisectrl5
	tst r4,#0x80
	moveq r0,#0
	beq nonoise

	ldrb r1,ch5balance
	ldrb r0,ch5control
	bl getvolume		;volume in r5, Z set if volume > 0.
	mov r5,r5,lsr#4			;0 <= r5 <= 0xf

	mov r0,r5,lsl#12
nonoise	strh r0,[r9,#REG_SG4CNT_L]	;set channel volume
	
	and r1,r4,#0x1f
	adr r2,noisefreqs
	ldrb r0,[r2,r1,lsr#1]
	orr r0,r0,#0x8000
	strh r0,[r9,#REG_SG4CNT_H]	;set freq

	ldmfd sp!,{r3-r9,pc}
;----------------------------------------------------------------------------
updatesoundDS
;----------------------------------------------------------------------------
	ldrb r0,globalbalance
	mov r1,#0x8800				;enable noise
	orr r1,r1,r0,lsr#1
	strh r1,[r9,#REG_SGCNT_L]	;main volume.

	b donoise1
;	ldmfd sp!,{r3-r9,pc}
;----------------------------------------------------------------------------

trivolume
	DCB 0x00,0x00,0x60,0x60,0x60,0x40,0x40,0x40
	DCB 0x40,0x80,0x80,0x80,0x80,0x20,0x20,0x20
noisefreqs
 DCB 2,2,2,3
 DCB 3,20,22,36
 DCB 37,39,53,55
 DCB 69,70,87,103

;----------------------------------------------------------------------------
SoundVariables
psgchannel	DCB 0		;channel select
globalbalance	DCB 0		;
noisectrl4	DCB 0		;noise control ch4
noisectrl5	DCB 0		;noise control ch5
lfofreq		DCB 0		;LFO frequency
lfoctrl		DCB 0		;LFO control
ch3change	DCB 0
		% 1
ch0control	DCB 0
ch1control	DCB 0
ch2control	DCB 0
ch3control	DCB 0
ch4control	DCB 0
ch5control	DCB 0
ch6control	DCB 0		;dummy
ch7control	DCB 0		;dummy

ch0balance	DCB 0
ch1balance	DCB 0
ch2balance	DCB 0
ch3balance	DCB 0
ch4balance	DCB 0
ch5balance	DCB 0
ch6balance	DCB 0		;dummy
ch7balance	DCB 0		;dummy

ch0waveindx	DCB 0
ch1waveindx	DCB 0
ch2waveindx	DCB 0
ch3waveindx	DCB 0
ch4waveindx	DCB 0
ch5waveindx	DCB 0
ch6waveindx	DCB 0		;dummy
ch7waveindx	DCB 0		;dummy

ch0freq		DCD 0
ch1freq 	DCD 0
ch2freq 	DCD 0
ch3freq 	DCD 0
ch4freq 	DCD 0
ch5freq 	DCD 0
ch6freq 	DCD 0		;dummy
ch7freq 	DCD 0		;dummy

pcm0currentaddr	DCD 0		;current addr
pcm1currentaddr	DCD 0		;current addr
pcm2currentaddr	DCD 0		;current addr
pcm3currentaddr	DCD 0		;current addr
pcm4currentaddr	DCD 0		;current addr
pcm5currentaddr	DCD 0		;current addr
pcm6currentaddr	DCD 0		;current addr
pcm7currentaddr	DCD 0		;current addr



soundmode	DCD 0		;soundmode (OFF/GB/DS)
mixrate		DCD 924		;mixrate (532=high, 924=low)
mixlength	DCD 304		;mixlength (528=high, 304=low)
freqconv	DCD 0xC52AD	;Frequency conversion (0x71854=high, 0xC52AD=low) (3580000/mixrate)*4096

pcmptr0 DCD PCMWAV
pcmptr1 DCD PCMWAV+PCMWAVSIZE

;----------------------------------------------------------------------------
	END

