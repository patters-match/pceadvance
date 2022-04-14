#include <string.h>
#include "gba.h"

#define STATEID 0x57a731da

#define SRAMSAVE 1
#define CONFIGSAVE 2

extern u8 Image$$RO$$Limit;
extern u8 g_cartflags;	//(from iNES header)
extern char g_scaling;	//(cart.s) current display mode
extern char flicker;	//from vdc.s
extern u8 stime;		//from main.c
extern char gammavalue;	//(vdc.s) current gammavalue
extern u32 soundmode;	//(sound.s) current soundmode
extern u8 *textstart;	//from main.c

extern char pogoshell;

//int totalstatesize;	//how much SRAM is used

//-------------------
//u8 *findrom(int);
//void cls(void);							//main.c
//void drawtext(int,char*,int);
//void waitframe(void);
//u32 getmenuinput(int);
void writeconfig(void);
//void setup_sram_after_loadstate(void);

//extern int roms;							//main.c
//extern int selected;						//ui.c
//extern char pogoshell_romname[32];		//main.c
//----asm stuff------
//int savestate(void*);						//cart.s
//void loadstate(int,void*);				//cart.s
void bytecopy_(u8 *dst,u8 *src,int count);	//memory.s

//extern u8 *romstart;						//from cart.s
//extern u32 romnum;						//from cart.s
//extern u32 frametotal;					//from h6280.s
//-------------------

typedef struct {		//(modified stateheader)
	u16 size;
	u16 type;	//=CONFIGSAVE
	char displaytype;
	char gammavalue;
	char soundmode;
	char sleepflick;
	u32 sram_checksum;	//checksum of rom using SRAM e000-ffff	
	u32 zero;	//=0
	char reserved4[32];  //="CFG"
} configdata;

//we have a big chunk of memory starting at Image$$RO$$Limit free to use
#define BUFFER1 (&Image$$RO$$Limit)


//quick & dirty rom checksum
u32 checksum(u8 *p) {
	u32 sum=0;
	int i;
	for(i=0;i<128;i++) {
		sum+=*p|(*(p+1)<<8)|(*(p+2)<<16)|(*(p+3)<<24);
		p+=128;
	}
	return sum;
}


int using_flashcart() {
	return (u32)textstart&0x8000000;
}


const configdata configtemplate={
	sizeof(configdata),
	CONFIGSAVE,
	3,2,0,0,0,0,
	"CFG"
};

void writeconfig() {
	configdata *cfg;
	int j;

	if(!using_flashcart())
		return;

	cfg=(configdata*)(BUFFER1);

	cfg->displaytype=g_scaling;				//store current display type
	cfg->gammavalue=gammavalue;				//store current gammavalue
	cfg->soundmode=(char)soundmode;			//store current soundmode
	j = stime & 0xF;						//store current autosleep time
	j |= ((flicker & 0x1)^1)<<4;			//store current flicker setting
	cfg->sleepflick = j;

	bytecopy_((u8*)MEM_SRAM+0x2000,(u8*)cfg,sizeof(configdata));
}

void readconfig() {
	int j;
	configdata *cfg;
	if(!using_flashcart())
		return;

	cfg=(configdata*)(BUFFER1);

	bytecopy_((u8*)cfg,(u8*)MEM_SRAM+0x2000,sizeof(configdata));

	if(cfg->type!=CONFIGSAVE || cfg->size!=sizeof(configdata)){
		memcpy(BUFFER1,&configtemplate,sizeof(configdata));
	}
	g_scaling=cfg->displaytype;
	gammavalue=cfg->gammavalue;
	soundmode=(u32)cfg->soundmode;
	j = cfg->sleepflick;
	stime = (j & 0xF);				//restore current autosleep time
	flicker = ((j & 0x10)^0x10)>>4;			//restore current flicker setting

}

