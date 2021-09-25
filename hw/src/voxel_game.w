// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

core(clk $1, clk2x $1, req_enabled $1, spi_miso $1, gamepad_in $1, is_sim $1) {
	cpu := cpu(
		#initial_locals: LOCALS,
		#initial_jump_table: JUMP_TABLE,
		clk: clk,
		req_enabled: req_enabled, 
		ins: code.rdata,
		mem_rdata: (ram_raddr_bank ?
			{ ram_raddr_req_byte ? '00000000 : ram_b.rdata[15:8], ram_raddr_sub ? ram_b.rdata[15:8] : ram_b.rdata[7:0] } : 
			{ ram_raddr_req_byte ? '00000000 : ram_a.rdata[15:8], ram_raddr_sub ? ram_a.rdata[15:8] : ram_a.rdata[7:0] })
		port_rdata: cpu_port_rdata)
	
	code := ROM5120x8(#initial_data: zx CODE, clk: clk, raddr: cpu.pc)
	
	gpu := gpu(
		clk: clk
		clk2x: clk2x
		port: cpu.port
		port_we: cpu.req_wport
		port_wdata: cpu.b
		ram_rdata: ram_raddr_bank ? ram_b.rdata : ram_a.rdata
		vram_rdata: vram_bt.rdata[15:8]
		grid_we: map_cloner.grid_we
		grid_waddr: map_cloner.grid_waddr
		grid_wdata: map_cloner.grid_wdata
	)

	vram_rg := RAM256K(
		clk: clk
		addr: gpu.vram_we ? gpu.vram_addr[14:1] : vga.vram_raddr
		wdata: { gpu.vram_wdata[7:0], gpu.vram_wdata[7:0] }
		wmask: { gpu.vram_addr[0], gpu.vram_addr[0], ~gpu.vram_addr[0], ~gpu.vram_addr[0] }
		we: gpu.vram_we
	)
	vram_bt := RAM256K_IS(
		#initial_data_sim: TEXTURES
		clk: clk
		addr: dma.vram_we ? dma.addr[13:0] : ((gpu.vram_re | gpu.vram_we) ? gpu.vram_addr[14:1] : vga.vram_raddr)
		wdata: { dma.wdata[15:8], gpu.vram_wdata[11:8], gpu.vram_wdata[11:8] }
		wmask: { dma.vram_we, dma.vram_we, gpu.vram_we & gpu.vram_addr[0], gpu.vram_we & ~gpu.vram_addr[0] }
		we: dma.vram_we | gpu.vram_we
	)

	vga := vga_gfx_buffered(
		clk: clk, 
		enable_overlay: vga_overlay[0],
		wide_overlay: vga_overlay[1],
		ram_available: ~dma.ram_e & ~gpu.ram_re & ~cpu.req_r & ~cpu.req_w & ~le.req_lram,
		ram_rdata: ram_a.rdata,
		vram_available: ~dma.vram_we & ~gpu.vram_re & ~gpu.vram_we,
		vram_rg_rdata: vram_rg.rdata,
		vram_bt_rdata: vram_bt.rdata)
	
	le := lighting_engine(
		clk: clk
		port: cpu.port
		port_we: cpu.req_wport
		port_wdata: cpu.b
		lram_rdata: ram_a.rdata
		bram_rdata: ram_b.rdata
		lram_available: ~dma.ram_e & ~gpu.ram_re & ~cpu.req_r & ~cpu.req_w
		bram_available: ~dma.ram_e & ~gpu.ram_re & ~cpu.req_r & ~cpu.req_w & ~map_cloner.ram_re)
		
	ram_a := RAM256K_IS(
		#initial_data_sim: RAM_A
		clk: clk
		addr: dma.ram_e ? dma.addr[13:0] : (gpu.ram_re ? gpu.ram_raddr[14:1] : ((cpu.req_r | cpu.req_w) ? cpu.b[14:1] : (le.req_lram ? le.laddr : vga.ram_raddr)))
		wdata: dma.ram_we ? dma.wdata : (cpu.req_w ? (cpu.req_byte ? { cpu.a[7:0], cpu.a[7:0] } : cpu.a) : le.wdata)
		wmask: dma.ram_we ? '1111 : (cpu.req_w ? (cpu.req_byte ? (cpu.b[0] ? '1100 : '0011) : '1111) : le.wmask)
		we: (dma.ram_we & ~dma.addr[14]) | (cpu.req_w & ~cpu.b[15]) | (~dma.ram_e & ~gpu.ram_re & ~cpu.req_r & ~cpu.req_w & le.req_lw)
	)
	ram_b := RAM256K_IS(
		#initial_data_sim: MAP
		clk: clk
		addr: dma.ram_e ? dma.addr[13:0] : (map_cloner.ram_re ? map_cloner.ram_raddr : (gpu.ram_re ? gpu.ram_raddr[14:1] : ((cpu.req_r | cpu.req_w) ? cpu.b[14:1] : le.baddr))) 
		wdata: dma.ram_we ? dma.wdata : (cpu.req_byte ? { cpu.a[7:0], cpu.a[7:0] } : cpu.a)
		wmask: dma.ram_we ? '1111 : (cpu.req_byte ? (cpu.b[0] ? '1100 : '0011) : '1111)
		we: (dma.ram_we & dma.addr[14]) | (~gpu.ram_re & cpu.req_w & cpu.b[15])
	)

	posedge clk {
		reg ram_raddr_bank <= gpu.ram_re ? gpu.ram_raddr[15] : cpu.b[15]
		reg ram_raddr_sub <= cpu.b[0]
		reg ram_raddr_req_byte <= cpu.req_byte
		reg timer $27 <= timer + 1
	}

	cpu_port_rdata := match cpu.port {
		0x00: { rep('0, 11), vga.vga_yl }
		0x01: timer[26:11] // 16 == 1ms (approx)
		0x08: gamepad.buttons
		0x09: gamepad.stick
		0x10: { rep('0, 15), gpu.ray_hit }
		0x11: { rep('0, 11), gpu.ray_cell.x }
		0x12: { rep('0, 11), gpu.ray_cell.y }
		0x13: { rep('0, 11), gpu.ray_cell.z }
		0x14: { rep('0, 11), gpu.ray_cell_adj.x }
		0x15: { rep('0, 11), gpu.ray_cell_adj.y }
		0x16: { rep('0, 11), gpu.ray_cell_adj.z }
		0x17: { rep('0, 8), gpu.ray_dist }
		0x1f: { rep('0, 15), gpu.on }
		0x25: { rep('0, 8), dma.sector_erase_count }
		0x26: { rep('0, 8), dma.page_program_count }
		0x27: { rep('0, 15), dma.on }
		0x2f: { rep('0, 15), map_cloner.on }
		0x37: { rep('0, 15), le.on }
		0x3f: { rep('0, 15), is_sim }
	}			

	posedge clk {
		if cpu.req_wport & cpu.port == 0x07 {
			reg vga_overlay <= { cpu.b[1], cpu.b[1] | cpu.b[0] }
		}
	}
	gamepad_read_sync := cpu.req_wport & cpu.port == 0x08

	gamepad := gamepad_controller(clk: clk, input: gamepad_in, req_sync: gamepad_read_sync, req_read: gamepad_read_sync)
	out gamepad_out_isLow := gamepad.output_isLow

	dma := dma_controller(
		clk: clk
		port: cpu.port
		port_we: cpu.req_wport
		port_wdata: cpu.b
		spi_miso: spi_miso
		ram_rdata: ram_a.rdata)
	out spi_cs_isLow := dma.spi_cs_isLow
	out spi_clk_isLow := dma.spi_clk_isLow
	out spi_mosi := dma.spi_mosi
	out led_red_isOff := dma.spi_cs_isLow

	map_cloner := map_cloner(
		clk: clk
		port: cpu.port
		port_we: cpu.req_wport
		port_wdata: cpu.b
		ram_rdata: ram_b.rdata
	)

	out vga_r := vga.vga_r
	out vga_g := vga.vga_g
	out vga_b := vga.vga_b
	out vga_hs := vga.vga_hs
	out vga_vs := vga.vga_vs
}
