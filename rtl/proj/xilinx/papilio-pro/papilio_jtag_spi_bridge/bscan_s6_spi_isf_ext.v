module top
  (
   inout wire LED1,
   output wire MOSI,
   output wire CSB,
   output wire DRCK1,
   input  MISO
   );
   
   wire   CAPTURE;
   wire   UPDATE;
   wire   TDI;
   wire   TDO1;
   reg [47:0] header;
   reg [15:0]  len;
   reg 	       have_header = 0;
   assign      MOSI = TDI ;
   wire        SEL1;
   wire        SHIFT;
   wire        RESET;
   reg 	       CS_GO = 0;
   reg 	       CS_GO_PREP = 0;
   reg 	       CS_STOP = 0;
   reg 	       CS_STOP_PREP = 0;
   reg [13:0] RAM_RADDR;
   reg [13:0] RAM_WADDR;
   wire        DRCK1_INV = !DRCK1;
   wire        RAM_DO;
   wire        RAM_DI;
   reg 	       RAM_WE = 0;
   reg [15:0]   counter = 0;
   
   RAMB16_S1_S1 RAMB16_S1_S1_inst
     (
      .DOA(RAM_DO),
      .DOB(),
      .ADDRA(RAM_RADDR),
      .ADDRB(RAM_WADDR),
      .CLKA(DRCK1_INV),
      .CLKB(DRCK1),
      .DIA(1'b0),
      .DIB(RAM_DI),
      .ENA(1'b1),
      .ENB(1'b1),
      .SSRA(1'b0),
      .SSRB(1'b0),
      .WEA(1'b0),
      .WEB(RAM_WE)
      );
   
   BSCAN_SPARTAN6 BSCAN_SPARTAN6_inst
     (
      .CAPTURE(CAPTURE),
      .DRCK(DRCK1),
      .RESET(RESET),
      .RUNTEST(),
      .SEL(SEL1),
      .SHIFT(SHIFT),
      .TCK(),
      .TDI(TDI),
      .TMS(),
      .UPDATE(UPDATE),
      .TDO(TDO1)
      );

   assign      CSB = !(CS_GO && !CS_STOP);
      
   assign      RAM_DI = MISO;
   assign      TDO1 = RAM_DO;

   wire        rst = CAPTURE || RESET || UPDATE || !SEL1;
   
   assign LED1=counter[15];
   always @(posedge DRCK1)
     if(!CSB)
       counter <= counter + 1;
   
   always @(negedge DRCK1 or posedge rst)
     if (rst)
       begin
	  have_header <= 0;
	  CS_GO_PREP <= 0;
	  CS_STOP <= 0;
       end
     else
       begin
	  CS_STOP <= CS_STOP_PREP;
	  if (!have_header)
	    begin
	       if (header[46:15] == 32'h59a659a6)
		 begin
		    len <= {header [14:0],1'b0};
		    have_header <= 1;
		    if ({header [14:0],1'b0} != 0)
		      begin
			 CS_GO_PREP <= 1;
		      end
		 end
	    end
	  else if (len != 0)
	    begin
	       len <= len -1;
	    end // if (!have_header)
       end // else: !if(CAPTRE || RESET || UPDATE || !SEL1)

   always @(posedge DRCK1 or posedge rst)
     if (rst)
       begin
	  CS_GO <= 0;
	  CS_STOP_PREP <= 0;
	  RAM_WADDR <= 0;
	  RAM_RADDR <=0;
	  RAM_WE <= 0;
       end
     else
       begin
	  RAM_RADDR <= RAM_RADDR + 1;
	  RAM_WE <= !CSB;
	  if(RAM_WE)
	    RAM_WADDR <= RAM_WADDR + 1;
	  header <= {header[46:0], TDI};
	  CS_GO <= CS_GO_PREP;
	  if (CS_GO && (len == 0))
	    CS_STOP_PREP <= 1;
       end // else: !if(CAPTURE || RESET || UPDATE || !SEL1)
endmodule

/* ucf file for scarab hardware xc6s ftg256
# see ug385.pdf p.279
net "MISO"  LOC = "P10" | IOSTANDARD = LVCMOS33 | PULLUP; # [N] DIN
net "MOSI"  LOC = "T10" | IOSTANDARD = LVCMOS33; # [B] CSI
net "CSB"   LOC = "T3"  | IOSTANDARD = LVCMOS33; # [b] CSO
net "DRCK1" LOC = "R11" | IOSTANDARD = LVCMOS33; # [C] CCLK

NET "LEDS<0>" LOC="P11" | IOSTANDARD = LVCMOS33;
NET "LEDS<1>" LOC="N9"  | IOSTANDARD = LVCMOS33;
NET "LEDS<2>" LOC="M9"  | IOSTANDARD = LVCMOS33;
NET "LEDS<3>" LOC="P9"  | IOSTANDARD = LVCMOS33;
NET "LEDS<4>" LOC="T8"  | IOSTANDARD = LVCMOS33;
NET "LEDS<5>" LOC="N8"  | IOSTANDARD = LVCMOS33;
NET "LEDS<6>" LOC="P8"  | IOSTANDARD = LVCMOS33;
NET "LEDS<7>" LOC="P7"  | IOSTANDARD = LVCMOS33;
*/
