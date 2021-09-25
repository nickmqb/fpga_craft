// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

dma_controller(
	clk $1
	spi_miso $1
	port $6
	port_we $1
	port_wdata $16
	ram_rdata $16
) {
	reg offset $16
	reg num_words $15
	// Flag bits
	// 0: read flash data into VRAM
	// 1: use upper flash memory range (0x800000-0xffffff)
	reg flags $2
	reg ram_offset $15
	reg op $3
	out reg sector_erase_count $8
	out reg page_program_count $8

	posedge clk {
		op <= 0
		if port_we {
			if port == 0x20 { offset <= port_wdata }
			if port == 0x21 { num_words <= port_wdata[15:1] }
			if port == 0x22 { flags <= port_wdata[1:0] }
			if port == 0x23 { ram_offset <= port_wdata[15:1] }
			if port == 0x27 { 
				op <= port_wdata[2:0]
				if port_wdata[2:0] == 1 {
					sector_erase_count <= sector_erase_count + 1
				} else if port_wdata[2:0] == 2 {
					page_program_count <= page_program_count + 1
				}
			}
		}
	}

	flash := flash_rw_controller(
		clk: clk
		op: op
		offset: { flags[1], offset }
		num_words: num_words
		ram_offset: ram_offset
		ram_rdata: ram_rdata,
		spi_miso: spi_miso)
	out spi_cs_isLow := flash.spi_cs_isLow
	out spi_clk_isLow := flash.spi_clk_isLow
	out spi_mosi := flash.spi_mosi
	out led_red_isOff := flash.spi_cs_isLow
	out ram_we := flash.we & ~flags[0]
	out ram_e := (flash.we & ~flags[0]) | flash.re
	out vram_we := flash.we & flags[0]
	out addr := flash.addr
	out wdata := flash.wdata
	out on := flash.on
}
