// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

emitter(
	clk $1
	pc $5
	ray vec3_14
	player_frac vec3_7
) {
	reg r $14
	reg player_frac_c $7
	reg ray_abs $13
	reg is_neg $1
	reg j $19
	out reg jump vec3_20
	out reg next vec3_20

	posedge clk {		
		if pc[1:0] == '00 {
			r <= match pc[4:2] {
				'000: ray.x
				'001: ray.y
				'010: ray.z
			}
		}
		if pc[1:0] == '01 {
			ray_abs <= abs(in: r).o
			is_neg <= r[13]
		}
		if pc[1:0] == '00 {
			j <= invert(clk: clk, x: ray_abs, begin: pc[1:0] == '10).o
			player_frac_c <= match pc[4:2] {
				'001: player_frac.x
				'010: player_frac.y
				'011: player_frac.z
			}
		}
		if pc[1:0] == '01 {
			t := MUL16x16(clk: clk, a: j[18:3], b: { '000000000, player_frac_c ^ rep(~is_neg, 7) }).o[23:4]
			t_sat := j[18:16] == '111 ? 0x7ffff_$20 : t
			if pc[4:2] == '001 {
				jump.x <= { '0, j }
				next.x <= t_sat
			}
			if pc[4:2] == '010 {
				jump.y <= { '0, j }
				next.y <= t_sat
			}
			if pc[4:2] == '011 {
				jump.z <= { '0, j }
				next.z <= t_sat
			}
		}
	}
}

tracer(
	clk $1
	pc_nz $1
	init_jump vec3_20
	init_next vec3_20
	init_cell vec3_6
	init_step vec3_6
	init_path $15
	init_halt $1
	init_oob $2
	grid_rdata $1
	grid_rdata_prev $1
) {
	out reg jump vec3_20
	out reg next vec3_20
	out reg cell vec3_6
	out reg step vec3_6
	out reg path $15
	out reg halt $1
	out reg oob $2
	reg grid_rdata_prev_d $1
	reg pc_pattern $2

	posedge clk {
		if ~pc_nz {
			jump <= init_jump
			next <= init_next
			cell <= init_cell
			step <= init_step
			path <= init_path
			halt <= init_halt
			oob <= init_oob
		}
		
		pc_pattern <= { ~pc_nz, pc_pattern[1] }
		grid_rdata_prev_d <= grid_rdata_prev
		if pc_nz {
			oob <= { (cell.x[5] | cell.y[5] | cell.y[4:3] == '11 | cell.z[5]), oob[1] }
		}
		out grid_raddr := { cell.y[4:0], cell.z[4:0], cell.x[4:0] }
		out col := oob[0] | (pc_pattern != 0 ? grid_rdata_prev_d : grid_rdata)

		if pc_nz & col {
			halt <= '1
		}

		if pc_nz & ~halt {
			xsy := { '0, next.x[19:0] } - { '0, next.y[19:0] }
			xsz := { '0, next.x[19:0] } - { '0, next.z[19:0] }
			ysz := { '0, next.y[19:0] } - { '0, next.z[19:0] }
			
			path <= { path[11:0], ysz[20], xsz[20], xsy[20] }
			
			if xsy[20] & xsz[20] {
				cell.x <= cell.x + step.x
				next.x <= next.x + jump.x
			}
			if ~xsy[20] & ysz[20] {
				cell.y <= cell.y + step.y
				next.y <= next.y + jump.y
			}
			if ~xsz[20] & ~ysz[20] {
				cell.z <= cell.z + step.z
				next.z <= next.z + jump.z
			}
		}
	}
}

plotter(
	clk $1
	pc $5
	output_x $9
	output_y $7
	ray vec3_14
	player_frac vec3_7
	init_jump vec3_20
	init_next vec3_20
	init_cell vec3_6
	init_step vec3_6
	init_path $15
	map_offset vec3_5
	ram_rdata $16
	vram_rdata $8
	mining_block_addr $16
	is_underwater $1
	use_max_light $1
	crosshair_mode $2
	texture_y_clamp $1
	sky_color $12
	override_xz $10
	override_y0 $5
	override_y1 $5
	override_dir $3
	override_block_hi $7
) {
	reg jump vec3_20
	reg next vec3_20
	reg cell vec3_6
	reg cell_hit vec3_6
	reg step vec3_6
	reg path $15

	out reg ram_re $1
	out reg ram_raddr $16
	out reg vram_re $1	
	out reg vram_we $1
	out reg vram_addr $15
	out reg vram_wdata $12

	posedge clk {
		if pc == 0 {
			jump <= init_jump
			next <= init_next
			cell <= init_cell
			step <= init_step
			path <= init_path			
		}

		if pc == 1 | pc == 2 | pc == 3 | pc == 4 {
			if path[0] & path[1] {
				cell.x <= cell.x - step.x
				next.x <= next.x - jump.x
			}
			if ~path[0] & path[2] {
				cell.y <= cell.y - step.y
				next.y <= next.y - jump.y
			}
			if ~path[1] & ~path[2] {
				cell.z <= cell.z - step.z
				next.z <= next.z - jump.z
			}
			if pc == 1 | pc == 2 | pc == 3 {
				path <= { 'xxx, path[14:3] }
			}
			cell_hit <= cell
		}

		if pc == 4 {
			reg oob <= cell.x[5] | cell.y[5] | cell.y[4:3] == '11 | cell.z[5]
		}

		reg t $15
		if pc == 5 {
			p := path[2:0]
			side_x_w := p[0] & p[1]
			side_y_w := ~p[0] & p[2]
			side_z_w := ~p[1] & ~p[2]
			if side_x_w {
				t <= next.x[17:3]
			}
			if side_y_w {
				t <= next.y[17:3]
			}
			if side_z_w {
				t <= next.z[17:3]
			}
			reg side_x <= side_x_w
			reg side_y <= side_y_w
			reg side_z <= side_z_w
			reg side_y_prev_clamp <= ~path[3] & path[5] & texture_y_clamp
			reg map_x <= (cell_hit.x[4:0] + map_offset.x)[4:0]
			reg map_y <= { '0, cell_hit.y[4:0] } + { '0, map_offset.y }
			reg map_z <= (cell_hit.z[4:0] + map_offset.z)[4:0]
			adj_map_x := cell.x[4:0] + map_offset.x
			adj_map_y := cell.y[4:0] + map_offset.y
			adj_map_z := cell.z[4:0] + map_offset.z
			map_data := is_override ? { override_block_hi, is_override_y1 } : (map_x[0] ? ram_rdata[15:8] : ram_rdata[7:0])
			adj_map_data := adj_map_x[0] ? ram_rdata[15:8] : ram_rdata[7:0]
		}

		reg u_0 $7
		reg v_0 $7
		reg is_mining $1
		if pc == 6 {
			u_ray := side_x ? ray.y : ray.x
			v_ray := side_z ? ray.y : ray.z
			u_0 <= MUL16x16_SIGNED(clk: clk, a: { '0, t }, b: { rep(u_ray[13], 2), u_ray }).o[20:14]
			v_0 <= MUL16x16_SIGNED(clk: clk, a: { '0, t }, b: { rep(v_ray[13], 2), v_ray }).o[20:14]
			ram_raddr <= { '1, map_z[4:1], map_x[4:1], map_y[4:0], map_z[0], map_x[0] }
			ram_re <= '1
			is_mining <= mining_block_addr == { '1, map_z[4:1], map_x[4:1], map_y[4:0], map_z[0], map_x[0] }
			reg is_override_dir <= (side_x & override_dir[0] & ray.x[13] == override_dir[2]) | (side_z & override_dir[1] & ray.z[13] == override_dir[2])
			reg is_override_xz <= override_xz == { map_z, map_x }
			reg is_override_y0 <= override_y0 == map_y[4:0]
			reg is_override_y1 <= override_y1 == map_y[4:0]
		}

		reg u $4
		reg v $4
		reg index $2
		reg is_override $1
		if pc == 7 {
			u_pos := side_x ? player_frac.y : player_frac.x
			v_pos := side_z ? player_frac.y : player_frac.z
			u <= (u_0 + u_pos)[6:3]
			v <= (v_0 + v_pos)[6:3]
			ram_raddr <= { '1, adj_map_z[4:1], adj_map_x[4:1], adj_map_y, adj_map_z[0], adj_map_x[0] }
			is_override <= is_override_xz & (is_override_y0 | is_override_y1) & is_override_dir
		}

		reg hit $1
		reg uv_addr $8
		reg map_data_d $7
		if pc == 8 {
			hit <= ~oob & map_data[7:1] != 0 & ~map_y[5]
			u_y_clamped := ((side_y_prev_clamp & ~ray.y[13] & u == '1111) ? '0000 : ((side_y_prev_clamp & ray.y[13] & u == '0000) ? '1111 : u))
			v_y_clamped := ((side_y_prev_clamp & ~ray.y[13] & v == '1111) ? '0000 : ((side_y_prev_clamp & ray.y[13] & v == '0000) ? '1111 : v))
			uv_addr <= side_x ? { u_y_clamped, v ^ rep(~ray.x[13], 4) } : (side_z ? { v_y_clamped, u ^ rep(ray.z[13], 4) } : { v, u })
			map_data_d <= map_data[7:1]
			ram_raddr <= { '01, adj_map_z, adj_map_x, adj_map_y[4:1] } // Block light
		}
		
		block_info := RAM256x16(
			#initial_data: BLOCK_TEXTURE_INFO
			rclk: clk, wclk: clk
			raddr: pc == 8 ? map_data : { map_data_d, block_info.rdata[14] }
			we: '0, waddr: ---, wdata: ---)

		reg double_block_info $1
		reg rotate $1
		reg is_water $1
		if pc == 9 {
			vram_addr <= { side_y ? block_info.rdata[13:7] : block_info.rdata[6:0], (block_info.rdata[15] & (~side_y | map_data_d[0])) ? { uv_addr[3:0], ~uv_addr[7:4] } : uv_addr }
			double_block_info <= block_info.rdata[14] & (side_x | (side_z & ray.z[13]) | (side_y & ~ray.y[13]))			
			rotate <= block_info.rdata[15]
			is_water <= adj_map_data == 1 & ~map_y[5]
			ram_re <= '0
		}

		if pc == 10 & double_block_info {
			texture_index := side_x ? (ray.x[13] ? block_info.rdata[7:4] : block_info.rdata[15:12]) : (side_z ? block_info.rdata[11:8] : block_info.rdata[3:0])
			vram_addr <= { vram_addr[14:12], texture_index, (rotate & (~side_y | map_data_d[0])) ? { uv_addr[3:0], ~uv_addr[7:4] } : uv_addr }
		}

		reg light $4
		if pc == 10 {
			light <= match adj_map_y[1:0] {
				'00: ram_rdata[3:0]
				'01: ram_rdata[7:4]
				'10: ram_rdata[11:8]
				'11: ram_rdata[15:12]
			}
			vram_re <= '1
		}

		reg light_table_raddr_lo $4
		reg light_table_raddr_hi $4
		light_table := RAM256x16(
			#initial_data: LIGHT_LOOKUP
			rclk: clk, wclk: clk
			raddr: pc == 13 ? { '001, is_underwater & ~is_water, mining_overlay, (side_y & ~ray.y[13]) | side_z, side_x } : { light_table_raddr_hi, light_table_raddr_lo }
			we: '0, waddr: ---, wdata: ---)		

		reg palette_section $7
		reg vram_addr_lo $1
		if pc == 11 {
			palette_section <= vram_addr[14:8]
			vram_addr <= { '1111110, uv_addr }
			vram_addr_lo <= vram_addr[0]
			light_table_raddr_lo <= { output_y[1:0], output_x[1:0] }
			light_table_raddr_hi <= '0000
		}

		if pc == 12 {
			color_index := vram_addr_lo ? vram_rdata[7:4] : vram_rdata[3:0]
			ram_re <= '1
			ram_raddr <= { '0000, palette_section, color_index, '0 }
			vram_re <= '0
		}

		reg dither $6
		reg light_m $4
		if pc == 13 {
			ram_re <= '0
			mining_overlay := is_mining ? (uv_addr[0] ? vram_rdata[5:4] : vram_rdata[1:0]) : '00
			dither <= light_table.rdata[13:8]
			light_m <= use_max_light ? '1111 : light
		}

		reg sky_color_component $4
		reg tex_g $4
		reg tex_b $4
		reg force_dither $1
		reg apply_dither $1
		if pc == 14 {
			light_table_raddr_hi <= ram_rdata[3:0]
			tex_g <= ram_rdata[7:4]
			tex_b <= ram_rdata[11:8]
			force_dither <= ram_rdata[12]
			light_mod := { '0, light_m } + { light_table.rdata[11:8] != 0, light_table.rdata[11:8] }
			light_table_raddr_lo <= ~light_mod[4] ? light_mod[3:0] : '0000
		}
		mix_blue_lo := hit ? ~is_underwater : is_water
		if pc == 15 {
			light_table_raddr_hi <= { '01, hit, mix_blue_lo }
			sky_color_component <= sky_color[3:0]
			apply_dither <= hit & (light_table_raddr_lo[3] == '0 | light_table_raddr_lo[3:1] == '100 | light_table_raddr_lo == '1010 | force_dither)
		}
		if pc == 16 {
			light_table_raddr_hi <= tex_g
		}
		if pc == 17 {
			light_table_raddr_hi <= { '10, hit, mix_blue_lo }
			sky_color_component <= sky_color[7:4]
		}
		if pc == 18 {
			light_table_raddr_hi <= tex_b
		}
		if pc == 19 {
			light_table_raddr_hi <= { '11, hit, mix_blue_lo }
			sky_color_component <= sky_color[11:8]
		}

		reg color $8
		if pc[4] & ~pc[0] {
			color <= hit ? light_table.rdata[7:0] : { sky_color_component, '0000 }
		}
		if pc[4] & pc[0] & (is_water | is_underwater) {
			color <= { '0, color[7:1] } + light_table.rdata[15:8]
		}
		color_dithered := color + { rep(dither[3] & apply_dither, 4), apply_dither ? dither[3:0] : '0000 }
		if pc == 18 {
			reg r_light <= color_dithered[7:4]
		}
		if pc == 20 {
			reg g_light <= color_dithered[7:4]
		}

		reg wide_crosshair $1
		if output_x[7:0] == 126 {
			wide_crosshair <= '1
		}
		if output_x[2:0] == 3 {
			wide_crosshair <= '0
		}
		reg is_center <= wide_crosshair & output_x[2:0] == 0
		reg crosshair <= (crosshair_mode & { is_center, wide_crosshair }) != 0

		if pc == 22 {
			vram_we <= ~output_x[8]
			vram_addr <= { output_y, output_x[7:0] }
			vram_wdata <= { color_dithered[7:4], g_light, r_light } ^ rep(crosshair, 12)
		} else {
			vram_we <= '0
		}

		out reg ray_hit $1
		out reg ray_cell vec3_5
		out reg ray_cell_adj vec3_5
		out reg ray_dist $8 // 6.2

		if is_center {
			ray_hit <= hit
			ray_cell <= vec3_5 { x: cell_hit.x[4:0], y: cell_hit.y[4:0], z: cell_hit.z[4:0] }
			ray_cell_adj <= vec3_5 { x: cell.x[4:0], y: cell.y[4:0], z: cell.z[4:0] }
			ray_dist <= t[14:7]
		}
	}
}

map_cloner(
	clk $1
	port $6
	port_we $1
	port_wdata $16
	ram_rdata $16
) {
	reg map_offset vec3_5
	reg index $14
	reg write_started $1
	out reg on $1
	out reg grid_we $1
	out reg grid_waddr $14

	posedge clk {
		if port_we {
			if port == 0x28 { map_offset <= vec3_5 { x: { port_wdata[10:7], port_wdata[0] }, y: port_wdata[6:2], z: { port_wdata[14:11], port_wdata[1] } } }
			if port == 0x2f {
				on <= '1
				write_started <= '0
				index <= 0
				grid_waddr <= 0
			}
		}
		
		out ram_re := on
		map_x := { index[3:0], '0 } + map_offset.x
		map_y := { '0, index[13:9] } + { '0, map_offset.y }
		reg map_y_hi_d <= map_y[5]
		map_z := index[8:4] + map_offset.z
		out ram_raddr := { map_z[4:1], map_x[4:1], map_y[4:0], map_z[0] }
		
		if on {
			grid_we <= '1
			index <= index + 1
			if write_started {
				grid_waddr <= grid_waddr + 1
			} else {
				write_started <= '1
			}
			out grid_wdata := { ram_rdata[15:9] != 0 & ~map_y_hi_d, ram_rdata[7:1] != 0 & ~map_y_hi_d }
			if grid_waddr == 0x2fff {
				on <= '0
				grid_we <= '0
			}
		}
	}	
}

vec3_4 struct {
	x $4
	y $4
	z $4
}

vec2_5 struct {
	x $5
	z $5
}

vec3_5 struct {
	x $5
	y $5
	z $5
}

vec3_6 struct {
	x $6
	y $6
	z $6
}

vec3_7 struct {
	x $7
	y $7
	z $7
}

vec3_12 struct {
	x $12
	y $12
	z $12
}

vec3_13 struct {
	x $13
	y $13
	z $13
}

vec3_14 struct {
	x $14
	y $14
	z $14
}

vec3_16 struct {
	x $16
	y $16
	z $16
}

vec3_18 struct {
	x $18
	y $18
	z $18
}

vec3_19 struct {
	x $19
	y $19
	z $19
}

vec3_20 struct {
	x $20
	y $20
	z $20
}

abs(in $14) {
	out o := in[13] ? (~in[12:0] + 1) : in[12:0]
}

invert(clk $1, x $13, begin $1) {
	posedge clk {
		is_small := x[12:9] == 0
		index := is_small ? x[8:2] : x[12:6]
		reg t <= is_small ? {~x[1:0], '0000 } : ~x[5:0]
		reg index_d <= index
		reg is_small_d <= is_small
		lookup := RAM256x16(
			#initial_data: INVERT_LOOKUP
			rclk: clk, wclk: clk
			raddr: begin ? { '1, index } : { '0, index_d }
			we: '0, waddr: ---, wdata: ---
		)
		
		reg dt <= MUL16x16(clk: clk, a: lookup.rdata, b: { '0000000000, t }).o[21:5]
		reg is_small_dd <= is_small_d
		
		dt_base := { '00, dt } + { '0, lookup.rdata, '00 }
		out o := is_small_dd ? (dt_base[18:15] != 0 ? 0x7ffff_$19 : { dt_base[14:0], '0000 }) : dt_base
	}
}

INVERT_LOOKUP $4096 := [
	ffff0080555500403333aa2a92240020711c991945175515b113491211110010
	0f0f380e790dcc0c300ca20b210baa0a3d0ad8097b092409d308880842080008
	c107870750071c07eb06bc06900666063e061806f405d105b005900572055505
	39051e050505ec04d404bd04a70492047d046904560444043204210410040004
	f003e003d203c303b503a8039b038e038103750369035e03530348033d033303
	29031f0315030c030303fa02f102e802e002d802d002c802c002b902b102aa02
	a3029c0295028f02880282027c02760270026a0264025e02590253024e024902
	43023e023902340230022b02260222021d021902140210020c02080204020002
	0000ffff5655aa2a9a191111310c24091d07b005a804e1034803d00270022202
	e201ad017f01590138011c010301ed00db00c900bb00ad00a20096008d008400
	7d0074006f00680062005d005900540050004c004800460042003f003d003a00
	38003500330032002f002e002c002b0029002800260025002400220022002000
	20001f001d001d001c001b001a001a0019001800180017001600160015001500
	1400140013001300120012001200110011001000100010000f000f000f000e00
	0e000e000e000d000d000c000d000c000c000c000c000b000b000b000b000a00
	0b000a000a000a0009000a000900090009000900090008000900080008000800
]
