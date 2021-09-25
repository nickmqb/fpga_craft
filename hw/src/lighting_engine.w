// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

// Note: light levels are inverted, i.e. 0 = bright, 15 = dark

sat_add(a $4, b $4) {
	sum := { '0, a } + { '0, b }
	out o := sum[4] ? '1111 : sum[3:0]
}

combine_light(lv $4, adj $4, absorb $4) {
	new_lv := sat_add(a: adj, b: absorb).o
	delta := { '0, new_lv } - { '0, lv }
	out o := delta[4] ? new_lv : lv
}

lighting_engine(
	clk $1
	port $6
	port_we $1
	port_wdata $16
	lram_rdata $16
	bram_rdata $16
	lram_available $1
	bram_available $1
) {
	reg pc $4
	reg from vec2_5
	reg to vec2_5
	reg clip_from vec2_5
	reg clip_to vec2_5
	reg p_x_lo $1
	reg p_x_hi $4
	reg p_y_inv $5
	reg p_z $5
	reg iter $5
	reg iter_count $4
	reg init_sky $4
	reg limit_darkness $2
	reg sky $4
	reg level $4
	reg adj_light $4
	out reg on $1
	out reg req_lw $1
	out reg req_lram $1
	out reg laddr $14
	out reg laddr_lo $2
	out baddr := { p_z[4:1], p_x_hi, ~p_y_inv, p_z[0] }
	out wmask := match p_y_inv[1:0] {
		'00: '1000
		'01: '0100
		'10: '0010
		'11: '0001
	}

	posedge clk {
		if port_we {
			if port == 0x30 { from <= vec2_5 { x: port_wdata[4:0], z: port_wdata[9:5] } }
			if port == 0x31 { to <= vec2_5 { x: port_wdata[4:0], z: port_wdata[9:5] } }
			if port == 0x32 { clip_from <= vec2_5 { x: port_wdata[4:0], z: port_wdata[9:5] } }
			if port == 0x33 { clip_to <= vec2_5 { x: port_wdata[4:0], z: port_wdata[9:5] } }
			if port == 0x34 { iter_count <= port_wdata[3:0] } // Note: needs to be set to num iterations - 1
			if port == 0x35 { init_sky <= port_wdata[3:0] }
			if port == 0x36 { limit_darkness <= port_wdata[1:0] }
			if port == 0x37 {
				iter <= 0
				p_x_lo <= 0
				p_x_hi <= from.x[4:1]
				p_y_inv <= 0
				p_z <= from.z
				sky <= init_sky
				pc <= 0
				on <= '1
			}
		}

		if on != 0 {
			pc <= pc + 1

			if pc == 0 & ~bram_available {
				pc <= pc
			}

			if pc == 1 {
				map_data := p_x_lo ? bram_rdata[15:8] : bram_rdata[7:0]
				reg absorb_up <= map_data[7:1] == 0 ? { '00, map_data[0], '0 } : 15
				reg absorb <= map_data[7:1] == 0 ? { '00, map_data[0], ~map_data[0] } : 15
				reg emit <= map_data[7:5] == 0 & map_data[4:1] != 0
				reg emit_low <= map_data[3:2] == '11
				adj_light <= level
			}

			if pc == 2 {
				sky_w := sat_add(a: sky, b: absorb_up).o
				sky <= sky_w
				level <= emit ? { emit_low, '000 } : sky_w
			}

			dx_pos := pc == 1
			dx_neg := pc == 3
			adj_x := { p_x_hi, p_x_lo } + { rep(dx_neg, 4), dx_pos | dx_neg }
			dz_pos := pc == 5
			dz_neg := pc == 7
			adj_z := p_z + { rep(dz_neg, 4), dz_pos | dz_neg }
			dy_neg := pc == 9
			adj_y := ~p_y_inv + rep(dy_neg, 5)

			if pc == 1 | pc == 3 | pc == 5 | pc == 7 | pc == 9 | pc == 11 {
				laddr <= { '1, adj_z, adj_x, adj_y[4:2] }
				laddr_lo <= adj_y[1:0]
				req_lram <= '1
			}

			if pc == 2 | pc == 4 | pc == 6 | pc == 8 | pc == 10 {
				if lram_available {
					req_lram <= '0
				} else {
					pc <= pc
				}
			}

			if pc == 3 | pc == 5 | pc == 7 | pc == 9 | pc == 11 {
				adj_light <= ~match laddr_lo {
					'00: lram_rdata[3:0]
					'01: lram_rdata[7:4]
					'10: lram_rdata[11:8]
					'11: lram_rdata[15:12]
				}
			}

			clip := match pc {
				3: p_y_inv == 0
				4: { p_x_hi, p_x_lo } == clip_to.x
				6: { p_x_hi, p_x_lo } == clip_from.x
				8: p_z == clip_to.z
				10: p_z == clip_from.z
				12: p_y_inv == 31
			}

			if (pc == 3 | pc == 4 | pc == 6 | pc == 8 | pc == 10 | pc == 12) & ~clip {
				level <= combine_light(lv: level, adj: adj_light, absorb: absorb).o	
			}

			if pc == 13 {
				wvalue := limit_darkness[1] ? '1110 : ((limit_darkness[0] & level[3]) ? '1000 : ~level)
				out reg wdata <= rep(wvalue, 4)
			}

			if pc == 14 {
				req_lw <= '1
				req_lram <= '1
			}

			if pc == 15 {
				if lram_available {
					req_lw <= '0
					req_lram <= '0
					p_y_inv <= p_y_inv + 1
					if p_y_inv == 31 {
						p_x_hi <= p_x_hi + 1
						sky <= init_sky
						if p_x_hi == to.x[4:1] {
							p_x_lo <= ~p_x_lo
							p_x_hi <= from.x[4:1]
							p_z <= p_z + 1
							if p_z == to.z {
								p_x_lo <= p_x_lo
								p_z <= from.z
								iter <= iter + 1
								if (iter == { iter_count, '1 }) {
									on <= '0
								}
							}
						}
					}
				} else {
					pc <= pc
				}
			}
		}
	}
}
