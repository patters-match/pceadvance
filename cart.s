	INCLUDE equates.h
	INCLUDE memory.h
	INCLUDE h6280mac.h
	INCLUDE h6280.h
	INCLUDE vdc.h
	INCLUDE io.h
	INCLUDE arcadecard.h

	IMPORT findrom ;from main.c
	IMPORT pogoshell ;from main.c
	IMPORT pogosize ;from main.c

	EXPORT loadcart
	EXPORT _43
	EXPORT _53
	EXPORT mirrorPCE
	EXPORT chrfinish
	EXPORT savestate
	EXPORT loadstate
	EXPORT g_emuflags
	EXPORT romstart
	EXPORT romnum
	EXPORT g_scaling
	EXPORT g_scalingx
	EXPORT g_cartflags
	EXPORT g_isobase
	EXPORT g_tgcdbase
;----------------------------------------------------------------------------
 AREA rom_code, CODE, READONLY
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
loadcart ;called from C:  r0=rom number, r1=emuflags
;----------------------------------------------------------------------------
	stmfd sp!,{r0-r1,r4-r11,lr}

	ldr r1,=findrom
	bl thumbcall_r1
	add r3,r0,#48		;r0 now points to rom image (including header)

	ldr globalptr,=|wram_globals0$$Base|	;need ptr regs init'd
	ldr pce_zpage,=PCE_RAM
;	bl TestEZ4RAM
;	cmp r0,#0
;	bleq EnableEZ4RAM
	bl EnableEZ4RAM

	ldmfd sp!,{r0-r1}
	str r0,romnumber
	str r1,emuflags

	ldr r1,=pogoshell
	ldrb r1,[r1]
	cmp r1,#0
	addeq r3,r3,#16		;If using rombuilder skip NES header.
						;r3=rombase til end of loadcart so DON'T FUCK IT UP
	ldrne r1,=pogosize
	ldrne r1,[r1]		;Size from Pogoshell
	ldreq r1,[r3,#-32]	;size of rom in bytes (from rombuilder).
	tst r1,#0x200		;Check for PCE header.
	addne r3,r3,#0x200
	str r3,rombase		;set rom base

	mov r1,r1,lsr#13	;size in 8k blocks
	mov r2,#1
bigmask
	mov r2,r2,lsl#1
	cmp r2,r1
	bmi bigmask
	sub r2,r2,#1
	str r2,rommask		;rommask=romsize-1

	mov r0,#0
	ldr r4,=SF2Mapper
	str r0,[r4]			;reset SF2CE mapper.
	ldr r4,=MEMMAPTBL_
	ldr r5,=RDMEMTBL_
	ldr r6,=WRMEMTBL_
	ldr r7,=rom_R0
	ldr r8,=rom_W
	cmp r1,#0x30		;wierd rom banking?
	bne normalbank

tbloop0
	and r1,r0,#0x70
	mov r9,r0			;0x00, 0x10, 0x50
	cmp r1,#0x20
	cmpne r1,#0x40
	cmpne r1,#0x60
	subeq r9,r9,#0x10
	cmpne r1,#0x30
	cmpne r1,#0x70
	subeq r9,r9,#0x10

	and r1,r9,r2
	add r1,r3,r1,lsl#13
	str r1,[r4,r0,lsl#2]
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x88
	bne tbloop0
	b resbg

normalbank
tbloop1
	and r1,r0,r2
	add r1,r3,r1,lsl#13
	str r1,[r4,r0,lsl#2]
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x88
	bne tbloop1
resbg
	mov r1,#0
	ldr r7,=empty_R
	ldr r8,=empty_W
tbloop2
	str r1,[r4,r0,lsl#2]	;MemMap
	str r7,[r5,r0,lsl#2]
	str r8,[r6,r0,lsl#2]
	add r0,r0,#1
	cmp r0,#0x100
	bne tbloop2

	cmp r2,#0x1F			;BIOS = 256kB
	bne nocd
	ldr r1,SCD_RAMp			;EZ3 PSRAM
	cmp r1,#0
	beq noscd
	ldr r8,=scdram_W
	mov r0,#0x68			;Super-CD_RAM
meml1
	str r1,[r4,r0,lsl#2]	;MemMap
	str r8,[r6,r0,lsl#2]	;WrMem
	add r1,r1,#0x2000
	add r0,r0,#1
	cmp r0,#0x80
	bne meml1

;------------------------	ArcadeCard hack thing, 0x40-0x43 = port to extra RAM.
;	mov r0,#0x40
;	ldr r7,=AC00_R
;	ldr r8,=AC00_W
;	str r7,[r5,r0,lsl#2]	;RdMem
;	str r8,[r6,r0,lsl#2]	;WrMem

;	mov r0,#0x41
;	ldr r7,=AC10_R
;	ldr r8,=AC10_W
;	str r7,[r5,r0,lsl#2]	;RdMem
;	str r8,[r6,r0,lsl#2]	;WrMem

;	mov r0,#0x42
;	ldr r7,=AC20_R
;	ldr r8,=AC20_W
;	str r7,[r5,r0,lsl#2]	;RdMem
;	str r8,[r6,r0,lsl#2]	;WrMem

;	mov r0,#0x43
;	ldr r7,=AC30_R
;	ldr r8,=AC30_W
;	str r7,[r5,r0,lsl#2]	;RdMem
;	str r8,[r6,r0,lsl#2]	;WrMem
;------------------------
noscd
	mov r0,#0x80			;CD_RAM
	ldr r1,=PCE_CD_RAM
	ldr r8,=cdram_W
meml2
	str r1,[r4,r0,lsl#2]	;MemMap
	str r8,[r6,r0,lsl#2]	;WrMem
	add r1,r1,#0x2000
	add r0,r0,#1
	cmp r0,#0x88
	bne meml2
nocd
;------------------------	Populous hack thing, 0x40-0x43 extra RAM.
;	andpl r0,r4,#3
;	ldrpl r1,=PCE_CD_RAM
;	addpl r1,r1,r0,lsl#13
;	ldrpl r8,=cdram_W
;------------------------

	mov r0,#SRAM
	tst r3,#0x8000000
	biceq r0,r0,#SRAM		;don't use SRAM if not running from a flash cart
	strb r0,cartflags		;set cartflags

	ldrne r8,=sram_W
	ldreq r8,=empty_W
	mov r1,#AGB_SRAM
	ldrne r7,=sram_R
	ldreq r7,=empty_R
	mov r0,#0xF7			;SRAM
	str r1,[r4,r0,lsl#2]	;MemMap
	str r7,[r5,r0,lsl#2]	;RdMem
	str r8,[r6,r0,lsl#2]	;WrMem

	ldr r1,=PCE_RAM
	ldr r7,=ram_R
	ldr r8,=ram_W
meml3
	add r0,r0,#1			;0xF8-0xFB RAM
	str r1,[r4,r0,lsl#2]	;MemMap
	str r7,[r5,r0,lsl#2]	;RdMem
	str r8,[r6,r0,lsl#2]	;WrMem
	cmp r0,#0xFB
	bne meml3

	mov r1,#0
	ldr r7,=IO_R
	ldr r8,=IO_W
	mov r0,#0xFF			;IO
	str r1,[r4,r0,lsl#2]	;MemMap
	str r7,[r5,r0,lsl#2]	;RdMem
	str r8,[r6,r0,lsl#2]	;WrMem

	mov pce_pc,#0		;(eliminates any encodePC errors during mapper*init)
	str pce_pc,lastbank

	adr r4,HuMapData
	mov r5,#0x80
HuDataLoop
	mov r0,r5
	ldrb r1,[r4],#1
	bl HuMapper_
	movs r5,r5,lsr#1
	bne HuDataLoop

	mov r0,pce_zpage		;clear PCE RAM
	mov r1,#0		
	mov r2,#0x2000/4
	bl memset_


	ldr r0,=CD_PCM_RAM		;Dst, use this as temporary space
	mov r1,#AGB_SRAM		;Src
	mov r2,#8				;Just header
	bl bytecopy_

	ldr r3,[r0]
	ldr r4,=0x4d425548		;Init BRAM. "HUBM"
	cmp r3,r4
	beq dontinitsram
	mov r1,#0				;clear PCE BRAM
	mov r2,#0x2000/4
	bl memset_
	str r4,[r0]				;Init BRAM. "HUBM",0x00,0xA0,0x10,0x80
	ldr r1,=0x8010A000		;0x8010=first free address, 0xa000=last address.
	str r1,[r0,#4]

	mov r0,#AGB_SRAM		;Dst
	ldr r1,=CD_PCM_RAM		;Src, use this as temporary space
	mov r2,#0x2000			;PCE SRAM size
	bl bytecopy_
dontinitsram


	mov r0,#0x40
	bl mirrorPCE

	bl SpeedHackSetup		;check games for speedhack
	bl pce_reset			;reset everything else
	ldmfd sp!,{r4-r11,lr}
	bx lr
;----------------------------------------------------------------------------
HuMapData
	DCB 0x00,0x00,0x00,0xF7,0x00,0x00,0xF8,0xFF
;----------------------------------------------------------------------------
SpeedHackSetup
	ldr r0,memmap_tbl+7*4
	ldr r1,=TIM_VECTOR
	ldrb r1,[r0,r1]!
	ldrb r2,[r0,#1]!
	ldrb r4,[r0,#1]!
	ldrb r0,[r0,#1]
	orr r1,r1,r2,lsl#8
	orr r1,r1,r4,lsl#16
	orr r1,r1,r0,lsl#24

	adr r2,hacklist
mp0	ldr r0,[r2],#8
	cmp r0,r1			;find which rom...
	beq remap
	cmp r0,#0
	bne mp0

	mov r0,#0x200			;0x200=BEQ(0xF0), 0x100=BNE(0xD0), 0x80=BCS(0xB0), 0x40=BCC(0x90), 0x20=BRA(0x80), 0x02=BMI(0x30), 0x01=BPL(0x10).
	str r0,hackflags		;0x800=TIA(E3), 0x400=CLI(0x58) (only Maniac Pro wrestling)
	mov pc,lr
remap
	ldr r0,[r2,#-4]
	str r0,hackflags
	mov pc,lr

hacklist						;
	DCD 0x2BED2BEA,0x280		;Andre Panza Kick Boxing (U), BCS. (-7)
	DCD 0xE000E001,0x02000100	;Ankoko Densetsu (J), BNE5.
	DCD 0xE19BE18D,0x002		;Aoi Blue Blink (J), BMI.
	DCD 0xE1C5E1C5,0x020		;Barunba (J), BRA.
	DCD 0xE052FE75,0x100		;Batman (J), BNE.
;	DCD 0xE0DEE0DF,0x200		;Battle Royal (U), BEQ.
	DCD 0xFD22FDC3,0x020		;Be Ball (J), BRA.
	DCD 0xEAB2EAB3,0x240		;Blazing Lazers (U), BEQ & BCC.
	DCD 0xE0FAE1C2,0x10000100	;Blodia (J), BNE-.
;	DCD 0xE12CE12c,0x200		;Body Conquest 2 (J), BEQ.
	DCD 0xE1B6E122,0x100		;Bomberman '94 (J), BNE.
	DCD 0xF00CF3B8,0x020		;Bravoman (U), BRA.
	DCD 0xE186E213,0x300		;Bullfight Ring no Haja (J), BNE & BEQ.
	DCD 0xE1E7E129,0x020		;Cadash (J), BRA. 
	DCD 0xE1F4E136,0x020		;Cadash (U), BRA. 
	DCD 0xE732E73C,0x20000320	;CD-ROM System V1.00 (J), BNE+, BRA & BEQ.			(For Rayxanber2)
;	DCD 0xE732E73C,0x20000120	;CD-ROM System V1.00 (J), BNE+ & BRA.				(BRA for Super Darius)
	DCD 0xE6A9E6B3,0xA00		;CD-ROM System V2.00/V2.10/V3.00 (J), BEQ & TIA.
;	DCD 0xE6C2E6CC,0x300		;CD-ROM System V2.00/V3.01 (U), BNE & BEQ.
;	DCD 0xE16CE8ED,0x200		;Champions Forever Boxing (U), BEQ.
	DCD 0xFED3FED1,0x80000000	;Chikudenya Toubee (J), -JMP. still doesn't work?
;	DCD 0xE343E641,0x200		;Cross Viber - Cyber Combat Police (J), BEQ.
	DCD 0xE09BE09B,0x02000120	;Cyber Cross (J), BRA.			Same CRC as World Jockey (J), BNE5.
	DCD 0xE0A3E0A3,0x020		;Darius Alpha/Plus (J), BRA.
	DCD 0xFFE0E02E,0x300		;Darkwing Duck (U), BNE & BEQ.
	DCD 0xE074FE1B,0x100		;Dead Moon (J), BNE.
	DCD 0xE08DFE34,0x100		;Dead Moon (U), BNE.
;	DCD 0xFFF0FFF0,0x20000100	;Deep Blue (J/U), BNE+, BEQ. -12 too much?
	DCD 0xEAA2E000,0x300		;Die Hard (J), BNE & BEQ.
	DCD 0xE182E182,0x020		;Don Doko Don (J), BRA.
	DCD 0xE222E223,0x020		;Dragon Saber (J), BRA.
	DCD 0xF604F7C4,0x10000100	;Doraemon Nobita no Dorabian Night (J), BNE-.
	DCD 0xE0ECF6DD,0x10000100	;Energy (J), BNE-.
	DCD 0xEE34ECEA,0x100		;F1 Circus (J), BNE.
	DCD 0xF06AEE42,0x10000100	;F1 Circus '91 - World Championship (J), BNE-.
	DCD 0xEAD824CC,0x100		;F1 Circus '92 - The Speed of Sound (J), BNE.
	DCD 0xE3A4E3A4,0x10000300	;F1 Dream (J), BNE- & BEQ.
	DCD 0xE0CCFC13,0x100		;Figthing Run (J), BNE.
	DCD 0xE128E128,0x001		;Final Lap Twin (J), BPL.
	DCD 0xE140E140,0x001		;Final Lap Twin (U), BPL.
	DCD 0xE0AEE29A,0x220		;Final Soldier (Special)(J), BEQ & BRA.
	DCD 0xE060E060,0x20000100	;Galaga (J/U), BNE+. -10 too much?
	DCD 0xEA2DEA2E,0x240		;Gunhed (J), BEQ & BCC.
	DCD 0xE787E788,0x240		;Gunhed Taikai (J), BEQ & BCC.
	DCD 0xEEB2E7DF,0x020		;Hit The Ice (J), BRA.
	DCD 0xEECBE7DF,0x020		;Hit The Ice (U), BRA.
	DCD 0xE026FF00,0x08000200	;Idol Hanafuda Fan Club (J), BEQ+.
;	DCD 0xE078E220,0x200		;Jackie Chan's Action Kung Fu (J), BEQ.
;	DCD 0xE08EE236,0x200		;Jackie Chan's Action Kung Fu (U), BEQ.
	DCD 0xF9FCF9CC,0x300		;Jaseikin Necromancer (J), BNE & BEQ.
;	DCD 0xE179FCA9,0x200		;Jimmu Densho Yaksa (J), BEQ.
	DCD 0xE355FD03,0x140		;Jyuohki (J), BNE & BCC.
	DCD 0xE0DBE0DC,0x020		;Jiguko Meguri (J), BRA.
	DCD 0xF347F347,0x20000100	;Kaiser's Quest (J), BNE+.
	DCD 0xE032E5CF,0x08000200	;Kaizou Ningen Shubibiman (J), BEQ+.
;	DCD 0xE0E6FF00,0x200		;Kiyuu Kiyoku Mahjong Idol Graphics (J), BEQ.
;	DCD 0xE054FF00,0x200		;Kiyuu Kiyoku Mahjong Idol Graphics II (J), BEQ.
	DCD 0xE0D5E434,0x100		;Klax (J), BNE.
	DCD 0xE019E44D,0x100		;Klax (U), BNE.
;	DCD 0xE969E99F,0x80000000	;Lode Runner - Ushina Wareta Mai (J), -JMP. Still doesn't work?
	DCD 0xE009E006,0x80000200	;Magical Chase (J/U), BEQ & -JMP.
	DCD 0xFFF0FE00,0x100		;Mahjong Goku Special (J), BNE.
	DCD 0xEBC4EAA3,0x100		;Mahjong Shikaka Retsuden Mahjong Wars (J), BNE.
	DCD 0xE12EE12E,0x80000100	;Makai Hakkenden Shada (J), -JMP & BNE.
	DCD 0xE000E270,0x600		;Maniac Pro Wrestling (J), BEQ & CLI. VDC Burst mode needed?
	DCD 0xE3DEE3CB,0x04000300	;Morita Shogi PC (J), BNE & BEQ+.
	DCD 0xE06DF894,0x08000200	;Moto Roader (J), BNE8.
	DCD 0xE0DDF67B,0x08000200	;Moto Roader (U), BNE8.
	DCD 0xE0C5E72E,0x08000200	;Moto Roader II (J), BNE8.
;	DCD 0xE000E09A,0x200		;Nazo no Masukare-do (J), BEQ.
	DCD 0xFFE0E1CE,0x240		;Neketsu Soccer (J), BCC & BEQ.
	DCD 0xE5AAE773,0x220		;New Adventure Island (U), BEQ & BRA.
;	DCD 0xE06BE072,0x200		;Neutopia II (U), BEQ.
	DCD 0xFCD6FCD3,0x040		;Ninja Gaiden (J), BCC.
	DCD 0xE018EB3B,0x300		;Outrun (J), BNE.
;	DCD 0xE1C9E1D3,0x200		;Order of The Griffon (U), BEQ.
	DCD 0xE0410000,0xa00		;Pacland (J/U), BEQ & TIA-.
;	DCD 0xE04DFF70,0x200		;Pc Pachislot Idol Gambler (J), BEQ.
	DCD 0xE3F8E394,0x100		;Power Drift (J), BNE.
	DCD 0xE1A5E197,0x002		;Power Eleven (J), BMI.
	DCD 0xFB8EFCBB,0x220		;Power League '93 (J), BEQ & BRA.
	DCD 0xF9BEFA9E,0x220		;Power League II (J), BEQ & BRA.
	DCD 0xFB82FC5F,0x220		;Power League III (J), BEQ & BRA.
	DCD 0xFB7DFCD0,0x220		;Power League IV (J), BEQ & BRA.
	DCD 0xFBDBFD08,0x220		;Power League V (J), BEQ & BRA.
	DCD 0xE07CE137,0x080		;Power Sports (J), BCS. (-8)
;	DCD 0xE18AE18B,0x220		;Power Tennis (J), BEQ & BRA. hack screws up intro.
	DCD 0xF13BFE35,0x900		;Pro Yakyuu World Stadium (J), BNE & TIA-.
	DCD 0xE48DEEE3,0x900		;Pro Yakyuu World Stadium '91(J), BNE & TIA-.
	DCD 0xE1EDE1D9,0x100		;Puzzle Boy (J), BNE.
	DCD 0xF35BF4F7,0x140		;Rabio Lepus (J), BNE & BCC.
	DCD 0xE404E464,0x10000100	;Rock On (J), BNE-.
;	DCD 0xE12AE12B,0x80000000	;Sinistron (J) / Violent Soldier (U). All disabled.
;	DCD 0xE11AE11A,0x100		;Skweek (J). BNE (0xFB). Screws up if enabled.
	DCD 0xE1C3E117,0x100		;Soldier Blade (J). BNE.
	DCD 0xE1DCE130,0x100		;Soldier Blade (U). BNE.
	DCD 0xE1BD3C60,0x40000201	;Street Fighter II (J), BEQ+ & BPL.
;	DCD 0xE1B8FF19,0x201		;Strip Fighter II (J), BEQ & BPL.
;	DCD 0xE0C7E1BC,0x200		;Super Metal Crusher (J), BEQ.
	DCD 0xE0ADE0AE,0x040		;Super Wolleyball (J), BCC.
	DCD 0xE0C6E0C7,0x040		;Super Wolleyball (U), BCC.
;	DCD 0xE7EAE7D4,0x200		;Talespin (U), BEQ.
	DCD 0xE594E75D,0x220		;Takahashi Meijin no Shin Boukenjima (J), BEQ & BRA.
;	DCD 0xE000E001,0x0			;Takin' It to the Hoop (U)/USA Pro Basketball (J), no hack.
	DCD 0xE61EE61E,0x10000100	;Thunderblade (J). BNE-, screws up
;	DCD 0xE61EE61E,0			;Thunderblade (J). No hacks.
	DCD 0xE113E1DB,0x10000100	;Timeball, BNE-.
	DCD 0xE0D8FC02,0x020		;Toilet Kids (J), BRA.
	DCD 0xE335E335,0x020		;Tower of Druaga (J), BRA.
	DCD 0xE000E0E8,0x020		;Toy Shop Boys (J), BRA.
;	DCD 0xE190E191,0x200		;Tsuppari Sumo Wrestling Game (J), BEQ.
	DCD 0xEB7BEBFE,0x100		;Veigues Tactical Gladiator (J). BNE.
	DCD 0xEB93EC16,0x100		;Veigues Tactical Gladiator (U). BNE.
	DCD 0xE6A0E681,0x300		;Vigilante (J). BNE & BEQ.
	DCD 0xE6B9E694,0x300		;Vigilante (U). BNE & BEQ.
	DCD 0xE0C1E0C2,0x020		;Volfied (J), BRA. 
;	DCD 0xE373E372,0x200		;Winning Shot (J), BEQ.
	DCD 0xE373E372,0x20000100	;Winning Shot (J), BNE+.
	DCD 0xE8E80000,0x100		;Wonder Momo (J), BNE.
	DCD 0xE258E258,0x020		;World Circuit (J), BRA.
	DCD 0xE000E08F,0x100		;World Court Tennis (J), BNE.
	DCD 0xE000E0B2,0x100		;World Court Tennis (U), BNE.
;	DCD 0xE09BE09B,0x02000100	;World Jockey (J), BNE5.
	DCD 0xE095E150,0x080		;World Sports Competition (U), BCS. (-8)
	DCD 0xEAF1FC18,0x300		;Xevious (J), BNE & BEQ.
	DCD 0
;----------------------------------------------------------------------------
savestate	;called from ui.c.
;int savestate(void *here): copy state to <here>, return size
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r6,globalptr,lr}

	ldr globalptr,=|wram_globals0$$Base|

	ldr r2,rombase
	rsb r2,r2,#0				;adjust rom maps,etc so they aren't based on rombase
	bl fixromptrs				;(so savestates are valid after moving roms around)

	mov r6,r0					;r6=where to copy state
	mov r0,#0					;r0 holds total size (return value)

	adr r4,savelst				;r4=list of stuff to copy
	mov r3,#(lstend-savelst)/8	;r3=items in list
ss1	ldmia r4!,{r1,r2}			;r1=what to copy, r2=how much to copy
	add r0,r0,r2
ss0	ldr r5,[r1],#4
	str r5,[r6],#4
	subs r2,r2,#4
	bne ss0
	subs r3,r3,#1
	bne ss1

	ldr r2,rombase
	bl fixromptrs

	ldmfd sp!,{r4-r6,globalptr,lr}
	bx lr

savelst	DCD rominfo,8,PCE_RAM,0x2000,AGB_SRAM,0x2000,PCE_PALETTE,1024			;Remember to fix the copy loop to do bytes for SRAM
		DCD mapperstate,8;,cpustate,44,vdcstate,80;PCE_VRAM,0x10000
lstend

fixromptrs	;add r2 to some things
	stmfd sp!,{r0,r2,lr}

	mov r3,#0x80
	adrl r4,mapperdata+7
HuMapLoop
	ldrb r0,[r4],#-1	;What contents.
	mov r1,r3		;Which bank.
	bl HuMapper_
	movs r3,r3,lsr#1
	bne HuMapLoop

	ldmfd sp!,{r0,r2,lr}

	ldr r3,lastbank
	add r3,r3,r2
	str r3,lastbank

	ldr r3,cpuregs+6*4	;6502 PC
	add r3,r3,r2
	str r3,cpuregs+6*4

	mov pc,lr
;----------------------------------------------------------------------------
loadstate	;called from ui.c
;void loadstate(int rom#,u32 *stateptr)	 (stateptr must be word aligned)
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r7,globalptr,lr}

	mov r6,r1		;r6=where state is at
	ldr globalptr,=|wram_globals0$$Base|

	ldr r1,[r6]		;emuflags
	bl loadcart		;cart init

	mov r0,#(lstend-savelst)/8	;read entire state
	adr r4,savelst
ls1	ldmia r4!,{r1,r2}
ls0	ldr r5,[r6],#4
	str r5,[r1],#4
	subs r2,r2,#4
	bne ls0
	subs r0,r0,#1
	bne ls1

	ldr r2,rombase		;adjust ptr shit (see savestate above)
	bl fixromptrs

	ldr r3,=PCE_VRAM+0x2000	;init nametbl+attrib
	ldr r4,=AGB_BG
ls4	mov r5,#0
ls3	mov r1,r3
	mov r2,r4
	mov addy,r5
	ldrb r0,[r1,addy]
;	bl writeBG
	add r5,r5,#1
	tst r5,#0x400
	beq ls3
	add r3,r3,#0x400
	add r4,r4,#0x800
	tst r4,#0x10000
	beq ls4


	mov r1,#-1		;init BG CHR
	ldr r5,=AGB_VRAM
;	adrl r6,pce_chr_map
;	bl im_lazy
	mov r1,#-1
	ldr r5,=AGB_VRAM+0x4000
;	adrl r6,pce_chr_map+4
;	bl im_lazy

	ldrb r0,vdcctrl1	;prep buffered DMA stuff
	bl VDC_CR_L_W
	bl newX
;	bl resetBGCHR

	ldmfd sp!,{r4-r7,globalptr,lr}
	bx lr

;	bg0_cnt 0x5c02,
;----------------------------------------------------------------------------
EnableEZ4RAM
;----------------------------------------------------------------------------

;OpenWrite() - unlocks PSRAM for writes
	ldr r2,=0x9fe0000
	mov r0,#0xd200
	strh r0,[r2]			;*(u16 *)0x9fe0000 = 0xd200;
	mov r4,#0x8000000
	mov r1,#0x1500
	strh r1,[r4]			;*(u16 *)0x8000000 = 0x1500;
	add r4,r4,#0x20000
	strh r0,[r4]			;*(u16 *)0x8020000 = 0xd200;
	add r4,r4,#0x20000
	strh r1,[r4]			;*(u16 *)0x8040000 = 0x1500;
	ldr r4,=0x9c40000
	strh r1,[r4]			;*(u16 *)0x9c40000 = 0x1500;
	sub r2,r2,#0x20000
	strh r1,[r2]			;*(u16 *)0x9fc0000 = 0x1500;

;----------------------------------------------------------------------------
TestEZ4RAM
;----------------------------------------------------------------------------
	ldr r0,=0x08FD0000		;EZ4 PSRAM, last 192KB
	ldr r1,=0x5AB07A6E		;https://www.youtube.com/watch?v=z5rRZdiu1UE
	str r1,[r0]
	ldr r2,[r0]
	cmp r1,r2
	movne r0,#0
	str r0,SCD_RAMp
	subeq r0,r0,#0x200000		;Arcade Card is 2MB.
	str r0,ACC_RAMp
	bx lr

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
mTable
	DCW 0x000a,0x400a,0x400a,0x400a,0x800a,0xc00a,0xc00a,0xc00a
;----------------------------------------------------------------------------
mirrorPCE
	and r0,r0,#0x70
	adr r1,mTable
	add r1,r1,r0,lsr#3
	ldrh r0,[r1]
	str r0,BGmirror
	mov pc,lr

;----------------------------------------------------------------------------
chrfinish	;end of frame...  finish up BGxCNTBUFF
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r9,r11,lr}

	ldrb r0,chrmemreload
	cmp r0,#0
	bne notreload
	strb r0,chrmemalloc
	ldr r0,=TILEREMAPLUT
	mov r1,#-1
	mov r2,#32		;128/4 entries
	bl memset_		;clear map
	strb r0,chrmemreload

	ldr r0,=DIRTYSPRITES
	ldr r1,=0x20202020
	mov r2,#128		;512/4 entries
	bl memorr_		;clear map
notreload
	ldr r3,=TILEREMAPLUT
	ldr r1,=scrollbuff
	ldr r8,[r1]

	ldrb r2,mwreg
	mov addy,#0xfc
	tst r2,#0x20
	moveq addy,#0x7c
	tst r2,#0x30
	moveq addy,#0x3c

	ldr r1,emuflags
	tst r1,#0x200
	ldreq r4,windowtop+4		;first scanline unscaled.
	ldrneb r4,ystart			;first scanline scaled.
	moveq r0,#160
	movne r0,#214
	ldr r1,vblscanlinegfx
	cmp r0,r1
	movpl r0,r1
	add r5,r4,r0
	add r8,r8,r4,lsl#2
	ldr r1,=sheight
	str r5,[r1]

	mov r1,#AGB_VRAM
	ldr r0,BGoffset2
	add r1,r1,r0,lsl#3
	ldr r0,=tmapadr
	str r1,[r0]

	ldr r0,=oldtilerow
	ldr r6,[r0]
	mov lr,#0x00F80000			;Mask for x & y values.
	tst r2,#0x40				;Screen height
	orrne lr,lr,#0x01000000
	orr lr,lr,addy,lsl#2

	and r2,r2,#0x30
	adr r1,chrshifttbl
	ldr r1,[r1,r2,lsr#2]
	ldr r0,=chrshift
	str r1,[r0]
	ldr r11,=0x0ff00ff0
	b tslo2
chrshifttbl
	add r5,r5,r0,lsr#13		;3=32, 4=64, 5=128.
	add r5,r5,r0,lsr#12		;3=32, 4=64, 5=128.
	add r5,r5,r0,lsr#11		;3=32, 4=64, 5=128.
	add r5,r5,r0,lsr#11		;3=32, 4=64, 5=128.




;----------------------------------------------------------------------------
 AREA wram_code4, CODE, READWRITE
;----------------------------------------------------------------------------
_43;   TMA #$nn 	Read from Memory mapper
;----------------------------------------------------------------------------
	ldrb r1,[pce_pc],#1

	adrl r2,mapperdata
tmaloop
	movs r1,r1,lsr#1
	ldrcsb r0,[r2]
	add r2,r2,#1
	bne tmaloop

	mov pce_a,r0,lsl#24
	fetch 4
;----------------------------------------------------------------------------
_53;   TAM #$nn 	Write to Memory mapper
;----------------------------------------------------------------------------
	ldrb r0,[pce_pc],#1		;Which MPRs are affected (each bit represents one MPR)
	mov r1,pce_a,lsr#24		;Which bank in the ROM
	bl HuMapper_
	fetch 5

;----------------------------------------------------------------------------
HuMapper_	;rom paging..
;----------------------------------------------------------------------------
	stmfd sp!,{r3-r7}
	ldr r6,=MEMMAPTBL_
	ldr r2,[r6,r1,lsl#2]!
	ldr r3,[r6,#-1024]		;RDMEMTBL_
	ldr r4,[r6,#-2048]		;WRMEMTBL_

	mov r5,#0
	cmp r1,#0x88
	movmi r5,#12
	bpl wr_tbl
;------------------------	SF2CE support
	cmp r1,#0x40
	ldrpl r6,SF2Mapper
	addpl r2,r2,r6,lsl#19
;------------------------

;wr_tbl
;	adr r6,readmem_tbl
;	add r7,r6,#96
;memapl
;	movs r0,r0,lsr#1
;	strcs r3,[r6]			;readmem_tbl
;	strcs r4,[r6,#32]		;writemem_tbl
;	strcs r2,[r6,#64]		;memmap_tbl
;	strcsb r1,[r7]			;MPR reg
;	add r6,r6,#4
;	add r7,r7,#1
;	add r3,r3,r5
;	subne r2,r2,#0x2000
;	bne memapl

wr_tbl
	adr r6,readmem_tbl
	add r7,r6,#96
	tst r0,#0xFF
	bne memaps				;safety
	b flush
memapl
	add r6,r6,#4
	add r7,r7,#1
memap2
	add r3,r3,r5
	sub r2,r2,#0x2000
memaps
	movs r0,r0,lsr#1
	bcc memapl				;C=0
	strcs r3,[r6],#4		;readmem_tbl
	strcs r4,[r6,#28]		;writemem_tb
	strcs r2,[r6,#60]		;memmap_tbl
	strcsb r1,[r7],#1		;MPR reg
	bne memap2

;------------------------------------------
flush		;update pce_pc & lastbank
;------------------------------------------
	ldr r1,lastbank
	sub pce_pc,pce_pc,r1
	encodePC

	ldmfd sp!,{r3-r7}
	mov pc,lr


;----------------------------------------------------------------------------
RedrawTiles
;----------------------------------------------------------------------------
	mov addy,lr
	ldr r5,=CHR_DECODE
	ldr r7,=TILEREMAPLUT
	mov r8,#0x7f
tiloop
	ldrb r1,[r7,r8]
	tst r1,#0xc0
	bleq dotiles
	subs r8,r8,#1
	bpl tiloop
	mov pc,addy

dotiles
	orr r1,r1,#0x40				;must be #0x40 for tileram 2
	strb r1,[r7,r8]
	ldr r2,=DIRTYSPRITES
	ldr r3,=0x20202020
	ldr r0,[r2,r8,lsl#2]		;read from dirtymap.
	tst r0,r3
	moveq pc,lr
	bic r0,r0,r3
	str r0,[r2,r8,lsl#2]		;write to dirtymap.

dotiles2
	ldr r4,=PCE_VRAM
	mov r6,#AGB_VRAM			;r3=AGB BG tileset
	add r4,r4,r8,lsl#9
	add r6,r6,r1,lsl#9			;tile ram 2

chr1
	ldrb r0,[r4],#1				;read 1st plane
	ldrb r1,[r4],#1				;read 2nd plane
	ldrb r2,[r4,#14]			;read 3rd plane
	ldrb r3,[r4,#15]			;read 4th plane

	ldr r0,[r5,r0,lsl#2]
	ldr r1,[r5,r1,lsl#2]
	ldr r2,[r5,r2,lsl#2]
	ldr r3,[r5,r3,lsl#2]
	orr r0,r0,r1,lsl#1
	orr r2,r2,r3,lsl#1
	orr r0,r0,r2,lsl#2
	str r0,[r6],#4
	tst r6,#0x1c
	addeq r4,r4,#16
	tsteq r6,#0x1e0
	bne chr1

	mov pc,lr
;----------------------------------------------------------------------------
;chrfinish2	;end of frame...  finish up BGxCNTBUFF, set tileset depending on tile number
;----------------------------------------------------------------------------
tslo2
	ldr r0,[r8],#4			;x & y offset
	add r0,r0,r4,lsl#16
	and r0,r0,lr
	cmp r6,r0
	bne tsbo2
tsbo1
	add r4,r4,#1
	cmp r4,r5			;160*4/3=213.33333
	bne tslo2

	bl RedrawTiles
	ldmfd sp!,{r3-r9,r11,pc}

tsbo2
	str r0,oldtilerow
	ldr r5,=PCE_VRAM
chrshift
	add r5,r5,r0,lsr#13		;3=32, 4=64, 5=128.
	add r2,r5,r0,lsr#2
	bic r5,r5,addy

	ldr r9,tmapadr
	tst addy,#0x40
	tstne r0,#0x01000000
	eorne r0,r0,#0x03000000
	add r9,r9,r0,lsr#13
	mov r7,#16				;width
trloop
	and r2,r2,addy
	ldr r0,[r5,r2]			;Read from virtual PCE_VRAM
	and r6,r0,#0x000007f0
	ldrb r1,[r3,r6,lsr#4]	;TileRemapLUT
	tst r1,#0xc0
	bne outofchrmem
outret
	and r6,r0,#0x07f00000
	bic r0,r0,r11			;#0x0ff00ff0
	orr r0,r0,r1,lsl#4
	ldrb r1,[r3,r6,lsr#20]	;TileRemapLUT
	tst r1,#0xc0
	bne outofchrmem2
outret2
	orr r0,r0,r1,lsl#20
	orr r6,r2,r2,lsl#5		;move 0x40 to 0x800
	bic r6,r6,#0x17c0		;remove 0x1000 to allow 1024 wide screens.
	str r0,[r9,r6]			;Write to GBA_VRAM
	add r2,r2,#4
	subs r7,r7,#1
	bne trloop
	ldr r5,sheight
	ldr r6,oldtilerow
	b tsbo1

outofchrmem
	bic r1,r1,#0x40			;test
	tst r1,#0x80
	ldrneb r1,chrmemalloc
	strb r1,[r3,r6,lsr#4]	;strneb?
	beq outret

	addne r6,r1,#1
	strneb r6,chrmemalloc
	tst r6,#0x40
	beq outret

	movne r6,#0
	strneb r6,chrmemreload
	strneb r6,chrmemalloc
	b outret

outofchrmem2
	bic r1,r1,#0x40			;test
	tst r1,#0x80
	ldrneb r1,chrmemalloc
	strb r1,[r3,r6,lsr#20]	;strneb?
	beq outret2

	addne r6,r1,#1
	strneb r6,chrmemalloc
	tst r6,#0x40
	beq outret2

	movne r6,#0
	strneb r6,chrmemreload
	strneb r6,chrmemalloc
	b outret2

oldtilerow DCD 0
sheight DCD 0
tmapadr DCD 0x06000000

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
 AREA wram_globals2, CODE, READWRITE

romstart
	DCD 0 ;rombase
romnum
	DCD 0 ;romnumber
rominfo                 ;keep emuflags/BGmirror together for savestate/loadstate
g_emuflags	DCB 0 ;emuflags        (label this so UI.C can take a peek) see equates.h for bitfields
g_scaling	DCB SCALED_SPRITES ;(display type)
	% 2   ;(sprite follow val)
	DCD 0 ;BGmirror		(BG size for BG0CNT)

	DCD 0 ;rommask
g_isobase
	DCD 0 ;isobase
g_tgcdbase
	DCD 0 ;tgcdbase
	DCD 0 ;ACC_RAMp, Arcade Card extra RAM
	DCD 0 ;SCD_RAMp, Super CD-ROM extra RAM
	DCD 0 ;BGoffset1
	DCD 0 ;BGoffset2
	DCD 0 ;BGoffset3

g_cartflags
	DCB 0 ;cartflags
g_scalingx
	DCB 0 ;xcentering
;----------------------------------------------------------------------------
	END

