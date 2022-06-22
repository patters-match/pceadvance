# PCEAdvance v7.5

This is an NEC PC Engine / TurboGrafx-16 emulator by FluBBa for the Gameboy Advance with support for PC Engine CD-ROM², rescued from the [Web Archive](https://web.archive.org/web/20150430211123/http://www.ndsretro.com/gbadown.html).

It can also use additional RAM in an EZ-Flash III or SuperCard flashcart to emulate Super CD-ROM² (+192KB), and even Arcade CD-ROM² titles (+2240KB).

### Enhancement
In June 2022 I (patters) forked the source code to [create a version](https://github.com/patters-syno/pceadvance/releases/tag/v7.5-ez4) with the additional RAM support working for EZ-Flash IV and EZ-Flash 3in1 flashcarts.

Originally, PCEAdvance enabled the EZ-Flash III PSRAM [here in **cart.s**](https://github.com/patters-syno/pceadvance/blob/65c94787246d6f8c3655c55d0106812b51fa41fc/src/cart.s#L542), which is an ASM implementation of the _OpenRamWrite()_ function as seen in the [source code published by EZ-Team](https://github.com/ez-flash/ez3pda/blob/1d16559caf7a94dff6d8fdcf94f572bc09b36ae4/hard.cpp#L39). I scanned through the EZ-Flash IV firmware binary looking for compiled versions of some of those instructions, and once I found a relevant area I disassembled it. I found that _OpenWrite()_ preceded _OpenRamWrite()_ just as it does in the EZ-Team source code. I also compared various implementations of PSRAM access for EZ-Flash IV and EZ-Flash 3in1 devices which were written for the Nintendo DS:
- Rick "Lick" Wong's [RAM Unlocking API](https://forum.gbadev.org/viewtopic.php?f=18&t=13023) - dead download links now, but the latest v1.3 code can be found in **ram.c** in [memtestARM](http://pineight.com/ds/#memtestARM). This library was used by Simon J Hall's incredible DS ports of [Quake](https://web.archive.org/web/20170115031913/http://quake.drunkencoders.com/index_q1.html) and [Quake II](https://web.archive.org/web/20080912065436/http://quake.drunkencoders.com/index_q2.html).
- Dartz150's EZFlash3in1 [access library](https://github.com/Dartz150/EZFlash3in1/blob/eda7a82ef8ded7103f030a5cdf2d0d4d834b735e/dsCard.cpp#L574)
- Martin (NO$GBA) Korth's [cartridge port RAM documentation](https://www.problemkaputt.de/gbatek-ds-cart-expansion-ram.htm)

They all have in common that they use that same _OpenWrite()_ function to unlock the RAM, but _OpenRamWrite()_ is not used. So I made that function substitution in [PCEAdvance's **cart.s**](https://github.com/patters-syno/pceadvance/blob/e964f93a16d97ecd5427c6353c78da1e7db14d09/src/cart.s#L547), which did indeed awaken the EZ-Flash IV PSRAM. I then added EZ-Flash specific code for [exit back to the cart menu](https://github.com/patters-syno/pceadvance/blob/ez4/src/visoly.s), re-locking the PSRAM just prior, to replace **visoly.s**. I also added [clearing of the 192KB of PSRAM](https://github.com/patters-syno/pceadvance/blob/e964f93a16d97ecd5427c6353c78da1e7db14d09/src/cart.s#L130) before it is used as emulator RAM. EZ-Flash firmware will [not clear this automatically](https://www.dwedit.org/dwedit_board/viewtopic.php?pid=3349#p3349) so it could contain garbage from a previous game after exit back to the menu. This resolved the issue of Super CD-ROM² support only functioning directly after a power-on.

Unfortunately it is not possible to add support for EZ-Flash Omega, despite the open nature of its [technical documentation](https://github.com/ez-flash/omega-kernel/blob/master/docs/EZ-FLASH%20OMEGA%20DOCUMENT.pdf). As [confirmed by EZ-Team](https://gbatemp.net/threads/ezflash-omega-writing-in-psram.580813/post-9328539), PSRAM is not exposed for access once in game mode.

### Compatibility

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

These are just suggestions, please try what ever game you like. A lot of US games don't work because they are encrypted, use PCEToy to decrypt these before you use them. Also remember to click "US rom" in the legacy Win32 builder app if you want them to work. If using the Python 3 builder make sure US ROM filenames contain (U) or (USA). Don't use overdumps as these are evil on PC Engine.

## How to use
When the emulator starts use Up/Down to select game, then use B or A to start the game selected. Press L+R to open the menu, A to choose, B (or L+R again) to cancel.

### Settings:
	HScroll: (Manual) Lets you scroll the screen with the L & R buttons
	Unscaled modes: L & R buttons scroll the screen up and down
	Scaled modes: Press L+SELECT to adjust the background
	Sound:
		Off: no sound
		On: low quality low CPU usage
		On: (Mixer) - better quality more cpu usage
	TimerIRQ:
		Some games use the TimerIRQ to play sounds and music, by disabling the timer
		you can make some games faster
	EWRAM speed:
		This changes the waitstate on EWRAM between 2 and 1, this can probably damage
		your GBA and definitly uses more power, little to no speedgain. Don't use!
	Speed modes: L+START switches between throttled/unthrottled/slomo mode
	Sleep: START+SELECT wakes up from sleep mode (activated from menu or 5/10/30
	       minutes of inactivity)

## Pogoshell
To use as a Pogoshell plugin, first copy *pceadvance.gba* to the plugin folder then rename it to *pce.bin*. To make it work with US roms the name of the rom must not contain (J) or (j). In the same manner Japanese roms should preferably contain (J) or (j), most Japanese roms seem to run on US hardware anyway though.

## Multiplayer link play
Go to the menu and change Controller: to read *Link2P/Link3P/Link4P*, depending on how many Gameboys you will use. Once this is done on all GBAs, leave the menu on all slaves first, then the master, the game will restart and you can begin playing. If the link is lost (cable is pulled out, or a GBA is restarted), link must be re-initiated, this is done by a restart on the master and then selecting the appropriate link and leave the menu. The slaves doesn't have to do anything. Use an original Nintendo cable!

## SRAM
The first 8KB of the GBA SRAM is the PC Engine SRAM. This can be exchanged between other PC Engine emulators, I think you have to change MagicEngine's INI to old format. Use a CD-ROM System ROM to manage your PC Engine SRAMs, press Select to access the SRAM manager. The US version is encrypted, don't forget to decrypt it.

## PC Engine CD-ROM support
Compilations built with the legacy Win32 builder included with PCEAdvance 7.5 cannot have CD-ROM data appended correctly. This builder mistakenly pads the preceding ROM data which breaks CD support. Use the new Python 3 builder instead. You can read the builder's full help text using the ```-h``` option.

To be able to use PC Engine / TurboGrafx16 CD-ROM games you have to have a CD-ROM System ROM in your build. The builder will add this automatically, it defaults to importing the file *bios.bin* but this can be overridden using the ```-b``` option (BIOS). To use CD-ROM support from Pogoshell just make a compilation with only a CD-ROM System ROM and use it as the plugin for ```.iso``` and ```.pce``` files.

Most CD-ROM games have their data stored in CD track 2, and have a very similar sized second copy of that data as the final CD track. All other tracks are usually audio. PCEAdvance cannot play the audio so usually it only needs a game's track 2 data in ```.iso``` format. This can be extracted from a typical ```.bin/.cue``` disc image using a tool such as Isobuster for Windows, or using *bchunk* on macOS or Linux. Add ```.iso``` files using the builder in the same way as you would add a regular ```.pce``` file.

Some games do have multiple data tracks (excluding the last duplicate of track 2), for instance *Macross 2036*, and in this case they will need a ```.tcd``` track index file. Some are included with PCEAdvance, along with details of the specification. If you need to make new ones, the Table of Contents (TOC) LBA values can be taken directly from https://www.necstasy.net and converted to hex. If the Python 3 builder finds a ```.tcd``` file with the same name as the ```.iso``` file it will be added automatically. The track index can also be manually specified using the ```-t``` option.

Owing to the way PCEAdvance organises the CD-ROM data you are limited to a single CD game in each build, but it can co-exist with other ROMs and it can be added in any order in the list using the Python 3 builder.

Note that PSRAM on the EZ-Flash flashcarts is limited to 16MB. Unfortunately PSRAM cannot be addressed if the emulator is run from NOR flash (32MB). This means that both the PCEAdvance compilation and its additional RAM requirement must fit within that 16MB. Oversized compilations can be truncated by the builder using the ```-trim``` option, losing some game data in the process. For this reason you should label your ISO filenames with the required system type: (CD) for CD-ROM², (SCD) for Super CD-ROM², or (ACD) for Arcade CD-ROM². You can determine this by consulting the lists published at https://www.necstasy.net. *Akumajou Dracula X: Chi no Rondo* (20.8MB) is one such title. Although the trimmed game does apparently work, it would not be playable to completion on EZ-Flash.

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
- Rainbow Islands (J): Very slow
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
- Zero Wing (J): Ok

#### Super CD-ROM² games tested so far (SuperCard / EZ-Flash builds only):
- Akumajou Dracula X: Chi no Rondo (J): Ok
- Akumajou Dracula X: Chi no Rondo (J) (T+Eng): Ok
- Conan: Intro Ok
- Cotton - Fantastic Night Dream (U): Ok
- Double Dragon 2: Very slow
- Forgotten Worlds (J): Ok
- Gate of Thunder (J): Ok
- Genocide (J): Ok
- Gradius II - Gofer no Yabou (J): Ok
- Image Fight 2 (U): Ok
- Loom (U): Flickering graphics.
- Lords Of Thunder: Ok
- Nexzr: Ok
- Rayxanber III (J): Ok
- Riot Zone: Ok
- R-Type Complete CD (J): Ok
- Shadow of the Beast (U): Ok, some flicker in intro

#### Arcade CD-ROM² games tested so far (SuperCard / EZ-Flash builds only):
None confirmed working with EZ-Flash at least. Most data tracks are way too large. The only realistic contenders are:
- Mad Stalker (5.1MB): Hangs at loading screen
- Ginga Fukei Densetsu Sapphire (15.6MB): Hangs at white screen
- World Heroes 2 (17.7MB): Hangs at black screen

## Credits
Huge thanks to Loopy for the incredible PocketNES, without it this emulator would probably never have been made. Big thanks to Hoe for the ROM-Builder.
Thanks to:
- Zeograd for a lot of help with the debugging
- [Charles MacDonald](http://techno-junk.org) &
- David Shadoff for a lot of the info.


**Fredrik Ahlström**

https://github.com/FluBBaOfWard

https://twitter.com/TheRealFluBBa

Some things to consider regarding this emulation:
PC Engine|Gameboy Advance
:----|:----
64KB of VRAM which can be background and/or sprites|64KB background VRAM and 32KB sprite VRAM
CPU runs at either 1.78MHz (like the NES) or at 7.2MHz <br />all games seem to use the fast mode|CPU runs at 16MHz
