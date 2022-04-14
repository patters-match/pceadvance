//based on Jeff Frohwein's slave boot demo:
//http://www.devrs.com/gba/files/mbclient.txt

#include <stdio.h>
#include "gba.h"

u8 *findrom(int);

extern u8 Image$$RO$$Limit;
extern u8 Image$$ZI$$Base;
extern u32 romnum;	//from cart.s
extern u32 g_emuflags;	//from cart.s
extern u8 *textstart;	//from main.c

extern char pogoshell;
extern int pogosize;

romheader mb_header;
char neshead[16]={'N','E','S',0x1a,0,0,0,0,0,0,0,0,0,0,0,0};

u32 max_multiboot_size;		//largest possible multiboot transfer (init'd by boot.s)

typedef struct {
  u32 reserve1[5];      //
  u8 hs_data;           // 20 ($14) Needed by BIOS
  u8 reserve2;          // 21 ($15)
  u16 reserve3;         // 22 ($16)
  u8 pc;                // 24 ($18) Needed by BIOS
  u8 cd[3];             // 25 ($19)
  u8 palette;           // 28 ($1c) Needed by BIOS - Palette flash while load
  u8 reserve4;          // 29 ($1d) rb
  u8 cb;                // 30 ($1e) Needed by BIOS
  u8 reserve5;          // 31 ($1f)
  u8 *startp;           // 32 ($20) Needed by BIOS
  u8 *endp;             // 36 ($24) Needed by BIOS
  u8 *reserve6;         // 40 ($28)
  u8 *reserve7[3];      // 44 ($2c)
  u32 reserve8[4];      // 56 ($38)
  u8 reserve9;          // 72 ($48)
  u8 reserve10;         // 73 ($49)
  u8 reserve11;         // 74 ($4a)
  u8 reserve12;         // 75 ($4b)
} MBStruct;

const
#include "client.h"

void delay() {
	int i=32768;
	while(--i);	//(we're running from EXRAM)
}

void DelayCycles (u32 cycles)
{
    __asm{mov r2, pc}
    
    // EWRAM
    __asm{mov r1, #12}
    __asm{cmp r2, #0x02000000}
    __asm{beq MultiBootWaitCyclesLoop}
    
    // ROM 4/2 wait
    __asm{mov r1, #14}
    __asm{cmp r2, #0x08000000}
    __asm{beq MultiBootWaitCyclesLoop}
    
    // IWRAM
    __asm{mov r1, #4}
    
    __asm{MultiBootWaitCyclesLoop:}
    __asm{sub r0, r0, r1}
    __asm{bgt MultiBootWaitCyclesLoop}
}

u16 xfer(u32 send) {
    u32 i;
	
    i=1000;
	
	REG_SIOMLT_SEND = send;
	REG_SIOCNT = 0x2083;
	while((REG_SIOCNT & 0x80) && --i) {DelayCycles(10);}
	return (REG_SIOMULTI1);
}

int swi25(void *p) {
	__asm{mov r1,#1}
	__asm{swi 0x25, {r0-r1}, {}, {r0-r2} }
}

//returns error code:  1=no link, 2=bad send, 3=too big
#define TIMEOUT 40
int SendMBImageToClient(void) {
	MBStruct mp;
	u8 palette;
	u32 i,j;
	u16 key;
	u16 *p;
//	u16 slaves;
	u16 ie;
	u32 emusize1,emusize2,romsize;

//	emusize=((u32)(&Image$$RO$$Limit)&0x3ffff)+((u32)(&Image$$RW$$Limit)&0x7fff);
	emusize1=((u32)(&Image$$RO$$Limit)&0x3ffff);
	emusize2=((u32)(&Image$$ZI$$Base)&0x7fff);
	if(pogoshell) romsize=pogosize+16+sizeof(romheader);
	else romsize=sizeof(romheader)+*(u32*)(findrom(romnum)+32);
	if(emusize1+romsize>max_multiboot_size) return 3;

#if 0
    //this check frequently causes hangs, and is not necessary
	REG_RCNT=0x8003;		//general purpose comms - sc/sd inputs
	i=TIMEOUT;
	while(--i && (REG_RCNT&3)==3) delay();
	if(!i) return 1;

	i=TIMEOUT;
	while(--i && (REG_RCNT&3)!=3) delay();
	if(!i) return 1;
#endif

	REG_RCNT=0;			//non-general purpose comms

	i=250;
	do {
		DelayCycles(10);
		j=xfer(0x6202);
	} while(--i && j!=0x7202);
	if(!i) return 2;

	xfer (0x6100);
	p=(u16*)0x2000000;
	for(i=0;i<96; i++) {		//send header
		xfer(*p);
		p++;
	}

	xfer(0x6202);
	mp.cb = 2;
	mp.pc = 0xd1;
	mp.startp=(u8*)Client;
	i=sizeof(Client);
	i=(i+15)&~15;		//16 byte units
	mp.endp=(u8*)Client+i;

	palette = 0xef;
//8x=purple->blue
//9x=blue->emerald
//ax=emerald->green
//bx=green->yellow
//cx=yellow->red
//dx=red->purple
//ex=purple->white
	mp.palette = palette;

	xfer(0x6300+palette);
	i=xfer(0x6300+palette);

	mp.cd[0] = i;
	mp.cd[1] = 0xff;
	mp.cd[2] = 0xff;

	key = (0x11 + (i & 0xff) + 0xff + 0xff) & 0xff;
	mp.hs_data = key;

	xfer(0x6400 | (key & 0xff));

	ie=REG_IE;
	REG_IE=0;		//don't interrupt
	REG_DM0CNT_H=0;		//DMA stop
	REG_DM1CNT_H=0;
	REG_DM2CNT_H=0;
	REG_DM3CNT_H=0;

	if(swi25(&mp)){	//Execute BIOS routine to transfer client binary to slave unit
		i=2;
		goto transferEnd;
	}
	//now send everything else

	REG_RCNT=0;			//non-general purpose comms
	i=200;
	do {
		delay();
		j=xfer(0x99);
	} while(--i && j!=0x99); //wait til client is ready
	if(!i){ //mbclient not responding
		i=2;
		goto transferEnd;
	}
	xfer(emusize1+emusize2+romsize);		//transmission size..
	xfer((emusize1+emusize2+romsize)>>16);

	p=(u16*)((u32)0x2000000);	//(from ewram.)
	for(;emusize1;emusize1-=2)		//send first part of emu
		xfer(*(p++));
	p=(u16*)0x3000000;			//(from iwram)
	for(;emusize2;emusize2-=2)		//send second part of emu
		xfer(*(p++));
	if(pogoshell)
	{
		mb_header.filesize=pogosize+16;
		mb_header.flags=g_emuflags;
		p=(u16*)&mb_header;	//send MBheader
		for(i=0;i<sizeof(romheader);i+=2)
			xfer(*(p++));
		p=(u16*)&neshead;	//send NESheader
		for(i=0;i<16;i+=2)
			xfer(*(p++));
		romsize-=sizeof(romheader)+16;

		p=(u16*)findrom(romnum)+sizeof(romheader)/2;
	}
	else p=(u16*)findrom(romnum);	//send ROM
	for(;romsize;romsize-=2)
		xfer(*(p++));
	i=0;
transferEnd:
	REG_IE=ie;
	return i;
}