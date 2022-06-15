PSR_N EQU 0x80000000	;ARM flags
PSR_Z EQU 0x40000000
PSR_C EQU 0x20000000
PSR_V EQU 0x10000000

C EQU 2_00000001	;HuC6280 flags
Z EQU 2_00000010
I EQU 2_00000100
D EQU 2_00001000
B EQU 2_00010000
;T EQU 2_00100000
V EQU 2_01000000
N EQU 2_10000000

	MACRO		;translate pce_pc from HuC6280 PC to rom offset
	encodePC
	and r1,pce_pc,#0xe000
	adr r2,memmap_tbl
	ldr r0,[r2,r1,lsr#11]
	str r0,lastbank
	add pce_pc,pce_pc,r0
	MEND

	MACRO		;pack HuC6280 flags into r0
	encodeP $extra
	and r0,cycles,#CYC_D+CYC_I+CYC_C+CYC_V
	tst pce_nz,#PSR_N
	orrne r0,r0,#N				;N
	tst pce_nz,#0xff
	orreq r0,r0,#Z				;Z
	orr r0,r0,#$extra			;B...
	MEND

	MACRO		;unpack HuC6280 flags from r0
	decodePF
	bic cycles,cycles,#CYC_D+CYC_I+CYC_C+CYC_V
	and r1,r0,#D+I+C+V
	orr cycles,cycles,r1		;DICV
	bic pce_nz,r0,#0xFD			;r0 is signed
	eor pce_nz,pce_nz,#Z
	MEND

	MACRO
	fetch $count
	subs cycles,cycles,#$count*3*CYCLE
	ldrplb r0,[pce_pc],#1
	ldrpl pc,[pce_optbl,r0,lsl#2]
	ldr pc,nexttimeout
	MEND

	MACRO
	fetch_c $count				;same as fetch except it adds the Carry (bit 0) also.
	sbcs cycles,cycles,#$count*3*CYCLE
	ldrplb r0,[pce_pc],#1
	ldrpl pc,[pce_optbl,r0,lsl#2]
	ldr pc,nexttimeout
	MEND

	MACRO
	clearcycles
	and cycles,cycles,#CYC_MASK		;Save CPU bits
	MEND

	MACRO
	readmemabs
	and r1,addy,#0xe000
	adr lr,%F0
	ldr pc,[pce_rmem,r1,lsr#11]	;in: addy,r1=addy&0xe000
0				;out: r0=val (bits 8-31=0 (LSR,ROR,INC,DEC,ASL)), addy preserved for RMW instructions
	MEND

	MACRO
	readmemzp
	ldrb r0,[pce_zpage,addy]
	MEND

	MACRO
	readmemzpi
	ldrb r0,[pce_zpage,addy,lsr#24]
	MEND

	MACRO
	readmemzps
	ldrsb pce_nz,[pce_zpage,addy]
	MEND

	MACRO
	readmemimm
	ldrb r0,[pce_pc],#1
	MEND

	MACRO
	readmemimms
	ldrsb pce_nz,[pce_pc],#1
	MEND

	MACRO
	readmem
	[ _type = _ABS
		readmemabs
	]
	[ _type = _ZP
		readmemzp
	]
	[ _type = _ZPI
		readmemzpi
	]
	[ _type = _IMM
		readmemimm
	]
	MEND

	MACRO
	readmems
	[ _type = _ABS
		readmemabs
		orr pce_nz,r0,r0,lsl#24
	]
	[ _type = _ZP
		readmemzps
	]
	[ _type = _IMM
		readmemimms
	]
	MEND


	MACRO
	writememabs
	and r1,addy,#0xe000
	adr r2,writemem_tbl
	adr lr,%F0
	ldr pc,[r2,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?),r1=addy&0xe000(for CDRAM_W)
0				;out: r0,r1,r2,addy=?
	MEND

	MACRO
	writememzp
	strb r0,[pce_zpage,addy]
	MEND

	MACRO
	writememzpi
	strb r0,[pce_zpage,addy,lsr#24]
	MEND

	MACRO
	writemem
	[ _type = _ABS
		writememabs
	]
	[ _type = _ZP
		writememzp
	]
	[ _type = _ZPI
		writememzpi
	]
	MEND
;----------------------------------------------------------------------------

	MACRO
	push16		;push r0
	mov r1,r0,lsr#8
	ldr r2,pce_s
	strb r1,[r2],#-1
	orr r2,r2,#0x100
	strb r0,[r2],#-1
	strb r2,pce_s
	MEND		;r1,r2=?

	MACRO
	push8 $x
	ldr r2,pce_s
	strb $x,[r2],#-1
	strb r2,pce_s
	MEND		;r2=?

	MACRO
	pop16		;pop pce_pc
	ldrb r2,pce_s
	add r2,r2,#2
	strb r2,pce_s
	ldr r2,pce_s
	ldrb r0,[r2],#-1
	orr r2,r2,#0x100
	ldrb pce_pc,[r2]
	orr pce_pc,pce_pc,r0,lsl#8
	MEND		;r0,r1=?

	MACRO
	pop8 $x
	ldrb r2,pce_s
	add r2,r2,#1
	strb r2,pce_s
	orr r2,r2,#0x100
	ldrsb $x,[r2,pce_zpage]		;signed for PLA, PLX & PLY
	MEND	;r2=?

;----------------------------------------------------------------------------
;doXXX: load addy, increment pce_pc

	GBLA _type

_IMM	EQU 1			;immediate
_ZP	EQU 2			;zero page
_ZPI	EQU 3			;zero page indexed
_ABS	EQU 4			;absolute

	MACRO
	doABS				;absolute               $nnnn
_type	SETA      _ABS
	ldrb addy,[pce_pc],#1
	ldrb r0,[pce_pc],#1
	orr addy,addy,r0,lsl#8
	MEND

	MACRO
	doAIX				;absolute indexed X     $nnnn,X
_type	SETA      _ABS
	ldrb addy,[pce_pc],#1
	ldrb r0,[pce_pc],#1
	orr addy,addy,r0,lsl#8
	add addy,addy,pce_x,lsr#24
;	bic addy,addy,#0xff0000
	MEND

	MACRO
	doAIY				;absolute indexed Y     $nnnn,Y
_type	SETA      _ABS
	ldrb addy,[pce_pc],#1
	ldrb r0,[pce_pc],#1
	add addy,addy,r0,lsl#8
	add addy,addy,pce_y,lsr#24
;	bic addy,addy,#0xff0000
	MEND

	MACRO
	doIMM				;immediate              #$nn
_type	SETA      _IMM
	MEND

	MACRO
	doIIX				;indexed indirect X     ($nn,X)
_type	SETA      _ABS
	ldrb r0,[pce_pc],#1
	add r0,pce_x,r0,lsl#24
	ldrb addy,[pce_zpage,r0,lsr#24]
	add r0,r0,#0x01000000
	ldrb r1,[pce_zpage,r0,lsr#24]
	orr addy,addy,r1,lsl#8
	MEND

	MACRO
	doIIY				;indirect indexed Y     ($nn),Y
_type	SETA      _ABS
	ldrb r0,[pce_pc],#1
	ldrb addy,[r0,pce_zpage]!
	ldrb r1,[r0,#1]
	add addy,addy,r1,lsl#8
	add addy,addy,pce_y,lsr#24
;	bic addy,addy,#0xff0000
	MEND

	MACRO
	doZPI				;Zeropage indirect     ($nn)
_type	SETA      _ABS
	ldrb r0,[pce_pc],#1
	ldrb addy,[r0,pce_zpage]!
	ldrb r1,[r0,#1]
	orr addy,addy,r1,lsl#8
	MEND

	MACRO
	doZ				;zero page              $nn
_type	SETA      _ZP
	ldrb addy,[pce_pc],#1
	MEND

	MACRO
	doZ2				;zero page              $nn
_type	SETA      _ZP
	ldrb addy,[pce_pc],#2		;ugly thing for bbr/bbs
	MEND

	MACRO
	doZIX				;zero page indexed X    $nn,X
_type	SETA      _ZP
	ldrb addy,[pce_pc],#1
	add addy,addy,pce_x,lsr#24
	and addy,addy,#0xff
	MEND

	MACRO
	doZIXf				;zero page indexed X    $nn,X
_type	SETA      _ZPI
	ldrb addy,[pce_pc],#1
	add addy,pce_x,addy,lsl#24
	MEND

	MACRO
	doZIY				;zero page indexed Y    $nn,Y
_type	SETA      _ZP
	ldrb addy,[pce_pc],#1
	add addy,addy,pce_y,lsr#24
	and addy,addy,#0xff
	MEND

	MACRO
	doZIYf				;zero page indexed Y    $nn,Y
_type	SETA      _ZPI
	ldrb addy,[pce_pc],#1
	add addy,pce_y,addy,lsl#24
	MEND

;----------------------------------------------------------------------------

	MACRO
	opADC
	readmem
	tst cycles,#CYC_D
	bne opADC_Dec

	movs r1,cycles,lsr#1		;get C
	subcs r0,r0,#0x00000100
	adcs pce_a,pce_a,r0,ror#8
	mov pce_nz,pce_a,asr#24		;NZ
	orr cycles,cycles,#CYC_C+CYC_V	;Prepare C & V
	bicvc cycles,cycles,#CYC_V	;V
	MEND

	MACRO
	opADCD
;	mov r11,r11					;No$GBA debugg! inget i Valis2 iaf.
	movs r1,cycles,lsr#1        ;get C
	and r1,r0,#0xF
	subcs r1,r1,#0x10
	mov r1,r1,ror#4
	adcs r1,r1,pce_a,lsl#4
	cmncc r1,#0x60000000
	addcs r1,r1,#0x60000000

	mov r2,pce_a,lsr#28
	adc r0,r2,r0,lsr#4
	movs r0,r0,lsl#28			;Set C
	cmncc r0,#0x60000000
	addcs r0,r0,#0x60000000
	orr pce_a,r0,r1,lsr#4

	mov pce_nz,pce_a,asr#24 	;NZ
	orr cycles,cycles,#CYC_C	;Prepare C
	MEND


	MACRO
	opADCT
	readmem
	tst cycles,#CYC_D
	bne opADCT_Dec

	ldrb r2,[pce_zpage,pce_x,lsr#24]
	mov r2,r2,lsl#24

	movs r1,cycles,lsr#1		;get C
	subcs r0,r0,#0x00000100
	adcs r2,r2,r0,ror#8
	mov pce_nz,r2,asr#24		;NZ
	orr cycles,cycles,#CYC_C+CYC_V	;Prepare C & V
	bicvc cycles,cycles,#CYC_V	;V

	mov r2,r2,lsr#24
	strb r2,[pce_zpage,pce_x,lsr#24]
	MEND

	MACRO
	opADCTD
;	mov r11,r11					;No$GBA debugg! inget i Valis2 iaf.
	ldrb r2,[pce_zpage,pce_x,lsr#24]

	movs r1,cycles,lsr#1        ;get C
	and r1,r0,#0xF
	subcs r1,r1,#0x10
	mov r1,r1,ror#4
	adcs r1,r1,r2,lsl#28
	cmncc r1,#0x60000000
	addcs r1,r1,#0x60000000

	mov r2,r2,lsr#4
	adc r0,r2,r0,lsr#4
	movs r0,r0,lsl#28		;Set C
	cmncc r0,#0x60000000
	addcs r0,r0,#0x60000000
	orr r2,r0,r1,lsr#4

	mov pce_nz,r2,asr#24 ;NZ
	orr cycles,cycles,#CYC_C	;Prepare C

	strb pce_nz,[pce_zpage,pce_x,lsr#24]
	MEND


	MACRO
	opAND
	readmem
	and pce_a,pce_a,r0,lsl#24
	mov pce_nz,pce_a,asr#24		;NZ
	MEND

	MACRO
	opANDT
	readmem
	ldrb r2,[pce_zpage,pce_x,lsr#24]
	and r2,r2,r0
	orr pce_nz,r2,r2,lsl#24		;NZ
	strb r2,[pce_zpage,pce_x,lsr#24]
	MEND


	MACRO
	opASL
	readmem
	 add r0,r0,r0
	 orrs pce_nz,r0,r0,lsl#24	;NZ
	 orr cycles,cycles,#CYC_C	;Prepare C
	writemem
	MEND


	MACRO
	opBBR $x
	doZ2
	readmemzp
	tst r0,#1<<$x
	bne nobbranch
	ldreqsb r0,[pce_pc,#-1]
	addeq pce_pc,pce_pc,r0
	fetch 8
	MEND

	MACRO
	opBBRx $x
	doZ2
	readmemzp
	tst r0,#1<<$x
	bne nobbranch
	ldreqsb r0,[pce_pc,#-1]
	addeq pce_pc,pce_pc,r0
	cmp r0,#-3						;Ninja Spirit/Impossamole speed hack.
	andeq cycles,cycles,#CYC_MASK	;Save CPU bits
	fetch 8
	MEND

	MACRO
	opBBS $x
	doZ2
	readmemzp
	tst r0,#1<<$x
	beq nobbranch
	ldrnesb r0,[pce_pc,#-1]
	addne pce_pc,pce_pc,r0
	fetch 8
	MEND

	MACRO
	opBBSx $x
	doZ2
	readmemzp
	tst r0,#1<<$x
	beq nobbranch
	ldrnesb r0,[pce_pc,#-1]
	addne pce_pc,pce_pc,r0
	cmp r0,#-3						;Bloody Wolf speed hack.
	andeq cycles,cycles,#CYC_MASK	;Save CPU bits
	fetch 8
	MEND

	MACRO
	opBIT
	readmem
	bic cycles,cycles,#CYC_V	;reset V
	tst r0,#V
	orrne cycles,cycles,#CYC_V	;V
	and pce_nz,r0,pce_a,lsr#24	;Z
	orr pce_nz,pce_nz,r0,lsl#24	;N
	MEND

	MACRO
	opCOMP $x
	readmem
	subs pce_nz,$x,r0,lsl#24
	mov pce_nz,pce_nz,asr#24	;NZ
	orr cycles,cycles,#CYC_C	;Prepare C
	MEND

	MACRO
	opDEC
	readmem
	sub r0,r0,#1
	orr pce_nz,r0,r0,lsl#24		;NZ
	writemem
	MEND

	MACRO
	opEOR
	readmem
	eor pce_a,pce_a,r0,lsl#24
	mov pce_nz,pce_a,asr#24		;NZ
	MEND

	MACRO
	opEORT
	readmem
	ldrb r2,[pce_zpage,pce_x,lsr#24]
	eor r2,r2,r0
	orr pce_nz,r2,r2,lsl#24
	strb r2,[pce_zpage,pce_x,lsr#24]
	MEND


	MACRO
	opINC
	readmem
	add r0,r0,#1
	orr pce_nz,r0,r0,lsl#24		;NZ
	writemem
	MEND

	MACRO
	opLOAD $x
	readmems
	mov $x,pce_nz,lsl#24
	MEND

	MACRO
	opLSR
	[ _type = _ABS
		readmemabs
		movs r0,r0,lsr#1
		orr cycles,cycles,#CYC_C	;Prepare C
		mov pce_nz,r0				;Z, (N=0)
		writememabs
	]
	[ _type = _ZP
		ldrb pce_nz,[pce_zpage,addy]
		movs pce_nz,pce_nz,lsr#1	;Z, (N=0)
		orr cycles,cycles,#CYC_C	;Prepare C
		strb pce_nz,[pce_zpage,addy]
	]
	[ _type = _ZPI
		ldrb pce_nz,[pce_zpage,addy,lsr#24]
		movs pce_nz,pce_nz,lsr#1	;Z, (N=0)
		orr cycles,cycles,#CYC_C	;Prepare C
		strb pce_nz,[pce_zpage,addy,lsr#24]
	]
	MEND

	MACRO
	opORA
	readmem
	orr pce_a,pce_a,r0,lsl#24
	mov pce_nz,pce_a,asr#24
	MEND

	MACRO
	opORAT
	readmem
	ldrb r2,[pce_zpage,pce_x,lsr#24]
	orr r2,r2,r0
	orr pce_nz,r2,r2,lsl#24
	strb r2,[pce_zpage,pce_x,lsr#24]
	MEND

	MACRO
	opRMB $x
	doZ
	readmemzp
	bic r0,r0,#1<<$x
	writememzp
	fetch 7
	MEND

	MACRO
	opROL
	readmem
	 movs cycles,cycles,lsr#1		;get C
	 adc r0,r0,r0
	 orrs pce_nz,r0,r0,lsl#24		;NZ
	 adc cycles,cycles,cycles		;Set C
	writemem
	MEND

	MACRO
	opROR
	readmem
	 movs cycles,cycles,lsr#1		;get C
	 orrcs r0,r0,#0x100
	 movs r0,r0,lsr#1
	 orr pce_nz,r0,r0,lsl#24		;NZ
	 adc cycles,cycles,cycles		;Set C
	writemem
	MEND

	MACRO
	opSBC
	readmem
	tst cycles,#CYC_D
	bne opSBC_Dec

	movs r1,cycles,ror#1		;get C
	sbcs pce_a,pce_a,r0,lsl#24
	and pce_a,pce_a,#0xff000000
	mov pce_nz,pce_a,asr#24 	;NZ
	orr cycles,cycles,#CYC_C+CYC_V	;Prepare C & V
	bicvc cycles,cycles,#CYC_V	;V
	MEND

	MACRO
	opSBCD
	movs r1,cycles,ror#1		;get C
	mov r2,pce_a,lsl#4
	sbcs r1,r2,r0,lsl#28
	and r1,r1,#0xf0000000
	subcc r1,r1,#0x60000000

	mov r2,pce_a,lsr#28
	sbcs r0,r2,r0,lsr#4
	mov r0,r0,lsl#28
	subcc r0,r0,#0x60000000
	orr pce_a,r0,r1,lsr#4

	mov pce_nz,pce_a,asr#24 	;NZ
	orr cycles,cycles,#CYC_C	;Prepare C
	MEND

	MACRO
	opSMB $x
	doZ
	readmemzp
	orr r0,r0,#1<<$x
	writememzp
	fetch 7
	MEND

	MACRO
	opSTORE $x
	mov r0,$x,lsr#24
	writemem
	MEND

	MACRO
	opSTZ
	mov r0,#0
	writemem
	MEND

	MACRO
	opSWAP $x,$y
	eor $x,$x,$y
	eor $y,$y,$x
	eor $x,$x,$y
	MEND

	MACRO
	opTRB
	readmem
	 bic cycles,cycles,#CYC_V	;reset V
	 tst r0,#V
	 orrne cycles,cycles,#CYC_V	;V
	 bic pce_nz,r0,pce_a,lsr#24		;Z
	 orr pce_nz,pce_nz,r0,lsl#24	;N
	 bic r0,r0,pce_a,lsr#24			;result
	writemem
	MEND

	MACRO
	opTSB
	readmem
	 bic cycles,cycles,#CYC_V	;reset V
	 tst r0,#V
	 orrne cycles,cycles,#CYC_V	;V
	 orr pce_nz,r0,pce_a,lsr#24		;Z
	 orr pce_nz,pce_nz,r0,lsl#24	;N
	 orr r0,r0,pce_a,lsr#24			;result
	writemem
	MEND

	MACRO
	opTST				;needs a pce_pc++ before
	readmem
	bic cycles,cycles,#CYC_V	;reset V
	tst r0,#V
	orrne cycles,cycles,#CYC_V	;V
	and pce_nz,r0,pce_nz		;Z
	orr pce_nz,pce_nz,r0,lsl#24	;N
	MEND


	MACRO
	doTAI					;transfer alt inc
	stmfd sp!,{r3-r7,r9}

	ldrb r3,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r3,r3,r1,lsl#8		;load r3 = source
	ldrb r4,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r4,r4,r1,lsl#8		;load r4 = destination
	ldrb r5,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orrs r5,r5,r1,lsl#8		;load r5 = length
	str r9,[sp,#20]			;store r9(pce_pc) on stack again

	moveq r5,#0x10000
	mov r1,#6*3*CYCLE
	mul r1,r5,r1
	sub cycles,cycles,r1	;cycles=r8

	mov r4,r4,lsl#16
	adr r6,readmem_tbl
	adr r7,writemem_tbl

	and r1,r3,#0xe000
	ldr r6,[r6,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
	mov r9,#1
0
	mov addy,r3
	adr lr,%F1
	mov pc,r6				;in: addy,r0=val(bits 8-31=?)
1							;out: r0,r1,r2=?
	mov addy,r4,lsr#16
	and r1,addy,#0xe000
	adr lr,%F2
	ldr pc,[r7,r1,lsr#11]
2
	add r3,r3,r9
	add r4,r4,#0x00010000
	rsb r9,r9,#0
	subs r5,r5,#1
	bne %B0					;in: addy,r0=val(bits 8-31=?)
							;out: r0,r1,r2=?
	ldmfd sp!,{r3-r7,r9}
	fetch 17
	MEND


	MACRO
	doTDD					;transfer dec dec
	stmfd sp!,{r3-r7}

	ldrb r3,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r3,r3,r1,lsl#8		;load r3 = source
	ldrb r4,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r4,r4,r1,lsl#8		;load r4 = destination
	ldrb r5,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orrs r5,r5,r1,lsl#8		;load r5 = length

	moveq r5,#0x10000
	mov r1,#6*3*CYCLE
	mul r1,r5,r1
	sub cycles,cycles,r1	;cycles=r8

	mov r3,r3,lsl#16
	mov r4,r4,lsl#16
	adr r6,memmap_tbl
	adr r7,writemem_tbl
	adr lr,%F1
0
	and r1,r3,#0xe0000000
	ldr r1,[r6,r1,lsr#27]
	ldrb r0,[r1,r3,lsr#16]

	mov addy,r4,lsr#16
	and r1,addy,#0xe000
	ldr pc,[r7,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
1
	sub r3,r3,#0x10000
	sub r4,r4,#0x10000
	subs r5,r5,#1
	bne %B0

	ldmfd sp!,{r3-r7}
	fetch 17
	MEND


	MACRO
	doTIA			;transfer inc alt
	stmfd sp!,{r3-r7,r9}

	ldrb r3,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r3,r3,r1,lsl#8	;load r3 = source
	ldrb r4,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r4,r4,r1,lsl#8	;load r4 = destination
	ldrb r5,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orrs r5,r5,r1,lsl#8	;load r5 = length
	str r9,[sp,#20]		;store r9(pce_pc) on stack again

	moveq r5,#0x10000
	mov r1,#6*3*CYCLE
	mul r1,r5,r1
	sub cycles,cycles,r1	;cycles=r8

	mov r3,r3,lsl#16
	adr r6,memmap_tbl
	adr r7,writemem_tbl

	and r1,r4,#0xe000
	adr lr,%F1
	ldr r7,[r7,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
	mov r9,#1
0
	and r1,r3,#0xE0000000
	ldr r1,[r6,r1,lsr#27]	;r1=addy & 0xE0000000
	ldrb r0,[r1,r3,lsr#16]

	mov addy,r4
	and r1,r4,#0xe000		;not needed!?!
	mov pc,r7				;in: addy,r0=val(bits 8-31=?)
1							;out: r0,r1,r2,addy=?
	add r3,r3,#0x10000
	add r4,r4,r9
	rsb r9,r9,#0
	subs r5,r5,#1
	bne %B0

	ldmfd sp!,{r3-r7,r9}
	fetch 17
	MEND


	MACRO
	doTII			;Transfer Inc Inc
	stmfd sp!,{r3-r7}

	ldrb r3,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r3,r3,r1,lsl#8	;load r3 = source
	ldrb r4,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r4,r4,r1,lsl#8	;load r4 = destination
	ldrb r5,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orrs r5,r5,r1,lsl#8	;load r5 = length

	moveq r5,#0x10000
	mov r1,#6*3*CYCLE
	mul r1,r5,r1
	sub cycles,cycles,r1	;cycles=r8

	mov r3,r3,lsl#16
	mov r4,r4,lsl#16
	adr r6,memmap_tbl
	adr r7,writemem_tbl
	adr lr,%F1
0
	and r1,r3,#0xe0000000
	ldr r1,[r6,r1,lsr#27]
	ldrb r0,[r1,r3,lsr#16]

	mov addy,r4,lsr#16
	and r1,addy,#0xe000
	ldr pc,[r7,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
1
	add r3,r3,#0x10000
	add r4,r4,#0x10000
	subs r5,r5,#1
	bne %B0

	ldmfd sp!,{r3-r7}
	fetch 17
	MEND


	MACRO
	doTIN			;transfer inc none
	stmfd sp!,{r3-r7}

	ldrb r3,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r3,r3,r1,lsl#8	;load r3 = source
	ldrb r4,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orr r4,r4,r1,lsl#8	;load r4 = destination
	ldrb r5,[pce_pc],#1
	ldrb r1,[pce_pc],#1
	orrs r5,r5,r1,lsl#8	;load r5 = length

	moveq r5,#0x10000
	mov r1,#6*3*CYCLE
	mul r1,r5,r1
	sub cycles,cycles,r1	;cycles=r8

	mov r3,r3,lsl#16
	adr r6,memmap_tbl
	adr r7,writemem_tbl

	and r1,r4,#0xe000
	adr lr,%F1
	ldr r7,[r7,r1,lsr#11]	;in: addy,r0=val(bits 8-31=?)
0
	and r1,r3,#0xE0000000
	ldr r1,[r6,r1,lsr#27]
	ldrb r0,[r1,r3,lsr#16]

	mov addy,r4
	mov pc,r7		;in: addy,r0=val(bits 8-31=?)
1				;out: r0,r1,r2,addy=?
	add r3,r3,#0x10000
	subs r5,r5,#1
	bne %B0

	ldmfd sp!,{r3-r7}
	fetch 17
	MEND

;----------------------------------------------------
	END
