# FPGA craft

A voxel game for the iCE40 UP5K FPGA (for the iCEBreaker board).

## Disclaimer

Use this project at your own risk. This project has had no real testing, and unlike typical software, it may have bugs that damage your hardware (board, N64 controller, etc.). Only use it if you're familiar with FPGA/HW dev and you understand the risks.

## Screenshot

Note: this repo *does not* contain any assets/textures, you need to provide these yourself (more details below). 

![image](screenshot.png "Screenshot, made using the "Unity" texture pack (see below)")

## Features

* 3D voxel rendering on tiny FPGA!
* 256x192 resolution (256x128 3D area), 30 fps, 12 bit color
* Input via N64 controller
* Real-time terrain streaming from flash memory
* Placing and mining blocks
* Terrain changes by player are saved back to flash
* Max overworld size: 512x512x32 blocks (wraps at edges)
* Offline terrain generator (run on PC, then upload terrain to flash) with multiple biomes/features (grass, forest, desert, snow, caves)
* Low memory usage (15kb BRAM, 128kb SPRAM, 16MB flash)
* Custom ray tracing GPU that handles ~1 million rays/second
* Custom 16-bit CPU with its own instruction set, running at 32.625Mhz
* Compiled firmware is ~5kb, written in custom Forth like assembly langage, compiled using custom assembler ("kasm")
* Hardware design written in [Wyre, a custom hardware design language](https://github.com/nickmqb/wyre)
* Fully dynamic hardware based lighting system
* Day/night cycle (each full day is ~18 minutes)
* Up to 128 textures (using palette based texture compression to save memory)
* Dithering to emulate higher color bit depth
* Animated textures (lava, portals)
* Portals and multiple dimensions (though terrain gen for these is not implemented in this version, see note below)
* Transparent water rendering (slightly hacky)
* Underwater rendering & swim physics
* Fly around using rockets (item)
* Falling sand/gravel physics
* Water/lava physics (limited to modified terrain chunks)
* Noclip mode & debug info overlay (including player XYZ coords)
* Inventory system

Note: you may have seen (videos of) this project [on my twitter](https://twitter.com/nickmqb). This open source repo is a "light version" of the project, without the Minecraft specific terrain gen/biomes/structures.

## Requirements

* iCEBreaker board
* VGA PMOD
* VGA display
* N64 controller (You don't need an original "vintage" controller. For example, I'm just using a cheap third party replica.)
* Bring your own textures (see [Setting up textures](#setting-up-textures) below).

It should be possible to port the project to other boards/FPGAs, displays (e.g. using HDMI PMOD) and input devices (e.g. PS2 mouse/keyboard or GameCube controller). If you do, let me know and I'd be happy to add a link to your project.

## Build steps

### Preparation

1. Disconnect any currently connected peripherals from board.
1. Ensure yosys, nextpnr and icestorm are installed ([e.g. from here](https://github.com/esden/summon-fpga-tools)) and are available on your path.

### Getting the code

1. `git clone https://github.com/nickmqb/fpga_craft` (this repo) 
1. `git clone https://github.com/nickmqb/muon` and [follow the installation instructions](https://github.com/nickmqb/muon/blob/master/docs/getting_started.md).
1. If not already done, move the Muon compiler binary `mu` to the `muon` directory (i.e. file path of the binary, including filename should be: `muon/mu`).
1. `git clone https://github.com/nickmqb/wyre` and [follow the installation instructions](https://github.com/nickmqb/wyre/blob/master/docs/getting_started.md).
1. If not already done, move the Wyre compiler binary `wyre` to the `wyre/compiler` directory (i.e. file path of the binary, including filename should be: `wyre/compiler/wyre`).

### Setting up textures

As mentioned above, this repo does not include any textures (except for a few custom textures specifically made for this project). You need to provide your own. You have several options:

* If you own Minecraft, find your Minecraft .jar file (e.g. `.minecraft/versions/{latest_version}/{version.jar}`). From the .jar file, extract all .png files from `assets/minecraft/textures/block` and copy them to `fpga_craft/textures`.
* Download a Minecraft texture pack (e.g. [from here](https://www.curseforge.com/minecraft/texture-packs/sixteen-x?filter-game-version=&filter-sort=5)). This will be a .zip file with the same directory structure as the Minecraft .jar file. See the previous bullet point for which files to copy. Note: not all texture packs contain all required textures, so you may need to combine multiple packs. (Based on some quick experimentation, the ["Unity" pack](https://www.curseforge.com/minecraft/texture-packs/unity) works. The screenshot near the top of this doc was made with this pack.)
* Create your own textures or use a different source (e.g. a [Minetest texture pack](https://content.minetest.net/packages/?type=txp&page=1&tag=16px)). Because the naming scheme of the texture filenames will likely be different, you will need to manually tweak `fpga_craft/block_info_gen/block_info_generator.mu` (namespace `Ids`) and provide the right filenames.

### Building tools

1. `cd fpga_craft`
1. `cd bram_swap && ./build.sh && cd ..`
1. `cd kasm && ./build.sh && cd ..`

### Data gen

1. `cd block_info_gen && ./run.sh && cd ..`
1. `cd data_gen && ./run.sh && cd ..` (generates `fpga_craft/ram_a.bin` and `fpga_craft/textures.bin`)
1. `iceprog -o 2048k ram_a.bin`
1. `iceprog -o 2112k textures.bin`

### Terrain gen

1. Go to dir `fpga_craft/terrain_gen`
1. `./build.sh`
1. `./terrain_gen --dimension 1 --output overworld.bin` (Note: alternatively, you can use the OpenGL terrain_viewer for a preview of the generated terrain, see section below: [OpenGL terrain viewer: generating terrain](#opengl-terrain-viewer-generating-terrain))
1. `./terrain_gen --dimension 2 --output dim2.bin` ("Stub" generator, also see [Multiple dimensions](#multiple-dimensions))
1. `./terrain_gen --dimension 3 --output dim3.bin` ("Stub" generator)
1. `iceprog -o 8192k overworld.bin` (file is 8MB, so this will take several minutes)
1. `iceprog -o 4096k dim2.bin` (file is 0.5MB)
1. `iceprog -o 6144k dim3.bin` (file is 2MB)

### Building the hardware design

1. Go to dir `fpga_craft/hw`
1. Optional. A "save loop" bug could cause rapid flash write cycle use (though I didn't encounter any bugs like that so far). By default, the code to save terrain changes to flash is commented out. To enable saving, overwrite `src/firmware.ka` with `src/firmware_save.ka`, i.e.: `cp src/firmware_save.ka src/firmware.ka`. When the game is saving, a progress bar (consisting out of floppy disk icons) is shown in the top right. Saving is done when all floppy disks have vanished. If the progress bar gets stuck and doesn't update at all for a long time (e.g. >10 seconds), the game may be stuck in a "save loop", you should disconnect power if that happens. Additionally: there are hardware counters that track the number of flash sector erase and page program operations, if you enable 'DEBUG INFO' in the game menu, these are shown on the 3rd line from the top (first 2 numbers). If these counters start going crazy, or if the game freezes, you should also disconnect power.
1. Optional. If the pixels on your display have a non-square aspect ratio this may cause the 3D view to look slightly distorted. To fix, edit `src/firmware.ka` and tweak `FOV_SCALE_Y := ...` near the top of the file. Use the given formula.
1. `./build.sh` (builds FPGA bitstream; pay close attention to the result, may fail timing; if that happens, just re-run the command until you get a result that meets timing; may need to run a few times).
1. When the design meets timing: `./prog.sh` (upload bitstream to FPGA)

### Final steps

1. Disconnect board from power
1. Connect VGA and N64 controller according to pinout spec in `fpga_craft/hw/icebreaker_spi.pcf`
1. Reconnect power
1. Ready to play! (See below for controls and some useful gameplay tips)

## Controls

* Look around: stick
* Move/strafe: C buttons
* Jump: R
* Place block: Z
* Mine block: B (hold)
* Select hotbar slot: DPAD left/right
* Open door: A
* Move down (noclip mode): A
* Open/close inventory: L
* Inventory, move cursor: C buttons
* Inventory, select: A (or R)
* Open/close game menu: Start
* Game menu, move cursor: DPAD up/down
* Game menu, select: A
* Flying/boost: select rockets in hotbar, then: Z
* When flying: brake: B

## Gameplay tips

* There is a day/night cycle. If it gets dark and you want to skip the night, hit Start, then select 'TIME' and hit A a bunch of times (TIME 0x10-0x80 = day, TIME 0x90-0x00 = night).
* Terrain changes are buffered in memory. If you enabled saving (see instructions above), the game automatically saves changes to flash, as needed, to keep the buffer from getting too full. Before quitting, hit Start on the controller, then select 'SAVE XY CHUNKS' to save remaining changes to flash. A progress bar (consisting out of floppy disk icons) is shown in the top right; saving is done when all floppy disks have vanished.

## Optional steps

### Changing the firmware

1. Go to dir `fpga_craft/hw`
1. Modify `src/firmware.ka`, e.g. to change controls or game logic.
1. `./bfw.sh` (compiles the firmware to `src/firmware.w`, then modifies the bitstream directly; this avoids synthesis & routing stages to allow quick iteration on the firmware)
1. `./prog.sh` to upload bitstream to FPGA.

### Changing the hardware design (.w)

The HW design is written in [Wyre](https://github.com/nickmqb/wyre).

*Important*: to avoid errors, set your tab size to 4 when editing .w files. (Wyre uses significant whitespace, but the feature still needs more work; this is the easiest workaround for now.)

### Changing other tools (.mu)

The other tools in this repo are written in [Muon](https://github.com/nickmqb/muon). 

*Important*: to avoid errors, set your tab size to 4 when editing .mu files. (Muon uses significant whitespace, but the feature still needs more work; this is the easiest workaround for now.)

### OpenGL terrain viewer: set up

1. Go back to base directory (i.e. directory with `fpga_craft`, `muon`, etc.) 
1. `git clone https://github.com/nickmqb/muon_gfx` and [follow the install instructions for sdl_bindings](https://github.com/nickmqb/muon_gfx/tree/master/sdl_bindings). Note: the `SDL2` directory should be a subdirectory of the `sdl_bindings` directory.
1. `cd fpga_craft/terrain_viewer`
1. `./build.sh`

### OpenGL terrain viewer: generating terrain

1. Ensure previous section is done.
1. `./terrain_viewer --dimension 1 --output overworld.bin`
1. Fly around with WASD/space/C. Look around with arrow keys. Move slowly by holding shift.
1. To generate a new random world, press F3.
1. To save the world to the output path, press F12 (you must do this before exiting, otherwise output file will not be written).
1. The tool never frees memory, and will crash if you generate a lot of random worlds -- just restart in that case ("good enough, ship it!" ;)).

### OpenGL terrain viewer: viewing terrain

1. After playing, download modified world from flash. E.g.: `iceprog -o 8192k -R 8192k overworld_device.bin`
1. `./terrain_viewer --input overworld_device.bin`
1. Fly around with WASD/space/C. Look around with arrow keys. Move slowly by holding shift.

### Adding new blocks/textures

There currently is room for ~75 additional textures. To add new blocks/textures:

1. Modify `block_info_gen/block_info_generator.mu`. Add the textures under `Ids`, then add the block definitions in function `BlockInfoGenerator.generate`.
1. Run block_info_gen.
1. Add the new blocks to the inventory in `data_gen/data_generator.mu` (function `buildInventory`).
1. Run data_gen, reupload ram_a.bin and textures.bin, and rebuild and reupload the firmware.

### Multiple dimensions

The game supports multiple dimensions, though terrain gen is only implemented for the overworld.

* Dimension 1: 512x512x32 (overworld)
* Dimension 2: 128x128x32 (access by building an obsidian portal (like Nether portal in Minecraft))
* Dimension 3: 256x256x32 (access only through portal_3 block; can be enabled by adding the block to the inventory in `data_gen/data_generator.mu` (function `buildInventory`), or modifying terrain gen).

### Map file format

Each map consists of a series of 128 byte chunks. There is no header.

A chunk consists of 128 blocks. It has a base of 2x2 blocks (x, z) and a height of 32 blocks (y). 1 block = 1 byte. After running the block_info_generator, `block_info_generator/block_info.txt` contains the mapping from byte value to block type.

The offset (in bytes) of a block within a chunk has the bit pattern: `yyyyyzx` (rightmost bit is LSB, e.g. x=0, z=1, y=2 -> offset=10)

The offset (in whole chunks) of a chunk within a map file has the bit pattern: `zxzx xxxz zzzz zxxx` (rightmost bit is LSB, this pattern is used to ensure good data locality).

## License & acknowledgements

See [LICENSE](LICENSE).

stb_image.h: [https://github.com/nothings/stb](https://github.com/nothings/stb)

textures/custom_cracked.png: from ["Pixel pack" texture pack for Minetest by isaiah658](https://content.minetest.net/packages/isaiah658/the_pixel_pack/) (modified)
