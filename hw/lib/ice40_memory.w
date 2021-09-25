// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

RAM256K_IS(
	#initial_data_sim $262144
	clk $1
	addr $14
	wdata $16
	wmask $4
	we $1
) {
	out rdata := RAM.DATAOUT

	RAM := SB_SPRAM256KA(
		CLOCK: clk
		ADDRESS: addr
		DATAIN: wdata
		MASKWREN: wmask
		WREN: we
		CHIPSELECT: '1
		STANDBY: '0
		SLEEP: '0
		POWEROFF: '1
	)
}

RAM512K(
	clk $1
	addr $15
	wdata $16
	wmask $4
	we $1
) {
	bank0 := RAM256K(
		clk: clk
		addr: addr[13:0]
		wdata: wdata, wmask: wmask, we: we & ~addr[14]
	)
	bank1 := RAM256K(
		clk: clk
		addr: addr[13:0]
		wdata: wdata, wmask: wmask, we: we & addr[14]
	)
	posedge clk {
		reg bank <= addr[14]
	}
	out rdata := match bank {
		0: bank0.rdata
		1: bank1.rdata
	}
}

ROM2048x8(
    clk $1
    raddr $11
    #initial_data $16384
) {
	#sw := swizzle(#initial_data, 2, 8, 16384)
	bank0 := RAM2048x2(#initial_data: chunk(#sw, 0, 4), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank1 := RAM2048x2(#initial_data: chunk(#sw, 1, 4), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank2 := RAM2048x2(#initial_data: chunk(#sw, 2, 4), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank3 := RAM2048x2(#initial_data: chunk(#sw, 3, 4), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	
	out rdata := { bank3.rdata, bank2.rdata, bank1.rdata, bank0.rdata }
}

ROM4096x8(
    clk $1
    raddr $12
    #initial_data $32768
) {
	#sw := swizzle(#initial_data, 2, 16, 32768)
	bank0 := RAM2048x2(#initial_data: chunk(#sw, 0, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank1 := RAM2048x2(#initial_data: chunk(#sw, 1, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank2 := RAM2048x2(#initial_data: chunk(#sw, 2, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank3 := RAM2048x2(#initial_data: chunk(#sw, 3, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank4 := RAM2048x2(#initial_data: chunk(#sw, 4, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank5 := RAM2048x2(#initial_data: chunk(#sw, 5, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank6 := RAM2048x2(#initial_data: chunk(#sw, 6, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	bank7 := RAM2048x2(#initial_data: chunk(#sw, 7, 8), rclk: clk, wclk: clk, raddr: raddr[11:1], waddr: ---, wdata: ---, we: '0)
	
	posedge clk {
		reg bank <= raddr[0]
	}
	out rdata := match bank {
		0: { bank3.rdata, bank2.rdata, bank1.rdata, bank0.rdata }
		1: { bank7.rdata, bank6.rdata, bank5.rdata, bank4.rdata }
	}
}

ROM5120x8(
    clk $1
    raddr $13
    #initial_data $40960
) {
	#sw := swizzle(slice(#initial_data, 0, 32768), 2, 8, 16384)
	bank0 := RAM2048x2(#initial_data: chunk(#sw, 0, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank1 := RAM2048x2(#initial_data: chunk(#sw, 1, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank2 := RAM2048x2(#initial_data: chunk(#sw, 2, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank3 := RAM2048x2(#initial_data: chunk(#sw, 3, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank4 := RAM2048x2(#initial_data: chunk(#sw, 4, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank5 := RAM2048x2(#initial_data: chunk(#sw, 5, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank6 := RAM2048x2(#initial_data: chunk(#sw, 6, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	bank7 := RAM2048x2(#initial_data: chunk(#sw, 7, 8), rclk: clk, wclk: clk, raddr: raddr[10:0], waddr: ---, wdata: ---, we: '0)
	#sw2 := swizzle(slice(#initial_data, 32768, 8192), 4, 8, 8192)
	bank8 := RAM1024x4(#initial_data: chunk(#sw2, 0, 2), rclk: clk, wclk: clk, raddr: raddr[9:0], waddr: ---, wdata: ---, we: '0)
	bank9 := RAM1024x4(#initial_data: chunk(#sw2, 1, 2), rclk: clk, wclk: clk, raddr: raddr[9:0], waddr: ---, wdata: ---, we: '0)
	
	posedge clk {
		reg bank <= raddr[12:11]
	}
	out rdata := match bank {
		0: { bank3.rdata, bank2.rdata, bank1.rdata, bank0.rdata }
		1: { bank7.rdata, bank6.rdata, bank5.rdata, bank4.rdata }
		2: { bank9.rdata, bank8.rdata }
		3: { bank9.rdata, bank8.rdata }
	}
}
