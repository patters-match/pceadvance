	INCLUDE equates.h
	INCLUDE io.h
	INCLUDE memory.h

	EXPORT CD_reset_
	EXPORT CDROM_R
	EXPORT CDROM_W
	EXPORT updatecdrom
	EXPORT cdirqreq
	EXPORT TGCD_D_Header
	EXPORT TGCD_M_Header

	MACRO
	vbadebugg
;	swi 0xFF0000		;!!!!!!! Doesn't work on hardware !!!!!!!
	MEND

 AREA rom_code, CODE, READONLY ;-- - - - - - - - - - - - - - - - - - - - - -

;----------------------------------------------------------------------------
CD_reset_
;----------------------------------------------------------------------------

	mov r0,#0
	strb r0,scsidata
	strb r0,scsisignal
	strb r0,cdirqmask
	strb r0,cdaudioplaying

	mov r3,lr
	ldr r1,tgcdbase
	ldrb r0,[r1,#12]		;Last Track
	bl Track2LBA
	mov r0,r0,lsl#2			;2 extra bits for the cd frame vs gba frame.
	str r0,sectorend

	bx r3
;----------------------------------------------------------------------------
updatecdrom		;called every frame
;----------------------------------------------------------------------------
	ldrb r0,cdaudioplaying
	tst r0,#0xff
	streq r0,amplitude
	beq NoCDEnd
	ldrb r0,cdirqreq
	orr r0,r0,#0x10			;Set Sub Q-Channel ready.
	strb r0,cdirqreq
	ldr r0,amplitude
	adds r0,r0,r0,lsr#1
	addeq r0,r0,#0x45000
	str r0,amplitude

	ldr r0,sectorptr
	add r0,r0,#5
	str r0,sectorptr
	ldr r1,sectorend
	cmp r0,r1
	bmi NoCDEnd

;	mov r11,r11				;No$GBA Debugg
	ldrb r0,cdirqreq
	orr r0,r0,#0x20			;CD Audio finnished playing
	strb r0,cdirqreq
	mov r0,#0
	strb r0,cdaudioplaying

NoCDEnd
	ldr r0,adplaytime
	cmp r0,#0
	ldrb r1,adpcmrate
	subpls r0,r0,r1
	str r0,adplaytime
;	bxcs lr
	bcs Check_CD_IRQ
	ldrb r0,cdirqreq
	orr r0,r0,#0x08			;ADPCM finnished playing
	strb r0,cdirqreq
	
;----------------------------------------------------------------------------
Check_CD_IRQ			;don't use r0 as it may be used as return data.
;----------------------------------------------------------------------------
	ldrb r2,cdirqmask
	ldrb r1,cdirqreq
	ands r2,r2,r1
	ldrb r1,irqPending
	bic r1,r1,#1			;clear CD IRQ
	orrne r1,r1,#1			;set CD IRQ if appropriate
	strb r1,irqPending

	bx lr
;----------------------------------------------------------------------------
CDROM_R
;----------------------------------------------------------------------------
	tst addy,#0x7F0
	andeq r1,addy,#0x0F
	ldreq pc,[pc,r1,lsl#2]
	b more_CD_R		;anything else than 0x1800-0x180f
;---------------------------
cd_read_tbl
	DCD CD00_R		;CDC status
	DCD CD01_R		;CDC command / status / data
	DCD CD02_R		;ADPCM / CD control
	DCD CD03_R		;BRAM lock / CD status
	DCD CD04_R		;CD reset
	DCD CD05_R		;Convert PCM data / PCM data
	DCD CD06_R		;PCM data
	DCD CD07_R		;BRAM unlock / CD status
	DCD CD08_R		;ADPCM address (LSB) / CD data
	DCD CD09_R		;ADPCM address (MSB)
	DCD CD0A_R		;ADPCM RAM data port
	DCD CD0B_R		;ADPCM DMA control
	DCD CD0C_R		;ADPCM status
	DCD CD0D_R		;ADPCM address control
	DCD CD0E_R		;ADPCM playback rate
	DCD CD0F_R		;ADPCM and CD audio fade timer
;----------------------------------------------------------------------------
more_CD_R
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldr r0,SCD_RAMp			;EZ3 PSRAM
	cmp r0,#0
	beq empty_R
	andne r0,addy,#0x7F0
	cmpne r0,#0xC0
	bne empty_R

	ldrb r0,emuflags
	tst r0,#USCOUNTRY
	adreq r1,SCD_J
	adrne r1,SCD_U
	and r0,addy,#0x0F
	ldrb r0,[r1,r0]
	mov pc,lr
;---------------------------
SCD_J	DCB 0,0xAA,0x55,0,0,0xAA,0x55,0x03,0,0,0,0,0,0,0,0			;Super CDROM check (J)
SCD_U	DCB 0,0xAA,0x55,0,0,0x55,0xAA,0x03,0,0,0,0,0,0,0,0			;Super CDROM check (U)

;----------------------------------------------------------------------------
CDROM_W
;----------------------------------------------------------------------------
	tst addy,#0x7F0
	andeq r1,addy,#0x0F
	ldreq pc,[pc,r1,lsl#2]
	b more_CD_W		;anything else than 0x1800-0x180f
;---------------------------
cd_write_tbl
	DCD CD00_W		;CDC status
	DCD CD01_W		;CDC command / status / data
	DCD CD02_W		;ADPCM / CD control
	DCD CD03_W		;BRAM lock / CD status
	DCD CD04_W		;CD reset
	DCD CD05_W		;Convert PCM data / PCM data
	DCD CD06_W		;PCM data
	DCD CD07_W		;BRAM unlock / CD status
	DCD CD08_W		;ADPCM address (LSB) / CD data
	DCD CD09_W		;ADPCM address (MSB)
	DCD CD0A_W		;ADPCM RAM data port
	DCD CD0B_W		;ADPCM DMA control
	DCD CD0C_W		;ADPCM status
	DCD CD0D_W		;ADPCM address control
	DCD CD0E_W		;ADPCM playback rate
	DCD CD0F_W		;ADPCM and CD audio fade timer
;----------------------------------------------------------------------------
more_CD_W
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	and r1,addy,#0x7F0
	cmp r1,#0xC0
	bne empty_W
	cmp r0,#0xAA			;Enable Super CD-Rom?
	cmp r0,#0x55			;Enable Super CD-Rom?
	mov pc,lr

;----------------------------------------------------------------------------
CD00_R		; SCSI BUS SIGNALS
;----------------------------------------------------------------------------
	ldrb r0,scsisignal
	ldrb r1,cdirqmask
	and r1,r1,#0x80
	bic r0,r0,r1,lsr#1
	mov pc,lr
;----------------------------------------------------------------------------
CD01_R		; SCSI BUS DATA
;----------------------------------------------------------------------------
	ldrb r0,scsidata
	mov pc,lr
;----------------------------------------------------------------------------
CD02_R		; IRQ mask & SCSI ACK
;----------------------------------------------------------------------------
	ldrb r0,cdirqmask
	mov pc,lr
;----------------------------------------------------------------------------
CD03_R		; IRQ request
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,cdirqreq
	bic r1,r0,#0xfc
	strb r1,cdirqreq		;L/R bit should not be cleared.
	mov r1,#0
	strb r1,bramaccess		;BRAM is locked if 0x1803 is read
	ldrb r1,irqPending
	bic r1,r1,#1			;clear CD IRQ
	strb r1,irqPending
	mov pc,lr
;----------------------------------------------------------------------------
CD04_R		; SCSI reset reg?
;----------------------------------------------------------------------------
	ldrb r0,scsireset
	mov pc,lr
;----------------------------------------------------------------------------
CD05_R		; CD sound low(?) byte
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,amplitude+2
	mov pc,lr
;----------------------------------------------------------------------------
CD06_R		; CD sound high(?) byte
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,amplitude+3
	mov pc,lr
;----------------------------------------------------------------------------
CD07_R		; Read Sub Q-Channel, clear
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,cdirqreq
	bic r0,r0,#0x10			;Clear Sub Q-Channel ready.
	strb r0,cdirqreq

	mov r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
CD08_R
;----------------------------------------------------------------------------
	ldrb r0,scsisignal
	cmp r0,#0xC8			;Data out?
	bne NoRead08
Read08
	ldr r0,dataoutptr
	ldrb r1,[r0,#1]!
	str r0,dataoutptr
	ldrb r0,scsidata
	strb r1,scsidata
	ldr r1,datalen
	subs r1,r1,#1
	str r1,datalen
	movgt pc,lr

	mov r1,#0xD8			;Status out.
	strb r1,scsisignal
	mov r1,#0
	strb r1,scsidata

	adrl r1,scsicmd
	ldrb r1,[r1]
	cmp r1,#0x08
;	cmpne r1,#0xD8
;	cmpne r1,#0xD9
	ldreqb r1,cdirqreq
	orreq r1,r1,#0x20		;CD Read finnished
	streqb r1,cdirqreq
	b Check_CD_IRQ
;	mov pc,lr

NoRead08
	adr r0,RD_txt + 8*8
	vbadebugg
	mov r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
CD09_R
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	mov r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
CD0A_R		; ADPCM data read
;----------------------------------------------------------------------------
;	adr r0,RD_txt + 80
;	vbadebugg

	ldr r0,adrdptr
	add r1,r0,#0x10000
	str r1,adrdptr
	ldr r1,=CD_PCM_RAM
	ldrb r1,[r1,r0,lsr#16]
	ldrb r0,adlatch
	strb r1,adlatch

	mov pc,lr
;----------------------------------------------------------------------------
CD0B_R
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,addma
	mov pc,lr
;----------------------------------------------------------------------------
CD0C_R		; ADPCM Status
;----------------------------------------------------------------------------
;	adr r0,RD_txt + 96
;	vbadebugg
;	mov r11,r11				;No$GBA Debugg
	ldr r0,adplaytime
	cmp r0,#0
	movle r0,#1
	movhi r0,#0
	mov pc,lr
;----------------------------------------------------------------------------
CD0D_R
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	ldrb r0,adadrctrl
	mov pc,lr
;----------------------------------------------------------------------------
CD0E_R
;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
CD0F_R
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	mov r0,#0
	mov pc,lr


;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
CD00_W		; SCSI BUS SIGNALS
;----------------------------------------------------------------------------
	cmp r0,#0x60
	moveq r1,#0
	streqb r1,scsisignal
	ldrb r1,scsisignal
	cmp r1,#0
	cmpeq r0,#0x81
	moveq r1,#0xD0
	streqb r1,scsisignal
	moveq r1,#0
	streqb r1,scsiptr
	mov pc,lr
;----------------------------------------------------------------------------
CD01_W		; SCSI BUS DATA
;----------------------------------------------------------------------------
	ldrb r1,scsisignal
	tst r1,#0x08
	streqb r0,scsidata
	mov pc,lr
WR_txt
	DCB "W$1800",10,0
	DCB "W$1801",10,0
	DCB "W$1802",10,0
	DCB "W$1803",10,0
	DCB "W$1804",10,0
	DCB "W$1805",10,0
	DCB "W$1806",10,0
	DCB "W$1807",10,0
	DCB "W$1808",10,0
	DCB "W$1809",10,0
	DCB "W$180A",10,0
	DCB "W$180B",10,0
	DCB "W$180C",10,0
	DCB "W$180D",10,0
	DCB "W$180E",10,0
	DCB "W$180F",10,0
RD_txt
	DCB "R$1800",10,0
	DCB "R$1801",10,0
	DCB "R$1802",10,0
	DCB "R$1803",10,0
	DCB "R$1804",10,0
	DCB "R$1805",10,0
	DCB "R$1806",10,0
	DCB "R$1807",10,0
	DCB "R$1808",10,0
	DCB "R$1809",10,0
	DCB "R$180A",10,0
	DCB "R$180B",10,0
	DCB "R$180C",10,0
	DCB "R$180D",10,0
	DCB "R$180E",10,0
	DCB "R$180F",10,0
;----------------------------------------------------------------------------
CD02_W		; IRQ2 Mask & SCSI ACK
;----------------------------------------------------------------------------
	ldrb r1,cdirqmask
	strb r0,cdirqmask
	eor r1,r1,r0
	and r1,r1,r0
;---------------------
	ldrb r2,cdirqreq
	and r2,r2,r0
	tst r2,#0x7C
	ldrb r2,irqPending
	bic r2,r2,#1			;clear CD IRQ
	orrne r2,r2,#1			;set CD IRQ if appropriate
	strb r2,irqPending
;---------------------
	tst r1,#0x80			;cd-ack?
	moveq pc,lr				;no.

	ldrb r1,scsisignal
	cmp r1,#0xD0
	beq GetCommand
	cmp r1,#0xC8
	beq SendData
	cmp r1,#0xD8
	beq SendStatus
	cmp r1,#0xF8
	beq SendMessage
	mov pc,lr				;zero or unknown.

GetCommand
	adrl r1,scsicmd
	ldrb r2,scsiptr
	ldrb r0,scsidata
	strb r0,[r1,r2]
	add r2,r2,#1
	cmp r2,#10				;maybe even 6?
	moveq r2,#0
	strb r2,scsiptr
	movne pc,lr				;exit
	mov r0,#0xC8			;
	strb r0,scsisignal
	ldrb r0,[r1]			;Get command
	cmp r0,#0x00			;Test Unit Ready
	beq CMD_TestUnitReady
	cmp r0,#0x03			;Request Sense
	beq CMD_RequestSense
	cmp r0,#0x08			;Read 6
	beq CMD_Read6
	cmp r0,#0xD8			;Play CD, set start time, play & search
	beq CMD_PlayCD
	cmp r0,#0xD9			;Play CD, set end time
	beq CMD_PlayCD2
	cmp r0,#0xDA			;Paus CD
	beq CMD_PausCD
	cmp r0,#0xDD			;Read SubChannel?
	beq CMD_SubQ
	cmp r0,#0xDE			;Get Info
	beq CMD_GetInfo
	b CMD_Unknown

SendData
	ldr r1,datalen
	subs r1,r1,#1
	str r1,datalen
	ldr r2,dataoutptr
	ldrb r0,[r2,#1]!
	movle r0,#0				;Scsidata should be clear if we have sent all the data
	strb r0,scsidata
	str r2,dataoutptr
	movle r0,#0xD8
	strleb r0,scsisignal
	mov pc,lr
SendStatus
	mov r0,#0
	strb r0,scsidata
	mov r0,#0xF8
	strb r0,scsisignal
	mov pc,lr
SendMessage
	mov r0,#0x00
	strb r0,scsisignal
	mov pc,lr
;----------------------------------------------------------------------------
CD03_W
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	mov pc,lr
;----------------------------------------------------------------------------
CD04_W		; SCSI reset?
;----------------------------------------------------------------------------
	strb r0,scsireset
	tst r0,#2
	moveq pc,lr
	mov r1,#0
	strb r1,scsisignal
	strb r1,scsidata
	strb r1,cdaudioplaying
	mov pc,lr
;----------------------------------------------------------------------------
CD05_W		; start CD sound fetching, toggle L/R bit in $1803
;----------------------------------------------------------------------------
	ldrb r0,cdirqreq
	eor r0,r0,#2
	strb r0,cdirqreq
	mov pc,lr
;----------------------------------------------------------------------------
CD06_W
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	mov pc,lr
;----------------------------------------------------------------------------
CD07_W
;----------------------------------------------------------------------------
	tst r0,#0x80			;unlock BRAM if bit 7 is set when writing to 0x1807
	movne r1,#1
	strneb r1,bramaccess
	mov pc,lr
;----------------------------------------------------------------------------
CD08_W		; ADPCM read/write adr low
;----------------------------------------------------------------------------
	strb r0,adptr+2
	mov pc,lr
;----------------------------------------------------------------------------
CD09_W		; ADPCM read/write adr high
;----------------------------------------------------------------------------
	strb r0,adptr+3
	mov pc,lr
;----------------------------------------------------------------------------
CD0A_W		; ADPCM-RAM write
;----------------------------------------------------------------------------
	ldr r1,adwrptr
	ldr r2,=CD_PCM_RAM
	strb r0,[r2,r1,lsr#16]
	add r1,r1,#0x10000
	str r1,adwrptr
	mov pc,lr
;----------------------------------------------------------------------------
CD0B_W		; CD-ROM to ADPCM-RAM DMA
;----------------------------------------------------------------------------
	strb r0,addma
	tst r0,#0x02
	moveq pc,lr
;-------------------------
	stmfd sp!,{r3-r6}

	ldr r2,dataoutptr		;CD sector pointer
	str r2,dmaoutptr		;CD sector pointer
	ldr r1,datalen			;CD transfer length
	ldr r3,adwrptr			;ADPCM write pointer
	ldr r4,=CD_PCM_RAM		;ADPCM-RAM base
dmaloop
	ldrb r0,[r2],#1
	strb r0,[r4,r3,lsr#16]
	add r3,r3,#0x10000
	subs r1,r1,#1
	bhi dmaloop
	str r3,adwrptr


	ldmfd sp!,{r3-r6}
;-------------------------
	ldrb r1,cdirqreq
	orr r1,r1,#0x20
	strb r1,cdirqreq
	mov r1,#0xD8			;no data only status
	strb r1,scsisignal
	mov r1,#0
	strb r1,scsidata
	adr r0,CDMA_txt
	vbadebugg
	and cycles,cycles,#CYC_MASK		;Save CPU bits
	b Check_CD_IRQ
CDMA_txt
	DCB "CD DMA",10,0
;----------------------------------------------------------------------------
CD0C_W		; ADPCM status (Read Only?)
;----------------------------------------------------------------------------
;	mov r11,r11				;No$GBA Debugg
	mov pc,lr
;----------------------------------------------------------------------------
CD0D_W		; ADPCM adr control
;----------------------------------------------------------------------------
	ldrb r1,adadrctrl
	strb r0,adadrctrl
	eor r1,r0,r1
	and r0,r0,r1			;r0=bits set this time
	bic r1,r1,r0			;r1=bits reset this time
	ldr r2,adptr

	tst r1,#0x03
	strne r2,adwrptr
	tst r1,#0x0C
	strne r2,adrdptr
	tst r1,#0x10
	strne r2,adlen
	tst r0,#0x80
	movne r2,#0
	strne r2,adlen
	strne r2,adptr
	strne r2,adwrptr
	strne r2,adrdptr
	tst r0,#0x60			;was r1
	ldrne r0,adlen
	movne r0,r0,lsr#20		;just a made up number to count.
	strne r0,adplaytime
	moveq pc,lr
	adr r0,PS_txt
	vbadebugg
	mov pc,lr

PS_txt
	DCB "PlaybackStart",10,0,0
;----------------------------------------------------------------------------
CD0E_W		; ADPCM playback rate
;----------------------------------------------------------------------------
	strb r0,adpcmrate
	adr r0,PB_txt
	vbadebugg
	mov pc,lr
PB_txt
	DCB "PlaybackRate",10,0,0,0
;----------------------------------------------------------------------------
CD0F_W		; CD Audio fade
;----------------------------------------------------------------------------
	strb r0,cdaudiofade
	mov pc,lr

;----------------------------------------------------------------------------
dmaoutptr
	DCD 0 ;dma data byte ptr
dataoutptr
	DCD 0 ;scsi data byte ptr
datalen
	DCD 0 ;scsi data length in bytes
sectorptr
	DCD 0 ;audio sector pointer, shift 2 right to get real value.
sectorend
	DCD 0 ;audio end sector pointer, shift 2 right to get real value.
adptr
	DCD 0 ;ADPCM ptr
adlen
	DCD 0 ;ADPCM length
adwrptr
	DCD 0 ;ADPCM write ptr
adrdptr
	DCD 0 ;ADPCM read ptr
adplaytime
	DCD 0 ;ADPCM play timer (for emulation)
amplitude
	DCD 0 ;CD Audio amplitude

scsisignal
	DCB 0 ;bit7-3		($1800)
scsidata
	DCB 0 ;				($1801)
cdirqmask
	DCB 0 ;bit7=cd-ack?	($1802)
cdirqreq
	DCB 0 ;				($1803)
scsireset
	DCB 0 ;				($1804)
adlatch
	DCB 0 ;ADPCM read latch ($180A)
addma
	DCB 0 ;ADPCM DMA ctrl ($180B)
adadrctrl
	DCB 0 ;ADPCM address control ($180D)
adpcmrate
	DCB 0 ;ADPCM playback rate ($180E)
cdaudiofade
	DCB 0 ;CD Audio fade ($180F)
cdaudioplaying
	DCB 0	;is cd audio playing?
scsiptr
	DCB 0	;which byte of the command
scsicmd
	DCB 0,0,0,0,0,0,0,0,0,0
scsiresponse
	DCB 0,0,0,0,0,0,0,0,0,0
d8cmd
	DCB 0,0,0,0,0,0,0,0,0,0

	ALIGN

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
CMD_TestUnitReady
	mov r0,#0xD8			;no data only status
	strb r0,scsisignal
	mov r0,#0
	strb r0,scsidata
	adr r0,TUR_txt
	vbadebugg
	mov pc,lr
TUR_txt
	DCB "TestUnitReady",10,0,0
;----------------------------------------------------------------------------
CMD_RequestSense
	adr r0,RS_txt
	vbadebugg
	mov pc,lr
RS_txt
	DCB "RequestSense",10,0,0,0
;----------------------------------------------------------------------------
CMD_Read6
	stmfd sp!,{r3-r5,lr}

	ldrb r0,cdirqreq
	bic r0,r0,#0x20			;Clear CD Read finnished.
	strb r0,cdirqreq
	mov r0,#0				;Audio isn't playing anymore
	strb r0,cdaudioplaying
	adrl r2,scsicmd
	ldrb r0,[r2,#4]			;number of sectors
	mov r0,r0,lsl#11		;0x800
	str r0,datalen

	ldrb r0,[r2,#1]			;LBA1
	and r0,r0,#0x1F
	ldrb r1,[r2,#2]			;LBA2
	orr r0,r1,r0,lsl#8		;
	ldrb r1,[r2,#3]			;LBA3
	orr r0,r1,r0,lsl#8
	mov r4,r0				;Save LBA
	bl LBA2Track			;Figure out which track it tries to read from
	mov r5,r0				;Save track
	bl Track2LBA			;Get first sector of this track

	sub r4,r4,r0
	mov r0,r5
	bl Track2Offset

	ldr r1,isobase
	add r1,r1,r0
	add r0,r1,r4,lsl#11		;0x800
	str r0,dataoutptr
	ldrb r0,[r0]
	strb r0,scsidata

	ldmfd sp!,{r3-r5,lr}

	adr r0,R6_txt
	vbadebugg
	mov pc,lr
R6_txt
	DCB "Read6",10,0,0
;----------------------------------------------------------------------------
CMD_PlayCD
	stmfd sp!,{r3-r5,lr}
	ldrb r0,cdirqreq
	bic r0,r0,#0x20			;Clear CD Read finnished.
	strb r0,cdirqreq

	adrl r4,scsicmd
	ldrb r0,[r4,#9]			;Tracks or MSF
	cmp r0,#0x40			;MSF
	bne notMSF
	ldrb r0,[r4,#2]			;Min
	ldrb r1,[r4,#3]			;Sec
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#4]			;Fra
	orr r0,r1,r0,lsl#8
	bl MSF2LBA
	b  writeSec
notMSF
	cmp r0,#0x80			;Tracks
	bne notTrack
	ldrb r0,[r4,#2]			;Track
	bl Bcd2Hex
	bl Track2LBA
writeSec
	mov r0,r0,lsl#2			;2 extra bits for the cd frame vs gba frame.
	str r0,sectorptr

notTrack
	ldrb r0,[r4,#1]			;To play or not.
	strb r0,cdaudioplaying
	mov r1,#0xD8			;no data only status
	strb r1,scsisignal
	mov r1,#0
	strb r1,scsidata

	mov r0,#10
d8loop
	ldrb r1,[r4],#1
	strb r1,[r4,#19]
	subs r0,r0,#1
	bne d8loop

	ldmfd sp!,{r3-r5,lr}
	adr r0,PC_txt
	vbadebugg
	mov pc,lr
PC_txt
	DCB "PlayCD_D8",10,0,0
;----------------------------------------------------------------------------
CMD_PlayCD2
	stmfd sp!,{r3-r5,lr}
	ldrb r0,cdirqreq
	bic r0,r0,#0x20			;Clear CD Read finnished.
	strb r0,cdirqreq

	adrl r4,scsicmd
	ldrb r0,[r4,#9]			;Tracks or MSF
	cmp r0,#0x40			;MSF
	bne notMSF2
	ldrb r0,[r4,#2]			;Min
	ldrb r1,[r4,#3]			;Sec
	orr r0,r1,r0,lsl#8
	ldrb r1,[r4,#4]			;Fra
	orr r0,r1,r0,lsl#8
	bl MSF2LBA
	b  writeSec2
notMSF2
	cmp r0,#0x80			;Tracks
	bne notTrack2
	ldrb r0,[r4,#2]			;Track
	bl Bcd2Hex
	bl Track2LBA
writeSec2
	mov r0,r0,lsl#2			;2 extra bits for the cd frame vs gba frame.
	str r0,sectorend

notTrack2
	ldrb r0,[r4,#1]			;To play or not.
	strb r0,cdaudioplaying
	mov r1,#0xD8			;no data only status
	strb r1,scsisignal
	mov r1,#0
	strb r1,scsidata

	ldmfd sp!,{r3-r5,lr}
	adr r0,PC2_txt
	vbadebugg
	mov pc,lr
PC2_txt
	DCB "PlayCD_D9",10,0,0
;----------------------------------------------------------------------------
CMD_PausCD
	mov r0,#0xD8			;no data only status
	strb r0,scsisignal
	mov r0,#0
	strb r0,scsidata
	strb r0,cdaudioplaying
	adr r0,PA_txt
	vbadebugg
	mov pc,lr
PA_txt
	DCB "PauseCD",10,0,0,0,0
;----------------------------------------------------------------------------
CMD_SubQ
;	mov r11,r11				;No$GBA Debugg
	stmfd sp!,{r3-r5,lr}
	adrl r5,scsiresponse
	ldrb r0,cdaudioplaying
	cmp r0,#0
	movne r0,#0				;0 if playing.
	moveq r0,#0x03			;3 if not playing.
	strb r0,[r5]			;CTRL & ADR, BIOS want's this to be 0 before a Pause.
	mov r0,#0x00
	strb r0,[r5,#1]			;????

	ldr r0,sectorptr
	mov r0,r0,lsr#2			;Throw away the lowest bits.
	bl LBA2Track			;r0 in & out
	mov r4,r0
	bl Hex2Bcd
	strb r0,[r5,#2]			;Track in BCD
	mov r1,#0x01
	strb r1,[r5,#3]			;Index (allways 1 for data track)

	mov r0,r4
	bl Track2LBA			;r0 in & out
	ldr r4,sectorptr
	rsb r0,r0,r4,lsr#2		;calculate sectors into this track.
	sub r0,r0,#150			;As this is only relative.
	bl LBA2MSF				;r0 in & out
	strb r0,[r5,#6]			;Track Frames
	mov r0,r0,lsr#8
	strb r0,[r5,#5]			;Track Seconds
	mov r0,r0,lsr#8
	strb r0,[r5,#4]			;Track Minutes

	ldr r0,sectorptr
	mov r0,r0,lsr#2			;Throw away the lowest bits.
	bl LBA2MSF				;r0 in & out
	strb r0,[r5,#9]			;Absolute Frames
	mov r0,r0,lsr#8
	strb r0,[r5,#8]			;Absolute Seconds
	mov r0,r0,lsr#8
	strb r0,[r5,#7]			;Absolute Minutes

	str r5,dataoutptr
	ldrb r0,[r5]
	strb r0,scsidata
	mov r0,#10
	str r0,datalen

	ldmfd sp!,{r3-r5,lr}
	adr r0,SQ_txt
	vbadebugg
	mov pc,lr
SQ_txt
	DCB "SubQ",10,0,0,0
;----------------------------------------------------------------------------
CMD_GetInfo
	mov r0,#0
	mov r2,#4
	str r2,datalen
	adrl r1,scsiresponse
	str r1,dataoutptr
GIloop
	subs r2,r2,#1
	strneb r0,[r1,r2]
	bne GIloop

	adrl r2,scsicmd
	ldrb r0,[r2,#1]
	cmp r0,#0
	beq firstlasttrack
	cmp r0,#1
	beq totaltime
	cmp r0,#2
	beq trackinfo
	adrl r1,GIUK_txt
GIback
	ldrb r0,scsiresponse
	strb r0,scsidata
	mov r0,r1
	vbadebugg
	mov pc,lr

;--------------------------------
firstlasttrack
	stmfd sp!,{r3-r4,lr}
	ldr r4,tgcdbase
	mov r0,#0x01			;First Track
	strb r0,scsiresponse
	ldrb r0,[r4,#12]		;Last Track
	bl Hex2Bcd
	strb r0,scsiresponse+1
	adr r1,GIFL_txt
	ldmfd sp!,{r3-r4,lr}
	b GIback
;--------------------------------
totaltime
	stmfd sp!,{r3,r4,lr}

	ldr r4,tgcdbase
	ldrb r0,[r4,#13]		;Total len, LBA
	ldrb r2,[r4,#14]
	orr r0,r2,r0,lsl#8
	ldrb r2,[r4,#15]
	orr r0,r2,r0,lsl#8

	bl LBA2MSF

	strb r0,scsiresponse+2	;frames
	mov r0,r0,lsr#8
	strb r0,scsiresponse+1	;seconds (2=150 frames/sectors)
	mov r0,r0,lsr#8
	strb r0,scsiresponse	;total minutes

	ldmfd sp!,{r3,r4,lr}
	adrl r1,GITT_txt
	b GIback
;--------------------------------
trackinfo
	ldrb r0,[r2,#2]			;track number
	adrl r1,GITI_txt
	and r2,r0,#0xf
	add r2,r2,#0x30
	strb r2,[r1,#19]
	mov r2,r0,lsr#4
	add r2,r2,#0x30
	strb r2,[r1,#18]

	stmfd sp!,{r3,lr}

	bl Bcd2Hex				;r0 in & out

	ldr r2,tgcdbase
	add r2,r2,r0,lsl#3		;(Track number x 8)
	ldrb r1,[r2,#8]			;Mode for this track
	strb r1,scsiresponse+3

	bl Track2LBA			;r0 in & out
	bl LBA2MSF				;r0 in & out

	strb r0,scsiresponse+2	;frames
	mov r0,r0,lsr#8
	strb r0,scsiresponse+1	;seconds (2=150 frames/sectors)
	mov r0,r0,lsr#8
	strb r0,scsiresponse	;track starting minutes

	ldmfd sp!,{r3,lr}
	adrl r1,GITI_txt
	b GIback

;----------------------------------------------------------------------------
LBA2MSF						;r0 input & output, uses r1-r3.
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	add r0,r0,#150			;MSF is 150 more than LBA

	ldr r1,=4500			;number of frames in a minute
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	mov r4,r1
	bl Hex2Bcd
	mov r5,r0				;track starting minutes

	mov r0,r4
	mov r1,#75				;number of frames in a second
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	mov r4,r1
	bl Hex2Bcd
	orr r5,r0,r5,lsl#8		;seconds (2=150 frames/sectors)
	mov r0,r4
	bl Hex2Bcd
	orr r0,r0,r5,lsl#8		;frames

	ldmfd sp!,{r4-r5,pc}
;----------------------------------------------------------------------------
MSF2LBA						;r0 input & output, uses r1-r3.
;----------------------------------------------------------------------------
	stmfd sp!,{r4,lr}

	mov r4,r0				;save MSF to r4
	mov r0,r0,lsr#16
	bl Bcd2Hex
	ldr r1,=4500			;number of frames in a minute
	mul r3,r1,r0

	mov r0,r4,lsr#8
	and r0,r0,#0xFF
	bl Bcd2Hex
	mov r1,#75				;number of frames in a second
	mla r3,r1,r0,r3

	and r0,r4,#0xFF
	bl Bcd2Hex
	add r0,r3,r0

	sub r0,r0,#150			;LBA is 150 less than MSF

	ldmfd sp!,{r4,pc}
;----------------------------------------------------------------------------
LBA2Track					;r0 input & output, uses r1-r3.
;----------------------------------------------------------------------------
	stmfd sp!,{r4-r5,lr}

	mov r4,r0				;Save LBA to compare.
	ldr r1,tgcdbase
	ldrb r5,[r1,#12]		;How many tracks
TrLoop
	mov r0,r5
	bl Track2LBA			;r0 in & out
	cmp r4,r0
	submi r5,r5,#1
	bmi TrLoop
	mov r0,r5

	ldmfd sp!,{r4-r5,pc}
;----------------------------------------------------------------------------
Track2LBA					;r0 input & output, uses r1-r2.
;----------------------------------------------------------------------------
	ldr r2,tgcdbase
	add r2,r2,r0,lsl#3		;(Track number x 8)

	ldrb r0,[r2,#9]			;LBA for this track
	ldrb r1,[r2,#10]
	orr r0,r1,r0,lsl#8
	ldrb r1,[r2,#11]
	orr r0,r1,r0,lsl#8

	bx lr
;----------------------------------------------------------------------------
Track2Offset				;r0 input & output, uses r1. Gives the offset from the iso start.
;----------------------------------------------------------------------------
	ldr r1,tgcdbase
	add r1,r1,r0,lsl#3		;(Track number x 8)
	ldr r0,[r1,#12]			;Offset for this track
	bx lr
;----------------------------------------------------------------------------
Hex2Bcd						;r0 input & output, uses r1-r3.
;----------------------------------------------------------------------------
	mov r1,#10
	swi 0x060000			;Division r0/r1, r0=result, r1=remainder.
	add r0,r1,r0,lsl#4		;(result x 16)+Remainder.
	bx lr
;----------------------------------------------------------------------------
Bcd2Hex						;r0 input & output, uses r1.
;----------------------------------------------------------------------------
	mov r1,r0,lsr#4
	and r0,r0,#0xf
	add r1,r1,r1,lsl#2		;multiply by 5
	add r0,r0,r1,lsl#1		;multiply by 2 and add low
	bx lr
;----------------------------------------------------------------------------
CMD_Unknown
;	mov r11,r11				;No$GBA Debugg
	adr r0,UK_txt
	vbadebugg
	mov pc,lr
;----------------------------------------------------------------------------
TGCD_D_Header
	INCBIN Default.tcd
TGCD_M_Header
	INCBIN MusicCD.tcd

GIFL_txt
	DCB "GetInfo FirstLast",10,0
GITT_txt
	DCB "GetInfo TotalTime",10,0
GITI_txt
	DCB "GetInfo TrackInfo   ",10,0
GIUK_txt
	DCB "GetInfo "
UK_txt
	DCB "Unknown",10,0

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
	END
