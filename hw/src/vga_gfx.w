// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

vga_gfx(
	clk $1 // clk must be 32.5mhz
	pixel $12
) {
	posedge clk {
		out reg x $10
		out reg y $10
		if x == 671 {
			x <= 0
		} else {
			x <= x + 1
		}
		if x == 511 {
			if y == 805 {
				y <= 0
			} else {
				y <= y + 1
			}
		}
		
		reg vis_x $1
		reg vis_y $1
		reg hs $1
		reg vs $1
		if x == 0 {
			vis_x <= 1
		}
		if x == 512 {
			vis_x <= 0
		}
		if x == 524 {
			hs <= 1
		}
		if x == 592 {
			hs <= 0
		}
		if y == 4 {
			vis_y <= 1
		}
		if y == 768 + 4 {
			vis_y <= 0
		}
		if y == 771 + 4 {
			vs <= 1
		}
		if y == 777 + 4 {
			vs <= 0
		}

		vis := vis_x & vis_y
		out vga_r := vis ? pixel[3:0] : '0000
		out vga_g := vis ? pixel[7:4] : '0000
		out vga_b := vis ? pixel[11:8] : '0000
		out vga_hs := ~hs // hsync
		out vga_vs := ~vs // vsync
	}
}

vga_gfx_buffered(
	clk $1
	enable_overlay $1
	wide_overlay $1
	ram_available $1
	ram_rdata $16
	vram_available $1
	vram_rg_rdata $16
	vram_bt_rdata $16
) {
	vga := vga_gfx(clk: clk, pixel: vga_pixel)
	out vga_r := vga.vga_r
	out vga_g := vga.vga_g
	out vga_b := vga.vga_b
	out vga_hs := vga.vga_hs
	out vga_vs := vga.vga_vs
	out vga_yl := vga.y[9:5]
	
	reg state $4
	reg fill_x $8
	reg pixel $12
	out reg vram_raddr $14
	out reg ram_raddr $14

	posedge clk {
		vga_y_main := vga.y[9:7] + 7
		if state == 0 & vga.y[1:0] == 0 & vga.x[9:1] == 0 & vga.y[9:8] != '11 {
			state <= vga_y_main[2] ? 8 : 1
		}		
		if state == 1 {
			state <= 2
			vram_raddr <= { vga_y_main[1:0], vga.y[6:2], fill_x[7:1] }
		}
		if state == 2 & vram_available {
			state <= 3
		}
		if state == 3 {
			pixel <= match fill_x[0] {
				0: { vram_bt_rdata[3:0], vram_rg_rdata[7:0] }
				1: { vram_bt_rdata[7:4], vram_rg_rdata[15:8] }
			}	
			state <= 7
		}
		if state == 8 {
			ram_raddr <= { '00100, vga.y[9:5], fill_x[7:4] }
			state <= 9
		}
		if state == 9 & ram_available {
			state <= 10
		}
		cell := fill_x[3] ? ram_rdata[15:8] : ram_rdata[7:0]		
		if state == 10 {
			reg cell_hi_d <= cell[7]
			no_flip := fill_x[7:3] == 6 | fill_x[7:3] == 7 | fill_x[7:3] == 12 | fill_x[7:3] == 13 | fill_x[7:3] == 18 | fill_x[7:3] == 19 | fill_x[7:3] == 24 | fill_x[7:3] == 25
			vram_raddr <= { cell[6:0], '1, ~vga.y[4:2], fill_x[3] ^ ~no_flip, fill_x[2:1] }
			state <= 11
		}
		if state == 11 & cell_hi_d == '0 {
			glyph_pixel := fill_x[0] ? glyphs.rdata[1] : glyphs.rdata[0]
			pixel <= glyph_pixel ? '110011001100 : 0
			state <= 15
		}
		if state == 11 & cell_hi_d == '1 & vram_available {
			state <= 12
		}
		if state == 12 {
			color_index := fill_x[0] ? vram_bt_rdata[15:12] : vram_bt_rdata[11:8]
			palette_section := vram_raddr[13:7]
			ram_raddr <= { '000, palette_section, color_index }
			state <= 13
		}
		if state == 13 & ram_available {
			state <= 14
		}
		if state == 14 {
			pixel <= ram_rdata[11:0]
			state <= 15
		}
		if state[2:0] == '111 {
			next_fill_x := fill_x + 1
			if fill_x == 255 {
				state <= 0
			} else {
				vga_y_cell := { vga_y_main[2:0], vga.y[6] }
				not_x_overlay := wide_overlay ? (next_fill_x[7:4] == '0000 | next_fill_x[7:4] == '1111) : (next_fill_x[7:5] == '000 | next_fill_x[7:5] == '111)
				is_overlay := vga_y_main[2] | (enable_overlay & ~(vga_y_cell == '0000 | vga_y_cell == '0111 | not_x_overlay))
				state <= is_overlay ? 8 : 1
			}
			fill_x <= next_fill_x
		}
		reg rbuf <= vga.y[2]
		glyphs := RAM2048x2(
			#initial_data: FONT_GLYPH_DATA
			rclk: clk, wclk: clk
			raddr: { cell[5:0], vga.y[4:2], fill_x[2:1] }
			we: 0, wdata: ---, waddr: ---
		)
	}
	
	wbuf := ~rbuf
	we := state[2:0] == '111
	
	buf_0 := RAM256x16(#initial_data: 0, rclk: clk, wclk: clk,
		raddr: vga.x[8:1],
		we: wbuf == 0 & we, waddr: fill_x, wdata: { 'xxxx, pixel })

	buf_1 := RAM256x16(#initial_data: 0, rclk: clk, wclk: clk,
		raddr: vga.x[8:1],
		we: wbuf == 1 & we, waddr: fill_x, wdata: { 'xxxx, pixel })
		
	vga_pixel := rbuf == 0 ? buf_0.rdata[11:0] : buf_1.rdata[11:0]
}
