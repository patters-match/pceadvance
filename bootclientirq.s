	INCLUDE equates.h

	IMPORT AGBmain
	EXPORT irq
	EXPORT IOmode
	EXPORT current
	EXPORT total

	AREA entrypoint, CODE, READONLY
	ENTRY

	b AGBmain
	% 28
irq ;-------------------------interrupt handler for boot client's serial comms
	ldr r2,=REG_IF
	mov r0,#-1
	strh r0,[r2]		;interrupt clear

	ldr r2,=REG_SIOMULTI0
	ldrh r0,[r2]

	ldr r1,IOmode
	adr r2,jmptbl
	add r3,r1,#1
	ldr pc,[r2,r1,lsl#2]
mode0				;0=waiting for master
	cmp r0,#0x99
	streq r3,IOmode
	bx lr
mode1				;1=read total (low)
	cmp r0,#0x99
	strneh r0,total
	strne r3,IOmode
	bx lr
mode2				;2=read total (high)
	strh r0,total+2
	str r3,IOmode
	bx lr
mode3				;3=transfer data
	mov r1,#0x2000000
	ldr r2,current
	strh r0,[r1,r2]
	add r2,r2,#2

	ldr r0,total
	cmp r2,r0
	strne r2,current
	streq r3,IOmode
mode4				;4=finished
	bx lr

IOmode	DCD 0
current	DCD 0		;bytes transferred
total	DCD 0xabcde	;bytes expected
jmptbl	DCD mode0,mode1,mode2,mode3,mode4
;--------------------------------------------
	END
