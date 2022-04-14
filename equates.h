		GBLL DEBUG
		GBLL SAFETY

DEBUG		SETL {FALSE}

;BUILD		SETS "DEBUG"/"GBA"	(defined at cmdline)
;----------------------------------------------------------------------------

ch0waveform		EQU 0x3004D00
PCE_RAM			EQU 0x3004E00			;keep $200 byte aligned for h6280 stack shit
CHR_DECODE		EQU PCE_RAM+0x2000
PCE_PALETTE 	EQU CHR_DECODE+0x400
OAM_BUFFER1		EQU PCE_PALETTE+0x400
OAM_BUFFER2		EQU OAM_BUFFER1+0x200
OAM_BUFFER3		EQU OAM_BUFFER2+0x200
YSCALE_EXTRA	EQU OAM_BUFFER3+0x200
YSCALE_LOOKUP	EQU YSCALE_EXTRA+0x50
;?				EQU YSCALE_LOOKUP+0x200		; was 0x100

PCE_VRAM		EQU 0x2040000-0x10000	;64k
MAPPED_RGB		EQU PCE_VRAM-512*2		;PCE palette lookup
MAPPED_BNW		EQU MAPPED_RGB-512*2	;PCE palette lookup
PCEPALBUFF		EQU MAPPED_BNW-512*2	;PCE palette buffer, also in GBA.h
VDCBUFF1		EQU PCEPALBUFF-240*2
VDCBUFF2		EQU VDCBUFF1-240*2
VDCBUFF3		EQU VDCBUFF2-240*2
BG0CNTBUFF1		EQU VDCBUFF3-240*2
BG0CNTBUFF2		EQU BG0CNTBUFF1-240*2
DMA3BUFF		EQU BG0CNTBUFF2-164*2
SCROLLBUFF1		EQU DMA3BUFF-240*4
SCROLLBUFF2		EQU SCROLLBUFF1-240*4
DMA0BUFF		EQU SCROLLBUFF2-164*4
DIRTYSPRITES	EQU DMA0BUFF-512
TILEREMAPLUT	EQU DIRTYSPRITES-128
MEMMAPTBL_		EQU TILEREMAPLUT-256*4
RDMEMTBL_		EQU MEMMAPTBL_-256*4
WRMEMTBL_		EQU RDMEMTBL_-256*4
SPRTILELUT		EQU WRMEMTBL_-768*4
FREQTBL			EQU SPRTILELUT-4096*2
PCMWAVSIZE		EQU 528
PCMWAV			EQU FREQTBL-PCMWAVSIZE*4
END_OF_EXRAM	EQU PCMWAV-0x2A00					;-0x2A00 room left for code.
PCE_CD_RAM		EQU END_OF_EXRAM-0x10000	;64k
CD_PCM_RAM		EQU PCE_CD_RAM-0x10000		;64k

AGB_IRQVECT		EQU 0x3007FFC
AGB_PALETTE		EQU 0x5000000
AGB_VRAM		EQU 0x6000000
AGB_OAM			EQU 0x7000000
AGB_SRAM		EQU 0xE000000
AGB_BG			EQU AGB_VRAM+0xe000
DEBUGSCREEN		EQU AGB_VRAM+0x3800

REG_BASE		EQU 0x4000000
REG_DISPCNT		EQU 0x00
REG_DISPSTAT	EQU 0x04
REG_VCOUNT		EQU 0x06
REG_BG0CNT		EQU 0x08
REG_BG1CNT		EQU 0x0A
REG_BG2CNT		EQU 0x0C
REG_BG3CNT		EQU 0x0E
REG_BG0HOFS		EQU 0x10
REG_BG0VOFS		EQU 0x12
REG_BG1HOFS		EQU 0x14
REG_BG1VOFS		EQU 0x16
REG_BG2HOFS		EQU 0x18
REG_BG2VOFS		EQU 0x1A
REG_BG3HOFS		EQU 0x1C
REG_BG3VOFS		EQU 0x1E
REG_WIN0H		EQU 0x40
REG_WIN1H		EQU 0x42
REG_WIN0V		EQU 0x44
REG_WIN1V		EQU 0x46
REG_WININ		EQU 0x48
REG_WINOUT		EQU 0x4A
REG_BLDCNT		EQU 0x50
REG_BLDALPHA	EQU 0x52
REG_BLDY		EQU 0x54
REG_SG1CNT_L	EQU 0x60
REG_SG1CNT_H	EQU 0x62
REG_SG1CNT_X	EQU 0x64
REG_SG2CNT_L	EQU 0x68
REG_SG2CNT_H	EQU 0x6C
REG_SG3CNT_L	EQU 0x70
REG_SG3CNT_H	EQU 0x72
REG_SG3CNT_X	EQU 0x74
REG_SG4CNT_L	EQU 0x78
REG_SG4CNT_H	EQU 0x7c
REG_SGCNT_L		EQU 0x80
REG_SGCNT_H		EQU 0x82
REG_SGCNT_X		EQU 0x84
REG_SGBIAS		EQU 0x88
REG_SGWR0_L		EQU 0x90
REG_FIFO_A_L	EQU 0xA0
REG_FIFO_A_H	EQU 0xA2
REG_FIFO_B_L	EQU 0xA4
REG_FIFO_B_H	EQU 0xA6
REG_DM0SAD		EQU 0xB0
REG_DM0DAD		EQU 0xB4
REG_DM0CNT_L	EQU 0xB8
REG_DM0CNT_H	EQU 0xBA
REG_DM1SAD		EQU 0xBC
REG_DM1DAD		EQU 0xC0
REG_DM1CNT_L	EQU 0xC4
REG_DM1CNT_H	EQU 0xC6
REG_DM2SAD		EQU 0xC8
REG_DM2DAD		EQU 0xCC
REG_DM2CNT_L	EQU 0xD0
REG_DM2CNT_H	EQU 0xD2
REG_DM3SAD		EQU 0xD4
REG_DM3DAD		EQU 0xD8
REG_DM3CNT_L	EQU 0xDC
REG_DM3CNT_H	EQU 0xDE
REG_TM0D		EQU 0x100
REG_TM0CNT		EQU 0x102
REG_IE			EQU 0x200
REG_IF			EQU 0x4000202
REG_P1			EQU 0x4000130
REG_P1CNT		EQU 0x132
REG_WAITCNT		EQU 0x4000204

REG_SIOMULTI0	EQU 0x20 ;+100
REG_SIOMULTI1	EQU 0x22 ;+100
REG_SIOMULTI2	EQU 0x24 ;+100
REG_SIOMULTI3	EQU 0x26 ;+100
REG_SIOCNT		EQU 0x28 ;+100
REG_SIOMLT_SEND	EQU 0x2a ;+100
REG_RCNT		EQU 0x34 ;+100

		;r0,r1,r2=temp regs
pce_nz		RN r3 ;bit 31=N, Z=1 if bits 0-7=0
pce_rmem	RN r4 ;readmem_tbl
pce_a		RN r5 ;bits 0-23=0, also used to clear bytes in memory (vdc.s)
pce_x		RN r6 ;bits 0-23=0
pce_y		RN r7 ;bits 0-23=0
cycles		RN r8
pce_pc		RN r9
globalptr	RN r10 ;=wram_globals* ptr
pce_optbl	RN r10
pce_zpage	RN r11 ;=PCE_RAM
addy		RN r12 ;keep this at r12 (scratch for APCS)
		;r13=SP
		;r14=LR
		;r15=PC
;----------------------------------------------------------------------------

 MAP 0,pce_zpage
pce_ram # 0x2000
chr_decode # 0x400
pce_palette # 0x400
oam_buffer1 # 0x200
oam_buffer2 # 0x200
oam_buffer3 # 0x200
yscale_extra # 0x50	;(240-160) extra 80 is for scrolling unscaled sprites
yscale_lookup # 0x100	;sprite Y LUT

;pce_sram # 0x2000
;everything in wram_globals* areas:

 MAP 0,globalptr	;h6280.s
opz # 256*4
readmem_tbl # 8*4
writemem_tbl # 8*4
memmap_tbl # 8*4
mapperdata # 8
cpuregs # 7*4
pce_s # 4
lastbank # 4
nexttimeout # 4
nexttimeout_ # 4
oldcycles # 4
scanline # 4
scanlinehook # 4
frame # 4
cyclesperscanline # 4
lastscanline # 4
vblscanlinegfx # 4
vblscanlinecpu # 4
highcycles # 4
hackflags # 4
			;vdc.s (wram_globals1)
fpsvalue # 4
AGBjoypad # 4
PCEjoypad # 4
adjustblend # 4
windowtop # 16
hcenter # 4
palettePtr # 4
vram_w_adr # 4
vram_r_adr # 4
readlatch # 4
timCycles # 4
rasterCompare # 4
rasterCompareCPU # 4
scrollX # 4
scrollY # 4
satAddr # 4
sprite0y # 4
dmasource # 4
dmadestination # 4
vdcvdw # 4

writelatch # 1
dmalength # 1
sprite0x # 1
vdcRegister # 1
vramaddrinc # 1
vdcstat # 1
mwreg # 1
vdcburst # 1
vdcctrl0frame # 1
vdcctrl1 # 1
irqDisable # 1
irqPending # 1
timerLatch # 1
timerEnable # 1
iobuffer # 1
bramaccess # 1
vdchdw # 1
vdcvds # 1
vdcvsw # 1
vdcvcr # 1
ystart # 1		;13 scaled PCE screen starts on this line
dmacr # 1
dmairq # 1
dosprdma # 1
sprmemalloc # 1
sprmemreload # 1
chrmemalloc # 1
chrmemreload # 1
; # 3 ;align
			;cart.s (wram_globals2)
rombase # 4
romnumber # 4
emuflags # 4
BGmirror # 4

rommask # 4
isobase # 4
tgcdbase # 4
ACC_RAMp # 4
SCD_RAMp # 4

BGoffset1 # 4
BGoffset2 # 4
BGoffset3 # 4
cartflags # 1
xcentering # 1

 # 2 ;align
;----------------------------------------------------------------------------
RES_VECTOR		EQU 0xfffe ; RESET interrupt vector address
NMI_VECTOR		EQU 0xfffc ; NMI interrupt vector address
TIM_VECTOR		EQU 0xfffa ; TIMER interrupt vector address
IRQ_VECTOR		EQU 0xfff8 ; VDC interrupt vector address
BRK_VECTOR		EQU 0xfff6 ; BRK interrupt vector address
;-----------------------------------------------------------cartflags
SRAM			EQU 0x02 ;save SRAM
;-----------------------------------------------------------emuflags
USEPPUHACK		EQU 1	;use $2002 hack
NOCPUHACK		EQU 2	;don't use JMP hack
USCOUNTRY		EQU 4	;0=JAP 1=US
;?				EQU 16
FOLLOWMEM       EQU 32  ;0=follow sprite, 1=follow mem

				;bits 8-15=scale type

UNSCALED_NOAUTO	EQU 0	;display types
UNSCALED_AUTO	EQU 1
SCALED			EQU 2
SCALED_SPRITES	EQU 3

				;bits 16-31=sprite follow val

;----------------------------------------------------------------------------
CYC_SHIFT		EQU 8
CYCLE			EQU 1<<CYC_SHIFT ;one cycle (455*CYCLE cycles per scanline)

;cycle flags- (stored in cycles reg for speed)

CYC_C			EQU 0x01	;Carry bit
CYC_I			EQU 0x04	;IRQ mask
CYC_D			EQU 0x08	;Decimal bit
CYC_V			EQU 0x40	;Overflow bit
CYC_MASK		EQU CYCLE-1	;Mask
;----------------------------------------------------------------------------

		END

