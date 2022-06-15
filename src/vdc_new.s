	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE cart.h
	INCLUDE io.h
	INCLUDE h6280.h
	INCLUDE sound.h

	EXPORT vdc_init
	EXPORT vdcreset_
	EXPORT VCE_R
	EXPORT VCE_W
	EXPORT VDC_R
	EXPORT VDC_W
	EXPORT _VDC0W
	EXPORT _VDC2W
	EXPORT _VDC3W
;	EXPORT agb_nt_map
;	EXPORT vram_map
	EXPORT sprDMA_W
	EXPORT debug_
	EXPORT AGBinput
	EXPORT PCEinput
	EXPORT paletteinit
	EXPORT PaletteTxAll
	EXPORT newframe
	EXPORT pce_palette
	EXPORT flipsizeTable
	EXPORT vdcstate
;	EXPORT writeBG
	EXPORT wtop
	EXPORT spritelag
	EXPORT gammavalue
;	EXPORT oambuffer
	EXPORT scrollbuff
	EXPORT bgrbuff
	EXPORT VDC_CR_L_W
	EXPORT VdcHdr_L_W
	EXPORT newX
	EXPORT SF2Mapper

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

	ldr r1,=AGB_IRQVECT
	ldr r2,=irqhandler
	str r2,[r1]

	mov r1,#REG_BASE
	mov r0,#0x0008
	strh r0,[r1,#REG_DISPSTAT]	;vblank en

	mov r0,#7
	strh r0,[r1,#REG_COLY]		;darkness setting for faded screens (bigger number=darker)

	mov r0,#240
	strh r0,[r1,#REG_WIN0H]		;Window 0 Horizontal position
	mov r0,#160
	strh r0,[r1,#REG_WIN0V]		;Window 0 Vertical position
	ldr r0,=0x0004003f
	str r0,[r1,#REG_WININ]		;Window 0 settings. BG2 allways on.



	add r0,r1,#REG_BG0HOFS		;DMA0 always goes here
	str r0,[r1,#REG_DM0DAD]
	mov r0,#1			;1 word transfer
	strh r0,[r1,#REG_DM0CNT_L]
	ldr r0,=DMA0BUFF+4		;dmasrc=
	str r0,[r1,#REG_DM0SAD]

	str r1,[r1,#REG_DM1DAD]		;DMA1 goes here
	mov r0,#1			;1 word transfer
	strh r0,[r1,#REG_DM1CNT_L]

	add r2,r1,#REG_IE
	mov r0,#-1
	strh r0,[r2,#2]		;stop pending interrupts
	ldr r0,=0x1091
	strh r0,[r2]		;key,vblank,timer1,serial interrupt enable
	mov r0,#1
	strh r0,[r2,#8]		;master irq enable

	bx addy
;----------------------------------------------------------------------------
vdcreset_	;called with CPU reset
;----------------------------------------------------------------------------
	mov r0,#0
	strb r0,vdcctrl0	;VDC IRQ's off
	strb r0,vdcctrl1	;screen off
	strb r0,vdcstat		;flags off

	strb r0,ystart
	str r0,windowtop

	mov r9,lr
;	mov r0,#0
	ldr r1,=vdcstate
	mov r2,#21		;21*4
	bl filler_		;clear VDC regs

	mov r0,#1
	strb r0,vramaddrinc
	strb r0,sprmemreload
	mov r0,#-1
	str r0,rasterCompareCPU

	mov r0,#0x10		;dma repetition, helps Takeda Shingen.
	strb r0,dmacr


	bl paletteinit	;do palette mapping
	mov pc,r9

;----------------------------------------------------------------------------
paletteinit;	r0-r3 modified.
;called by ui.c:  void map_palette(char gammavalue)
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r8,lr}
	ldr r6,=MAPPED_RGB
	mov r4,#0		;pce rgb, r1=R, r2=G, r3=B
	ldr r0,=gammavalue
	ldr r5,[r0]		;gamma value = 0 -> 4
nomap				;map 0000000gggrrrbbb  ->  0bbbbbgggggrrrrr
	and r0,r4,#0x038
	orr r0,r0,r0,lsr#3	;Red ready
	bl gammaconvert
	mov r1,r0

	and r0,r4,#0x1c0
	orr r0,r0,r0,lsr#3
	mov r0,r0,lsr#3		;Green ready
	bl gammaconvert
	orr r1,r1,r0,lsl#5

	and r0,r4,#0x007
	orr r0,r0,r0,lsl#3	;Blue ready
	bl gammaconvert
	orr r1,r1,r0,lsl#10

	mov r7,r4,lsl#1
	strh r1,[r6,r7]
	add r4,r4,#1
	cmp r4,#512
	bne nomap

	ldmfd sp!,{r4-r8,lr}
	bx lr

;----------------------------------------------------------------------------
gammaconvert;	takes value in r0=0x3f, returns new value in r0=0x1f
;----------------------------------------------------------------------------
	eor r8,r0,#0x3f
	mul r7,r8,r8
	add r7,r7,#80
	mov r8,r7,lsr#6
	eor r8,r8,#0x3f
	rsb r7,r5,#4
	mul r8,r5,r8
	mul r0,r7,r0
	add r0,r0,r8
	mov r0,r0,lsr#3

	mov pc,lr
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

;	DCD 0x20000000,0x20000000,

;bgsizetbl
;	DCD VRAM_name32,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name64,VRAM_name64,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name32,VRAM_name32,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name64,VRAM_name64,VRAM_name64,VRAM_name64,VRAM_tiles,VRAM_tiles,VRAM_tiles,VRAM_tiles
;	DCD VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128
;	DCD VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128,VRAM_name128
;vram_write_tbl			;for vmdata_W, r0=data, addy=vram addr
;	DCD VRAM_name32		;0x0000
;	DCD VRAM_tiles		;0x0800
;----------------------------------------------------------------------------
VCE_R;		Video Color Encoder  read
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE		;VDC & VCE takes 1 more cycle to access
	and r2,addy,#7
	ldr pc,[pc,r2,lsl#2]
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
	and r2,addy,#7
	ldr pc,[pc,r2,lsl#2]
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
	ldr r2,palettePtr
	ldr r1,=pce_palette
	ldrb r0,[r1,r2,lsl#1]	;load from pce palette
	mov pc,lr
;----------------------------------------------------------------------------
_0405R		;VCE CTD H
;----------------------------------------------------------------------------
	ldr r2,palettePtr
	ldr r1,=pce_palette+1
	ldrb r0,[r1,r2,lsl#1]	;load from pce palette
	orr r0,r0,#0xfe		;not really necesary?
	add r2,r2,#1
	bic r2,r2,#0xFE00	;and 0x1FF
	str r2,palettePtr
	mov pc,lr
;----------------------------------------------------------------------------
_0400W		;VCE CR - dotclock, interlace, color.
;----------------------------------------------------------------------------
	mov pc,lr
;----------------------------------------------------------------------------
_0402W		;VCE Color Table Address L
;----------------------------------------------------------------------------
	strb r0,palettePtr
	mov pc,lr
;----------------------------------------------------------------------------
_0403W		;VCE Color Table Address H
;----------------------------------------------------------------------------
	and r0,r0,#1
	strb r0,palettePtr+1
	mov pc,lr
;----------------------------------------------------------------------------
_0404W		;VCE Color Table Data L
;----------------------------------------------------------------------------
	ldr r2,palettePtr
	ldr r1,=pce_palette
	strb r0,[r1,r2,lsl#1]	;store in pce palette
	b PaletteTx
;----------------------------------------------------------------------------
_0405W		;VCE Color Table Data H
;----------------------------------------------------------------------------
	ldr r2,palettePtr
	ldr r1,=pce_palette+1
	strb r0,[r1,r2,lsl#1]	;store in pce palette
	add r0,r2,#1
	bic r0,r0,#0xFE00	;and 0x1FF
	str r0,palettePtr
	b PaletteTx

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VDC_R;
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE		;VDC & VCE takes 1 more cycle to access
	ands r2,addy,#3
	beq _VDC0R
	cmp r2,#2
	beq _VDC2R
	bhi _VDC3R
	mov r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
_VDC0R		;VDC Register
;----------------------------------------------------------------------------
	ldrb r0,vdcstat
	mov r1,#0
	strb r1,vdcstat
	ldrb r1,irqPending
	bic r1,r1,#2			;clear VDC interrupt pending
	strb r1,irqPending
	mov pc,lr
;----------------------------------------------------------------------------
_VDC2R		;VDC Data L
;----------------------------------------------------------------------------
	ldrb r0,readlatch
	mov pc,lr
;----------------------------------------------------------------------------
_VDC3R		;VDC Data H
;----------------------------------------------------------------------------
	ldrb r0,readlatch+1

	ldrb r2,vdcRegister		;what function
	cmp r2,#2			;only VRAM Read increases address.
	movne pc,lr
fillrlatch
	ldrb r1,vramaddrinc
	ldr addy,vram_r_adr
	add r2,addy,r1
	bic r2,r2,#0xf8000 ;AND $7fff
	str r2,vram_r_adr

	add addy,addy,addy
	ldr r2,=PCE_VRAM
	ldrh r1,[r2,addy]		;read from virtual PCE_VRAM
	str r1,readlatch

	mov pc,lr
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
VDC_W;
;----------------------------------------------------------------------------
	sub cycles,cycles,#3*CYCLE		;VDC & VCE takes 1 more cycle to access
	ands r2,addy,#3
	beq _VDC0W
	cmp r2,#2
	adreq r1,VDC_write_tbl_L
	adrhi r1,VDC_write_tbl_H
	ldrplb r2,vdcRegister		;what function
	ldrpl pc,[r1,r2,lsl#2]
	mov pc,lr
;----------------------------------------------------------------------------
_VDC0W		;VDC Register
;----------------------------------------------------------------------------
	and r1,r0,#0x1f
	strb r1,vdcRegister		;what function
	mov pc,lr
;----------------------------------------------------------------------------
_VDC2W		;VDC Data L
;----------------------------------------------------------------------------
	ldrb r2,vdcRegister		;what function
	ldr pc,[pc,r2,lsl#2]
;---------------------------
	DCD 0
VDC_write_tbl_L
	DCD MAWR_L_W		;00 Mem Adr Write Reg
	DCD MARR_L_W		;01 Mem Adr Read Reg
	DCD VRAM_L_W		;02 VRAM write
	DCD empty_W
	DCD empty_W
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
	DCD empty_W		;14
	DCD empty_W		;15
	DCD empty_W		;16
	DCD empty_W		;17
	DCD empty_W		;18
	DCD empty_W		;19
	DCD empty_W		;1A
	DCD empty_W		;1B
	DCD empty_W		;1C
	DCD empty_W		;1D
	DCD empty_W		;1E
	DCD empty_W		;1F
;----------------------------------------------------------------------------
_VDC3W		;VDC Data H
;----------------------------------------------------------------------------
	ldrb r2,vdcRegister		;what function
	ldr pc,[pc,r2,lsl#2]
;---------------------------
	DCD 0
VDC_write_tbl_H
	DCD MAWR_H_W		;00 Mem Adr Write Reg
	DCD MARR_H_W		;01 Mem Adr Read Reg
	DCD VRAM_H_W		;02 VRAM write
	DCD empty_W
	DCD empty_W
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
	DCD empty_W		;14
	DCD empty_W		;15
	DCD empty_W		;16
	DCD empty_W		;17
	DCD empty_W		;18
	DCD empty_W		;19
	DCD empty_W		;1A
	DCD empty_W		;1B
	DCD empty_W		;1C
	DCD empty_W		;1D
	DCD empty_W		;1E
	DCD empty_W		;1F

;----------------------------------------------------------------------------
MAWR_L_W		;00
;----------------------------------------------------------------------------
	strb r0,vram_w_adr	;write low address
	mov pc,lr
;----------------------------------------------------------------------------
MAWR_H_W		;00
;----------------------------------------------------------------------------
	strb r0,vram_w_adr+1	;write high address
	mov pc,lr
;----------------------------------------------------------------------------
MARR_L_W		;01
;----------------------------------------------------------------------------
	strb r0,vram_r_adr	;read low address
	mov pc,lr
;----------------------------------------------------------------------------
MARR_H_W		;01
;----------------------------------------------------------------------------
	strb r0,vram_r_adr+1	;read high address
	b fillrlatch
;----------------------------------------------------------------------------
MemWid_L_W		;09 Memory Width (Bgr virtual size)
;----------------------------------------------------------------------------
	strb r0,mwreg
	b mirrorPCE
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
	mov pc,lr
;----------------------------------------------------------------------------
VdcHdr_L_W		;0B Horizontal Display Reg, width.
;----------------------------------------------------------------------------
	mov r1,#REG_BASE
	and r0,r0,#0x7f
	strb r0,vdchdw
	add r0,r0,#1
	mov r0,r0,lsl#3
	sub r0,r0,#240
	movs r0,r0,asr#1
	str r0,hcenter
	movpl r0,#0

	add r2,r0,#240
	rsb r0,r0,#0			;r0 = -r0
	orr r0,r2,r0,lsl#8
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
	b calcVBL
;----------------------------------------------------------------------------
VdcVcr_L_W		;0E Vertical Display End Reg, how much is blanked after the display (+3)
;----------------------------------------------------------------------------
	strb r0,vdcvcr
	mov pc,lr
;----------------------------------------------------------------------------
VdcVcr_H_W		;0E Vertical Display End Reg
;----------------------------------------------------------------------------

	mov pc,lr
;----------------------------------------------------------------------------
calcVBL
;	ldrb r0,vdcvsw
;	ldrb r1,vdcvds
;	add r0,r0,r1
	adrl r1,vdcvdw
	ldrh r0,[r1]
	add r0,r0,#1
	cmp r0,#241		;Rastan Saga II needs this. Timing?
	movhi r0,#241
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
DMACtl_L_W		;0F DMA Control Reg
;----------------------------------------------------------------------------
	strb r0,dmacr
	tst r0,#0x10		;check for dma repetition
	movne r1,#-1
	strneb r1,dosprdma
;----------------------------------------------------------------------------
DMACtl_H_W		;0F DMA Control Reg
;----------------------------------------------------------------------------
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
	strb r0,dmadestination
	mov pc,lr
;----------------------------------------------------------------------------
DMADst_H_W		;11 DMA Destination Reg
;----------------------------------------------------------------------------
	strb r0,dmadestination+1
	mov pc,lr
;----------------------------------------------------------------------------
DMALen_L_W		;12 DMA Length Reg
;----------------------------------------------------------------------------
	strb r0,dmalength
	mov pc,lr
;----------------------------------------------------------------------------
DMALen_H_W		;12 DMA Length Reg, this starts the transfer.
;----------------------------------------------------------------------------
;	mov pc,lr
;dmadum	b dmadum		;for testing of VRAM DMA (Davis Cup Tennis, Gaia no Monsho, Legendary Axe II, Magical Chase, Ninja Warriors).

	stmfd sp!,{r3-r8,lr}
	ldrb r1,dmalength
	orr r2,r1,r0,lsl#8
	
	ldrb r0,dmacr
	tst r0,#4
	moveq r7,#2			;Source increase
	movne r7,#-2			;Source decrease
	tst r0,#8
	moveq r8,#2			;Destination increase
	movne r8,#-2			;Destination decrease
	mov r1,#-1
	ldr r3,=PCE_VRAM
	ldr r4,dmasource
	add r4,r4,r4
	ldr r5,dmadestination
	add r5,r5,r5
	ldr r6,=DIRTYSPRITES
	adr lr,dmaret0
vramdmaloop
	ldrh r0,[r3,r4]			;read from virtual PCE_VRAM

	tst r5,#0x10000
	streqb r1,[r6,r5,lsr#7]		;write to dirtymap, r1=-1.
	streqh r0,[r3,r5]		;write to virtual PCE_VRAM
dmaret0
	add r4,r4,r7
	add r5,r5,r8
	subs r2,r2,#1
	bpl vramdmaloop

	strb r2,dmalength
	mov r5,r5,lsr#1
	bic r5,r5,#0xff0000
	str r5,dmadestination
	mov r4,r4,lsr#1
	bic r4,r4,#0xff0000
	str r4,dmasource
	ldrb r0,dmacr
	strb r0,dmairq

	ldmfd sp!,{r3-r8,pc}
;----------------------------------------------------------------------------
DMAOAM_L_W		;13 DMA Sprite Attribute Table
;----------------------------------------------------------------------------
	strb r0,satAddr
	mov r1,#-1
	strb r1,dosprdma
	mov pc,lr
;----------------------------------------------------------------------------
DMAOAM_H_W		;13 DMA Sprite Attribute Table
;----------------------------------------------------------------------------
	strb r0,satAddr+1
	mov r1,#-1
	strb r1,dosprdma
	mov pc,lr

;----------------------------------------------------------------------------
PaletteTxAll		; Called from ui.c
;----------------------------------------------------------------------------
	stmfd sp!,{r0-r4,lr}
	mov r1,#0xfffe03ff
	mov r4,#AGB_PALETTE		;palette transfer
	ldr r3,=MAPPED_RGB
	ldr r2,=pce_palette
nf8	ldrh r0,[r2],#2
	and r0,r1,r0,lsl#1
	ldrh r0,[r3,r0]
	strh r0,[r4],#2
	tst r4,#0x400
	beq nf8
	ldmfd sp!,{r0-r4,lr}
	bx lr
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	AREA wram_code1, CODE, READWRITE
irqhandler	;r0-r3,r12 are safe to use
;----------------------------------------------------------------------------
	mov r2,#REG_BASE
	ldr r1,[r2,#REG_IE]!
	and r1,r1,r1,lsr#16	;r1=IE&IF

		;---these CAN'T be interrupted
		ands r0,r1,#0x80
		strneh r0,[r2,#2]		;IF clear
		bne serialinterrupt
		;---
		adr r12,irq0

		;---these CAN be interrupted
		ands r0,r1,#0x01
		ldrne r12,=vblankinterrupt
		bne jmpintr
		ands r0,r1,#0x10
		ldrne r12,=timer1interrupt
		;----
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
	bx lr
;----------------------------------------------------------------------------
twitch DCD 0
vblankinterrupt;
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,globalptr,lr}

	ldr r0,=agb_vbl
	strb r1,[r0]

;--------------------------------- FPS counter
 [ DEBUG
	ldr r2,=fps1
	ldrb r1,[r2,#1]
	add r1,r1,#1
	cmp r1,#60
	moveq r1,#0
	strb r1,[r2,#1]
	ldreqb r0,[r2]
	streqb r1,[r2]
	moveq r1,#19
	bleq debug_
 ]
;---------------------------------


	ldr globalptr,=|wram_globals0$$Base|

	ldr r2,=DMA0BUFF	;setup DMA buffer for scrolling:
	add r3,r2,#160*4
	ldr r1,dmascrollbuff
        ldrb r0,emuflags+1
	cmp r0,#SCALED
	bhs vbl0

	ldr r0,windowtop+12
	add r1,r1,r0,lsl#2		;(unscaled)
vbl6	ldmia r1!,{r0,r4-r7}
	stmia r2!,{r0,r4-r7}
	cmp r2,r3
	bmi vbl6
	b vbl5
vbl0					;(scaled)
	ldrb r4,ystart
	mov r4,r4,lsl#16

	ldr r0,twitch
	eors r0,r0,#1
	str r0,twitch
		ldrh r5,[r1,#2]	 ;adjust vertical scroll to avoid screen wobblies
	add r1,r1,r4,lsr#14
	ldreq r0,[r1],#4
	addeq r0,r0,r4
	streq r0,[r2],#4
		ldr r0,adjustblend
		add r0,r0,r5
		ands r0,r0,#3
		str r0,totalblend
		beq vbl2
		cmp r0,#2
		bmi vbl3
		beq vbl4

vbl1	ldr r0,[r1],#4
	add r0,r0,r4
	str r0,[r2],#4
vbl2	ldr r0,[r1],#4
	add r0,r0,r4
	str r0,[r2],#4
vbl3	ldr r0,[r1],#4
	add r0,r0,r4
	str r0,[r2],#4
vbl4	add r1,r1,#4
	add r4,r4,#0x10000
	cmp r2,r3
	bmi vbl1
vbl5

;	ldr r1,dmabgrbuff
;	ldrb r2,ystart
;	add r1,r1,r2,lsl#1
;	ldr r2,=DMA3BUFF
;	bl nf0

        ldrb r0,emuflags+1		;get DMA1,3 source..
	cmp r0,#SCALED
	ldrhs r3,=DMA1BUFF
;	ldrhs r4,=DMA3BUFF
;	ldr r4,bgrbuff
	bhs vbl7
	ldr r0,windowtop+12
	ldr r3,=DISPCNTBUFF
;	ldr r4,bgrbuff			;dmabgrbuff
	add r3,r3,r0,lsl#1
;	add r4,r4,r0,lsl#1
vbl7
	mov r1,#REG_BASE
	strh r1,[r1,#REG_DM0CNT_H]	;DMA stop
	strh r1,[r1,#REG_DM1CNT_H]
	strh r1,[r1,#REG_DM3CNT_H]

	ldr r0,oambufferready
	cmp r0,#0
	ldrne r0,dmaoambuffer		;OAM transfer:
	strne r0,[r1,#REG_DM3SAD]
	movne r0,#AGB_OAM
	strne r0,[r1,#REG_DM3DAD]
	movne r0,#0x84000000			;noIRQ hblank 32bit repeat incsrc fixeddst
	orrne r0,r0,#0x80				;128 words (512 bytes)
	strne r0,[r1,#REG_DM3CNT_L]		;DMA go

	ldr r0,=DMA0BUFF		;setup HBLANK DMA for display scroll:
	ldr r2,[r0],#4
	str r2,[r1,#REG_BG0HOFS]		;set 1st value manually, HBL is AFTER 1st line
	ldr r0,=0xA660				;noIRQ hblank 32bit repeat incsrc inc_reloaddst
	strh r0,[r1,#REG_DM0CNT_H]		;DMA go
					;setup HBLANK DMA for DISPCNT (BG/OBJ enable)
	ldrh r2,[r3],#2
	strh r2,[r1,#REG_DISPCNT]		;set 1st value manually, HBL is AFTER 1st line
	str r3,[r1,#REG_DM1SAD]			;dmasrc=
	ldr r0,=0xA240				;noIRQ hblank 16bit repeat incsrc fixeddst
	strh r0,[r1,#REG_DM1CNT_H]		;DMA go
					;setup HBLANK DMA for BG CHR
;	add r0,r1,#REG_BG0CNT
;	str r0,[r1,#REG_DM3DAD]
;	ldr r2,[r4],#2
	ldr r2,BGmirror
	strh r2,[r1,#REG_BG0CNT]
;	str r4,[r1,#REG_DM3SAD]
;	ldr r0,=0xA2400001			;noIRQ hblank 16bit repeat incsrc fixeddst, 1 word transfer
;	str r0,[r1,#REG_DM3CNT_L]		;DMA go

	ldmfd sp!,{r4-r7,globalptr,pc}

totalblend	DCD 0


;----------------------------------------------------------------------------
nf0	add r3,r2,#160*2
		ldr r0,twitch
		tst r0,#1
	ldreqh r0,[r1],#2
	streqh r0,[r2],#2
		ldr r0,totalblend
		ands r0,r0,#3
		beq nf21
		cmp r0,#2
		bmi nf22
		addeq r1,r1,#2
nf20	ldrh r0,[r1],#2
	strh r0,[r2],#2
nf21		ldrh r0,[r1],#2
		strh r0,[r2],#2
nf22	ldrh r0,[r1],#4
	strh r0,[r2],#2
	cmp r2,r3
	bmi nf20
	mov pc,lr
;----------------------------------------------------------------------------
newframe	;called at line 0	(r0-r9 safe to use)
;----------------------------------------------------------------------------
	str lr,[sp,#-4]!

;-----------------------
	ldr r0,ctrl1old
	ldr r1,ctrl1line
	ldr addy,vblscanlinegfx
	bl ctrl1finish
	mov r0,#0x0440			;DISPCNTBUFF
	ldr r1,vblscanlinegfx
	mov addy,#239
	bl ctrl1finish
	mov r0,#0
	str r0,ctrl1line
;-----------------------
	bl chrfinish
;------------------------
	ldr r0,scrollX
	adr r1,scrollXold
	swp r0,r0,[r1]		;r0=lastval
	ldr r1,scrollXline
	mov addy,#239
	bl scrollXfinish
	mov r0,#0
	str r0,scrollXline
;--------------------------
	ldr r0,scrollY
;	sub r0,r0,#1
	adr r1,scrollYold
	swp r0,r0,[r1]		;r0=lastval
	ldr r1,scrollYline
	mov addy,#239
	bl scrollYfinish
	mov r0,#0
	str r0,scrollYline
;--------------------------
	bl sprDMA_do

	ldr r0,scrollbuff
	ldr r1,dmascrollbuff
	str r1,scrollbuff
	str r0,dmascrollbuff

;	ldr r0,bgrbuff
;	ldr r1,dmabgrbuff
;	str r1,bgrbuff
;	str r0,dmabgrbuff

	adrl r0,windowtop	;load wtop, store in wtop+4.......load wtop+8, store in wtop+12
	ldmia r0,{r1-r3}	;load with post increment
	stmib r0,{r1-r3}	;store with pre increment

	ldrb r0,emuflags+1             ;refresh DMA1,DMA2 buffers
	cmp r0,#SCALED				;not needed for unscaled mode..
	bmi nf7					;(DMA'd directly from dispcntbuff/bg0cntbuff)

	ldr r1,=DISPCNTBUFF			;(scaled)
	ldrb r2,ystart
	add r1,r1,r2,lsl#1
	ldr r2,=DMA1BUFF
	bl nf0
nf7
	ldr pc,[sp],#4
;----------------------------------------------------------------------------
PaletteTx		; takes palette number in r2
;----------------------------------------------------------------------------
	ldr r1,dontstop
	cmp r1,#0			;Check if menu is on.
	andeq r1,r2,#0x1e0
	cmpeq r1,#0x40			;Where the menu palette is.
	moveq pc,lr

	adrl r1,pce_palette
	add r1,r1,r2,lsl#1
	ldrh r0,[r1]
	mov r1,#0xfffe03ff
	and r0,r1,r0,lsl#1
	mov r1,#AGB_PALETTE		;palette transfer
	add r1,r1,r2,lsl#1
	ldr r2,=MAPPED_RGB
	ldrh r0,[r2,r0]
	strh r0,[r1]
	mov pc,lr
;----------------------------------------------------------------------------
VRAM_L_W		;02
;----------------------------------------------------------------------------
	strb r0,writelatch	;data low
	mov pc,lr
;----------------------------------------------------------------------------
VRAM_H_W		;02
;----------------------------------------------------------------------------
	ldrb r1,writelatch
	orr r0,r1,r0,lsl#8

	ldr addy,vram_w_adr
	ldrb r1,vramaddrinc
	bic addy,addy,#0xf0000 ;AND $ffff
	add r2,addy,r1
	str r2,vram_w_adr
	tst addy,#0x8000

	moveq r1,#-1
	addeq addy,addy,addy
	ldreq r2,=DIRTYSPRITES
	streqb r1,[r2,addy,lsr#7]		;write to dirtymap, r1!=0.
	ldreq r2,=PCE_VRAM
	streqh r0,[r2,addy]		;write to virtual PCE_VRAM

	mov pc,lr				;return if addy>=0x8000

;----------------------------------------------------------------------------
VDC_CR_L_W		;05
;----------------------------------------------------------------------------
	strb r0,vdcctrl1

	mov r1,#0x2400		;win0=on,2d sprites, BG2 enable. DISPCNTBUFF startvalue. 0x0440
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
	ldr r2,=DISPCNTBUFF
	add r1,r2,r1,lsl#1
	add r2,r2,addy,lsl#1
ct1	strh r0,[r2],#-2	;fill backwards from scanline to lastline
	cmp r2,r1
	bpl ct1

	mov pc,lr

ctrl1old	DCD 0x2440	;last write
ctrl1line	DCD 0 ;when?

;----------------------------------------------------------------------------
VDC_CR_H_W		;05
;----------------------------------------------------------------------------
	and r2,r0,#0x18
	adr r1,inctbl
	ldrb r0,[r1,r2,lsr#3]
	strb r0,vramaddrinc
	mov pc,lr
;----------------------------------------------------------------------------
inctbl	DCB 1,32,64,128
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
	b newX			;"Toy Shop Boys" requires this.
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
	swp r0,r0,[r2]		;r0=lastval

	ldr addy,scanline	;addy=scanline

;	ldr r2,=1128*CYCLE
;	cmp cycles,r2
	cmp cycles,#1104*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	addmi addy,addy,#1

	cmp addy,#239
	movhi addy,#239
	adr r2,scrollXline
	swp r1,addy,[r2]	;r1=lastline, lastline=scanline
scrollXfinish			;newframe jumps here
	ldr r2,hcenter
	add r0,r0,r2
	ldr r2,scrollbuff
	add r1,r2,r1,lsl#2
	add r2,r2,addy,lsl#2
sx1	strh r0,[r2],#-4	;fill backwards from scanline to lastline
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

	ldr r2,=1128*CYCLE
	cmp cycles,r2
;	cmp cycles,#1104*CYCLE	;Operation Wolf <= 1128, Fantazy Zone >= 1129, Devil's Crush >= 1160
	addmi addy,addy,#1

	cmp addy,#239
	movhi addy,#239
	adr r2,scrollYline
	swp r1,addy,[r2]	;r1=lastline, lastline=scanline
scrollYfinish			;newframe jumps here
	sub r0,r0,r1		;y-=scanline
	ldr r2,windowtop+8
	add r0,r0,r2		;y+=windowtop
	ldr r2,scrollbuff
	add r2,r2,#2		;r2+=2, flag Y write
	add r1,r2,r1,lsl#2	;r1=end2
	add r2,r2,addy,lsl#2	;r2=base
sy1
	strh r0,[r2],#-4
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

	stmfd sp!,{r1,r3,lr}
	ldrb r0,dmacr
	tst r0,#0x10		;check for dma repetition
	moveq r1,#0
	streqb r1,dosprdma

	ldr r0,satAddr
	ldr r1,=PCE_VRAM
	add r0,r1,r0,lsl#1	;addy=DMA source
	ldr r1,oambuffer	;destination
	mov r2,#0x80		;length/4

	swi 0x0c0000		;BIOS memcopy(fast) (uses r0-r3).
	ldmfd sp!,{r1,r3,pc}
;----------------------------------------------------------------------------
sprDMA_do			;Called from newframe.
;----------------------------------------------------------------------------
PRIORITY EQU 0x800		;0x800=AGB OBJ priority 2
	str lr,[sp,#-4]!

	mov r0,#0
	str r0,oambufferready

	ldr r9,=SPRTILELUT
	ldrb r0,sprmemreload
	tst r0,#0xff
	beq noreload
	mov r0,#0
	mov r1,r9
	mov r2,#768		;512+256 tile entries
	bl filler_		;clear lut
	strb r0,sprmemreload	;clear spr mem reload.
	strb r0,sprmemalloc	;clear spr mem alloc.
noreload

	ldr addy,oambuffer	;Source
	ldr r2,dmaoambuffer	;Destination

	ldr r8,=DIRTYSPRITES
        ldr r1,emuflags
	and r5,r1,#0x300
	cmp r5,#SCALED_SPRITES*256
	moveq r6,#2		;r6=ypos scale diff
	movne r6,#0

	ldrb r4,ystart			;first scanline?
	cmp r5,#UNSCALED_AUTO*256	;do autoscroll
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
	cmp r0,#239
	bhi dm0
	add r0,r0,r0,lsl#3
	mov r0,r0,lsr#4
	str r0,windowtop
dm0
	ldr r0,windowtop+4
	add r0,r0,r4
	adrl r5,yscale_lookup
	sub r5,r5,r0

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
	ldr r3,[addy],#4	;PCE OBJ Y,X
	ldr r4,[addy],#4	;PCE OBJ Pattern, flip, palette, prio, size.
	ands r0,r3,r7		;mask Y
	beq dm10		;skip if sprite Y=0
	cmp r0,#240+64
	bpl dm10		;skip if sprite Y>239+64
	ldr r1,hcenter		;(screenwidth-240)/2
	rsb r3,r1,r3,lsr#16	;x = x-(32+hcenter)
	and r3,r3,r7		;mask X
	cmp r3,#240+32
	bpl dm10		;skip if sprite X>239
	sub r3,r3,#32
	ldrb r0,[r5,r0]		;y = scaled y

	tst r4,#0x30000000	;check Ysize
	moveq r7,#1		;height=16
	movne r7,#2		;height=32
	subne r0,r0,r6		;r6=2 if scaled sprites
	tst r4,#0x20000000
	movne r7,#4		;height=64, length of spr copy.
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
;	and r0,r0,#0xff		;tile mask
	add r0,r0,r0		;new tile# from spr routine.
	and r1,r4,#0x000f0000	;color
	orr r0,r0,r1,lsr#4
	orr r0,r0,#PRIORITY	;priority
	strh r0,[r2],#4		;store OBJ Atr 2. Pattern, palette.
dm9
	tst r2,#0x1f8
	bne dm11

	ldr r0,spritelag
	cmp r0,#0
	ldreq r0,dmaoambuffer
	ldreq r1,tmpoambuffer
	streq r0,tmpoambuffer
	streq r1,dmaoambuffer

	mov r0,#1
	str r0,oambufferready
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
	bic r3,r1,#7
	ldr r0,[r9,r3,lsr#1]
	cmp r0,#0x00010000
	bhi luthit16
noluthit16
	mov r7,#4			;When allocating, redraw whole 32x64.
	ldrb r0,sprmemalloc
	orr r0,r0,r7,lsl#17
	str r0,[r9,r3,lsr#1]

	and r3,r0,#7
	eor r0,r0,r3
	orr r3,r3,r0,lsl#3
	and r0,r1,#6
	orr r0,r3,r0,lsl#3
	and r0,r0,#0xff
	add r0,r0,r0
	tst r1,#1
	orrne r0,r0,#1
	stmfd sp!,{r0-r6,lr}
	bic r0,r0,#0x61
	bic r1,r1,#7

	ldrb r3,sprmemalloc
	add r3,r3,#1
	strb r3,sprmemalloc
	tst r3,#0x20
	movne r3,#0xab
	strneb r3,sprmemreload
	b do32
luthit16
	and r3,r0,#7
	eor r0,r0,r3
	orr r3,r3,r0,lsl#3
	and r0,r1,#6
	orr r0,r3,r0,lsl#3
	and r0,r0,#0xff
	add r0,r0,r0
	tst r1,#1
	orrne r0,r0,#1
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
	b do16
;-----------------------------------------------
do16
	tst r7,#4		;16x64 sprite
	bne spr16x64		;16x64 sprite
	bic r0,r0,#0x01
	b do32

spr1
;	ldrb r0,[r4],#2		;read 1st plane
;	ldrb r1,[r4,#30]	;read 2nd plane
;	ldrb r2,[r4,#62]	;read 3rd plane
;	ldrb r3,[r4,#94]	;read 4th plane

;	ldr r0,[r5,r0,lsl#2]
;	ldr r1,[r5,r1,lsl#2]
;	ldr r2,[r5,r2,lsl#2]
;	ldr r3,[r5,r3,lsl#2]
;	orr r0,r0,r1,lsl#1
;	orr r2,r2,r3,lsl#1
;	orr r0,r0,r2,lsl#2
;	str r0,[r6],#4
;	tst r6,#0x1c
;	bne spr1
;	tst r6,#0x20
;	subne r4,r4,#17
;	bne spr1
;	add r4,r4,#1

;	tst r6,#0x40
;	bne spr1

;	subs r7,r7,#1		;nr of 16 blocks
;	addne r4,r4,#224
;	bne spr1

cachehit16
	ldmfd sp!,{r0-r6,pc}
;----------------------------------------------------------------------------
spr16x64
	ldr r4,=PCE_VRAM+1
	adr r5,chr_decode
	mov r6,#AGB_VRAM	;r6=AGB BG tileset
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#6
	orr r6,r6,#0x10000	;spr ram


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
	bic r3,r1,#7
	ldr r0,[r9,r3,lsr#1]
	cmp r0,#0x00010000
	bhi luthit32
noluthit32
	mov r7,#4			;When allocating, redraw whole 32x64.
	ldrb r0,sprmemalloc
	orr r0,r0,r7,lsl#17
	str r0,[r9,r3,lsr#1]

	and r3,r0,#7
	eor r0,r0,r3
	orr r3,r3,r0,lsl#3
	and r0,r1,#6
	orr r0,r3,r0,lsl#3
	and r0,r0,#0xff
	add r0,r0,r0
	stmfd sp!,{r0-r6,lr}
	bic r0,r0,#0x60
	bic r1,r1,#7

	ldrb r3,sprmemalloc
	add r3,r3,#1
	strb r3,sprmemalloc
	tst r3,#0x20
	movne r3,#0xab
	strneb r3,sprmemreload
	b do32
luthit32
	and r3,r0,#7
	eor r0,r0,r3
	orr r3,r3,r0,lsl#3
	and r0,r1,#6
	orr r0,r3,r0,lsl#3
	and r0,r0,#0xff
	add r0,r0,r0
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
	ldr r2,[r3]		;check dirtymap
	bic r2,r2,r5
	str r2,[r3]		;clear dirtymap
	b do32
cachehit02
	ldr r2,[r3]		;check dirtymap
	tst r2,r5
	beq cachehit32
	bic r2,r2,r5
	str r2,[r3]		;clear dirtymap
	b do32

cachehit01
	ldrh r2,[r8,r1]		;check dirtymap
	tst r2,r5
	beq cachehit32
	bic r2,r2,r5
	strh r2,[r8,r1]		;clear dirtymap
;-----------------------------------------------
do32
	bic r1,r1,#0x01
	ldr r4,=PCE_VRAM+1
	adr r5,chr_decode
	mov r6,#AGB_VRAM	;r6=AGB BG tileset
	add r4,r4,r1,lsl#7
	add r6,r6,r0,lsl#6
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
	add r6,r6,#0x380
	subne r4,r4,#127
	bne spr2

	subs r7,r7,#1		;nr of 16 blocks
	addne r4,r4,#97
	bne spr2

cachehit32
	ldmfd sp!,{r0-r6,pc}

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
pce_palette	% 512*2	;PCE VCE - copy this to real AGB palette every frame

spritelag  DCD 0
gammavalue DCD 0
SF2Mapper  DCD 0
scrollbuff DCD SCROLLBUFF1
dmascrollbuff DCD SCROLLBUFF2

bgrbuff DCD BG0CNTBUFF1
dmabgrbuff DCD BG0CNTBUFF2

oambuffer DCD OAM_BUFFER1	;1->2->1.. (loop)
tmpoambuffer DCD OAM_BUFFER2	;oam->tmpoam->dmaoam
dmaoambuffer DCD OAM_BUFFER3	;triple buffered hell!!!
oambufferready DCD 0
;----------------------------------------------------------------------------
	AREA wram_globals1, CODE, READWRITE

AGBinput		;this label here for main.c to use
	DCD 0 ;AGBjoypad (why is this in vdc.s again?  um.. i forget)
PCEinput	DCD 0 ;PCEjoypad (this is what PCE sees)
	DCD 2 ;adjustblend
wtop	DCD 0,0,0,0	;windowtop  (this label too)   L/R scrolling in unscaled mode
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

	DCW 0 ;vdcvdw
	DCW 0 ;dummy

	DCB 0 ;writelatch
	DCB 0 ;dmalength
	DCB 0 ;sprite0x
	DCB 0 ;vdcRegister
	DCB 1 ;vramaddrinc
	DCB 0 ;vdcstat
	DCB 0 ;mwreg		;memory width register
	DCB 0 ;vdcctrl0
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
