	INCLUDE equates.h
	INCLUDE memory.h


	EXPORT ARCADE_R
	EXPORT ARCADE_W
	EXPORT AC00_R
	EXPORT AC10_R
	EXPORT AC20_R
	EXPORT AC30_R
	EXPORT AC00_W
	EXPORT AC10_W
	EXPORT AC20_W
	EXPORT AC30_W

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -



;	Fix Page $40-$43
;----------------------------------------------------------------------------
ARCADE_R
;----------------------------------------------------------------------------
;	mov r11,r11			;No$GBA debugg
	and r0,addy,#0xC0
	cmp r0,#0xC0
	and r0,addy,#0x0F
	ldrne pc,[pc,r0,lsl#2]
	b AC_Read2
;---------------------------------------
	DCD ACx0_R		;Memory Read
	DCD ACx0_R		;Memory Read
	DCD AC02_R		;Base Address 0-7
	DCD AC03_R		;Base Address 8-15
	DCD AC04_R		;Base Address 16-23
	DCD AC05_R		;Offset Address 0-7
	DCD AC06_R		;Offset Address 8-15
	DCD AC07_R		;Address increment 0-7
	DCD AC08_R		;Address increment 8-15
	DCD AC09_R		;Control
	DCD AC0A_R		;Unknown
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
;----------------------------------------------------------------------------
AC_Read2
;----------------------------------------------------------------------------
	ldr pc,[pc,r0,lsl#2]
	DCD 0
;---------------------------------------
	DCD ACC0_R		;Shift Register 0
	DCD ACC1_R		;Shift Register 1
	DCD ACC2_R		;Shift Register 2
	DCD ACC3_R		;Shift Register 3
	DCD ACC4_R		;Shift Amount
	DCD ACC5_R		;Unknown
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD empty_R		;
	DCD ACCE_R		;Unknown
	DCD ACCF_R		;Arcade Card Check

;----------------------------------------------------------------------------
ARCADE_W
;----------------------------------------------------------------------------
;	mov r11,r11			;No$GBA debugg
	and r1,addy,#0xC0
	cmp r1,#0xC0
	and r1,addy,#0x0F
	ldrne pc,[pc,r1,lsl#2]
	b AC_Write2
;---------------------------
ac_write_tbl
	DCD ACx0_W		;Memory Write
	DCD ACx0_W		;Memory Write
	DCD AC02_W		;Base Address 0-7
	DCD AC03_W		;Base Address 8-15
	DCD AC04_W		;Base Address 16-23
	DCD AC05_W		;Offset Address 0-7
	DCD AC06_W		;Offset Address 8-15
	DCD AC07_W		;Address increment 0-7
	DCD AC08_W		;Address increment 8-15
	DCD AC09_W		;Control
	DCD AC0A_W		;Offset addition
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;

;----------------------------------------------------------------------------
AC_Write2
;----------------------------------------------------------------------------
	ldr pc,[pc,r1,lsl#2]
	DCD 0
;---------------------------------------
	DCD ACC0_W		;Shift Register 0
	DCD ACC1_W		;Shift Register 1
	DCD ACC2_W		;Shift Register 2
	DCD ACC3_W		;Shift Register 3
	DCD ACC4_W		;Shift Amount
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;
	DCD empty_W		;

;----------------------------------------------------------------------------
AC00_R
;----------------------------------------------------------------------------
	mov r2,#0x00
	b ac00_xr
;----------------------------------------------------------------------------
AC10_R
;----------------------------------------------------------------------------
	mov r2,#0x10
	b ac00_xr
;----------------------------------------------------------------------------
AC20_R
;----------------------------------------------------------------------------
	mov r2,#0x20
	b ac00_xr
;----------------------------------------------------------------------------
AC30_R
;----------------------------------------------------------------------------
	mov r2,#0x30
	b ac00_xr
;----------------------------------------------------------------------------
ACx0_R
;----------------------------------------------------------------------------
	and r2,addy,#0x30
ac00_xr
	stmfd sp!,{r3,lr}
	adr r3,ac_baseaddress
	ldr r2,[r3,r2,lsr#2]!		;r3=base
	ldrb r1,[r3,#48]			;Control
	tst r1,#0x02				;Should we use offset?
	ldrne r0,[r3,#16]			;Offset
	addne r2,r2,r0
	bic r2,r2,#0xE0000000
	ldr r0,ACC_RAMp
	ldrb r0,[r0,r2,lsr#8]

	tst r1,#0x01				;Should we increment?
	ldmeqfd sp!,{r3,pc}
;	moveq pc,lr

	ldr r2,[r3,#32]				;Increment

	tst r1,#0x10				;Should we increment base or offset?
	ldrne r1,[r3]				;Base
	ldreq r1,[r3,#16]!			;Offset
	add r1,r1,r2
	biceq r1,r1,#0xFF000000
	str r1,[r3]
	ldmfd sp!,{r3,pc}
;	mov pc,lr
;----------------------------------------------------------------------------
AC02_R		;Base Address
;----------------------------------------------------------------------------
	ldr r1,=ac_baseaddress+1
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC03_R		;Base Address
;----------------------------------------------------------------------------
	ldr r1,=ac_baseaddress+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC04_R		;Base Address
;----------------------------------------------------------------------------
	ldr r1,=ac_baseaddress+3
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC05_R		;Offset Address
;----------------------------------------------------------------------------
	ldr r1,=ac_offsetaddress+1
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC06_R		;Offset Address
;----------------------------------------------------------------------------
	ldr r1,=ac_offsetaddress+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC07_R		;Address Increment
;----------------------------------------------------------------------------
	ldr r1,=ac_addressincrement+1
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC08_R		;Address Increment
;----------------------------------------------------------------------------
	ldr r1,=ac_addressincrement+2
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC09_R		;Control
;----------------------------------------------------------------------------
	adr r1,ac_control
	and r2,addy,#0x30
	ldrb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC0A_R		;Unknown
;----------------------------------------------------------------------------
	mov r0,#0
	mov pc,lr


;----------------------------------------------------------------------------
ACC0_R		;Shift register 0
;----------------------------------------------------------------------------
	ldrb r0,ac_shiftreg
	mov pc,lr
;----------------------------------------------------------------------------
ACC1_R		;Shift register 1
;----------------------------------------------------------------------------
	ldrb r0,ac_shiftreg+1
	mov pc,lr
;----------------------------------------------------------------------------
ACC2_R		;Shift register 2
;----------------------------------------------------------------------------
	ldrb r0,ac_shiftreg+2
	mov pc,lr
;----------------------------------------------------------------------------
ACC3_R		;Shift register 3
;----------------------------------------------------------------------------
	ldrb r0,ac_shiftreg+3
	mov pc,lr
;----------------------------------------------------------------------------
ACC4_R		;Shift amount
;----------------------------------------------------------------------------
	ldrb r0,ac_shiftbits
	mov pc,lr

;----------------------------------------------------------------------------
ACC5_R		;Unknown
;----------------------------------------------------------------------------
	ldrb r0,ac_1ac5
	mov pc,lr
;----------------------------------------------------------------------------
ACCE_R		;Unknown
;----------------------------------------------------------------------------
	mov r0,#0x10
	mov pc,lr
;----------------------------------------------------------------------------
ACCF_R		;Arcade Card check
;----------------------------------------------------------------------------
	mov r0,#0x51
	mov pc,lr



;----------------------------------------------------------------------------
AC00_W
;----------------------------------------------------------------------------
	mov addy,#0x00
	b ac00_xw
;----------------------------------------------------------------------------
AC10_W
;----------------------------------------------------------------------------
	mov addy,#0x10
	b ac00_xw
;----------------------------------------------------------------------------
AC20_W
;----------------------------------------------------------------------------
	mov addy,#0x20
	b ac00_xw
;----------------------------------------------------------------------------
AC30_W
;----------------------------------------------------------------------------
	mov addy,#0x30
	b ac00_xw
;----------------------------------------------------------------------------
ACx0_W
;----------------------------------------------------------------------------
	and addy,addy,#0x30
ac00_xw
	and r0,r0,#0xFF
	adr r2,ac_baseaddress
	ldr addy,[r2,addy,lsr#2]!
	ldrb r1,[r2,#48]			;Control
	orr r0,r0,r1,lsl#24
	tst r1,#2					;Should we use offset?
	ldrne r1,[r2,#16]			;Offset
	addne addy,addy,r1
	bic addy,addy,#0xE0000000
	ldr r1,ACC_RAMp
	eor addy,addy,#0x100
	ldrb addy,[r1,addy,lsr#8]!
	tst r1,#1
	orrne addy,r0,addy,lsl#8
	orreq addy,addy,r0,lsl#8
	bic r1,r1,#1
	strh addy,[r1]

	tst r0,#0x01000000			;Should we increment?
	moveq pc,lr

	ldr r1,[r2,#32]				;Increment

	tst r0,#0x10000000			;Should we increment base or offset?
	ldrne addy,[r2]				;Base
	ldreq addy,[r2,#16]!		;Offset
	add addy,addy,r1
	biceq addy,addy,#0xFF000000
	str addy,[r2]
	mov pc,lr
;----------------------------------------------------------------------------
AC02_W		;Base Address
;----------------------------------------------------------------------------
	ldr r1,=ac_baseaddress+1
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC03_W		;Base Address
;----------------------------------------------------------------------------
	ldr r1,=ac_baseaddress+2
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC04_W		;Base Address
;----------------------------------------------------------------------------
	adr r1,ac_baseaddress+3
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr

;----------------------------------------------------------------------------
AC05_W		;Offset Address
;----------------------------------------------------------------------------
	adr r1,ac_offsetaddress+1
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC06_W		;Offset Address
;----------------------------------------------------------------------------
	adr r1,ac_baseaddress
	and r2,addy,#0x30
	add r2,r1,r2,lsr#2
	strb r0,[r2,#16+2]		;Offset+2

	ldrb r0,[r2,#48]		;Control
	tst r0,#0x40
	ldrne r1,[r2,#16]		;Offset
	ldrne r0,[r2]			;Base
	addne r0,r1,r0
	strne r0,[r2]			;Base

	mov pc,lr

;----------------------------------------------------------------------------
AC07_W		;Address Increment
;----------------------------------------------------------------------------
	adr r1,ac_addressincrement+1
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC08_W		;Address Increment
;----------------------------------------------------------------------------
	adr r1,ac_addressincrement+2
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr

;----------------------------------------------------------------------------
AC09_W		;Control
;----------------------------------------------------------------------------
	adr r1,ac_control
	and r2,addy,#0x30
	strb r0,[r1,r2,lsr#2]
	mov pc,lr
;----------------------------------------------------------------------------
AC0A_W		;Address Addition
;----------------------------------------------------------------------------
	and r2,addy,#0x30
	ldr r1,=ac_control
	ldrb r1,[r1,r2,lsr#2]
	and r1,r1,#0x60
	cmp r1,#0x60
	movne pc,lr
	ldr r1,=ac_baseaddress
	ldr r0,[r1,r2,lsr#2]!
	ldr r2,[r1,#16]
	add r0,r0,r2
	str r0,[r1]
	mov pc,lr



;----------------------------------------------------------------------------
ACC0_W		;Shift register 0
;----------------------------------------------------------------------------
	strb r0,ac_shiftreg
	mov pc,lr
;----------------------------------------------------------------------------
ACC1_W		;Shift register 1
;----------------------------------------------------------------------------
	strb r0,ac_shiftreg+1
	mov pc,lr
;----------------------------------------------------------------------------
ACC2_W		;Shift register 2
;----------------------------------------------------------------------------
	strb r0,ac_shiftreg+2
	mov pc,lr
;----------------------------------------------------------------------------
ACC3_W		;Shift register 3
;----------------------------------------------------------------------------
	strb r0,ac_shiftreg+3
	mov pc,lr
;----------------------------------------------------------------------------
ACC4_W		;Shift amount
;----------------------------------------------------------------------------
	and r0,r0,#0xF
	strb r0,ac_shiftbits
	ldr r1,ac_shiftreg
	tst r0,#8
	rsbne r0,r0,#16
	movne r1,r1,lsr r0
	moveq r1,r1,lsl r0
	str r1,ac_shiftreg
	mov pc,lr
;----------------------------------------------------------------------------
ACC5_W
;----------------------------------------------------------------------------
	strb r0,ac_1ac5
	mov pc,lr

;----------------------------------------------------------------------------
ac_baseaddress
	DCD 0,0,0,0
ac_offsetaddress
	DCD 0,0,0,0
ac_addressincrement
	DCD 0,0,0,0
ac_control
	DCD 0,0,0,0

ac_shiftreg
	DCD 0		;shift register
ac_shiftbits
	DCB 0		;shit amount
ac_1ac5
	DCB 0



;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	END
