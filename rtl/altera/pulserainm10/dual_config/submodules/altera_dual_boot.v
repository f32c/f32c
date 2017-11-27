// (C) 2001-2016 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


module altera_dual_boot
(
	clk,
	nreset,
	avmm_rcv_address,
	avmm_rcv_writedata,
	avmm_rcv_write,
	avmm_rcv_read,
	avmm_rcv_readdata
);
	parameter LPM_TYPE = "ALTERA_DUAL_BOOT";
	parameter INTENDED_DEVICE_FAMILY = "MAX 10 FPGA";
	parameter A_WIDTH = 3;
	parameter WD_WIDTH = 4;
	parameter RD_WIDTH = 17;
	parameter MAX_DATA_WIDTH = 32;
	parameter CONFIG_CYCLE = 28;	
	parameter RESET_TIMER_CYCLE = 40;
	
	input clk;
	input nreset;
	input [A_WIDTH-1:0] avmm_rcv_address;
	input [MAX_DATA_WIDTH-1:0] avmm_rcv_writedata;
	input avmm_rcv_write;
	input avmm_rcv_read;
	output [MAX_DATA_WIDTH-1:0] avmm_rcv_readdata;
	
	alt_dual_boot_avmm alt_dual_boot_avmm_comp
	(
		.clk(clk),
		.nreset(nreset),
		.avmm_rcv_address(avmm_rcv_address),
		.avmm_rcv_writedata(avmm_rcv_writedata),
		.avmm_rcv_write(avmm_rcv_write),
		.avmm_rcv_read(avmm_rcv_read),
		.avmm_rcv_readdata(avmm_rcv_readdata)
	);
	defparam
		alt_dual_boot_avmm_comp.LPM_TYPE = LPM_TYPE,
		alt_dual_boot_avmm_comp.INTENDED_DEVICE_FAMILY = INTENDED_DEVICE_FAMILY,
		alt_dual_boot_avmm_comp.A_WIDTH = A_WIDTH,
		alt_dual_boot_avmm_comp.MAX_DATA_WIDTH = MAX_DATA_WIDTH,
		alt_dual_boot_avmm_comp.WD_WIDTH = WD_WIDTH,
		alt_dual_boot_avmm_comp.RD_WIDTH = RD_WIDTH,
		alt_dual_boot_avmm_comp.CONFIG_CYCLE = CONFIG_CYCLE,
		alt_dual_boot_avmm_comp.RESET_TIMER_CYCLE = RESET_TIMER_CYCLE;
	
endmodule
