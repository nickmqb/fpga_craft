// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

gamepad_controller(clk $1, input $1, req_sync $1, req_read $1) {
	reg timer $19
	reg poll $1

	reg commit $16
	reg diff $16
	reg latest $16

	out reg stick $16
	out reg response_time $16
	out reg num_reads $16

	gamepad := gamepad(clk: clk, input: input, begin_poll: poll)

	posedge clk {
		if req_sync {
			timer <= 8192
		}
		if timer == 180543 {
			timer <= 0
			poll <= '1
			num_reads <= num_reads + 1
		} else {
			timer <= timer + 1
			poll <= '0
		}

		out buttons := commit ^ diff

		if req_read {
			diff <= 0
			commit <= buttons
		} else {
			diff <= diff | (commit ^ latest)
		}

		if gamepad.data_ready {
			stick <= { gamepad.data[8:1], gamepad.data[16:9] }
			latest <= { gamepad.data[24:17], gamepad.data[32:25] }
			response_time <= gamepad.response_time
		}
	}

	out output_isLow := gamepad.output_isLow
}

GAMEPAD_SEND_DELAY := 31 // 1 us @ 32.625 Mhz = 32 cycles + remainder
GAMEPAD_READ_DELAY := 64 // 2 us @ 32.625 Mhz = approx 65 cycles

gamepad(clk $1, input $1, begin_poll $1) {
	reg state $2
	out reg response_time $16
	reg response_wait $1

	posedge clk {
		reg i $6
		reg sd $6

		if state == '00 & begin_poll {
			state <= '01
			i <= 0
			sd <= 0
		}

		if state == '01 {
			if sd == GAMEPAD_SEND_DELAY {
				if i == 33 {
					state <= '10
					response_time <= 0
					response_wait <= '1
				} else {
					i <= i + 1
				}
				sd <= rep(i[2:0] == 1 | i[2:0] == 3 | i[2:0] == 4 | i[2:0] == 6 | i[2:0] == 7, 6)
			} else {
				sd <= sd + 1
			}
			output_bit := (i[5:2] == 7 | i[5:2] == 8) // Send request byte: 0x01 (msb first)
			out output_isLow := state == '01 & match i[1:0] {
				'00: '1
				'01: ~output_bit
				'10: ~output_bit
				'11: '0
			}
		}

		out reg data_ready <= '0
		out reg data $33
		reg j $6
		reg rd $7

		reg input_d <= input
		if state == '10 & input_d & ~input {
			rd <= 0
			state <= '11
		}

		if response_wait {
			response_time <= response_time + 1
		}

		if state == '11 {			
			rd <= rd + 1
			if rd == GAMEPAD_READ_DELAY {
				data <= { data[31:0], input }
				if j == 32 {
					j <= 0
					data_ready <= '1
					response_wait <= '0
					state <= '00
				} else {
					j <= j + 1
					state <= '10
				}
			}
		}
	}
}
