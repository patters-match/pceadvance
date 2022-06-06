# PCEAdvance v7.5

This is an NEC PC Engine / TurboGrafx-16 emulator for the Gameboy Advance, rescued from the [Web 
Archive](https://web.archive.org/web/20150430211123/http://www.ndsretro.com/gbadown.html). It can also emulate PC Engine 
CD-ROM² games, Super CD-ROM², and even Arcade CD-ROM² titles if you have an EZ-Flash III / IV / 3in1 flashcart or a 
SuperCard, which can provide the required additional RAM.

It's mostly slow but there are actually games that are enjoyable:
- 1943 Kai (J) - Takes some time before it starts, but runs ok
- Aero Blasters (U) - ok speed. (spr 6)
- After Burner II (J) - Cool game =)
- Alien Crush (J) - Perfect?
- Atomic Robokid Special (J) - Good speed. (spr 0)
- Bomberman 93 - Perfect?
- Darius (Alpha/Plus) - Very good speed
- Gomola Speed - Strange but funny game
- Hani in the Sky (J) - Good speed
- Image Fight (J) - Good speed
- Kyuukyoku Tiger (J) - Good Speed
- Mr. Heli - Screen to wide, otherwise ok
- Neutopia (U) - Seem ok, even save
- Ninja Warriors (J) - Good speed
- Operation Wolf (J) - Good speed
- Override (J) - Super speed if you turn off Timer IRQ
- Pacland (J) - Good speed
- R-Type - Good speed
- Rastan Saga II (J) - Good speed
- Super Star Soldier
- Tatsujin (J) - Good speed
- Tenseiryu Saint Dragon (J) - Good speed

These are just suggestions, please try what ever game you like. A lot of US games don't work because they are encrypted, use 
PCEToy to decrypt these before you use them. Also remember to click "US rom" in the legacy Win32 builder app if you want 
them to work. If using the Python 3 builder make sure US ROM filenames contain (U) or (USA). Don't use overdumps as these 
are evil on PC Engine.

## How to use
When the emulator starts use Up/Down to select game, then use B or A to start the game selected. Press L+R to open the menu, 
A to choose, B (or L+R again) to cancel.
- HScroll: (Manual) Lets you scroll the screen with the L & R buttons
- Unscaled modes: L & R buttons scroll the screen up and down
- Scaled modes: Press L+SELECT to adjust the background
- Sound:
  - *Off* - no sound
  - *On* - low quality low CPU usage
  - *On (Mixer)* - better quality more cpu usage
- TimerIRQ: Some games use the TimerIRQ to play sounds and music, by disabling the timer you can make some games faster
- EWRAM speed: this changes the waitstate on EWRAM between 2 and 1, this can probably damage your GBA and definitly uses 
more power, little to no speedgain. Don't use!
- Speed modes: L+START switches between throttled/unthrottled/slomo mode
- Sleep: START+SELECT wakes up from sleep mode (activated from menu or 5/10/30 minutes of inactivity)

## Pogoshell
To use as a Pogoshell plugin, first copy *pceadvance.gba* to the plugin folder then rename it to *pce.bin*. To make it work 
with US roms the name of the rom must not contain (J) or (j). In the same manner Japanese roms should preferably contain (J) 
or (j), most Japanese roms seem to run on US hardware anyway though.

## Multiplayer link play
Go to the menu and change Controller: to read *Link2P/Link3P/Link4P*, depending on how many Gameboys you will use. Once this 
is done on all GBAs, leave the menu on all slaves first, then the master, the game will restart and you can begin playing. 
If the link is lost (cable is pulled out, or a GBA is restarted), link must be re-initiated, this is done by a restart on 
the master and then selecting the appropriate link and leave the menu. The slaves doesn't have to do anything. Use an 
original Nintendo cable!

## SRAM
The first 8KB of the GBA SRAM is the PC Engine SRAM. This can be exchanged between other PC Engine emulators, I think you 
have to change MagicEngine's INI to old format. Use a *CD-ROM System* ROM to manage your PC Engine SRAMs, press Select to 
access the SRAM manager. The US version is encrypted, don't forget to decrypt it.

## PC Engine CD-ROM support
The legacy Win32 builder prevents adding CD-ROM data correctly (it mistakenly pads the preceding ROM data), so use the new 
Python 3 builder instead. You can read the builder's full help text using the ```-h``` option. To be able to use PC Engine / 
TurboGrafx16 CD-ROM games you have to have a *CD-ROM System* ROM in your build. The builder will add this automatically, it 
defaults to importing the file *bios.bin* but this can be overridden using the ```-b``` option (BIOS).

Most CD-ROM games have data in CD track 2, and a very similar sized second copy of that data as the final CD track. All 
other tracks are usually audio. PCEAdvance cannot play the audio so usually it only needs the track 2 data in ```.iso``` 
format. This can be extracted from a typical ```.bin/.cue``` disc image using a tool such as Isobuster for Windows, or using 
*bchunk* on macOS or Linux. You should include in the ISO filename the required system type: (CD), or (SCD) for Super 
CD-ROM², or (ACD) for Arcade CD-ROM². You can determine this by consulting the lists published at https://www.necstasy.net

Some games do have multiple data tracks (excluding the last duplicate of track 2), for instance *Macross 2036*, and in this 
case they will need at ```.tcd``` track index file. Some are included with PCEAdvance, along with the specification. If you 
need to make new ones, the TOC LBA values can be taken directly from https://www.necstasy.net and converted to hex. If the 
Python 3 builder finds a ```.tcd``` file with the same name as the added ```.iso``` file it will be added automatically. If 
the name is different, it can be specified using the ```-t``` option.

Owing to the way PCEAdvance organises the CD-ROM data you are limited to a single CD game in each build, but it can co-exist 
with other ROMs and it can be added in any order in the list using the Python 3 builder.

An additional caveat is that the PSRAM on the EZ-Flash flashcarts is limited to 16MB. Unfortunately PSRAM cannot be accessed 
if the emulator is run from NOR flash (32MB). This means that for Super CD-ROM² support (which needs 192KB of cart RAM), 
titles larger than 16MB must truncated by the Python builder using the ```-trim``` option so they will fit in PSRAM, losing 
some game data in the process. *Akumajou Dracula X: Chi no Rondo* is one such title. Though it does apparently work, it 
would not be playable to completion on EZ-Flash.

To use CD-ROM support from Pogoshell just make a build with only the CD-ROM System ROM and use it as the plugin for 
```.iso``` files (and ```.pce``` files).

#### CD-ROM² games tested so far:
- Addams Family (U): Ok, fullscreen images flicker
- Cosmic Fantasy 2 (U): Intro & game ok, can't fit whole game though
- Download 2 (J): Ok
- Exile (U): Crashes if you hit the Ants
- Final Zone II (U): Ok, need to skip intro
- Gain Ground: Too big.
- Golden Axe: Ok, need to skip intro
- HellFire S: Ok, screen too wide though
- Jyuohki (J)/(Altered Beast): Ok
- Macross 2036 (J): Ok
- MineSweeper (J): Ok
- Monster Lair: Ok
- Rayxanber II (U): Ok
- Red Alert (J): Ok
- Road Spirits: Ok
- Space Fantasy Zone (J/U): Ok
- Splash Lake (U): Ok
- Spriggan (J): Ok, stops after 3rd level?
- Super Darius: Ok. What is different from the Hucard version? A bigger logo?
- Valis II (U): Ok, need to skip intro
- Valis III (U): Works,I've only got the first data track so the intro is corrupt
- Valis IV (J): Same as Valis III
- Ys Book 1&2 (U): Ok
- Ys 3: Wanderers From Ys (U): Too big too fit on a flashcart

#### Super CD-ROM² games tested so far (SuperCard / EZ-Flash builds only):
- Conan: Intro Ok
- Cotton - Fantastic Night Dream (U): Ok
- Double Dragon 2: Ok
- Dracula X (J): Ok
- Forgotten Worlds (J): Ok
- Genocide (J): Ok
- Gradius 2 (J): Ok
- Image Fight 2 (U): Ok
- Loom (U): Flickering graphics.
- Lords Of Thunder: Ok
- Nexzr: Ok
- Rayxanber III (J): Ok
- Riot Zone: Ok
- R-Type Complete CD (J): Ok
- Shadow of the Beast (U): Ok, some flicker in intro

## Credits
Huge thanks to Loopy for the incredible PocketNES, without it this emulator would probably never have been made. Big thanks 
to Hoe for the ROM-Builder.
Thanks to:
- Zeograd for a lot of help with the debugging
- [Charles MacDonald](http://techno-junk.org) &
- David Shadoff for a lot of the info.


**Fredrik Ahlström**

https://github.com/FluBBaOfWard

https://twitter.com/TheRealFluBBa

Some things to consider regarding this emulation: PCE has 64KB of VRAM which can be background and/or sprites, GBA has 64KB 
background and 32KB sprite VRAM. The PCE CPU runs at either 1.78MHz (like the NES) or at 7.2MHz (all games seem to use the 
fast mode), the GBA CPU runs at 16MHz.

