// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

// All instructions are 1 byte, except for the following which have an extra 1 byte argument/suffix:
// in, out, get_ex, put_ex, call, jump, goto, bz, bnz

// 0x00-0x7f: get(128)
// 0x80-0xbf: put(64)
// 0xc_: + dec dup inc swap sub inv neg & | ^ &~ store storeb push pop
// 0xd_: >=u <u <s >=s >u <=u <=s >s not to_bool == != mul mul16 mul8s mul12s
// 0xe_: load loadb in out get_ex put_ex ? ? call jump ret ? add_offset ? push_slow pop_slow
// 0xf_: goto(8) bz(4) bnz(4)

cpu(#initial_locals $4096, #initial_jump_table $4096, clk $1, req_enabled $1, ins $8, mem_rdata $16, port_rdata $16) {
	out reg pc $13
	out reg a $16
	out reg b $16	

	reg sp $6
	reg temp_mul $16
	reg temp_in $16
	reg temp_misc $16
	reg carry_out $1

	posedge clk {
		reg decode <= req_enabled
		reg ins_d <= ins

		if req_enabled & ~stall {
			pc <= pc + 1
		}

		if decode {
			reg ctrl_get <= ins[7] == '0
			reg ctrl_put <= ins[7:6] == '10
			reg ctrl_alu <= (ins[7:4] == 0xc & (ins[3] == 0 | ins[3:1] == 6)) | (ins[7:4] == 0xd & (ins[3] == 0 | ins[2] == 0))
			reg ctrl_alu_a_mode <= { ins[4:0] == 1 | ins[4:3] == 1, ins[4:1] == 1 | ins[4:1] == 3 | ins[4:3] == 1 | ins[4:1] == 12 }
			reg ctrl_alu_b_mode <= { ins[4:0] == 4, ins[4:2] == 1 | ins[4:3] == 2 | ins[4:1] == 13 }
			reg ctrl_alu_carry_in <= { ins[4:0] == 3 | ins[4:0] == 5 | ins[4:0] == 7 | ins[4:0] == 12 | ins[4:3] == 2 | ins[4:1] == 13 }
			reg ctrl_alu_compare <= '0
			reg ctrl_alu_compare_mode <= { ins[3:2] == 1, ins[3:2] == 0 | ins[3:1] == 3 }
			reg ctrl_alu_compare_invert <= ins[0]
			reg ctrl_bitwise <= (ins[7:4] == 0xc & ins[3:2] == 2)
			reg ctrl_mul <= (ins[7:4] == 0xd & ins[3:2] == 3)
			reg ctrl_load <= ins == 0xe0 | ins == 0xe1
			reg ctrl_store <= ins == 0xcc | ins == 0xcd
			reg ctrl_ls_byte <= ins[0]
			reg ctrl_in <= ins == 0xe2
			reg ctrl_in_f <= '0
			reg ctrl_out <= ins == 0xe3
			reg ctrl_get_ex <= ins == 0xe4
			reg ctrl_put_ex <= ins == 0xe5
			reg ctrl_push <= ins == 0xce | ins == 0xee
			reg ctrl_pop <= ins == 0xcf | ins == 0xef
			reg ctrl_jump <= ins == 0xe8 | ins == 0xe9
			reg ctrl_jump_f <= '0
			reg ctrl_call <= ins == 0xe9
			reg ctrl_ret <= ins == 0xea
			reg ctrl_add_offset <= ins == 0xec
			reg ctrl_goto <= ins[7:4] == 0xf

			// >=2 cycles
			if ins[7:4] == 0xd | ins[7:4] == 0xe | ins[7:4] == 0xf { 
				decode <= '0
			}
			
			// cycles > num_bytes
			stall := decode & (ins[7:4] == 0xd | (ins[7:4] == 0xe & (ins[3:1] == 0 | ins[3:0] == 2 | ins[3:2] == 3)))
		}

		if ctrl_mul & ~decode {
			mul_u := MUL16x16(clk: clk, a: a, b: b).o
			mul_s := MUL16x16_SIGNED(clk: clk, a: a, b: b).o
			temp_mul <= match ins_d[1:0] {
				'00: mul_u[15:0]
				'01: mul_u[31:16]
				'10: mul_s[23:8]
				'11: mul_s[27:12]
			}
		}
		if ctrl_mul & decode {
			b <= temp_mul
		}

		if ctrl_add_offset & ~decode {
			offset_x := { b[10:7], b[0] } + { a[10:7], a[0] }
			offset_y := b[6:2] + a[6:2]
			offset_z := { b[14:11], b[1] } + { a[14:11], a[1] }
			temp_misc <= { '1, offset_z[4:1], offset_x[4:1], offset_y, offset_z[0], offset_x[0] }
		}
		if ctrl_add_offset & decode {
			b <= temp_misc
		}

		out req_rport := ctrl_in_f
		out req_wport := ctrl_out & decode
		out port := ins_d[5:0]
		if ctrl_in {			
			ctrl_in <= 0
			ctrl_in_f <= 1
			decode <= 0
		}
		if ctrl_in_f & ~decode {
			temp_in <= port_rdata
		}
		if ctrl_in_f & decode {
			b <= temp_in
			a <= b
		}

		if ctrl_alu_compare {
			cmp := match ctrl_alu_compare_mode {
				'00: eq0
				'01: carry_out
				'10: carry_out & ~eq0
				'11: carry_out | eq0
			}
			b <= { rep('0, 15), cmp ^ ctrl_alu_compare_invert }
		}

		if ctrl_bitwise {
			b <= match ins_d[1:0] {
				'00: a & b
				'01: a | b
				'10: a ^ b
				'11: a & ~b
			}
		}

		eq0 := b == 0
		if ctrl_goto & ~decode & (ins_d[3] == 0 | (ins_d[2] != eq0)) {
			pc <= pc + { ins_d[3] ? rep(ins_d[1], 3) : rep(ins_d[2], 3), ins_d[1:0], ins }
			ctrl_goto <= 0
			decode <= 0
		}
	
		out req_r := ctrl_load & ~decode
		out req_w := ctrl_store
		out req_byte := ctrl_ls_byte
		if ctrl_load & decode {
			b <= mem_rdata			
			a <= b
		}

		if ctrl_push {
			sp <= sp + 1
		}

		if ctrl_push & ~decode {
			ctrl_push <= 0
		}

		if ctrl_pop {
			ctrl_pop <= 0
			sp <= sp - 1
			b <= jump_stack.rdata
			a <= b
		}

		if ctrl_jump {
			ctrl_jump <= 0
			ctrl_jump_f <= 1
			decode <= 0
		}

		if ctrl_jump_f {
			ctrl_jump_f <= 0
			decode <= 0
			pc <= jump_stack.rdata[12:0]
		}

		if ctrl_call {
			ctrl_call <= 0
			sp <= sp + 1
		}

		if ctrl_ret {
			ctrl_ret <= 0
			decode <= 0
			sp <= sp - 1
			pc <= jump_stack.rdata[12:0]
		}

		jump_stack := RAM256x16(
			#initial_data: #initial_jump_table
			rclk: clk, wclk: clk
			raddr: ctrl_jump ? ins : { '11, sp - 1 }
			we: ctrl_push | ctrl_call, waddr: { '11, sp }, wdata: ctrl_push ? b : { '000, pc }
		)

		if ctrl_alu & ~ctrl_alu_compare {
			alu := alu(clk: clk, a: a, b: b, a_mode: ctrl_alu_a_mode, b_mode: ctrl_alu_b_mode, carry_in: ctrl_alu_carry_in, signed: ins_d[1])			
			b <= alu.o[15:0]
			carry_out <= alu.o[16]
			if ctrl_alu_b_mode[1] { // If swap
				a <= b
			}
			ctrl_alu_compare <= ins_d[4]
		}

		if (ctrl_get & (prev_ctrl_put == 0 | ins_d[7:6] != 0 | ins_d[5:0] != prev_ctrl_put_addr)) | (ctrl_get_ex & decode) {
			b <= locals.rdata
		}
		if ctrl_get | (ctrl_get_ex & decode) {
			a <= b
		}

		locals := RAM256x16(
			#initial_data: #initial_locals
			rclk: clk, wclk: clk
			raddr: ins
			we: ctrl_put | (ctrl_put_ex & ~decode), waddr: ctrl_put ? { '00, ins_d[5:0] } : ins, wdata: b
		)

		reg prev_ctrl_put <= ctrl_put
		reg prev_ctrl_put_addr <= ins_d[5:0]
	}
}

alu(clk $1, a $16, b $16, a_mode $2, b_mode $2, carry_in $1, signed $1) {
	lhs := match a_mode {
		'00: a
		'01: 0_$16
		'10: 0xffff_$16
		'11: 1_$16
	}

	rhs := match b_mode {
		'00: b
		'01: ~b
		'10: 0_$16
		'11: 0_$16
	}
		
	out o := { signed ? lhs[15] : '0, lhs } + { signed ? rhs[15] : '0, rhs } + { 0_$16, carry_in }
}
