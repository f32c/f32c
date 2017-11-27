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
//  ALTERA_ONCHIP_FLASH_AVMM_CSR_CONTROLLER
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

module altera_onchip_flash_avmm_csr_controller (
	// To/From System
	clock,
	reset_n,

	// To/From Avalon_MM csr slave interface
	avmm_read,
	avmm_write,
	avmm_addr,
	avmm_writedata,
	avmm_readdata,
	
	// To/From Avalon_MM data slave interface
	csr_status,
	csr_control
);

	parameter AVMM_CSR_DATA_WIDTH = 32;

	localparam [1:0]	ERASE_ST_IDLE = 0,
						ERASE_ST_PENDING = 1,
						ERASE_ST_BUSY = 2;

	localparam [1:0]	STATUS_IDLE = 0,
						STATUS_BUSY_ERASE = 1,
						STATUS_BUSY_WRITE = 2,
						STATUS_BUSY_READ = 3;

	// To/From System
	input clock;
	input reset_n;

	// To/From Avalon_MM csr slave interface
	input avmm_read;
	input avmm_write;
	input avmm_addr;
	input [AVMM_CSR_DATA_WIDTH-1:0] avmm_writedata;
	output [AVMM_CSR_DATA_WIDTH-1:0] avmm_readdata;
	
	// To/From Avalon_MM data slave interface
	input [9:0] csr_status;
	output [31:0] csr_control;
	
	reg [22:0] csr_sector_page_erase_addr_reg;
	reg [4:0] csr_wp_mode;
	reg [1:0] csr_erase_state;
	reg csr_control_access;
	reg reset_n_reg1;
	reg reset_n_reg2;

	wire reset_n_w;
	wire is_idle;
	wire is_erase_busy;
	wire valid_csr_erase_addr;
	wire valid_csr_write;
	wire [31:0] csr_control_signal;
	wire [22:0] csr_erase_addr;

	assign is_idle = (csr_status[1:0] == STATUS_IDLE);
	assign is_erase_busy = (csr_status[1:0] == STATUS_BUSY_ERASE);
	assign csr_erase_addr = avmm_writedata[22:0];
	assign valid_csr_erase_addr = (csr_erase_addr != {(23){1'b1}});
	assign valid_csr_write = (avmm_write & avmm_addr);		
	assign csr_control_signal = { csr_erase_state, {(2){1'b1}}, csr_wp_mode, csr_sector_page_erase_addr_reg };
	assign csr_control = csr_control_signal;
	assign avmm_readdata = (csr_control_access) ? csr_control_signal : { {(22){1'b1}}, csr_status[9:0] };

	// avoid async reset removal issue 
	assign reset_n_w = reset_n_reg2;
	
	// Initiate register value for simulation. The initiate value can't be xx
	initial begin
		csr_sector_page_erase_addr_reg <= {(23){1'b1}};
		csr_wp_mode = {(5){1'b1}};
		csr_erase_state = ERASE_ST_IDLE;
		csr_control_access = 1'b0;
		reset_n_reg1 = 1'b0;
		reset_n_reg2 = 1'b0;
	end

	// -------------------------------------------------------------------
	// Avoid async reset removal issue 
	// -------------------------------------------------------------------
	always @ (negedge reset_n or posedge clock) begin
		if (~reset_n) begin
			{reset_n_reg2, reset_n_reg1} <= 2'b0;
		end
		else begin
			{reset_n_reg2, reset_n_reg1} <= {reset_n_reg1, 1'b1};
		end
	end
	
	// -------------------------------------------------------------------
	// Avalon_MM read/write
	// -------------------------------------------------------------------		
	always @ (posedge clock) begin
		
		// synchronous reset
		if (~reset_n_w) begin

			// reset all register
			csr_sector_page_erase_addr_reg <= {(23){1'b1}};
			csr_wp_mode <= {(5){1'b1}};
			csr_erase_state <= ERASE_ST_IDLE;
			csr_control_access <= 1'b0;

		end
		else begin

			// store read address
			if (avmm_read) begin
				csr_control_access <= avmm_addr;
			end
		
			// write control register
			if (valid_csr_write) begin
				csr_wp_mode <= avmm_writedata[27:23];
				if (is_idle) begin 
					csr_sector_page_erase_addr_reg <= avmm_writedata[22:0]; 
				end
			end
		
			// erase control fsm
			case (csr_erase_state)
				ERASE_ST_IDLE:
					if (is_idle && valid_csr_write && valid_csr_erase_addr) begin 
						csr_erase_state <= ERASE_ST_PENDING;
					end
				ERASE_ST_PENDING:
					if (is_erase_busy) begin 
						csr_erase_state <= ERASE_ST_BUSY; 
					end
				ERASE_ST_BUSY:
					if (is_idle) begin
						csr_erase_state <= ERASE_ST_IDLE; 
					end
				default: begin
					csr_erase_state <= ERASE_ST_IDLE;
				end
			endcase
		end
		
	end

endmodule
