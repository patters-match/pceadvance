#include <stdio.h>
#include <string.h>

#include "gba.h"

//header files?  who needs 'em :P

void cls(int);		//from main.c
void initpalette(void);
void rommenu(void);
void drawtext(int,char*,int);
void setdarknessgs(int dark);
void setbrightnessall(int light);
extern char *textstart;

int SendMBImageToClient(void);	//mbclient.c

//----asm calls------
void resetSIO(u32);			//io.s
void doReset(void);			//io.s
void suspend(void);			//io.s
void waitframe(void);		//io.s
int gettime(void);			//io.s
void spriteinit(char);		//io.s
void debug_(int,int);		//vdc.s
void paletteinit(void);		//vdc.s
void PaletteTxAll(void);	//vdc.s
void endframe(void);		//vdc.s
void Sound_reset_(void);	//sound.s
//-------------------

extern u32 joycfg;			//from io.s
extern u32 timermask;		//from io.s
extern char g_emuflags;		//from cart.s
extern char g_scaling;		//from cart.s
extern char g_scalingx;		//from cart.s
extern char novblankwait;	//from h6280.s
extern u32 sleeptime;		//from h6280.s
extern u32 FPSValue;		//from vdc.s
extern u32 oambufferready;	//from vdc.s
extern char fpsenabled;		//from vdc.s
extern char gammavalue;		//from vdc.s
extern char twitch;			//from vdc.s
extern char flicker;		//from vdc.s
extern u32 soundmode;		//from sound.s	0=off, 1=on(GB), 2=on(DS)

extern char rtc;
extern char pogoshell;
extern char gameboyplayer;
extern char gbaversion;

u8 autoA,autoB;				//0=off, 1=on, 2=R
u8 stime=0;
u8 ewram=0;

void autoAset(void);
void autoBset(void);
void swapAB(void);
void controller(void);
void vblset(void);
void restart(void);
void exit(void);
void multiboot(void);
void scrolll(int f);
void scrollr(void);
void drawui1(void);
void drawui2(void);
void drawui3(void);
void subui(int menunr);
void ui2(void);
void ui3(void);
void drawclock(void);
void sleep(void);
void sleepset(void);
void fpsset(void);
void brightset(void);
void fadetowhite(void);
void ewramset(void);
void display(void);
void flickset(void);
void soundset(void);
void centerset(void);
void timerset(void);

void writeconfig(void);	//sram.c

#define MENU2ITEMS 6			//othermenu items
#define MENU3ITEMS 4			//displaymenu items
#define CARTMENUITEMS 10		//mainmenuitems when running from cart (not multiboot)
#define MULTIBOOTMENUITEMS 9	//"" when running from multiboot
const fptr fnlist1[]={autoBset,autoAset,controller,ui3,ui2,soundset,multiboot,sleep,restart,exit};
const fptr fnlist2[]={vblset,fpsset,sleepset,ewramset,swapAB,timerset};
const fptr fnlist3[]={display,flickset,brightset,centerset};

int selected;//selected menuitem.  used by all menus.
int mainmenuitems;//? or CARTMENUITEMS, depending on whether saving is allowed

u32 oldkey;//init this before using getmenuinput
u32 getmenuinput(int menuitems) {
	u32 keyhit;
	u32 tmp;
	int sel=selected;

	waitframe();		//(polling REG_P1 too fast seems to cause problems)
	tmp=~REG_P1;
	keyhit=(oldkey^tmp)&tmp;
	oldkey=tmp;
	if(keyhit&UP)
		sel=(sel+menuitems-1)%menuitems;
	if(keyhit&DOWN)
		sel=(sel+1)%menuitems;
	if(keyhit&RIGHT) {
		sel+=10;
		if(sel>menuitems-1) sel=menuitems-1;
	}
	if(keyhit&LEFT) {
		sel-=10;
		if(sel<0) sel=0;
	}
	if((oldkey&(L_BTN+R_BTN))!=L_BTN+R_BTN)
		keyhit&=~(L_BTN+R_BTN);
	selected=sel;
	return keyhit;
}

void ui() {
	int key,soundvol,oldsel,tm0cnt,i;
	ewram=((REG_WRWAITCTL & 0x0F000000) == 0x0E000000)?1:0;

	autoA=joycfg&A_BTN?0:1;
	autoA|=joycfg&(A_BTN<<16)?0:2;
	autoB=joycfg&B_BTN?0:1;
	autoB|=joycfg&(B_BTN<<16)?0:2;

	mainmenuitems=((u32)textstart>0x8000000?CARTMENUITEMS:MULTIBOOTMENUITEMS);//running from rom or multiboot?
	FPSValue=0;					//Stop FPS meter

	soundvol=REG_SGCNT0_L;
	REG_SGCNT0_L=0;				//stop sound (GB)
	tm0cnt=REG_TM0CNT;
	REG_TM0CNT=0;				//stop sound (directsound)

	selected=0;
	drawui1();
	initpalette();
	for(i=0;i<8;i++)
	{
		waitframe();
		setdarknessgs(i);		//Darken game screen
		REG_BG2HOFS=224-i*32;	//Move screen right
	}

	oldkey=~REG_P1;			//reset key input
	do {
		drawclock();
		key=getmenuinput(mainmenuitems);
		if(key&(A_BTN)) {
			oldsel=selected;
			fnlist1[selected]();
			selected=oldsel;
		}
		if(key&(A_BTN+UP+DOWN+LEFT+RIGHT))
			drawui1();
	} while(!(key&(B_BTN+R_BTN+L_BTN)));
	writeconfig();			//save any changes
	for(i=1;i<9;i++)
	{
		waitframe();
		setdarknessgs(8-i);	//Lighten screen
		REG_BG2HOFS=i*32;	//Move screen left
	}
	PaletteTxAll();			//restore PCE palette
	oambufferready=1;
	while(key&(B_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key=~REG_P1;
	}
	REG_SGCNT0_L=soundvol;	//resume sound (GB)
	REG_TM0CNT=tm0cnt;		//resume sound (directsound)
	cls(3);
}

void subui(int menunr) {
	int key,oldsel;

	selected=0;
	if(menunr==2)drawui2();
	if(menunr==3)drawui3();
	scrolll(0);
	oldkey=~REG_P1;			//reset key input
	do {
		if(menunr==2)key=getmenuinput(MENU2ITEMS);
		if(menunr==3)key=getmenuinput(MENU3ITEMS);
		if(key&(A_BTN)) {
			oldsel=selected;
			if(menunr==2)fnlist2[selected]();
			if(menunr==3)fnlist3[selected]();
			selected=oldsel;
		}
		if(key&(A_BTN+UP+DOWN+LEFT+RIGHT)) {
			if(menunr==2)drawui2();
			if(menunr==3)drawui3();
		}
	} while(!(key&(B_BTN+R_BTN+L_BTN)));
	scrollr();
	while(key&(B_BTN)) {
		waitframe();		//(polling REG_P1 too fast seems to cause problems)
		key=~REG_P1;
	}
}

void ui2() {
	subui(2);
}
void ui3() {
	subui(3);
}

void text(int row,char *str) {
	drawtext(row+10-mainmenuitems/2,str,selected==row);
}
void text2(int row,char *str) {
	drawtext(35+row+2,str,selected==row);
}


//trying to avoid using sprintf...  (takes up almost 3k!)
void strmerge(char *dst,char *src1,char *src2) {
	if(dst!=src1)
		strcpy(dst,src1);
	strcat(dst,src2);
}

char *const autotxt[]={"OFF","ON","with R"};
char *const vsynctxt[]={"ON","OFF","SLOWMO"};
char *const sleeptxt[]={"5min","10min","30min","OFF"};
char *const brightxt[]={"I","II","III","IIII","IIIII"};
char *const memtxt[]={"Normal","Turbo"};
char *const hostname[]={"Crap","Prot","GBA","GBP","NDS"};
char *const ctrltxt[]={"1P","2P","Link2P","Link3P","Link4P"};
char *const disptxt[]={"UNSCALED","UNSCALED (Auto)","SCALED","SCALED (w/sprites)"};
char *const flicktxt[]={"No Flicker","Flicker"};
char *const soundtxt[]={"OFF","ON","ON(Mixer)"};
char *const centxt[]={"Centered","Manual","Auto"};
char *const cntrtxt[]={"Pc-Engine (J)","TurboGrafx 16 (U)"};
char *const enabtxt[]={"Disabled","Enabled"};
char *const emuname[]={"      PCEAdvance ","         PogoPCE "};
void drawui1() {
	int i=0;
	char str[30];

	cls(1);
	drawtext(18,"Powered by XGFLASH2.com 2022",0);
	if(pogoshell) i=1;
	strmerge(str,emuname[i],"v7.5 on ");
	strmerge(str,str,hostname[gbaversion]);
	drawtext(19,str,0);

	strmerge(str,"B autofire: ",autotxt[autoB]);
	text(0,str);
	strmerge(str,"A autofire: ",autotxt[autoA]);
	text(1,str);
	strmerge(str,"Controller: ",ctrltxt[(joycfg>>29)-2]);
	text(2,str);
	text(3,"Display->");
	text(4,"Other Settings->");
	strmerge(str,"Sound: ",soundtxt[soundmode]);
	text(5,str);
	text(6,"Link Transfer");
	text(7,"Sleep");
	text(8,"Restart");
	if(mainmenuitems!=MULTIBOOTMENUITEMS) {
		text(9,"Exit");
	}
}

void drawui2() {
	char str[30];

	cls(2);
	drawtext(32,"       Other Settings",0);
	strmerge(str,"VSync: ",vsynctxt[novblankwait]);
	text2(0,str);
	strmerge(str,"FPS-Meter: ",autotxt[fpsenabled]);
	text2(1,str);
	strmerge(str,"Autosleep: ",sleeptxt[stime]);
	text2(2,str);
	strmerge(str,"EWRAM speed: ",memtxt[ewram]);
	text2(3,str);
	strmerge(str,"Swap A-B: ",autotxt[(joycfg>>10)&1]);
	text2(4,str);
	strmerge(str,"TimerIRQ: ",enabtxt[timermask]);
	text2(5,str);
	strmerge(str,"Machine: ",cntrtxt[(g_emuflags & 4)>>2]);		//USCOUNTRY=4
	text2(6,str);
}

void drawui3() {
	char str[30];

	cls(2);
	drawtext(32,"      Display Settings",0);
	strmerge(str,"Display: ",disptxt[g_scaling&3]);
	text2(0,str);
	strmerge(str,"Scaling: ",flicktxt[flicker]);
	text2(1,str);
	strmerge(str,"Gamma: ",brightxt[gammavalue]);
	text2(2,str);
	strmerge(str,"HScroll: ",centxt[g_scalingx&1]);
	text2(3,str);
}

void drawclock() {

    char str[30];
    char *s=str+20;
    int timer,mod;

    if(rtc)
    {
	strcpy(str,"                    00:00:00");
	timer=gettime();
	mod=(timer>>4)&3;				//Hours.
	*(s++)=(mod+'0');
	mod=(timer&15);
	*(s++)=(mod+'0');
	s++;
	mod=(timer>>12)&15;				//Minutes.
	*(s++)=(mod+'0');
	mod=(timer>>8)&15;
	*(s++)=(mod+'0');
	s++;
	mod=(timer>>20)&15;				//Seconds.
	*(s++)=(mod+'0');
	mod=(timer>>16)&15;
	*(s++)=(mod+'0');

	drawtext(0,str,0);
    }
}

void autoAset() {
	autoA++;
	joycfg|=A_BTN+(A_BTN<<16);
	if(autoA==1)
		joycfg&=~A_BTN;
	else if(autoA==2)
		joycfg&=~(A_BTN<<16);
	else
		autoA=0;
}

void autoBset() {
	autoB++;
	joycfg|=B_BTN+(B_BTN<<16);
	if(autoB==1)
		joycfg&=~B_BTN;
	else if(autoB==2)
		joycfg&=~(B_BTN<<16);
	else
		autoB=0;
}

void controller() {					//see io.s: refreshPCEjoypads
	u32 i=joycfg+0x20000000;
	if(i>=0xe0000000)
		i-=0xa0000000;
	resetSIO(i);					//reset link state
}

void sleepset() {
	stime++;
	if(stime==1)
		sleeptime=60*60*10;			// 10min
	else if(stime==2)
		sleeptime=60*60*30;			// 30min
	else if(stime==3)
		sleeptime=0x7F000000;		// 360days...
	else if(stime>=4){
		sleeptime=60*60*5;			// 5min
		stime=0;
	}
}

void vblset() {
	novblankwait++;
	if(novblankwait>=3)
		novblankwait=0;
}

void fpsset() {
	fpsenabled = (fpsenabled^1)&1;
}

void brightset() {
	gammavalue++;
	if (gammavalue>4) gammavalue=0;
	paletteinit();
	PaletteTxAll();					//make new palette visible
	initpalette();
}

void multiboot() {
	int i;
	cls(1);
	drawtext(9,"          Sending...",0);
	i=SendMBImageToClient();
	if(i) {
		if(i<3)
			drawtext(9,"         Link error.",0);
		else
			drawtext(9,"  Game is too big to send.",0);
		if(i==2) drawtext(10,"       (Check cable?)",0);
		for(i=0;i<90;i++)			//wait a while
			waitframe();
	}
}

void restart() {
	writeconfig();					//save any changes
	scrolll(1);
	__asm {mov r0,#0x3007f00}		//stack reset
	__asm {mov sp,r0}
	rommenu();
}
void exit() {
	writeconfig();					//save any changes
	fadetowhite();
	REG_DISPCNT=FORCE_BLANK;		//screen OFF
	REG_BG0HOFS=0;
	REG_BG0VOFS=0;
	REG_BLDCNT=0;					//no blending
	doReset();
}

void sleep() {
	fadetowhite();
	suspend();
	setdarknessgs(7);				//restore screen
	while((~REG_P1)&0x3ff) {
		waitframe();				//(polling REG_P1 too fast seems to cause problems)
	}
}
void fadetowhite() {
	int i;
	for(i=7;i>=0;i--) {
		setdarknessgs(i);			//go from dark to normal
		waitframe();
	}
	for(i=0;i<17;i++) {				//fade to white
		setbrightnessall(i);		//go from normal to white
		waitframe();
	}
}

void scrolll(int f) {
	int i;
	for(i=0;i<9;i++)
	{
		if(f) setdarknessgs(8+i);	//Darken screen
		REG_BG2HOFS=i*32;			//Move screen left
		waitframe();
	}
}
void scrollr() {
	int i;
	for(i=8;i>=0;i--)
	{
		waitframe();
		REG_BG2HOFS=i*32;			//Move screen right
	}
	cls(2);							//Clear BG2
}

void ewramset() {
	ewram^=1;
	if(ewram==1){
		REG_WRWAITCTL = (REG_WRWAITCTL & ~0x0F000000) | 0x0E000000;		//1 waitstate, overclocked
	}else{
		REG_WRWAITCTL = (REG_WRWAITCTL & ~0x0F000000) | 0x0D000000;		//2 waitstates, normal
	}
}

void swapAB() {
	joycfg^=0x400;
}

void display() {
	char sc;
	g_scaling=sc=(g_scaling+1)&3;
	spriteinit(sc);
	endframe();
	initpalette();
}

void flickset() {
	flicker++;
	if(flicker > 1){
		flicker=0;
		twitch=0;
	}
}

//void setcountry() {
//	g_emuflags ^= 4;				// USCOUNTRY
//	if(g_emuflags & 4)				// USCOUNTRY
//		joyptr=&JOYP_Ru;
//	else
//		joyptr=&JOYP_Rj;
//}

void soundset() {
	soundmode++;
	if(soundmode>2)
		soundmode=0;
	Sound_reset_();
}
void centerset() {
	g_scalingx^=1;
}
void timerset() {
	timermask^=1;
}
