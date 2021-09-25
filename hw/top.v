// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

module top(
    input clock_12mhz,
	input gamepad_data,
	output spi_cs,
	output spi_clk,
	output spi_mosi,
	input spi_miso,
	output led_red,
	//input keyboard_data,
	//input keyboard_clock,
	output [3:0] vga_r,
	output [3:0] vga_g,
	output [3:0] vga_b,
	output vga_hsync,
	output vga_vsync
);

// GLOBAL BUFFERS

wire clock_vga;
wire clock_vga_2x;
wire [7:2] bufs;
(* keep *) SB_GB buf2(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[2]));
(* keep *) SB_GB buf3(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[3]));
(* keep *) SB_GB buf4(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[4]));
(* keep *) SB_GB buf5(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[5]));
(* keep *) SB_GB buf6(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[6]));
(* keep *) SB_GB buf7(.USER_SIGNAL_TO_GLOBAL_BUFFER(1'b0),.GLOBAL_BUFFER_OUTPUT(bufs[7]));

// CLOCKS

// 65.250mhz -> 32.625mhz
SB_PLL40_2F_PAD #(
    .FEEDBACK_PATH("SIMPLE"),
	.PLLOUT_SELECT_PORTA("GENCLK_HALF"),
	.PLLOUT_SELECT_PORTB("GENCLK"),
    .DIVR(4'b0000),		// DIVR =  0
    .DIVF(7'b1010110),	// DIVF = 86
    .DIVQ(3'b100),		// DIVQ =  4
    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
) pll (
    .RESETB(1'b1),
    .BYPASS(1'b0),
    .PACKAGEPIN(clock_12mhz),
    .PLLOUTGLOBALA(clock_vga),
	.PLLOUTGLOBALB(clock_vga_2x)
);

// BRINGUP

reg [25:0] bringup = 0;
reg ready = 0;

always @(posedge clock_vga) begin
	ready <= 1'b0;
	if (bringup == 26'h3ffffff) begin
		ready <= 1'b1;
	end else begin
		bringup <= bringup + 26'd1;
	end
end

// IMPLEMENTATION

wire [3:0] core_vga_r;
wire [3:0] core_vga_g;
wire [3:0] core_vga_b;
wire core_vga_hsync;
wire core_vga_vsync;
wire core_spi_cs_isLow;
wire core_spi_clk_isLow;
wire core_spi_mosi;
wire core_spi_miso;
wire core_led_red_isOff;
wire core_gamepad_out_isLow;
wire core_gamepad_in;
core core(
	.clk(clock_vga),
	.clk2x(clock_vga_2x),
	.req_enabled(ready),
	.vga_r(core_vga_r),
	.vga_g(core_vga_g),
	.vga_b(core_vga_b),
	.vga_hs(core_vga_hsync),
	.vga_vs(core_vga_vsync),
	.is_sim(1'b0),
	.spi_cs_isLow(core_spi_cs_isLow),
	.spi_clk_isLow(core_spi_clk_isLow),
	.spi_mosi(core_spi_mosi),
	.spi_miso(core_spi_miso),
	.led_red_isOff(core_led_red_isOff),
	.gamepad_out_isLow(core_gamepad_out_isLow),
	.gamepad_in(core_gamepad_in)
);

// IO

SB_IO #(.PIN_TYPE(6'b010101)) io_vga_r0 (.PACKAGE_PIN(vga_r[0]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_r[0]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_r1 (.PACKAGE_PIN(vga_r[1]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_r[1]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_r2 (.PACKAGE_PIN(vga_r[2]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_r[2]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_r3 (.PACKAGE_PIN(vga_r[3]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_r[3]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_g0 (.PACKAGE_PIN(vga_g[0]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_g[0]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_g1 (.PACKAGE_PIN(vga_g[1]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_g[1]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_g2 (.PACKAGE_PIN(vga_g[2]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_g[2]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_g3 (.PACKAGE_PIN(vga_g[3]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_g[3]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_b0 (.PACKAGE_PIN(vga_b[0]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_b[0]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_b1 (.PACKAGE_PIN(vga_b[1]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_b[1]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_b2 (.PACKAGE_PIN(vga_b[2]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_b[2]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_b3 (.PACKAGE_PIN(vga_b[3]),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_b[3]));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_hs (.PACKAGE_PIN(vga_hsync),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_hsync));
SB_IO #(.PIN_TYPE(6'b010101)) io_vga_vs (.PACKAGE_PIN(vga_vsync),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_vga_vsync));

SB_IO #(.PIN_TYPE(6'b011101)) io_spi_cs (.PACKAGE_PIN(spi_cs),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_spi_cs_isLow));
SB_IO #(.PIN_TYPE(6'b011101)) io_spi_clk (.PACKAGE_PIN(spi_clk),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_spi_clk_isLow));
SB_IO #(.PIN_TYPE(6'b010101)) io_spi_mosi (.PACKAGE_PIN(spi_mosi),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_spi_mosi));
SB_IO #(.PIN_TYPE(6'b000001)) io_spi_miso (.PACKAGE_PIN(spi_miso),.D_IN_0(core_spi_miso));

SB_IO #(.PIN_TYPE(6'b010101)) io_led_red (.PACKAGE_PIN(led_red),.OUTPUT_CLK(clock_vga),.D_OUT_0(core_led_red_isOff));

SB_IO #(.PIN_TYPE(6'b111000),.PULLUP(1'b1)) io_gamepad_data (
	.PACKAGE_PIN(gamepad_data),
	.INPUT_CLK(clock_vga),
	.OUTPUT_CLK(clock_vga),
	.OUTPUT_ENABLE(core_gamepad_out_isLow),
	.D_OUT_0(1'b0),
	.D_IN_0(core_gamepad_in)
); /* synthesis PULLUP_RESISTOR = "3P3K" */

endmodule
