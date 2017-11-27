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


////////////////////////////////////////////////////////////////////
//
//   ALTERA_ONCHIP_FLASH
//
//  Copyright (C) 1991-2013 Altera Corporation
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, Altera MegaCore Function License 
//  Agreement, or other applicable license agreement, including, 
//  without limitation, that your use is for the sole purpose of 
//  programming logic devices manufactured by Altera and sold by 
//  Altera or its authorized distributors.  Please refer to the 
//  applicable agreement for further details.
//
////////////////////////////////////////////////////////////////////

// synthesis VERILOG_INPUT_VERSION VERILOG_2001

`timescale 1 ps / 1 ps

module  altera_onchip_flash ( 
	// To/From System
	clock,
	reset_n,
	
	// To/From Avalon_MM data slave interface
	avmm_data_read,
	avmm_data_write,
	avmm_data_addr,
	avmm_data_writedata,
	avmm_data_burstcount,
	avmm_data_waitrequest,
	avmm_data_readdatavalid,
	avmm_data_readdata,
	
	// To/From Avalon_MM csr slave interface
	avmm_csr_read,
	avmm_csr_write,
	avmm_csr_addr,
	avmm_csr_writedata,
	avmm_csr_readdata
);
	parameter DEVICE_FAMILY = "MAX 10";
	parameter PART_NAME = "Unknown";
	parameter IS_DUAL_BOOT = "False";
	parameter IS_ERAM_SKIP = "False";
	parameter IS_COMPRESSED_IMAGE = "False";
	parameter INIT_FILENAME = "";

	// simulation only start
	parameter DEVICE_ID = "08";
	parameter INIT_FILENAME_SIM = "";
	// simulation only end

	parameter PARALLEL_MODE = 0;
	parameter READ_AND_WRITE_MODE = 0;
	parameter WRAPPING_BURST_MODE = 0;
	
	parameter AVMM_CSR_DATA_WIDTH = 32;
	parameter AVMM_DATA_DATA_WIDTH = 32;
	parameter AVMM_DATA_ADDR_WIDTH = 20;
	parameter AVMM_DATA_BURSTCOUNT_WIDTH = 13;
	parameter FLASH_DATA_WIDTH = 32;
	parameter FLASH_ADDR_WIDTH = 23;
	parameter FLASH_SEQ_READ_DATA_COUNT = 2;	//number of 32-bit data per sequential read. only need in parallel mode.
	parameter FLASH_READ_CYCLE_MAX_INDEX = 3;	//period to for each sequential read. only need in parallel mode.
	parameter FLASH_ADDR_ALIGNMENT_BITS = 1; 	//number of last addr bits for alignment. only need in parallel mode.
	parameter FLASH_RESET_CYCLE_MAX_INDEX = 28;	//period that required by flash before back to idle for erase and program operation
	parameter FLASH_BUSY_TIMEOUT_CYCLE_MAX_INDEX = 112; //flash busy timeout period (960ns)
	parameter FLASH_ERASE_TIMEOUT_CYCLE_MAX_INDEX = 40603248; //erase timeout period (350ms)
	parameter FLASH_WRITE_TIMEOUT_CYCLE_MAX_INDEX = 35382; //write timeout period (305us)
	parameter MIN_VALID_ADDR = 1;
	parameter MAX_VALID_ADDR = 1;
	parameter MIN_UFM_VALID_ADDR = 1;
	parameter MAX_UFM_VALID_ADDR = 1;
	parameter SECTOR1_START_ADDR = 1;
	parameter SECTOR1_END_ADDR = 1;
	parameter SECTOR2_START_ADDR = 1;
	parameter SECTOR2_END_ADDR = 1;
	parameter SECTOR3_START_ADDR = 1;
	parameter SECTOR3_END_ADDR = 1;
	parameter SECTOR4_START_ADDR = 1;
	parameter SECTOR4_END_ADDR = 1;
	parameter SECTOR5_START_ADDR = 1;
	parameter SECTOR5_END_ADDR = 1;
	parameter SECTOR_READ_PROTECTION_MODE = 5'b11111;
	parameter SECTOR1_MAP = 1;
	parameter SECTOR2_MAP = 1;
	parameter SECTOR3_MAP = 1;
	parameter SECTOR4_MAP = 1;
	parameter SECTOR5_MAP = 1;
	parameter ADDR_RANGE1_END_ADDR = 1;
	parameter ADDR_RANGE1_OFFSET = 1;
	parameter ADDR_RANGE2_OFFSET = 1;
	
	// To/From System
	input clock;
	input reset_n;

	// To/From Avalon_MM data slave interface
	input avmm_data_read;
	input avmm_data_write;
	input [AVMM_DATA_ADDR_WIDTH-1:0] avmm_data_addr;
	input [AVMM_DATA_DATA_WIDTH-1:0] avmm_data_writedata;
	input [AVMM_DATA_BURSTCOUNT_WIDTH-1:0] avmm_data_burstcount;
	output avmm_data_waitrequest;
	output avmm_data_readdatavalid;
	output [AVMM_DATA_DATA_WIDTH-1:0] avmm_data_readdata;

	// To/From Avalon_MM csr slave interface
	input avmm_csr_read;
	input avmm_csr_write;
	input avmm_csr_addr;
	input [AVMM_CSR_DATA_WIDTH-1:0] avmm_csr_writedata;
	output [AVMM_CSR_DATA_WIDTH-1:0] avmm_csr_readdata;

	wire [AVMM_DATA_DATA_WIDTH-1:0] avmm_data_readdata_wire;
	wire [AVMM_CSR_DATA_WIDTH-1:0] avmm_csr_readdata_wire;
	wire [31:0] csr_control_wire;
	wire [9:0] csr_status_wire;
	wire [FLASH_ADDR_WIDTH-1:0] flash_ardin_wire;
	wire [FLASH_DATA_WIDTH-1:0] flash_drdout_wire;
	wire flash_busy;
	wire flash_se_pass;
	wire flash_sp_pass;
	wire flash_osc;
	wire flash_xe_ye;
	wire flash_se;
	wire flash_arclk;
	wire flash_arshft;
	wire flash_drclk;
	wire flash_drshft;
	wire flash_drdin;
	wire flash_nprogram;
	wire flash_nerase;
	wire flash_par_en;
	wire flash_xe_ye_wire;
	wire flash_se_wire;
	
	assign avmm_data_readdata = avmm_data_readdata_wire;

	generate
		if (READ_AND_WRITE_MODE == 0) begin
			assign avmm_csr_readdata = 32'hffffffff;
			assign csr_control_wire = 32'h3fffffff;
		end
		else begin
			assign avmm_csr_readdata = avmm_csr_readdata_wire;
		end
	endgenerate

	generate
		if (DEVICE_ID == "02" || DEVICE_ID == "01") begin
			assign flash_par_en = 1'b1;
			assign flash_xe_ye = 1'b1;
			assign flash_se = 1'b1;
		end
		else begin
			assign flash_par_en = PARALLEL_MODE[0];
			assign flash_xe_ye = flash_xe_ye_wire;
			assign flash_se = flash_se_wire;
		end
	endgenerate
	
	generate
		if (READ_AND_WRITE_MODE) begin
			// -------------------------------------------------------------------
			// Instantiate a Avalon_MM csr slave controller
			// -------------------------------------------------------------------	
			altera_onchip_flash_avmm_csr_controller avmm_csr_controller ( 
				// To/From System
				.clock(clock),
				.reset_n(reset_n),

				// To/From Avalon_MM csr slave interface
				.avmm_read(avmm_csr_read),
				.avmm_write(avmm_csr_write),
				.avmm_addr(avmm_csr_addr),
				.avmm_writedata(avmm_csr_writedata),
				.avmm_readdata(avmm_csr_readdata_wire),
		
				// To/From Avalon_MM data slave interface
				.csr_control(csr_control_wire),
				.csr_status(csr_status_wire)
			);
		end
	endgenerate

	// -------------------------------------------------------------------
	// Instantiate a Avalon_MM data slave controller
	// -------------------------------------------------------------------	
	altera_onchip_flash_avmm_data_controller # (

		.READ_AND_WRITE_MODE (READ_AND_WRITE_MODE),
		.WRAPPING_BURST_MODE (WRAPPING_BURST_MODE),
		.AVMM_DATA_ADDR_WIDTH (AVMM_DATA_ADDR_WIDTH),
		.AVMM_DATA_BURSTCOUNT_WIDTH (AVMM_DATA_BURSTCOUNT_WIDTH),
		.FLASH_SEQ_READ_DATA_COUNT (FLASH_SEQ_READ_DATA_COUNT),
		.FLASH_READ_CYCLE_MAX_INDEX (FLASH_READ_CYCLE_MAX_INDEX),
		.FLASH_ADDR_ALIGNMENT_BITS (FLASH_ADDR_ALIGNMENT_BITS),
		.FLASH_RESET_CYCLE_MAX_INDEX (FLASH_RESET_CYCLE_MAX_INDEX),
		.FLASH_BUSY_TIMEOUT_CYCLE_MAX_INDEX (FLASH_BUSY_TIMEOUT_CYCLE_MAX_INDEX),
		.FLASH_ERASE_TIMEOUT_CYCLE_MAX_INDEX (FLASH_ERASE_TIMEOUT_CYCLE_MAX_INDEX),
		.FLASH_WRITE_TIMEOUT_CYCLE_MAX_INDEX (FLASH_WRITE_TIMEOUT_CYCLE_MAX_INDEX),
		.MIN_VALID_ADDR (MIN_VALID_ADDR),
		.MAX_VALID_ADDR (MAX_VALID_ADDR),
		.SECTOR1_START_ADDR (SECTOR1_START_ADDR),
		.SECTOR1_END_ADDR (SECTOR1_END_ADDR),
		.SECTOR2_START_ADDR (SECTOR2_START_ADDR),
		.SECTOR2_END_ADDR (SECTOR2_END_ADDR),
		.SECTOR3_START_ADDR (SECTOR3_START_ADDR),
		.SECTOR3_END_ADDR (SECTOR3_END_ADDR),
		.SECTOR4_START_ADDR (SECTOR4_START_ADDR),
		.SECTOR4_END_ADDR (SECTOR4_END_ADDR),
		.SECTOR5_START_ADDR (SECTOR5_START_ADDR),
		.SECTOR5_END_ADDR (SECTOR5_END_ADDR),
		.SECTOR_READ_PROTECTION_MODE (SECTOR_READ_PROTECTION_MODE),
		.SECTOR1_MAP (SECTOR1_MAP),
		.SECTOR2_MAP (SECTOR2_MAP),
		.SECTOR3_MAP (SECTOR3_MAP),
		.SECTOR4_MAP (SECTOR4_MAP),
		.SECTOR5_MAP (SECTOR5_MAP),
		.ADDR_RANGE1_END_ADDR (ADDR_RANGE1_END_ADDR),
		.ADDR_RANGE1_OFFSET (ADDR_RANGE1_OFFSET),
		.ADDR_RANGE2_OFFSET (ADDR_RANGE2_OFFSET)

	) avmm_data_controller ( 
		// To/From System
		.clock(clock),
		.reset_n(reset_n),
		
		// To/From Flash IP interface
		.flash_busy(flash_busy),
		.flash_se_pass(flash_se_pass),
		.flash_sp_pass(flash_sp_pass),
		.flash_osc(flash_osc),
		.flash_drdout(flash_drdout_wire),
		.flash_xe_ye(flash_xe_ye_wire),
		.flash_se(flash_se_wire),
		.flash_arclk(flash_arclk),
		.flash_arshft(flash_arshft),
		.flash_drclk(flash_drclk),
		.flash_drshft(flash_drshft),
		.flash_drdin(flash_drdin),
		.flash_nprogram(flash_nprogram),
		.flash_nerase(flash_nerase),
		.flash_ardin(flash_ardin_wire),

		// To/From Avalon_MM data slave interface
		.avmm_read(avmm_data_read),
		.avmm_write(avmm_data_write),
		.avmm_addr(avmm_data_addr),
		.avmm_writedata(avmm_data_writedata),
		.avmm_burstcount(avmm_data_burstcount),
		.avmm_waitrequest(avmm_data_waitrequest),
		.avmm_readdatavalid(avmm_data_readdatavalid),
		.avmm_readdata(avmm_data_readdata_wire),

		// To/From Avalon_MM csr slave interface
		.csr_control(csr_control_wire),
		.csr_status(csr_status_wire)
	);
	
	// -------------------------------------------------------------------
	// Instantiate wysiwyg for onchip flash block
	// -------------------------------------------------------------------
	altera_onchip_flash_block # (
	
		.DEVICE_FAMILY (DEVICE_FAMILY),
		.PART_NAME (PART_NAME),
		.IS_DUAL_BOOT (IS_DUAL_BOOT),
		.IS_ERAM_SKIP (IS_ERAM_SKIP),
		.IS_COMPRESSED_IMAGE (IS_COMPRESSED_IMAGE),
		.INIT_FILENAME (INIT_FILENAME),
		.MIN_VALID_ADDR (MIN_VALID_ADDR),
		.MAX_VALID_ADDR (MAX_VALID_ADDR),
		.MIN_UFM_VALID_ADDR (MIN_UFM_VALID_ADDR),
		.MAX_UFM_VALID_ADDR (MAX_UFM_VALID_ADDR),
		.ADDR_RANGE1_END_ADDR (ADDR_RANGE1_END_ADDR),
		.ADDR_RANGE1_OFFSET (ADDR_RANGE1_OFFSET),
		.ADDR_RANGE2_OFFSET (ADDR_RANGE2_OFFSET),

		// simulation only start
		.DEVICE_ID (DEVICE_ID),
		.INIT_FILENAME_SIM (INIT_FILENAME_SIM)
		// simulation only end
		
	) altera_onchip_flash_block (
		.xe_ye(flash_xe_ye),
		.se(flash_se),
		.arclk(flash_arclk),
		.arshft(flash_arshft),
		.ardin(flash_ardin_wire),
		.drclk(flash_drclk),
		.drshft(flash_drshft),
		.drdin(flash_drdin),
		.nprogram(flash_nprogram),
		.nerase(flash_nerase),
		.nosc_ena(1'b0),
		.par_en(flash_par_en),
		.drdout(flash_drdout_wire),
		.busy(flash_busy),
		.se_pass(flash_se_pass),
		.sp_pass(flash_sp_pass),
		.osc(flash_osc)
	);
	
	
endmodule //altera_onchip_flash
//VALID FILE
