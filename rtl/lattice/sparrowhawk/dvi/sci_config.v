// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2009 ~ 2013 by Lattice Semiconductor Corporation
// --------------------------------------------------------------------
//
// Permission:
//
//   Lattice Semiconductor grants permission to use this code for use
//   in synthesis for any Lattice programmable logic product.  Other
//   use of this code, including the selling or duplication of any
//   portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL or Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//
// --------------------------------------------------------------------
//
//                     Lattice Semiconductor Corporation
//                     5555 NE Moore Court
//                     Hillsboro, OR 97214
//                     U.S.A
//
//                     TEL: 1-800-Lattice (USA and Canada)
//                          503-268-8001 (other locations)
//
//                     web: http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
//
// --------------------------------------------------------------------
//
//  Project:           HDMI Encoder and Decoder
//  File:              sci_config.v
//  Title:             sci_config
//  Description:       adaptively update SERDES configuration according
//                     to HDMI input pixel frequency 
//
// --------------------------------------------------------------------
//
// Revision History :
// --------------------------------------------------------------------
// $Log: RD#rd1097_hdmi_dvi_interface#rd1097#source#verilog#sci_config.v,v $
// Revision 1.2  2015-04-15 00:07:10-07  sgomkale
// ...No comments entered during checkin...
//
// Revision 1.0  2013-02-22  kile
//
//---------------------------------------------------------------------

module sci_config (

      input  wire        rstn,            // reset, low-actived
      input  wire        pix_clk,         // pixel clock from HDMI input
      input  wire        osc_clk,         // oscillator clock, default 100MHz
      
      input  wire        force_tx_en,     // force SERDES_tx to one dedicated mode when data source is not from SERDES_rx
      input  wire        sel_low_res,     // select force mode: 1-> low resolution output
      
      output  reg        sci_active,      // SCI in writing precess
      output  reg        sci_wren,        // SCI write enable
      output  reg  [8:0] sci_addr,        // SCI write address
      output  reg  [7:0] sci_data         // SCI write data
      
      );

//--------------------------------------------------------------------
// -- parameter
//--------------------------------------------------------------------

parameter PIXEL_NUMBER_FOR_COUNTER = 8'd90; 

parameter IDLE           = 2'd0,
          CHANNEL_CONFIG = 2'd1,
          QUAD_CONFIG    = 2'd2,
          WAIT_PERIOD    = 2'd3;

//--------------------------------------------------------------------
// -- internal signals
//--------------------------------------------------------------------

reg     [7:0] osc_cnt;
reg           cnt_en_sync;

reg           cnt_en;
reg     [7:0] pix_cnt;
reg           low_res_det;  // low resolution detected

reg     [1:0] cur_state;

reg     [3:0] wr_cnt;       // for SCI writing timing
reg     [5:0] wait_cnt;     // for SCI waiting period
  
//--------------------------------------------------------------------
// --
// -- calculate pixel frequency using osc_clk
// --
// --       counting active only during "PIXEL_NUMBER_FOR_COUNTER" 
// --       pixel cycles
//--------------------------------------------------------------------
      
always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      osc_cnt <= 8'd0;
   else if ( cnt_en_sync )
      osc_cnt <= osc_cnt[7] ? osc_cnt : ( osc_cnt + 8'd1 );
   else
      osc_cnt <= 8'd0;

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      cnt_en_sync <= 1'b0;
   else
      cnt_en_sync <= cnt_en;

always @ ( posedge pix_clk or negedge rstn )
   if ( !rstn )
      cnt_en <= 1'b0;
   // start counting with stable pixel clock
   else if ( pix_cnt == 8'd128 )
      cnt_en <= 1'b1;
   // finish counting after "PIXEL_NUMBER_FOR_COUNTER" pixel cycles
   else if ( pix_cnt == 8'd128 + PIXEL_NUMBER_FOR_COUNTER )
      cnt_en <= 1'b0;

always @ ( posedge pix_clk or negedge rstn )
   if ( !rstn )
      pix_cnt <= 8'd0;
   else if ( pix_cnt == 8'd128 + PIXEL_NUMBER_FOR_COUNTER + 1 )
      //pix_cnt <= pix_cnt;
      pix_cnt <= 0;
   else
      pix_cnt <= pix_cnt + 7'd1;

//--------------------------------------------------------------------
// -- detect low resolution => pixel frequency < 70MHz
//--------------------------------------------------------------------

// for 128 clock cycles with 100MHz osc_clk input, 
// it is about 90 clock cycles for 70MHz pixel clock

always @ ( posedge pix_clk or negedge rstn )
   if ( !rstn )
      low_res_det <= 1'b0;
   else if ( pix_cnt == 8'd128 + PIXEL_NUMBER_FOR_COUNTER )
      low_res_det <= osc_cnt[7];

//--------------------------------------------------------------------
// -- state machine
//--------------------------------------------------------------------

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      cur_state <= IDLE;
   else begin
      case ( cur_state )
      
         IDLE : begin
            if ( pix_cnt == 8'd128 + PIXEL_NUMBER_FOR_COUNTER )
               cur_state <= CHANNEL_CONFIG;
         end
         
         // SERDES channel configuration
         CHANNEL_CONFIG : begin
            if ( wr_cnt == 4'd15 )
               cur_state <= QUAD_CONFIG;
         end
         
         // SERDES quad configuration
         QUAD_CONFIG : begin
            if ( wr_cnt == 4'd3 )
               cur_state <= WAIT_PERIOD;
         end
         
         WAIT_PERIOD : begin
            //cur_state <= WAIT_PERIOD;
            if ( wait_cnt == 6'd63 )
               cur_state <= IDLE;
         end
         
         default :
            cur_state <= IDLE;
            
      endcase
   end

//--------------------------------------------------------------------
// -- writing counter
//--------------------------------------------------------------------

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      wr_cnt <= 4'd0;
   else if ( cur_state == CHANNEL_CONFIG )
      wr_cnt <= ( wr_cnt == 4'd15 ) ? 4'd0 : ( wr_cnt + 1 );
   else if ( cur_state == QUAD_CONFIG )
      wr_cnt <= ( wr_cnt == 4'd3 ) ? 4'd0 : ( wr_cnt + 1 );
   else
      wr_cnt <= 4'd0;

//--------------------------------------------------------------------
// -- waiting counter
//--------------------------------------------------------------------

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      wait_cnt <= 6'd0;
   else if ( cur_state == WAIT_PERIOD )
      wait_cnt <= wait_cnt + 1;
   else
      wait_cnt <= 6'd0;

//--------------------------------------------------------------------
// -- SCI output
//--------------------------------------------------------------------

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      sci_active <= 0;
   else
      sci_active <= ( cur_state == CHANNEL_CONFIG ) || ( cur_state == QUAD_CONFIG );

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      sci_wren <= 0;
   else if ( wr_cnt[1:0] == 2'd2 )
      sci_wren <= 1;
   else
      sci_wren <= 0;

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      sci_addr <= 9'd0;
   else if ( wr_cnt[1:0] == 2'd1 ) begin
      // register address of CH_10 : 'h410/'h450/'h490/'h4D0
      if ( cur_state == CHANNEL_CONFIG )
         sci_addr <= { 1'b0, wr_cnt[3:2], 6'b010000 };
      // register address of QD_0D : 'h50D
      else if ( cur_state == QUAD_CONFIG )
         sci_addr <= 9'b1_0000_1101;
   end

always @ ( posedge osc_clk or negedge rstn )
   if ( !rstn )
      sci_data <= 8'h00;
   // CH_10
   else if ( cur_state == CHANNEL_CONFIG ) begin
      if ( low_res_det )
         sci_data <= 8'hCE;
      else
         sci_data <= 8'hCA;
   end
   // QD_0D      
   else if ( cur_state == QUAD_CONFIG ) begin
      if ( ( force_tx_en && sel_low_res ) || ( !force_tx_en && low_res_det ) )
         sci_data <= 8'h05;
      else
         sci_data <= 8'h02;
   end

endmodule
