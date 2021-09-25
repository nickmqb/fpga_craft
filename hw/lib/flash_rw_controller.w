// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

// All spi_* outputs must be registered I/Os (i.e. outputted with 1 cycle delay)

flash_rw_controller(
	clk $1
	op $3
	offset $17 // In 128 byte blocks
	num_words $15 // 1 word = 16-bit
	ram_offset $15 // In 16-bit words
	ram_rdata $16
	spi_miso $1
) {
	out reg we $1
	out reg re $1
	out reg addr $15
	out on := state != 1

	out reg spi_cs_isLow $1
	out reg spi_clk_isLow $1
	out reg spi_mosi $1
	
	reg state $3
	reg header_data $32
	reg header_include_offset $1
	reg is_any_read $1
	reg is_page_program $1
	reg header_count $6

	reg read_data $16
	reg read_count $19
	reg write_data $15
	reg write_count $19
	reg ram_write_started $1

	posedge clk {
		we <= '0
		re <= '0
		if state == 0 {
			spi_cs_isLow <= '0
			spi_clk_isLow <= '0
			spi_mosi <= '0
			header_count <= 0
			ram_write_started <= 0
			read_count <= 0
			write_count <= 0
			state <= 1
		}
		if state == 1 {
			spi_cs_isLow <= '0
			spi_clk_isLow <= '0
			// Don't allow erase/page program in area reserved for FPGA bitstream (first 128kb)
			is_valid_command := (op == 1 | op == 2) ? (offset[16:10] != 0) : '1
			if op != 0 & is_valid_command {
				state <= 2
				spi_cs_isLow <= '1
				addr <= ram_offset
				ins := match op {
					0: 0x03_$8 // Read data (not used)
					1: 0x20_$8 // Sector erase
					2: 0x02_$8 // Page program
					3: 0x03_$8 // Read data
					4: 0x75_$8 // Suspend
					5: 0x05_$8 // Read status 1
					6: 0x06_$8 // Write enable
					7: 0x7a_$8 // Resume
				}
				is_any_read <= op == 0x03 | op == 0x05
				is_page_program <= op == 0x02
				header_include_offset <= op[2] == '0
				header_data <= { ins, offset, 0_$7 }
			}
		}
		if state == 2 {
			spi_clk_isLow <= ~spi_clk_isLow
			if ~spi_clk_isLow {
				spi_mosi <= header_data[31]
				header_data <= { header_data[30:0], '0 }
				header_count <= header_count + 1
				if header_count == (header_include_offset ? 31_$6 : 7_$6) {
					state <= is_page_program ? 5_$3 : (is_any_read ? 3_$3 : 7_$3)
					re <= is_page_program
				}
			}
		}
		if state == 3 {
			spi_clk_isLow <= ~spi_clk_isLow
			if ~spi_clk_isLow {
				spi_mosi <= '0
				state <= 4
			}
		}
		if state == 4 {
			spi_clk_isLow <= ~spi_clk_isLow
			if ~spi_clk_isLow {
				read_data <= { read_data[14:0], spi_miso }
				read_count <= read_count + 1
				if read_count[3:0] == '1111 {
					we <= '1
					if ram_write_started {
						addr <= addr + 1
					} else {
						ram_write_started <= '1
					}
					out wdata := { read_data[7:0], read_data[15:8] } // Little endian
				}
			}
			if (read_count == { num_words, '0000 }) {
				state <= 0
			}
		}
		if state == 5 {
			spi_clk_isLow <= ~spi_clk_isLow
			if ~spi_clk_isLow {
				if write_count[3:0] == '0000 {
					spi_mosi <= ram_rdata[7]
					write_data <= { ram_rdata[6:0], ram_rdata[15:8] } // Little endian
				} else {
					spi_mosi <= write_data[14]
					write_data <= { write_data[13:0], '0 }
				}
				write_count <= write_count + 1
				if write_count[3:0] == '1111 {
					addr <= addr + 1
					re <= '1
				}
			}
			if (write_count == { num_words, '0000 }) {
				state <= 0
			}
		}
		if state == 7 {
			spi_clk_isLow <= ~spi_clk_isLow
			state <= 0
		}
	}
}
