// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

gpu(
	clk $1
	clk2x $1
	port $6
	port_we $1
	port_wdata $16
	ram_rdata $16
	vram_rdata $8
	grid_we $1
	grid_waddr $14
	grid_wdata $2
) {
	reg pc $5
	reg pc_nz $1
	out reg on $1
	reg output_x $9
	reg output_y $7
	reg player vec3_12 // 5.7
	reg right_x $14 // 2.12
	reg right_z $14 // 2.12
	reg ray_x $18
	reg ray_y $14
	reg ray_z $18
	reg ray_x_d $18
	reg ray_z_d $18
	reg map_offset vec3_5
	reg mining_block_addr $16
	reg is_underwater $1
	reg use_max_light $1
	reg crosshair_mode $2
	reg texture_y_clamp $1
	reg sky_color $12
	reg override_xz $10
	reg override_y0 $5
	reg override_y1 $5
	reg override_dir $3
	reg override_block_hi $7

	posedge clk {
		if port_we {
			if port == 0x10 { player.x <= port_wdata[11:0] }
			if port == 0x11 { player.y <= port_wdata[11:0] }
			if port == 0x12 { player.z <= port_wdata[11:0] }

			if port == 0x13 { right_x <= port_wdata[13:0] }
			if port == 0x14 { right_z <= port_wdata[13:0] }
			
			if port == 0x15 {
				ray_x <= { port_wdata[13:0], '0000 }
				ray_x_d <= { port_wdata[13:0], '0000 }
			}
			if port == 0x16 {
				ray_y <= port_wdata[13:0]
			}
			if port == 0x17 {
				ray_z <= { port_wdata[13:0], '0000 }
				ray_z_d <= { port_wdata[13:0], '0000 }
			}

			if port == 0x18 { output_y <= port_wdata[6:0] }

			if port == 0x19 {
				map_offset <= vec3_5 { x: { port_wdata[10:7], port_wdata[0] }, y: port_wdata[6:2], z: { port_wdata[14:11], port_wdata[1] } }
			}

			if port == 0x1a {
				crosshair_mode <= port_wdata[1:0]
				texture_y_clamp <= port_wdata[2]
			}
			
			if port == 0x1b { mining_block_addr <= port_wdata }

			if port == 0x1c {
				is_underwater <= port_wdata[0]
				use_max_light <= port_wdata[1]
			}

			if port == 0x1d { sky_color <= port_wdata[11:0] }

			if port == 0x1e { override_dir <= port_wdata[2:0] }
			if port == 0x0d { override_block_hi <= port_wdata[7:1] }
			if port == 0x0e {
				override_xz <= { port_wdata[14:11], port_wdata[1], port_wdata[10:7], port_wdata[0] }
				override_y0 <= port_wdata[6:2]
			}
			if port == 0x0f { 
				override_y1 <= port_wdata[6:2]
			}

			if port == 0x1f {
				on <= '1
				output_x <= 508 // (512 - 1 - num_tracers)
			}
		}
		if on != 0 {
			pc <= pc + 1
			pc_nz <= '1
			if pc == 24 {
				pc <= 0
				pc_nz <= '0
				output_x <= output_x + 1
				ray_x <= ray_x + { rep(right_x[13], 7), right_x[13:3] }
				ray_z <= ray_z + { rep(right_z[13], 7), right_z[13:3] }

				if ~output_x[8] {
					ray_x_d <= ray_x_d + { rep(right_x[13], 7), right_x[13:3] }
					ray_z_d <= ray_z_d + { rep(right_z[13], 7), right_z[13:3] }
				}
				if output_x == 255 {
					on <= '0
				}
			}
		}
	}

	emitter := emitter(
		clk: clk,
		pc: pc
		player_frac: vec3_7 { x: player.x[6:0], y: player.y[6:0], z: player.z[6:0] }
		ray: vec3_14 { x: ray_x[17:4], y: ray_y, z: ray_z[17:4] }
	)
		
	tracer_a := tracer(
		clk: clk
		pc_nz: pc_nz
		init_jump: emitter.jump
		init_next: emitter.next
		init_cell: vec3_6 { x: { '0, player.x[11:7] }, y: { '0, player.y[11:7] }, z: { '0, player.z[11:7] } }
		init_step: vec3_6 { x: { rep(ray_x[17], 5), '1 }, y: { rep(ray_y[13], 5), '1 }, z: { rep(ray_z[17], 5), '1 } }
		init_path: 0
		init_oob: '00
		init_halt: '0
		grid_rdata: grid_a.rdata0
		grid_rdata_prev: '0
	)

	tracer_b := tracer(
		clk: clk
		pc_nz: pc_nz
		init_jump: tracer_a.jump
		init_next: tracer_a.next
		init_cell: tracer_a.cell
		init_step: tracer_a.step
		init_path: tracer_a.path
		init_halt: tracer_a.halt
		init_oob: tracer_a.oob
		grid_rdata: grid_b.rdata0
		grid_rdata_prev: grid_a.rdata0
	)

	tracer_c := tracer(
		clk: clk
		pc_nz: pc_nz
		init_jump: tracer_b.jump
		init_next: tracer_b.next
		init_cell: tracer_b.cell
		init_step: tracer_b.step
		init_path: tracer_b.path
		init_halt: tracer_b.halt
		init_oob: tracer_b.oob
		grid_rdata: grid_b.rdata1
		grid_rdata_prev: grid_b.rdata0
	)

	plotter := plotter(
		clk: clk
		pc: pc
		player_frac: vec3_7 { x: player.x[6:0], y: player.y[6:0], z: player.z[6:0] }
		ray: vec3_14 { x: ray_x_d[17:4], y: ray_y, z: ray_z_d[17:4] }
		init_jump: tracer_c.jump
		init_next: tracer_c.next
		init_cell: tracer_c.cell
		init_step: tracer_c.step
		init_path: tracer_c.path
		map_offset: map_offset
		ram_rdata: ram_rdata
		vram_rdata: vram_rdata
		output_x: output_x
		output_y: output_y
		mining_block_addr: mining_block_addr
		is_underwater: is_underwater
		use_max_light: use_max_light
		crosshair_mode: crosshair_mode
		texture_y_clamp: texture_y_clamp
		sky_color: sky_color
		override_xz: override_xz
		override_y0: override_y0
		override_y1: override_y1
		override_dir: override_dir
		override_block_hi: override_block_hi
	)

	grid_a := grid(
		clk: clk
		clk2x: clk2x
		raddr0: tracer_a.grid_raddr
		raddr1: tracer_a.grid_raddr
		grid_we: grid_we
		grid_waddr: grid_waddr
		grid_wdata: grid_wdata
	) 
	grid_b := grid(
		clk: clk
		clk2x: clk2x
		raddr0: tracer_b.grid_raddr
		raddr1: tracer_c.grid_raddr
		grid_we: grid_we
		grid_waddr: grid_waddr
		grid_wdata: grid_wdata
	) 

	out ram_re := plotter.ram_re
	out ram_raddr := plotter.ram_raddr	
	out vram_re := plotter.vram_re
	out vram_we := plotter.vram_we
	out vram_addr := plotter.vram_addr
	out vram_wdata := plotter.vram_wdata
	out ray_hit := plotter.ray_hit
	out ray_cell := plotter.ray_cell
	out ray_cell_adj := plotter.ray_cell_adj
	out ray_dist := plotter.ray_dist
}

grid(
	clk $1
	clk2x $1
	raddr0 $15
	raddr1 $15
	grid_we $1
	grid_waddr $14
	grid_wdata $2
) {	
	grid_a := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '000, waddr: grid_waddr[10:0], wdata: grid_wdata
	)
	grid_b := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '001, waddr: grid_waddr[10:0], wdata: grid_wdata
	)
	grid_c := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '010, waddr: grid_waddr[10:0], wdata: grid_wdata
	)
	grid_d := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '011, waddr: grid_waddr[10:0], wdata: grid_wdata
	)
	grid_e := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '100, waddr: grid_waddr[10:0], wdata: grid_wdata
	)
	grid_f := RAM2048x2(
		#initial_data: 0
		rclk: clk2x, wclk: clk
		raddr: clk ? raddr1_d[11:1] : raddr0[11:1]
		we: grid_we & grid_waddr[13:11] == '101, waddr: grid_waddr[10:0], wdata: grid_wdata
	)

	reg raddr0_lo $1
	reg raddr0_hi $3
	reg raddr1_d $15
	reg raddr1_d_hi_d $3
	reg rdata0_e $6
	reg rdata1_e $6
	posedge clk {
		raddr0_lo <= raddr0[0]
		raddr0_hi <= raddr0[14:12]
		raddr1_d <= raddr1
	}
	negedge clk {
		rdata0_e <= (raddr0_lo ? 
			{ grid_f.rdata[1], grid_e.rdata[1], grid_d.rdata[1], grid_c.rdata[1], grid_b.rdata[1], grid_a.rdata[1] } :
			{ grid_f.rdata[0], grid_e.rdata[0], grid_d.rdata[0], grid_c.rdata[0], grid_b.rdata[0], grid_a.rdata[0] })
	}
	posedge clk {
		out reg rdata0 <= match raddr0_hi {
			'000: rdata0_e[0]
			'001: rdata0_e[1]
			'010: rdata0_e[2]
			'011: rdata0_e[3]
			'100: rdata0_e[4]
			'101: rdata0_e[5]
		}
		rdata1_e <= (raddr1_d[0] ? 
			{ grid_f.rdata[1], grid_e.rdata[1], grid_d.rdata[1], grid_c.rdata[1], grid_b.rdata[1], grid_a.rdata[1] } :
			{ grid_f.rdata[0], grid_e.rdata[0], grid_d.rdata[0], grid_c.rdata[0], grid_b.rdata[0], grid_a.rdata[0] })
		raddr1_d_hi_d <= raddr1_d[14:12]
	}
	negedge clk {
		out reg rdata1 <= match raddr1_d_hi_d {
			'000: rdata1_e[0]
			'001: rdata1_e[1]
			'010: rdata1_e[2]
			'011: rdata1_e[3]
			'100: rdata1_e[4]
			'101: rdata1_e[5]
		}
	}
}
