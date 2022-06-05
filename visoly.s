	EXPORT doReset

init_flashcart
;CloseWrite - lock PSRAM to return it to its original state
	ldr r2,=0x9fe0000
	mov r0,#0xD200
	strh r0,[r2]			;*(u16 *)0x9fe0000 = 0xd200;
	mov r4,#0x8000000
	mov r1,#0x1500
	strh r1,[r4]			;*(u16 *)0x8000000 = 0x1500;
	add r4,r4,#0x20000
	strh r0,[r4]			;*(u16 *)0x8020000 = 0xd200;
	add r4,r4,#0x20000
	strh r1,[r4]			;*(u16 *)0x8040000 = 0x1500;
	ldr r4,=0x9c40000
	strh r0,[r4]			;*(u16 *)0x9c40000 = 0xd200;
	sub r2,r2,#0x20000
	strh r1,[r2]			;*(u16 *)0x9fc0000 = 0x1500;

;SetRomPage(0x8000) - put the EZ-Flash into OS Mode with bootloader mapped to 0x8000000
	ldr r2,=0x9fe0000
	mov r0,#0xD200
	strh r0,[r2]			;*(u16 *)0x9fe0000 = 0xD200;
	mov r4,#0x8000000
	mov r1,#0x1500
	strh r1,[r4]			;*(u16 *)0x8000000 = 0x1500;
	add r4,r4,#0x20000
	strh r0,[r4]			;*(u16 *)0x8020000 = 0xD200;
	add r4,r4,#0x20000
	strh r1,[r4]			;*(u16 *)0x8040000 = 0x1500;
	ldr r4,=0x9880000
	mov r0,#0x8000
	strh r0,[r4]			;*(u16 *)0x9880000 = 0x8000;
	sub r2,r2,#0x20000
	strh r1,[r2]			;*(u16 *)0x9fc0000 = 0x1500;
	bx lr

doReset
	mov r1,#REG_BASE
	mov r0,#0
	strh r0,[r1,#REG_DM0CNT_H]	;stop all DMA
	strh r0,[r1,#REG_DM1CNT_H]
	strh r0,[r1,#REG_DM2CNT_H]
	strh r0,[r1,#REG_DM3CNT_H]
	add r1,r1,#0x200
	str r0,[r1,#8]			;interrupts off

	bl init_flashcart
	
	mov r0, #0
	ldr r1,=0x3007ffa		;must be 0 before swi 0x00 is run, otherwise it tries to start from 0x02000000.
	strh r0,[r1]
;	mov r0, #0xC			;VRAM & Palette clear
	mov r0, #8			;VRAM clear
	swi 0x010000
	swi 0x000000

	END

