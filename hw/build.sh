set -xeo nounset

rm -f build/test.* && rm -f build/test_*.*
../kasm/kasm src/firmware.ka --output src/firmware.w
../../wyre/compiler/wyre src/voxel_game.w src/cpu.w src/vga_gfx.w src/firmware.w src/static_data.w src/data_sim.w src/dma.w src/gpu3.w src/gpu_rt.w src/lighting_engine.w lib/gamepad.w lib/flash_rw_controller.w ../../wyre/lib/ice40_bb.w ../../wyre/lib/ice40_hl_bb.w lib/ice40_memory.w --top core --output core.v --indent 4 --max-errors 20
../bram_swap/bram_swap --input core.v --output core cpu_locals cpu_jump_stack code_bank gpu_plotter_block_info gpu_plotter_light_table --seed 92389023

# icepack note: don't place flash in low power mode
yosys -ql build/test.log -p 'synth_ice40 -top top -json build/test.json' top.v core_random.v && nextpnr-ice40 -r --up5k --package sg48 --json build/test.json --pcf icebreaker_spi.pcf --asc build/test_random.asc && icebram -v core_random.hex core_contents.hex < build/test_random.asc > build/test.asc && icepack -s build/test.asc build/test.bin
