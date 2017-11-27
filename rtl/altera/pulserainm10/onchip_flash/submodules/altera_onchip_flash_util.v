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
//  ALTERA_ONCHIP_FLASH_UTIL
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

module altera_onchip_flash_address_range_check (
    address,
    is_addr_within_valid_range
);

    parameter FLASH_ADDR_WIDTH = 23;
    parameter MIN_VALID_ADDR = 1;
    parameter MAX_VALID_ADDR = 1;

    input [FLASH_ADDR_WIDTH-1:0] address;
    output is_addr_within_valid_range;
    
    assign is_addr_within_valid_range = (address >= MIN_VALID_ADDR) && (address <= MAX_VALID_ADDR);

endmodule


module altera_onchip_flash_address_write_protection_check (
    use_sector_addr,
    address,
    write_protection_mode,
    is_addr_writable
);

    parameter FLASH_ADDR_WIDTH = 23;
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

    input use_sector_addr;
    input [FLASH_ADDR_WIDTH-1:0] address;
    input [4:0] write_protection_mode;
    output is_addr_writable;

    wire is_sector1_addr;
    wire is_sector2_addr;
    wire is_sector3_addr;
    wire is_sector4_addr;
    wire is_sector5_addr;    
    wire is_sector1_writable;
    wire is_sector2_writable;
    wire is_sector3_writable;
    wire is_sector4_writable;
    wire is_sector5_writable;
    
    assign is_sector1_addr = (use_sector_addr) ? (address == 1) : ((address >= SECTOR1_START_ADDR) && (address <= SECTOR1_END_ADDR));
    assign is_sector2_addr = (use_sector_addr) ? (address == 2) : ((address >= SECTOR2_START_ADDR) && (address <= SECTOR2_END_ADDR));
    assign is_sector3_addr = (use_sector_addr) ? (address == 3) : ((address >= SECTOR3_START_ADDR) && (address <= SECTOR3_END_ADDR));
    assign is_sector4_addr = (use_sector_addr) ? (address == 4) : ((address >= SECTOR4_START_ADDR) && (address <= SECTOR4_END_ADDR));
    assign is_sector5_addr = (use_sector_addr) ? (address == 5) : ((address >= SECTOR5_START_ADDR) && (address <= SECTOR5_END_ADDR));
    assign is_sector1_writable = ~(write_protection_mode[0] || SECTOR_READ_PROTECTION_MODE[0]);
    assign is_sector2_writable = ~(write_protection_mode[1] || SECTOR_READ_PROTECTION_MODE[1]);
    assign is_sector3_writable = ~(write_protection_mode[2] || SECTOR_READ_PROTECTION_MODE[2]);
    assign is_sector4_writable = ~(write_protection_mode[3] || SECTOR_READ_PROTECTION_MODE[3]);
    assign is_sector5_writable = ~(write_protection_mode[4] || SECTOR_READ_PROTECTION_MODE[4]);
    assign is_addr_writable = ((is_sector1_writable && is_sector1_addr) ||
                               (is_sector2_writable && is_sector2_addr) ||
                               (is_sector3_writable && is_sector3_addr) ||
                               (is_sector4_writable && is_sector4_addr) ||
                               (is_sector5_writable && is_sector5_addr));

endmodule

module altera_onchip_flash_s_address_write_protection_check (
    address,
    is_sector1_writable,
    is_sector2_writable,
    is_sector3_writable,
    is_sector4_writable,
    is_sector5_writable,
    is_addr_writable
);

    input [2:0] address;
    input is_sector1_writable;
    input is_sector2_writable;
    input is_sector3_writable;
    input is_sector4_writable;
    input is_sector5_writable;
    output is_addr_writable;

    wire is_sector1_addr;
    wire is_sector2_addr;
    wire is_sector3_addr;
    wire is_sector4_addr;
    wire is_sector5_addr;

    assign is_sector1_addr = (address == 1);
    assign is_sector2_addr = (address == 2);
    assign is_sector3_addr = (address == 3);
    assign is_sector4_addr = (address == 4);
    assign is_sector5_addr = (address == 5);

    assign is_addr_writable = ((is_sector1_writable && is_sector1_addr) ||
                               (is_sector2_writable && is_sector2_addr) ||
                               (is_sector3_writable && is_sector3_addr) ||
                               (is_sector4_writable && is_sector4_addr) ||
                               (is_sector5_writable && is_sector5_addr));

endmodule

module altera_onchip_flash_a_address_write_protection_check (
    address,
    is_sector1_writable,
    is_sector2_writable,
    is_sector3_writable,
    is_sector4_writable,
    is_sector5_writable,
    is_addr_writable
);

    parameter FLASH_ADDR_WIDTH = 23;
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

    input [FLASH_ADDR_WIDTH-1:0] address;
    input is_sector1_writable;
    input is_sector2_writable;
    input is_sector3_writable;
    input is_sector4_writable;
    input is_sector5_writable;
    output is_addr_writable;

    wire is_sector1_addr;
    wire is_sector2_addr;
    wire is_sector3_addr;
    wire is_sector4_addr;
    wire is_sector5_addr;

    assign is_sector1_addr = ((address >= SECTOR1_START_ADDR) && (address <= SECTOR1_END_ADDR));
    assign is_sector2_addr = ((address >= SECTOR2_START_ADDR) && (address <= SECTOR2_END_ADDR));
    assign is_sector3_addr = ((address >= SECTOR3_START_ADDR) && (address <= SECTOR3_END_ADDR));
    assign is_sector4_addr = ((address >= SECTOR4_START_ADDR) && (address <= SECTOR4_END_ADDR));
    assign is_sector5_addr = ((address >= SECTOR5_START_ADDR) && (address <= SECTOR5_END_ADDR));

    assign is_addr_writable = ((is_sector1_writable && is_sector1_addr) ||
                               (is_sector2_writable && is_sector2_addr) ||
                               (is_sector3_writable && is_sector3_addr) ||
                               (is_sector4_writable && is_sector4_addr) ||
                               (is_sector5_writable && is_sector5_addr));

endmodule

module altera_onchip_flash_convert_address (
    address,
    flash_addr
);

    parameter FLASH_ADDR_WIDTH = 23;
    parameter ADDR_RANGE1_END_ADDR = 1;
    parameter ADDR_RANGE1_OFFSET = 1;
    parameter ADDR_RANGE2_OFFSET = 1;

    input [FLASH_ADDR_WIDTH-1:0] address;
    output [FLASH_ADDR_WIDTH-1:0] flash_addr;

    assign flash_addr = (address <= ADDR_RANGE1_END_ADDR[FLASH_ADDR_WIDTH-1:0]) ? 
        (address + ADDR_RANGE1_OFFSET[FLASH_ADDR_WIDTH-1:0]) : 
        (address + ADDR_RANGE2_OFFSET[FLASH_ADDR_WIDTH-1:0]);
    
endmodule


module altera_onchip_flash_convert_sector (
    sector,
    flash_sector
);

    parameter SECTOR1_MAP = 1;
    parameter SECTOR2_MAP = 1;
    parameter SECTOR3_MAP = 1;
    parameter SECTOR4_MAP = 1;
    parameter SECTOR5_MAP = 1;

    input [2:0] sector;
    output [2:0] flash_sector;

    assign flash_sector = 
        (sector == 1) ? SECTOR1_MAP[2:0] :
        (sector == 2) ? SECTOR2_MAP[2:0] :
        (sector == 3) ? SECTOR3_MAP[2:0] :
        (sector == 4) ? SECTOR4_MAP[2:0] :
        (sector == 5) ? SECTOR5_MAP[2:0] :
        3'd0; // Set to 0 for invalid sector ID

endmodule


module altera_onchip_flash_counter (
    clock,
    reset,
    count
);
    input clock;
    input reset;
    output [4:0] count;
    
    reg [4:0] count_reg;
    
    assign count = count_reg;

    initial begin
        count_reg = 0;
    end
    
    always @ (posedge reset or posedge clock) begin
        if (reset) begin
            count_reg <= 0;
        end
        else begin
            count_reg <= count_reg + 5'd1;
        end
    end

endmodule
