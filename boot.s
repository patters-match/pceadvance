	AREA rom_code, CODE, READONLY
	ENTRY

	INCLUDE equates.h

	IMPORT |Image$$RO$$Base|
	IMPORT |Image$$RO$$Limit|
	IMPORT |Image$$RW$$Base|
	IMPORT |Image$$RW$$Limit|
	IMPORT |Image$$ZI$$Base|
	IMPORT |Image$$ZI$$Limit|
 [ BUILD = "DEBUG"
	IMPORT |zzzzz$$Base|
 ]

	IMPORT C_entry	;from main.c
	IMPORT textstart

	IMPORT max_multiboot_size ;from mbclient.c

	EXPORT font
	EXPORT fontpal
;------------------------------------------------------------
 	b __main

	DCB 36,255,174,81,105,154,162,33,61,132,130,10,132,228,9,173
	DCB 17,36,139,152,192,129,127,33,163,82,190,25,147,9,206,32
	DCB 16,70,74,74,248,39,49,236,88,199,232,51,130,227,206,191
	DCB 133,244,223,148,206,75,9,193,148,86,138,192,19,114,167,252
	DCB 159,132,77,115,163,202,154,97,88,151,163,39,252,3,152,118
	DCB 35,29,199,97,3,4,174,86,191,56,132,0,64,167,14,253
	DCB 255,82,254,3,111,149,48,241,151,251,192,133,96,214,128,37
	DCB 169,99,190,3,1,78,56,226,249,162,52,255,187,62,3,68
	DCB 120,0,144,203,136,17,58,148,101,192,124,99,135,240,60,175
	DCB 214,37,228,139,56,10,172,114,33,212,248,7
	DCB "PCEAdvance  "	;title
	DCB "PCEA"			;gamecode
	DCW 0				;maker
	DCB 0x96			;fixed value
	DCB 0				;unit code
	DCB 0				;device type
	DCB 0,0,0,0,0,0,0	;unused
	DCB 0				;version
	DCB 0x6e			;complement check
	DCW 0				;unused
;----------------------------------------------------------
__main
;----------------------------------------------------------
	b %F0
	% 28			;multiboot struct. clock regs also?
0
	[ BUILD = "DEBUG"
		mov r0, #0x10	;usr mode
		msr cpsr_f, r0
	]

	ldr sp,=0x3007f00				;set System Stack
	LDR	r5,=|Image$$RO$$Limit|		;r5=pointer to IWRAM code
 [ BUILD = "DEBUG"
	ldr r1,=|zzzzz$$Base|
 |
	ldr r1,=|Image$$ZI$$Base|
 ]
	add r1,r1,r5
	sub r6,r1,#0x3000000			;r6=textstart

	adr lr,_3
	tst lr,#0x8000000
	beq _3							;running from cart?
		add r6,r6,#0x6000000		;textstart=8xxxxxx
		add r5,r5,#0x6000000		;RW code ptr=8xxxxxx

		ldr r1,=|Image$$RO$$Base|	;copy rom code to ewram
		adr r0,headcopy				; XG2 resets when 0x08000000 is accessed.
		add r3,r1,#192				; EZFA mess with the GBA header
_5		cmp r1,r3
		ldrcc r2, [r0], #4
		strcc r2, [r1], #4
		bcc _5
		add r0,r1,#0x6000000
		ldr r3,=|Image$$RO$$Limit|
_2		cmp r1,r3
		ldrcc r2, [r0], #4
		strcc r2, [r1], #4
		bcc _2
		sub pc,lr,#0x6000000	;jump to ewram copy
_3
	LDR	r1, =|Image$$RW$$Base|
	LDR	r3, =|Image$$ZI$$Base| ; Zero init base => top of initialized data
_0	CMP	r1, r3
	LDRCC	r2, [r5], #4		;copy RW code to IWRAM
	STRCC	r2, [r1], #4
	BCC	_0
	LDR	r1, =|Image$$ZI$$Limit| ; Top of zero init segment
	MOV	r2, #0
_1	CMP	r3, r1 ; Zero init
	STRCC	r2, [r3], #4
	BCC	_1


;---------------------------------------- MB test ----------
	tst lr,#0x8000000
	bne _4					;running from cart?
	ldr r0,=|Image$$RO$$Limit|
	mov r3,#0x20000			;up to 128kbyte
	add r3,r3,#0x240		;+headers (Adv(48)+NES(16)+PCE(512))
	mov r1,r0
_loop
	ldr r2,[r6],#4			;old textstart
	str r2,[r1],#4
	subs r3,r3,#4
	bne _loop
	mov r6,r0				;new textstart
_4
;---------------------------------------- MB test ----------

 [ DEBUG
	ldr r0,=PCE_RAM
	cmp r1,r0		;sanity check - make sure iwram code fits in iwram
giveup	bhi giveup
 ]
	ldr r4,=textstart	;textstart=ptr to PCE rom info
	str r6,[r4]

	ldr r6,=(END_OF_EXRAM-0x2000000)	;how much free space is left?
	ldr r4,=max_multiboot_size
	str r6,[r4]

;	ldr r0,=0x4014		;3/1 wait state, prefetch.  No difference???
;	mov r0,#0x0018		;2/1 wait state, not working on flashcarts?
	mov r0,#0x0014		;3/1 wait state
	ldr r1,=REG_WAITCNT
	strh r0,[r1]

;	ldr r0,=0x0E000020	;1 waitstate,0x0D000020=2 waitstate
;	ldr r1,=0x04000800	;EWRAM WAITCTL
;	str r0,[r1]			;2/1 waitstate

	ldr r1,=C_entry
	bx r1
;----------------------------------------------------------
headcopy
	DCD 0xEA00002E			;b main
	DCB 36,255,174,81,105,154,162,33,61,132,130,10,132,228,9,173
	DCB 17,36,139,152,192,129,127,33,163,82,190,25,147,9,206,32
	DCB 16,70,74,74,248,39,49,236,88,199,232,51,130,227,206,191
	DCB 133,244,223,148,206,75,9,193,148,86,138,192,19,114,167,252
	DCB 159,132,77,115,163,202,154,97,88,151,163,39,252,3,152,118
	DCB 35,29,199,97,3,4,174,86,191,56,132,0,64,167,14,253
	DCB 255,82,254,3,111,149,48,241,151,251,192,133,96,214,128,37
	DCB 169,99,190,3,1,78,56,226,249,162,52,255,187,62,3,68
	DCB 120,0,144,203,136,17,58,148,101,192,124,99,135,240,60,175
	DCB 214,37,228,139,56,10,172,114,33,212,248,7
	DCB "PCEAdvance  "	;title
	DCB "PCEA"			;gamecode
	DCW 0				;maker
	DCB 0x96			;fixed value
	DCB 0				;unit code
	DCB 0				;device type
	DCB 0,0,0,0,0,0,0	;unused
	DCB 0				;version
	DCB 0x6e			;complement check
	DCW 0				;unused

font
	INCBIN font.lz77
;	INCBIN font.bin
;	INCBIN fontclass.bin
;	INCBIN font-ff8wide.bin
;	INCBIN font-starfox.bin
;	INCBIN font-invaders.bin
;	INCBIN font-doom.bin
fontpal
	INCBIN fontpal.bin
	END
