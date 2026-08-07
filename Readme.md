#  [VSnes](https://en.wikipedia.org/wiki/Nintendo_VS._System) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

This is a FPGA implementation of the VS NES arcade system supporting UNI or DUAL systems allowing single or multi screen multiplayer. 

## OSD Options

* SNAC - Allows using NES accessories, can be used simultaneously with USB controls
* Light Gun - Enable to disable alarm of lightgun games. Needs a reset if enabled after boot
* Swap Joysticks - Swaps P1 and P2 controls, also P3 and P4 controls 
* Aspect Ratio - Original or stretched to 16:9
* Palette Override - Override the default palette
* Palette - Options (when overridden) 2C02,2C03,2C04-0000,2C04-0001,2C04-0002,2C04-0003,2C04-0004,2C05-99
* Swap Screen - Will swap screens between outputs. Can be used when in UNI mode or DUAL. In DUAL will swap the outputs or in splitscreen swap positions
* System Type - Uni will display NES1 by default to both HDMI and VGA outputs. Dual will Display NES1 and NES2 to both HDMI and VGA. Splitscreen is also possible on HDMI
* Split Screen - When in DUAL mode will enable vertical or horizontal split screen over HDMI
* Divider - Adds a black line dividing screens of splitscreen
* Keep Aspect Ratio - Tries to keep aspect ratio when using splitscreen
* Shared RAM - The two systems normally share RAM, this it disables that, used for two instances of SMB
* Audio Mix - NES1 or NES2 or a mix of both each with their own channel
* Save NVRAM - Manually saves the shared NVRAM.
* Load NVRAM - Manually load NVRAM that was loaded at boot
* Autosave - Automatically save NVRAM on OSD open
* DIPS - DIP switch settings for NES1 and NES2

## Installation

1. Copy the core `.rbf` file to your MiSTer `/_Arcade/cores` folder.
2. Copy the '.mra' file to your MiSTer '/_Arcade' folder.
3. Place the appropriate ROM `.zip` files in your `/games/mame` directory.

## Credits

* Sorgelig - ddram.sv, sdram.sv, framework, etc
* Andkorzh - [RP2A03](https://github.com/andkorzh/RP2A03-7-) and [RP2C02](https://github.com/andkorzh/RP2C02-7-)
* Mister Community - Thanks for all the help

