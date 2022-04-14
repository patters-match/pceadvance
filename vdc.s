	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE cart.h
	INCLUDE io.h
	INCLUDE h6280.h
	INCLUDE sound.h
	INCLUDE h6280mac.h

	EXPORT _03				;ST0
	EXPORT _13				;ST1
	EXPORT _23				;ST2
	EXPORT vdc_init
	EXPORT VDC_reset_
	EXPORT VCE_R
	EXPORT VCE_W
	EXPORT VDC_R
	EXPORT VDC_W
	EXPORT debug_
	EXPORT AGBinput
	EXPORT EMUinput
	EXPORT paletteinit
	EXPORT PaletteTxAll
	EXPORT newframe
	EXPORT endframe
	EXPORT flipsizeTable
	EXPORT vdcstate
	EXPORT gammavalue
	EXPORT oambufferready
	EXPORT scrollbuff
	EXPORT bgrbuff
	EXPORT VDC_CR_L_W
	EXPORT VdcHdr_L_W
	EXPORT newX
	EXPORT SF2Mapper
	EXPORT twitch
	EXPORT flicker
	EXPORT fpsenabled
	EXPORT FPSValue
	EXPORT vbldummy
	EXPORT vblankfptr
	EXPORT vblankinterrupt

 AREA rom_code, CODE, READONLY

;----------------------------------------------------------------------------
vdc_init	;(called from main.c) only need to call once
;----------------------------------------------------------------------------
	mov addy,lr

	mov r1,#0xffffff00		;build chr decode tbl
	ldr r2,=CHR_DECODE
ppi0	mov r0,#0
	tst r1,#0x01
	orrne r0,r0,#0x10000000
	tst r1,#0x02
	orrne r0,r0,#0x01000000
	tst r1,#0x04
	orrne r0,r0,#0x00100000
	tst r1,#0x08
	orrne r0,r0,#0x00010000
	tst r1,#0x10
	orrne r0,r0,#0x00001000
	tst r1,#0x20
	orrne r0,r0,#0x00000100
	tst r1,#0x40
	orrne r0,r0,#0x00000010
	tst r1,#0x80
	orrne r0,r0,#0x00000001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi0


	mov r1,#REG_BASE
	mov r0,#0x0008
	strh r0,[r1,#REG_DISPSTAT]	;vblank en

	mov r0,#240
	strh r0,[r1,#REG_WIN0H]		;Window 0 Horizontal position
	mov r0,#160
	strh r0,[r1,#REG_WIN0V]		;Window 0 Vertical position
	ldr r0,=0x0004003f
	str r0,[r1,#REG_WININ]		;Window 0 settings. BG2 allways on.



	add r0,r1,#REG_BG0HOFS		;DMA0 always goes here
	str r0,[r1,#REG_DM0DAD]
	ldr r0,=DMA0BUFF+4			;DMA0 src=
	str r0,[r1,#REG_DM0SAD]
	mov r0,#1					;1 word transfer
	strh r0,[r1,#REG_DM0CNT_L]

	add r2,r1,#REG_IE
	mov r0,#-1
	strh r0,[r2,#2]		;stop pending interrupts
	ldr r0,=irqhandler
	str r0,[r1,#-4]		;=AGB_IRQVECT
	ldr r0,=0x1091
	strh r0,[r2]		;key,vblank,timer1 enable. (serial interrupt=0x80)
	mov r0,#1
	strh r0,[r2,#8]		;master irq enable

	bx addy
;----------------------------------------------------------------------------
VDC_reset_	;called with CPU reset
;----------------------------------------------------------------------------
	mov r9,lr

	mov r1,#0
	str r1,windowtop
	str r1,hcenter

	ldr r0,=vdcstate
	mov r2,#21				;21*4
	bl memset_				;clear VDC regs

	ldr r0,=PCE_VRAM
	mov r2,#0x10000/4		;64k
	bl memset_				;clear PCE VRAM

	bl _VDC0W				;must be initialized.
	ldr r0,=0x00000101
	str r0,vram_w_adr
	str r0,vram_r_adr

	mov r0,#1
	strb r0,vramaddrinc
	strb r0,sprmemreload
	mov r0,#-1
	str r0,rasterCompareCPU
;	mov r0,#2
;	strb r0,vdcvsw
;	mov r0,#12
;	strb r0,vdcvds

	mov r0,#0
	str r0,BGoffset1
	mov r0,#0x800
	str r0,BGoffset2
	mov r0,#0xc00
	str r0,BGoffset3

	ldr r0,=VDCBUFF3		;clear DISPCNT+DMA1BUFF
	mov r1,#0x2440
	orr r1,r1,r1,lsl#16
	mov r2,#720/2
	bl memset_

	mov r0,#AGB_OAM
	mov r1,#0xe0
	mov r2,#0x100
	bl memset_		;no stray sprites please
	ldr r0,=OAM_BUFFER1
	mov r2,#0x180
	bl memset_


	bl paletteinit	;do palette mapping
	mov pc,r9

;----------------------------------------------------------------------------
paletteinit;	r0-r3 modified.
;called by ui.c:  void map_palette(char gammavalue)
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,lr}
	mov r7,#0xE0
	ldr r6,=MAPPED_RGB
	ldrb r1,gammavalue	;gamma value = 0 -> 4
	mov r4,#1024		;pce rgb, r1=R, r2=G, r3=B
	sub r4,r4,#2
nomap					;map 0000000gggrrrbbb  ->  0bbbbbgggggrrrrr
	and r0,r7,r4,lsl#1	;Red ready
	bl gprefix
	mov r5,r0

	and r0,r7,r4,lsr#2	;Green ready
	bl gprefix
	orr r5,r5,r0,lsl#5

	and r0,r7,r4,lsl#4	;Blue ready
	bl gprefix
	orr r5,r5,r0,lsl#10

	strh r5,[r6,r4]
	subs r4,r4,#2
	bpl nomap



	mov r7,#0x7
	ldr r6,=MAPPED_BNW
	mov r4,#1024		;pce rgb, r1=R, r2=G, r3=B
	sub r4,r4,#2
nomap2					;map 0000000gggrrrbbb  ->  0bbbbbgggggrrrrr
	and r2,r7,r4,lsr#4	;Red ready
	ldr r3,=0x0AF8AF8A	;30%
	mul r0,r3,r2

	and r2,r7,r4,lsr#7	;Green ready
	ldr r3,=0x1593BFA2	;59%
	mla r0,r3,r2,r0

	and r2,r7,r4,lsr#1	;Blue ready
	ldr r3,=0x0405D9F7	;11%
	mla r0,r3,r2,r0
	
	mov r0,r0,lsr#24

	bl gammaconvert
	orr r5,r0,r0,lsl#5
	orr r5,r5,r0,lsl#10

	strh r5,[r6,r4]
	subs r4,r4,#2
	bpl nomap2

	ldmfd sp!,{r4-r7,lr}
	bx lr

;----------------------------------------------------------------------------
gprefix
	orr r0,r0,r0,lsr#3
	orr r0,r0,r0,lsr#6
;----------------------------------------------------------------------------
gammaconvert;	takes value in r0(0-0xFF), gamma in r1(0-4),returns new value in r0=0x1F
;----------------------------------------------------------------------------
	rsb r2,r0,#0x100
	mul r3,r2,r2
	rsbs r2,r3,#0x10000
	subne r2,r2,#0x2a8			;Tweak for Gamma #4...
	rsb r3,r1,#4
	orr r0,r0,r0,lsl#8
	mul r2,r1,r2
	mla r0,r3,r0,r2
	mov r0,r0,lsr#13

	bx lr
;----------------------------------------------------------------------------
showfps_		;fps output, r0-r3=used.
;----------------------------------------------------------------------------
	ldrb r0,fpschk
	subs r0,r0,#1
	movmi r0,#59
	strb r0,fpschk
	bxpl lr					;End if not 60 frames has passed

	ldrb r0,fpsenabled
	tst r0,#1
	bxeq lr					;End if not enabled

	ldr r0,fpsvalue
	cmp r0,#0
	bxeq lr					;End if fps==0, to keep it from appearing in the menu
	mov r1,#0
	str r1,fpsvalue

	mov r1,#100
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	add r0,r0,#0x30
	strb r0,fpstext+5
	mov r0,r1
	mov r1,#10
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	add r0,r0,#0x30
	strb r0,fpstext+6
	add r1,r1,#0x30
	strb r1,fpstext+7
	

	adr r0,fpstext
	ldr r2,=DEBUGSCREEN
;	add r2,r2,r1,lsl#6
db1
	ldrb r1,[r0],#1
	orr r1,r1,#0x4100
	strh r1,[r2],#2
	tst r2,#0xE
	bne db1

	bx lr
;----------------------------------------------------------------------------
fpstext DCB "FPS:    "
fpsenabled DCB 0
fpschk	DCB 0
gammavalue DCB 0
		DCB 0
;----------------------------------------------------------------------------
debug_		;debug output, r0=val, r1=line, r2=used.
;----------------------------------------------------------------------------
 [ DEBUG
	ldr r2,=DEBUGSCREEN
	add r2,r2,r1,lsl#6
db0
	mov r0,r0,ror#28
	and r1,r0,#0x0f
	cmp r1,#9
	addhi r1,r1,#7
	add r1,r1,#0x30
	orr r1,r1,#0x4100
	strh r1,[r2],#2
	tst r2,#15
	bne db0
 ]
	bx lr
;----------------------------------------------------------------------------
flipsizeTable;	convert from PCE spr to GBA obj.
;----------------------------------------------------------------------------
;	    width=16	width=32
	DCD 0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000		;height 16
	DCD 0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000		;hor flip
	DCD 0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000		;height 32
	DCD 0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000
	DCD 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000		;height 64 (must be 32 wide)
	DCD 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000
	DCD 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000
	DCD 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000

	DCD 0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000,0x40000000,0x80004000		;height 16
	DCD 0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000,0x50000000,0x90004000		;hor flip
	DCD 0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000,0x80008000,0x80000000		;height 32
	DCD 0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000,0x90008000,0x90000000
	DCD 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000		;height 64 (must be 32 wide)
	DCD 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000
	DCD 0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000,0xc0008000
	DCD 0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000,0xd0008000

	DCD 0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000		;height 16, ver flip
	DCD 0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000		;hor flip
	DCD 0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000		;height 32
	DCD 0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000
	DCD 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000		;height 64 (must be 32 wide)
	DCD 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000
	DCD 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000
	DCD 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000

	DCD 0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000,0x60000000,0xa0004000		;height 16
	DCD 0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000,0x70000000,0xb0004000		;hor flip
	DCD 0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000,0xa0008000,0xa0000000		;height 32
	DCD 0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000,0xb0008000,0xb0000000
	DCD 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000		;height 64 (must be 32 wide)
	DCD 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000
	DCD 0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000,0xe0008000
	DCD 0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000,0xf0008000

;----------------------------------------------------------------------------
VCE_R;		Video Color Encoder  read
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE		;VDC & VCE takes 1 more cycle to access
	and r1,addy,#7
	ldr pc,[pc,r1,lsl#2]
;---------------------------
	DCD 0
VCE_read_tbl
	DCD empty_R
	DCD empty_R
	DCD empty_R
	DCD empty_R
	DCD _0404R
	DCD _0405R
	DCD empty_R
	DCD empty_R
;----------------------------------------------------------------------------
VCE_W;		Video Color Encoder  write
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE		;VDC & VCE takes 1 more cycle to access
	and r1,addy,#7
	ldr pc,[pc,r1,lsl#2]
;---------------------------
	DCD 0
VCE_write_tbl
	DCD _0400W
	DCD empty_W
	DCD _0402W
	DCD _0403W
	DCD _0404W
	DCD _0405W
	DCD empty_W
	DCD empty_W
;----------------------------------------------------------------------------
_0404R		;VCE CTD L
;----------------------------------------------------------------------------
	ldr r0,palettePtr
	ldr r1,=PCE_PALETTE
	ldrb r0,[r1,r0,lsr#22]	;load from pce palette
	mov pc,lr
;----------------------------------------------------------------------------
_0405R		;VCE CTD H
;----------------------------------------------------------------------------
	ldr r0,palettePtr
	add r1,r0,#0x00800000
	str r1,palettePtr
	ldr r1,=PCE_PALETTE+1
	ldrb r0,[r1,r0,lsr#22]	;load from pce palette
	orr r0,r0,#0xfe		;not really necesary?
	mov pc,lr
;----------------------------------------------------------------------------
_0400W		;VCE CR - dotclock, interlace, color.
;----------------------------------------------------------------------------
	ldr r1,=261			;NTSC (261-262) numer of lines=262+1
	tst r0,#4
	addne r1,r1,#1			;Chew Man Fu & Jyuohki likes this, Chase HQ does not.
	str r1,lastscanline
	tst r0,#0x80
;	ldr r1,=MAPPED_RGB
	ldreq r1,=MAPPED_RGB
	ldrne r1,=MAPPED_BNW
	ldr r0,=MappedColorPtr
	str r1,[r0]
	mov pc,lr
;----------------------------------------------------------------------------
_0402W		;VCE Color Table Address L
;----------------------------------------------------------------------------
	ldr r1,palettePtr
	and r1,r1,#0x80000000
	orr r1,r1,r0,lsl#23
	str r1,palettePtr
	mov pc,lr
;----------------------------------------------------------------------------
_0403W		;VCE Color Table Address H
;----------------------------------------------------------------------------
	ldr r1,palettePtr
	bic r1,r1,#0x80000000
	orr r1,r1,r0,lsl#31
	str r1,palettePtr
	mov pc,lr
;----------------------------------------------------------------------------
_0404W		;VCE Color Table Data L
;----------------------------------------------------------------------------
	ldr r1,palettePtr
	ldr r2,=PCE_PALETTE
	strb r0,[r2,r1,lsr#22]	;store in pce palette
	mov pc,lr
;	b PaletteTx
;----------------------------------------------------------------------------
_0405W		;VCE Color Table Data H
;----------------------------------------------------------------------------
	ldr r1,palettePtr
	add r2,r1,#0x00800000
	str r2,palettePtr
	ldr r2,=PCE_PALETTE+1
	strb r0,[r2,r1,lsr#22]	;store in pce palette
	mov pc,lr
;	b PaletteTx

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VDC_write_tbl_L
;----------------------------------------------------------------------------
	DCD MAWR_L_W		;00 Mem Adr Write Reg
	DCD MARR_L_W		;01 Mem Adr Read Reg
	DCD VRAM_L_W		;02 VRAM write
	DCD empty_W			;03
	DCD empty_W			;04
	DCD VDC_CR_L_W		;05 Interuppt, sync, increment width...
	DCD RstCmp_L_W		;06 Raster compare
	DCD ScrolX_L_W		;07 Scroll X
	DCD ScrolY_L_W		;08 Scroll Y
	DCD MemWid_L_W		;09 Memory Width (Bgr virtual size)
	DCD VdcHsr_L_W		;0A Horizontal Sync Reg
	DCD VdcHdr_L_W		;0B Horizontal Display Reg
	DCD VdcVpr_L_W		;0C Vertical Sync Reg
	DCD VdcVdw_L_W		;0D Vertical Display Reg
	DCD VdcVcr_L_W		;0E Vertical Display End Reg
	DCD DMACtl_L_W		;0F DMA Control Reg
	DCD DMASrc_L_W		;10 DMA Source Reg
	DCD DMADst_L_W		;11 DMA Destination Reg
	DCD DMALen_L_W		;12 DMA Length Reg
	DCD DMAOAM_L_W		;13 DMA Sprite Attribute Table
	DCD empty_W			;14
	DCD empty_W			;15
	DCD empty_W			;16
	DCD empty_W			;17
	DCD empty_W			;18
	DCD empty_W			;19
	DCD empty_W			;1A
	DCD empty_W			;1B
	DCD empty_W			;1C
	DCD empty_W			;1D
	DCD empty_W			;1E
	DCD empty_W			;1F
;----------------------------------------------------------------------------
VDC_write_tbl_H
	DCD MAWR_H_W		;00 Mem Adr Write Reg
	DCD MARR_H_W		;01 Mem Adr Read Reg
	DCD VRAM_H_W		;02 VRAM write
	DCD empty_W			;03
	DCD empty_W			;04
	DCD VDC_CR_H_W		;05 Interuppt, sync, increment width...
	DCD RstCmp_H_W		;06 Raster compare
	DCD ScrolX_H_W		;07 Scroll X
	DCD ScrolY_H_W		;08 Scroll Y
	DCD MemWid_H_W		;09 Memory Width (Bgr virtual size)
	DCD VdcHsr_H_W		;0A Horizontal Sync Reg
	DCD VdcHdr_H_W		;0B Horizontal Display Reg
	DCD VdcVpr_H_W		;0C Vertical Sync Reg
	DCD VdcVdw_H_W		;0D Vertical Display Reg
	DCD VdcVcr_H_W		;0E Vertical Display End Reg
	DCD DMACtl_H_W		;0F DMA Control Reg
	DCD DMASrc_H_W		;10 DMA Source Reg
	DCD DMADst_H_W		;11 DMA Destination Reg
	DCD DMALen_H_W		;12 DMA Length Reg
	DCD DMAOAM_H_W		;13 DMA Sprite Attribute Table
	DCD empty_W			;14
	DCD empty_W			;15
	DCD empty_W			;16
	DCD empty_W			;17
	DCD empty_W			;18
	DCD empty_W			;19
	DCD empty_W			;1A
	DCD empty_W			;1B
	DCD empty_W			;1C
	DCD empty_W			;1D
	DCD empty_W			;1E
	DCD empty_W			;1F

;----------------------------------------------------------------------------
MemWid_L_W		;09 Memory Width (Bgr virtual size)
;----------------------------------------------------------------------------
	strb r0,mwreg
	b mirrorPCE
;----------------------------------------------------------------------------
VdcHdr_L_W		;0B Horizontal Display Reg, width.
;----------------------------------------------------------------------------
	and r0,r0,#0x7f
	strb r0,vdchdw
	mov r0,r0,lsl#3
	sub r0,r0,#232
	movs r0,r0,asr#1
	ldrplb r1,xcentering
	tstpl r1,#1
	strle r0,hcenter

	cmp r0,#0
	movpl r0,#0
	add r2,r0,#240
	sub r0,r2,r0,lsl#8		;r0 = -r0
	mov r1,#REG_BASE
	strh r0,[r1,#REG_WIN0H]		;Window 0 Horizontal position/size
	mov pc,lr
;----------------------------------------------------------------------------
VdcVpr_L_W		;0C Vertical Sync Reg, Vertical Synch Width
;----------------------------------------------------------------------------
	and r0,r0,#0x1f
	strb r0,vdcvsw
	b calcVBL
;----------------------------------------------------------------------------
VdcVpr_H_W		;0C Vertical Sync Reg, Vertical Display Start
;----------------------------------------------------------------------------
	strb r0,vdcvds
	b calcVBL
;----------------------------------------------------------------------------
VdcVdw_L_W		;0D Vertical Display Reg
;----------------------------------------------------------------------------
	strb r0,vdcvdw
	b calcVBL
;----------------------------------------------------------------------------
VdcVdw_H_W		;0D Vertical Display Reg, display height
;----------------------------------------------------------------------------
	and r0,r0,#1
	strb r0,vdcvdw+1

;----------------------------------------------------------------------------
calcVBL
	ldrb r0,vdcvsw
	ldrb r2,vdcvds
	add r2,r2,r0
;	cmp r2,#14
;	movmi r2,#14
	ldr r0,vdcvdw
	add r0,r0,#1
	add r1,r0,r2
	cmp r1,#256
;	sub r0,r0,r2
	rsbhi r0,r2,#256
	str r0,vblscanlinecpu
	cmp r0,#239
	movhi r0,#239
	str r0,vblscanlinegfx

	subs r0,r0,#213		;160/0.75
	movmi r0,#0
	mov r0,r0,lsr#1
	strb r0,ystart		;for centering bgr in scaled mode.vertical
;	str r0,windowtop	;for centering obj in scaled mode.vertical

	mov pc,lr
;----------------------------------------------------------------------------
VdcVcr_L_W		;0E Vertical Display End Reg, how much is blanked after the display (+3)
;----------------------------------------------------------------------------
	strb r0,vdcvcr
;----------------------------------------------------------------------------
MemWid_H_W		;09 Memory Width (Bgr virtual size)
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VdcHsr_L_W		;0A Horizontal Sync Reg
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VdcHsr_H_W		;0A Horizontal Sync Reg
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VdcHdr_H_W		;0B Horizontal Display Reg
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VdcVcr_H_W		;0E Vertical Display End Reg
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
DMACtl_H_W		;0F DMA Control Reg
;----------------------------------------------------------------------------
	mov pc,lr
;----------------------------------------------------------------------------
DMACtl_L_W		;0F DMA Control Reg
;----------------------------------------------------------------------------
	strb r0,dmacr
	ands r0,r0,#0x10		;check for dma repetition
	strneb r0,dosprdma
	mov pc,lr
;----------------------------------------------------------------------------
DMASrc_L_W		;10 DMA Source Reg
;----------------------------------------------------------------------------
	strb r0,dmasource
	mov pc,lr
;----------------------------------------------------------------------------
DMASrc_H_W		;10 DMA Source Reg
;----------------------------------------------------------------------------
	strb r0,dmasource+1
	mov pc,lr
;----------------------------------------------------------------------------
DMADst_L_W		;11 DMA Destination Reg
;----------------------------------------------------------------------------
	strb r0,dmadestination+2
	mov pc,lr
;----------------------------------------------------------------------------
DMADst_H_W		;11 DMA Destination Reg
;----------------------------------------------------------------------------
	strb r0,dmadestination+3
	mov pc,lr
;----------------------------------------------------------------------------
DMALen_L_W		;12 DMA Length Reg
;----------------------------------------------------------------------------
	strb r0,dmalength
	mov pc,lr
;----------------------------------------------------------------------------
DMALen_H_W		;12 DMA Length Reg, this starts the transfer.
;----------------------------------------------------------------------------
;dmadum	b dmadum			;for testing of VRAM DMA (Davis Cup Tennis, Gaia no Monsho, Legendary Axe II, Magical Chase, Ninja Warriors).

	stmfd sp!,{r3-r8,lr}
	ldrb r1,dmalength
	orr r2,r1,r0,lsl#8
	
	ldrb r0,dmacr
	tst r0,#4
	mov r7,#0x00020000			;Source increase
	rsbne r7,r7,#0				;Source decrease
	tst r0,#8
	mov r8,#0x00010000			;Destination increase
	rsbne r8,r8,#0				;Destination decrease
	mov r1,#-1
	ldr r3,=PCE_VRAM
	ldr r4,dmasource
	mov r4,r4,lsl#17
	ldr r5,dmadestination
	ldr r6,=DIRTYSPRITES
vramdmaloop
	mov r4,r4,lsr#16
	movs r5,r5,asr#15
	ldrplh r0,[r3,r4]			;read from virtual PCE_VRAM
	strplh r0,[r3,r5]			;write to virtual PCE_VRAM
	strplb r1,[r6,r5,lsr#7]		;write to dirtymap, r1=-1.

	add r4,r7,r4,lsl#16
	add r5,r8,r5,lsl#15
	subs r2,r2,#1
	bpl vramdmaloop

	strb r2,dmalength
	str r5,dmadestination
	mov r4,r4,lsr#17
	str r4,dmasource

	ldrb r0,dmacr
	and r0,r0,#2			;should IRQ be generated?
	orr r0,r0,#0x20			;should vdcstat bit be set?
	strb r0,dmairq

	ldmfd sp!,{r3-r8,pc}
;----------------------------------------------------------------------------
DMAOAM_L_W		;13 DMA Sprite Attribute Table
;----------------------------------------------------------------------------
	strb r0,satAddr
;	mov r1,#-1
;	strb r1,dosprdma
	mov pc,lr
;----------------------------------------------------------------------------
DMAOAM_H_W		;13 DMA Sprite Attribute Table
;----------------------------------------------------------------------------
	strb r0,satAddr+1
	mov r1,#-1
	strb r1,dosprdma
	mov pc,lr

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	AREA wram_code1, CODE, READWRITE
irqhandler	;r0-r3,r12 are safe to use
;----------------------------------------------------------------------------
	mov r2,#REG_BASE
	mov r3,#REG_BASE
	ldr r1,[r2,#REG_IE]!
	and r1,r1,r1,lsr#16	;r1=IE&IF
	ldrh r0,[r3,#-8]
	orr r0,r0,r1
	strh r0,[r3,#-8]

		;---these CAN'T be interrupted
		ands r0,r1,#0x80
		strneh r0,[r2,#2]		;IF clear
		bne serialinterrupt
		;---

		;---these CAN be interrupted
		ands r0,r1,#0x01
		ldrne r12,vblankfptr
		bne jmpintr
		ands r0,r1,#0x10
		ldrne r12,=timer1interrupt
		;----
		adreq r12,irq0
		moveq r0,r1		;if unknown interrupt occured clear it.
jmpintr
	strh r0,[r2,#2]		;IF clear

	mrs r3,spsr
	stmfd sp!,{r3,lr}
	mrs r3,cpsr
	bic r3,r3,#0x9f
	orr r3,r3,#0x1f			;--> Enable IRQ . Set CPU mode to System.
	msr cpsr_cf,r3
	stmfd sp!,{lr}
	adr lr,irq0

	mov pc,r12


irq0
	ldmfd sp!,{lr}
	mrs r3,cpsr
	bic r3,r3,#0x9f
	orr r3,r3,#0x92        		;--> Disable IRQ. Set CPU mode to IRQ
	msr cpsr_cf,r3
	ldmfd sp!,{r0,lr}
	msr spsr_cf,r0
vbldummy
	bx lr
;----------------------------------------------------------------------------
vblankfptr DCD vbldummy			;later switched to vblankinterrupt
flicker	DCB 1
twitch	DCB 0
		DCB 0,0

vblankinterrupt;
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,globalptr,lr}
	ldr globalptr,=|wram_globals0$$Base|

	bl Vbl_Sound_1
	bl showfps_

	ldr r2,=DMA0BUFF		;setup DMA buffer for scrolling:
	add r3,r2,#160*4
	ldr r1,dmascrollbuff
	ldrb r0,emuflags+1
	cmp r0,#SCALED
	bhs vblscaled

vblunscaled
	ldr r0,windowtop+12
	add r1,r1,r0,lsl#2		;(unscaled)
vbl6
	ldmia r1!,{r4-r7}
	add r4,r4,r0,lsl#16
	add r5,r5,r0,lsl#16
	add r6,r6,r0,lsl#16
	add r7,r7,r0,lsl#16
	stmia r2!,{r4-r7}
	cmp r2,r3
	bmi vbl6

	ldr r3,pcevdcbuffer
	add r3,r3,r0,lsl#1
	b vbl5

vblscaled					;(scaled)
	ldrb r0,ystart
	ldrb r5,flicker
	ldrb r4,twitch
	eors r4,r4,r5
	strb r4,twitch
		ldrh r5,[r1,#2]	 	;adjust vertical scroll to avoid screen wobblies
	add r1,r1,r0,lsl#2
	ldreq r4,[r1],#4
	addeq r4,r4,r0,lsl#16
	streq r4,[r2],#4
		ldr r4,adjustblend
		add r4,r4,r5
		ands r4,r4,#3
		str r4,totalblend
		beq vbl3
		cmp r4,#2
		bhi vbl2
		addmi r1,r1,#4
vbl1
		addmi r0,r0,#1
		ldr r4,[r1],#4
		add r4,r4,r0,lsl#16
		str r4,[r2],#4
vbl2	ldr r4,[r1],#4
		add r4,r4,r0,lsl#16
		str r4,[r2],#4
vbl3	ldr r4,[r1],#8
		add r4,r4,r0,lsl#16
		str r4,[r2],#4
vbl4
;	add r0,r0,#1
;	ldmia r1!,{r4-r7}
;	add r4,r4,r0,lsl#16
;	add r5,r5,r0,lsl#16
;	add r6,r6,r0,lsl#16
;	stmia r2!,{r4-r6}

	cmp r2,r3
	bmi vbl1

	ldr r1,tmpvdcbuffer		;(scaled)
	ldr r2,dmavdcbuffer
	ldrb r0,ystart
	add r1,r1,r0,lsl#1
	ldr r0,oambufferready
	cmp r0,#0
	blne nf0
	ldr r3,dmavdcbuffer
vbl5


	mov r6,#REG_BASE
	strh r6,[r6,#REG_DM0CNT_H]		;DMA0 stop
	strh r6,[r6,#REG_DM3CNT_H]		;DMA3 stop

	add r2,r6,#REG_DM3SAD

	ldr r0,oambufferready
	cmp r0,#0
	ldrne r4,dmaoambuffer			;DMA3 src, OAM transfer:
	movne r5,#AGB_OAM				;DMA3 dst
	movne r1,#0x84000000			;noIRQ 32bit incsrc incdst
	orrne r7,r1,#0x80				;128 words (512 bytes)
	stmneia r2,{r4,r5,r7}			;DMA3 go

	ldrne r4,=PCEPALBUFF			;DMA3 src, Palette transfer:
	movne r5,#AGB_PALETTE			;DMA3 dst
	orrne r7,r1,#0x100				;256 words (1024 bytes)
	stmneia r2,{r4,r5,r7}			;DMA3 go
	mov r0,#0
	str r0,oambufferready

	ldr r0,=DMA0BUFF				;setup HBLANK DMA for display scroll:
	ldr r4,[r0],#4
	str r4,[r6,#REG_BG0HOFS]		;set 1st value manually, HBL is AFTER 1st line
	ldr r0,=0xA660					;noIRQ hblank 32bit repeat incsrc inc_reloaddst
	strh r0,[r6,#REG_DM0CNT_H]		;DMA0 go

	ldrh r0,[r3],#2					;setup HBLANK DMA for DISPCNT (BG/OBJ enable)
	strh r0,[r6,#REG_DISPCNT]		;set 1st value manually, HBL is AFTER 1st line
	ldr r7,=0xA2400001				;noIRQ hblank 16bit repeat incsrc fixeddst 1word
	stmia r2,{r3,r6,r7}				;DMA3 go


	ldr r2,BGmirror
	ldr r0,BGoffset1
	orr r0,r2,r0
	strh r0,[r6,#REG_BG0CNT]
;	ldr r0,BGoffset2				;Background debugg
;	orr r0,r2,r0
;	strh r0,[r6,#REG_BG1CNT]
;	ldr r0,BGoffset3
;	orr r0,r2,r0
;	strh r0,[r6,#REG_BG3CNT]
exit_vbl
	bl Vbl_Sound_2
	ldmfd sp!,{r4-r7,globalptr,pc}

totalblend	DCD 0


;----------------------------------------------------------------------------
nf0	add r3,r2,#160*2
	ldrb r0,twitch
	tst r0,#1
		ldreqh r0,[r1],#2
		streqh r0,[r2],#2
	ldr r0,totalblend
	ands r0,r0,#3
	beq nf22
	cmp r0,#2
	bhi nf21
	addmi r1,r1,#2
nf20	ldrh r0,[r1],#2
		strh r0,[r2],#2
nf21	ldrh r0,[r1],#2
		strh r0,[r2],#2
nf22	ldrh r0,[r1],#4
		strh r0,[r2],#2
	cmp r2,r3
	bmi nf20
	mov pc,lr
;----------------------------------------------------------------------------
newframe	;called before line 0	(r0-r9 safe to use)
;----------------------------------------------------------------------------
;	str lr,[sp,#-4]!
;------------------------
;	bl newX
;--------------------------
;	ldr r0,scrollY
;	adr r1,scrollYold
;	swp r0,r0,[r1]		;r0=lastval
;	ldr r1,scrollYline
;	mov addy,#239
;	bl scrollYfinish
	ldr r0,scrollY
	str r0,scrollYold
;--------------------------
	mov r0,#0
	str r0,ctrl1line
	str r0,scrollXline
	str r0,scrollYline
	str r0,scanline			;reset scanline count
;	strb r0,vdcstat			;vbl clear, sprite0 clear, Tatsujin needs this.
;	strb r0,irqPending

	ldrb r0,vdcctrl1
	and r0,r0,#0xC0		;Burst mode?
	strb r0,vdcburst
;--------------------------
;	ldr pc,[sp],#4
	bx lr

;----------------------------------------------------------------------------
endframe	;called just before screen end (~line 240)	(r0-r2 safe to use)
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r9,lr}

	bl newX
	bl newY

	ldrb r0,vdcburst
	ldrb r1,vdcctrl1
	orr r0,r0,r1
	tst r0,#0xC0
	blne chrfinish

;	bl chrfinish
;--------------------------
	bl sprDMA_do
;--------------------------
	bl PaletteTxAll
;--------------------------
	ldrb r0,vdcburst
	cmp r0,#0

	ldrne r0,ctrl1old
	ldrne r1,ctrl1line
	ldrne addy,vblscanlinegfx

	moveq r0,#0x2440			;If burstmode, wait 'till next frame with enabling bgr.
	moveq r1,#0					;1?
	moveq addy,#239
	bl ctrl1finish
;--------------------------
	mov r0,#0x2440			;DISPCNTBUFF
	ldr r1,vblscanlinegfx
	mov addy,#239
	bl ctrl1finish
;--------------------------

	mrs r3,cpsr
	orr r1,r3,#0x80			;--> Disable IRQ.
	msr cpsr_cf,r1

	ldr r0,dmaoambuffer
	ldr r1,tmpoambuffer
	str r0,tmpoambuffer
	str r1,dmaoambuffer

	ldr r0,scrollbuff
	ldr r1,dmascrollbuff
	str r1,scrollbuff
	str r0,dmascrollbuff

	ldr r0,BGoffset1
	ldr r1,BGoffset2
	str r1,BGoffset1
	ldr r1,BGoffset3
	str r1,BGoffset2
	str r0,BGoffset3

	ldr r0,tmpvdcbuffer
	ldr r1,pcevdcbuffer
	str r1,tmpvdcbuffer
	str r0,pcevdcbuffer

	mov r0,#1
	str r0,oambufferready

	adrl r0,windowtop+4		;load wtop, store in wtop+4.......load wtop+8, store in wtop+12
	ldmia r0,{r1-r2}		;load with post increment
	stmib r0,{r1-r2}		;store with pre increment

	msr cpsr_cf,r3			;--> restore mode,Enable IRQ.

	bl sprDMA_W

	ldmfd sp!,{r3-r9,lr}
	bx lr
;----------------------------------------------------------------------------
PaletteTxAll		; Called from ui.c
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7}
	mov r3,#0x400
	sub r4,r3,#2		;mask=0x3FE
	ldr r1,=PCEPALBUFF
	ldr r5,MappedColorPtr
	ldr r2,=PCE_PALETTE
	ldr r6,dontstop
	cmp r6,#0				;Check if menu is on.
	adrne r6,PalCpy2
	adreq r6,PalCpy
;----------------------------------------------------------------------------
PalCpy
	and r0,r3,#0x3C0
	cmp r0,#0x80			;Where the menu palette is.
	subeq r3,r3,#0x40
PalCpy2
	subs r3,r3,#4
	ldr r0,[r2,r3]			;Source
	and r7,r4,r0,lsl#1
	ldrh r7,[r5,r7]			;Gamma
	and r0,r4,r0,lsr#15
	ldrh r0,[r5,r0]			;Gamma
	orr r0,r7,r0,lsl#16
	str r0,[r1,r3]			;Destination
	movhi pc,r6				;loop to PalCpy or PalCpy2

	ldmfd sp!,{r4-r7}
	bx lr
MappedColorPtr
	DCD MAPPED_RGB
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VDC_R;
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE	;VDC & VCE takes 1 more cycle to access
	ands r1,addy,#3
	beq _VDC0R
	cmp r1,#2
	bhi _VDC3R
	ldreqb r0,readlatch			;_VDC2R
	movmi r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
_VDC0R		;VDC Register
;----------------------------------------------------------------------------
	ldrb r0,vdcstat
	strb pce_a,vdcstat			;lower 8bits allways zero
	ldrb r1,irqPending
	bic r1,r1,#2				;clear VDC interrupt pending
	strb r1,irqPending
	mov pc,lr
;----------------------------------------------------------------------------
;_VDC2R		;VDC Data L
;----------------------------------------------------------------------------
;	ldrb r0,readlatch
;	mov pc,lr
;----------------------------------------------------------------------------
_VDC3R		;VDC Data H
;----------------------------------------------------------------------------
	ldrb r0,readlatch+1

	ldrb r1,vdcRegister			;what function
	cmp r1,#2					;only VRAM Read increases address.
	movne pc,lr
fillrlatch
	ldr r2,vram_r_adr
VRR_add
	add r1,r2,#0x00010000		;modified by VDC_CR_H_W
	str r1,vram_r_adr
	orr r2,r2,#0x80000000		;set GBA address

	mov r2,r2,ror#15
	ldrh r1,[r2]				;read from virtual PCE_VRAM
	str r1,readlatch

	mov pc,lr
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VDC_W;
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE	;VDC & VCE takes 1 more cycle to access
	and r1,addy,#3
	ldr pc,[pc,r1,lsl#2]		;VDC, what function
	DCD 0
	DCD _VDC0W					;VDC0
	DCD empty_IO_W				;VDC1
vdcRegPtrL						;VDC2
	DCD 0
vdcRegPtrH						;VDC3
	DCD 0

;----------------------------------------------------------------------------
_03;   ST0 #$nn store immediate value at VDC0
;----------------------------------------------------------------------------
	readmemimm
	adr lr,ST_ret
;----------------------------------------------------------------------------
_VDC0W		;VDC Register
;----------------------------------------------------------------------------
	and r0,r0,#0x1f
	strb r0,vdcRegister		;what function
	ldr r2,=VDC_write_tbl_L
	ldr r1,[r2,r0,lsl#2]!
	ldr r2,[r2,#0x80]
	adr r0,vdcRegPtrL
	stmia r0,{r1-r2}
	mov pc,lr
;----------------------------------------------------------------------------
_13;   ST1 #$nn store immediate value at VDC1
;----------------------------------------------------------------------------
	readmemimm
	adr lr,ST_ret
	ldr pc,vdcRegPtrL		;what function
;----------------------------------------------------------------------------
_23;   ST2 #$nn store immediate value at VDC2
;----------------------------------------------------------------------------
	readmemimm
	adr lr,ST_ret
	ldr pc,vdcRegPtrH		;what function
ST_ret
	fetch 4
;----------------------------------------------------------------------------
MAWR_L_W		;00
;----------------------------------------------------------------------------
	strb r0,vram_w_adr+2		;write low address
	mov pc,lr
;----------------------------------------------------------------------------
MAWR_H_W		;00
;----------------------------------------------------------------------------
	strb r0,vram_w_adr+3		;write high address
	mov pc,lr
;----------------------------------------------------------------------------
MARR_L_W		;01
;----------------------------------------------------------------------------
	strb r0,vram_r_adr+2		;read low address
	mov pc,lr
;----------------------------------------------------------------------------
MARR_H_W		;01
;----------------------------------------------------------------------------
	strb r0,vram_r_adr+3		;read high address
	b fillrlatch
;----------------------------------------------------------------------------
VRAM_L_W		;02
;----------------------------------------------------------------------------
	strb r0,writelatch			;data low
	mov pc,lr
;----------------------------------------------------------------------------
VRAM_H_W		;02
;----------------------------------------------------------------------------
	ldrb r1,writelatch
	orr r0,r1,r0,lsl#8

	ldr r2,vram_w_adr
VRW_add
	add r1,r2,#0x00010000		;modified by VDC_CR_H_W
	str r1,vram_w_adr
	eors r1,r2,#0x80000000

	movmi r1,r1,ror#15
	strmih r0,[r1]				;write to virtual PCE_VRAM
	movmi r0,#-1
	ldrmi r1,=DIRTYSPRITES
	strmib r0,[r1,r2,lsr#22]	;write to dirtymap

	mov pc,lr

;----------------------------------------------------------------------------
VDC_CR_L_W		;05
;----------------------------------------------------------------------------
	strb r0,vdcctrl1

	mov r1,#0x2440		;win0=on,1d sprites, BG2 enable. DISPCNTBUFF startvalue. 0x2440
	tst r0,#0x80		;bg en?
	orrne r1,r1,#0x0100
	tst r0,#0x40		;obj en?
	orrne r1,r1,#0x1000

	adr r2,ctrl1old
	swp r0,r1,[r2]		;r0=lastval

	ldr addy,scanline	;addy=scanline
	ldr r2,vblscanlinegfx	;r2=vblscanline
	cmp addy,r2
	movhi addy,r2
	adr r2,ctrl1line
	swp r1,addy,[r2]	;r1=lastline, lastline=scanline
ctrl1finish
	ldr r2,pcevdcbuffer
	add r1,r2,r1,lsl#1
	add r2,r2,addy,lsl#1
ct1	strh r0,[r2],#-2	;fill backwards from scanline to lastline
	cmp r2,r1
	bpl ct1
	mov pc,lr

ctrl1old	DCD 0x2440	;last write
ctrl1line	DCD 0 		;when?

;----------------------------------------------------------------------------
VDC_CR_H_W		;05
;----------------------------------------------------------------------------
	and r2,r0,#0x18
	adr r1,inctbl
	ldrb r0,[r1,r2,lsr#3]
	strb r0,vramaddrinc
	add r1,r1,#4
	ldr r0,[r1,r2,lsr#1]
	str r0,VRW_add
	str r0,VRR_add
	mov pc,lr
;----------------------------------------------------------------------------
inctbl
	DCB 1,32,64,128
	add r1,r2,#0x00010000		;#1
	add r1,r2,#0x00200000		;#32
	add r1,r2,#0x00400000		;#64
	add r1,r2,#0x00800000		;#128

;----------------------------------------------------------------------------
RstCmp_L_W		;06 Raster compare
;----------------------------------------------------------------------------
	strb r0,rasterCompare
	b rasterfix
;----------------------------------------------------------------------------
RstCmp_H_W		;06 Raster compare
;----------------------------------------------------------------------------
	and r0,r0,#3
	strb r0,rasterCompare+1
;------------------
rasterfix
;------------------
	ldr r0,rasterCompare
	sub r0,r0,#0x40
	str r0,rasterCompareCPU
	mov pc,lr
;----------------------------------------------------------------------------
ScrolX_L_W		;07
;----------------------------------------------------------------------------
	strb r0,scrollX
	b newX					;"Toy Shop Boys" requires this.
;	mov pc,lr
;----------------------------------------------------------------------------
ScrolX_H_W		;07
;----------------------------------------------------------------------------
	and r0,r0,#3
	strb r0,scrollX+1
bgscrollX
newX			;ctrl0_W, loadstate jumps here
	ldr r0,scrollX
	adr r2,scrollXold
	swp r0,r0,[r2]			;r0=lastval

	ldr addy,scanline		;addy=scanline

;	ldr r2,=1180*CYCLE
;	cmp cycles,r2
;	cmp cycles,#1184*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	cmp cycles,#1104*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	addmi addy,addy,#1

	cmp addy,#239
	movhi addy,#239
	adr r2,scrollXline
	swp r1,addy,[r2]		;r1=lastline, lastline=scanline
scrollXfinish				;newframe jumps here
	ldr r2,hcenter
	add r0,r0,r2
	ldr r2,scrollbuff
	add r1,r2,r1,lsl#2		;r1=end
	add r2,r2,addy,lsl#2	;r2=base
sx1	strh r0,[r2],#-4		;fill backwards from scanline to lastline
	cmp r2,r1
	bpl sx1
	mov pc,lr

scrollXold DCD 0 ;last write
scrollXline DCD 0 ;..was when?

;----------------------------------------------------------------------------
ScrolY_L_W		;08
;----------------------------------------------------------------------------
	strb r0,scrollY
	mov pc,lr
;----------------------------------------------------------------------------
ScrolY_H_W		;08
;----------------------------------------------------------------------------
	and r0,r0,#0x1
	strb r0,scrollY+1
newY
	ldr r0,scrollY
	add r0,r0,#1		;extra
	adr r2,scrollYold
	swp r0,r0,[r2]		;r0=lastval

	ldr addy,scanline	;addy=scanline

;	ldr r2,=1180*CYCLE
;	cmp cycles,r2
;	cmp cycles,#1184*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	cmp cycles,#1104*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	addmi addy,addy,#1

	cmp addy,#239
	movhi addy,#239
	adr r2,scrollYline
	swp r1,addy,[r2]		;r1=lastline, lastline=scanline
scrollYfinish				;newframe jumps here
	sub r0,r0,r1			;y-=scanline
	ldr r2,scrollbuff
	add r2,r2,#2			;r2+=2, flag Y write
	add r1,r2,r1,lsl#2		;r1=end
	add r2,r2,addy,lsl#2	;r2=base
sy1
	strh r0,[r2],#-4		;fill backwards from scanline to lastline
	cmp r2,r1
	bpl sy1
	mov pc,lr

scrollYold DCD 0 ;last write
scrollYline DCD 0 ;..was when?

;----------------------------------------------------------------------------
sprDMA_W			;sprite DMA transfer
;----------------------------------------------------------------------------
	ldrb r0,dosprdma
	cmp r0,#0
	moveq pc,lr

	ldrb r0,dmacr
	ands r0,r0,#0x10		;check for dma repetition
	streqb r0,dosprdma

	ldr r0,satAddr
	ldr r1,=PCE_VRAM
	add r0,r1,r0,lsl#1	;r0=DMA source
	ldr r1,pceoambuffer	;destination
	mov r2,#0x80		;length/4

	swi 0x0c0000		;BIOS memcopy(fast) (uses r0-r3).
	mov pc,lr
;----------------------------------------------------------------------------
sprDMA_do			;Called from endframe.
;----------------------------------------------------------------------------
PRIORITY EQU 0x800		;0x800=AGB OBJ priority 2
	str lr,[sp,#-4]!


	ldr r9,=SPRTILELUT
	ldrb r0,sprmemreload
	tst r0,#0xff
	beq noreload
	mov r0,r9				;r0=destination
	mov r1,#0				;r1=value
	mov r2,#768				;512+256 tile entries
	bl memset_				;clear lut
	strb r1,sprmemreload	;clear spr mem reload.
	strb r1,sprmemalloc		;clear spr mem alloc.
noreload

	ldr addy,pceoambuffer	;Source
	ldr r2,tmpoambuffer		;Destination

	ldr r8,=DIRTYSPRITES
	ldr r1,emuflags
	and r5,r1,#0x300
	cmp r5,#SCALED_SPRITES*256
	moveq r6,#2		;r6=ypos scale diff
	movne r6,#0

	mov r0,#0
	ldrb r4,ystart			;first scanline?
	cmp r5,#UNSCALED_AUTO*256	;do autoscroll
	bhi dm2
	movle r4,#0
	bne dm0
	ldr r3,AGBjoypad
	ands r3,r3,#0x300
	eornes r3,r3,#0x300
	bne dm0				;stop if L or R pressed (manual scroll)
	mov r3,r1,lsr#16			;r3=follow value
	tst r1,#FOLLOWMEM
	ldrneb r0,[pce_zpage,r3]	;follow memory
	moveq r3,r3,lsl#3
	ldreqh r0,[addy,r3]		;follow sprite
	bic r0,r0,#0xfe00
	subs r0,r0,#104			;something like that
	movmi r0,#0
	add r0,r0,r0,lsl#3
	mov r0,r0,lsr#4
	ldr r5,vblscanlinegfx	;<240
	sub r5,r5,#160
	cmp r0,r5
	movhi r0,r5
	str r0,windowtop+4
dm0
	ldr r0,windowtop+8
dm2
	add r4,r4,r0
	adrl r5,yscale_lookup
	sub r5,r5,r4

;	ldrb r0,[addy,#1]		;sprite tile#
;	mov r1,#AGB_VRAM
;	add r1,r1,#0x10000
;	add r0,r1,r0,lsl#5		;r0=VRAM base+tile*32
;	ldr r1,[r0]			;I don't really give a shit about Y flipping at the moment
;	cmp r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	ldreq r1,[r0,#4]!
;	cmpeq r1,#0
;	and r0,r0,#31
;	ldrb r1,[addy]			;r1=sprite0 Y
;	add r1,r1,#1
;	add r1,r1,r0,lsr#2
;	cmp r1,#239
;	movhi r1,#512			;no hit if Y>240
;	str r1,sprite0y

	adr lr,ret01
dm11
	ldr r7,=0x000003ff
	ldmia addy!,{r3,r4}	;PCE OBJ, r3=Y & X, r4=Pattern, flip, palette, prio & size.
	ands r0,r3,r7		;mask Y
	beq dm10			;skip if sprite Y=0
	cmp r0,#240+64
	bpl dm10			;skip if sprite Y>239+64
	ldr r1,hcenter		;(screenwidth-240)/2
	rsb r3,r1,r3,lsr#16	;x = x-(32+hcenter)
	and r3,r3,r7		;mask X
	cmp r3,#240+32
	bpl dm10			;skip if sprite X>239
	sub r3,r3,#32
	ldrb r0,[r5,r0]		;y = scaled y

	tst r4,#0x30000000	;check Ysize
	moveq r7,#1
	movne r7,#2
	subne r0,r0,r6		;r6=2 if scaled sprites
	tst r4,#0x20000000
	movne r7,#4			;length of spr copy.
	subne r0,r0,r6,lsl#1	;r6=2 if scaled sprites
	and r0,r0,#0xff

	and r1,r4,#0x29000000
	cmp r1,#0x28000000	;16x64 x-flipped.
	subeq r3,r3,#0x10
	bic r3,r3,#0xfe00
	orr r0,r0,r3,lsl#16

	movs r1,r4,lsr#24
	ldr r3,=flipsizeTable
	ldr r1,[r3,r1,lsl#2]
	orrcc r1,r1,#0x00000400	;Set Transp OBJ.
	orr r0,r0,r1
	str r0,[r2],#4		;store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape, prio(transp).

	mov r1,r4,lsl#22	;and 0x1ff
	mov r1,r1,lsr#23
	tst r4,#0x01000000	;check width
	bne VRAM_spr_32		;jump to spr copy, takes tile# in r1, gives new tile# in r0
	beq VRAM_spr_16		;--		lr allready points to ret01
ret01
	and r0,r0,#0xff		;tile mask
	mov r0,r0,lsl#2		;new tile# from spr routine.
	and r1,r4,#0x000f0000	;color
	orr r0,r0,r1,lsr#4
	orr r0,r0,#PRIORITY	;priority
	strh r0,[r2],#4		;store OBJ Atr 2. Pattern, palette.
dm9
	tst r2,#0x1f8
	bne dm11
	ldr pc,[sp],#4
dm10
	mov r0,#0x2a0		;double, y=160
	str r0,[r2],#8
	b dm9

;----------------------------------------------------------------------------
VRAM_spr_16;		takes tilenumber in r1, returns new tilenumber in r0
;----------------------------------------------------------------------------
	cmp r7,#2
	bicpl r1,r1,r7
	bichi r1,r1,r7,lsr#1
	ldr r0,[r9,r1,lsl#2]
	cmp r7,r0,lsr#16
	ble luthit16
noluthit16
	ldrb r0,sprmemalloc
	orr r0,r0,r7,lsl#16
	str r0,[r9,r1,lsl#2]
	stmfd sp!,{r0-r6,lr}

	cmp r7,#2
	addeq r4,r1,#2
	addeq r3,r0,#1		;r7= 1,2 or 4
	streq r3,[r9,r4,lsl#2]

	add r3,r0,r7		;r7= 1,2 or 4
	addhi r3,r3,r7		;16x64 sprite

	strb r3,sprmemalloc
	tst r3,#0x100
	movne r3,#0xab
	strneb r3,sprmemreload
	b do16
luthit16
	stmfd sp!,{r0-r6,lr}

	tst r7,#6		;check sprite height.
	beq cachehit00
	add r3,r8,r1
	ldrb r2,[r3]		;check dirtymap
	ldrb r4,[r3,#2]		;check dirtymap
	orr r2,r2,r4
	tst r2,#0x80
	beq cachehit16
	bic r2,r2,#0x80
	bic r4,r4,#0x80
	strb r2,[r3]		;clear dirtymap
	strb r4,[r3,#2]		;clear dirtymap
	b do16

cachehit00
	ldrb r2,[r8,r1]		;check dirtymap
	tst r2,#0x80
	beq cachehit16
	bic r2,r2,#0x80
	strb r2,[r8,r1]		;clear dirtymap
;-----------------------------------------------
do16
	and r0,r0,#0xff
	ldr r4,=PCE_VRAM+1
	adr r5,chr_decode
	mov r6,#AGB_VRAM	;r6=AGB BG tileset
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#7
	orr r6,r6,#0x10000	;spr ram

	tst r7,#4		;16x64 sprite
	bne spr16x64		;16x64 sprite
spr1
	ldrb r0,[r4],#2		;read 1st plane
	ldrb r1,[r4,#30]	;read 2nd plane
	ldrb r2,[r4,#62]	;read 3rd plane
	ldrb r3,[r4,#94]	;read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne spr1
	tst r6,#0x20
	subne r4,r4,#17
	bne spr1
	add r4,r4,#1

	tst r6,#0x40
	bne spr1

	subs r7,r7,#1		;nr of 16 blocks
	addne r4,r4,#224
	bne spr1

cachehit16
	ldmfd sp!,{r0-r6,pc}
;----------------------------------------------------------------------------
spr16x64
	ldrb r0,[r4],#2		;read 1st plane
	ldrb r1,[r4,#30]	;read 2nd plane
	ldrb r2,[r4,#62]	;read 3rd plane
	ldrb r3,[r4,#94]	;read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne spr16x64
	tst r6,#0x20
	subne r4,r4,#17
	bne spr16x64
	add r4,r4,#1

	mov r0,#0
	mov r1,#0x10
sprclr	str r0,[r6],#4
	subs r1,r1,#1
	bne sprclr

	tst r4,#0x10
	bne spr16x64

	subs r7,r7,#1		;nr of 16 blocks
	addne r4,r4,#224
	bne spr16x64

	ldmfd sp!,{r0-r6,pc}
;----------------------------------------------------------------------------
VRAM_spr_32;		takes tilenumber in r1, returns new tilenumber in r0
;----------------------------------------------------------------------------
	bic r1,r1,#1
	bic r1,r1,r7
	bic r1,r1,r7,lsr#1
	orr r3,r1,#0x400
	ldr r0,[r9,r3,lsl#1]
	cmp r7,r0,lsr#17
	ble luthit32
noluthit32
	ldrb r0,sprmemalloc
	orr r0,r0,r7,lsl#17
	str r0,[r9,r3,lsl#1]
	stmfd sp!,{r0-r6,lr}


	cmp r7,#2
	addpl r4,r3,#2
	addpl r5,r0,#2
	strpl r5,[r9,r4,lsl#1]

	addhi r4,r4,#2
	addhi r5,r5,#2
	strhi r5,[r9,r4,lsl#1]
	addhi r4,r4,#2
	addhi r5,r5,#2
	strhi r5,[r9,r4,lsl#1]

	add r3,r0,r7,lsl#1
	strb r3,sprmemalloc
	tst r3,#0x100
	movne r3,#0xab
	strneb r3,sprmemreload
	b do32
luthit32
	stmfd sp!,{r0-r6,lr}

	ldr r5,=0x40404040
	cmp r7,#2
	bmi cachehit01
	add r3,r8,r1
	beq cachehit02

	ldr r2,[r3,#4]		;check dirtymap
	tst r2,r5
	beq cachehit02
	bic r2,r2,r5
	str r2,[r3,#4]		;clear dirtymap
	ldr r2,[r3]			;check dirtymap
	bic r2,r2,r5
	str r2,[r3]			;clear dirtymap
	b do32
cachehit02
	ldr r2,[r3]			;check dirtymap
	tst r2,r5
	beq cachehit32
	bic r2,r2,r5
	str r2,[r3]			;clear dirtymap
	b do32

cachehit01
	ldrh r2,[r8,r1]		;check dirtymap
	tst r2,r5
	beq cachehit32
	bic r2,r2,r5
	strh r2,[r8,r1]		;clear dirtymap
;-----------------------------------------------
do32
	and r0,r0,#0xff
	ldr r4,=PCE_VRAM+1
	adr r5,chr_decode
	mov r6,#AGB_VRAM	;r6=AGB BG tileset
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#7
	orr r6,r6,#0x10000	;spr ram

spr2
	ldrb r0,[r4],#2		;read 1st plane
	ldrb r1,[r4,#30]	;read 2nd plane
	ldrb r2,[r4,#62]	;read 3rd plane
	ldrb r3,[r4,#94]	;read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	bne spr2
	tst r6,#0x20
	subne r4,r4,#17
	bne spr2

	tst r6,#0x040
	addne r4,r4,#113
	bne spr2

	tst r4,#0x010
	subne r4,r4,#127
	bne spr2

	subs r7,r7,#1		;nr of 16 blocks
	addne r4,r4,#97
	bne spr2

cachehit32
	ldmfd sp!,{r0-r6,pc}

;----------------------------------------------------------------------------

SF2Mapper  DCD 0
scrollbuff DCD SCROLLBUFF1
dmascrollbuff DCD SCROLLBUFF2

bgrbuff DCD BG0CNTBUFF1
dmabgrbuff DCD BG0CNTBUFF2

pceoambuffer DCD OAM_BUFFER1	;1->2->1.. (loop)
tmpoambuffer DCD OAM_BUFFER2	;pceoam->tmpoam->dmaoam
dmaoambuffer DCD OAM_BUFFER3	;triple buffered hell!!!
pcevdcbuffer DCD VDCBUFF1		;1->2->1.. (loop)
tmpvdcbuffer DCD VDCBUFF2		;pcevdc->tmpvdc->dmavdc
dmavdcbuffer DCD VDCBUFF3		;triple buffered hell!!!

oambufferready DCD 0
pcepaletteready DCD 0
;----------------------------------------------------------------------------
	AREA wram_globals1, CODE, READWRITE

FPSValue
	DCD 0
AGBinput		;this label here for main.c to use
	DCD 0 ;AGBjoypad (why is this in vdc.s again?  um.. i forget)
EMUinput	DCD 0 ;PCEjoypad (this is what PCE sees)
	DCD 1 ;adjustblend
	DCD 0		;windowtop
wtop	DCD 0,0,0	;windowtop  (this label too)   L/R scrolling in unscaled mode
	DCD 0		;hcenter
vdcstate
	DCD 0 ;palettePtr
	DCD 0 ;vram_w_adr
	DCD 0 ;vram_r_adr (temp)
	DCD 0 ;readlatch
	DCD 0 ;timCycles
	DCD 0 ;rasterCompare
	DCD 0 ;rasterCompareCPU
	DCD 0 ;scrollX
	DCD 0 ;scrollY
	DCD 0 ;SATPtr
	DCD 0 ;sprite0y
	DCD 0 ;dmasource
	DCD 0 ;dmadestination
	DCD 0 ;vdcvdw

	DCB 0 ;writelatch
	DCB 0 ;dmalength
	DCB 0 ;sprite0x
	DCB 0 ;vdcRegister
	DCB 1 ;vramaddrinc
	DCB 0 ;vdcstat
	DCB 0 ;mwreg		;memory width register
	DCB 0 ;vdcburst
	DCB 0 ;vdcctrl0frame	;state of $2000 at frame start
	DCB 0 ;vdcctrl1
	DCB 0 ;irqDisable	;from IO PCE1402
	DCB 0 ;irqPending	;from IO PCE1403
	DCB 0 ;timerLatch	;from IO PCE0c00
	DCB 0 ;timerEnable	;from IO PCE0c01
	DCB 0 ;iobuffer		;reads from $0800 -> $17ff
	DCB 0 ;bramaccess
	DCB 0 ;vdchdw
	DCB 0 ;vdcvds
	DCB 0 ;vdcvsw
	DCB 0 ;vdcvcr
	DCB 0 ;ystart
	DCB 0 ;dmacr
	DCB 0 ;dmairq
	DCB 0 ;dosprdma
	DCB 0 ;sprmemalloc
	DCB 0 ;sprmemreload
	DCB 0 ;chrmemalloc
	DCB 0 ;chrmemreload
;...update load/savestate if you move things around in here
;----------------------------------------------------------------------------
	END

