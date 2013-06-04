
library IEEE;
use IEEE.std_logic_1164.all;
library xp2;
use xp2.components.all;


entity bram_sp_x36 is
    port (
	clk: in std_logic; 
	ce: in std_logic;
	we: in std_logic; 
	res: in std_logic; 
	addr: in std_logic_vector(8 downto 0); 
	data_in: in std_logic_vector(35 downto 0); 
	data_out: out std_logic_vector(35 downto 0)
    );
end bram_sp_x36;

architecture Structure of bram_sp_x36 is
begin
    bram_16_0: DP16KB
	generic map (
	    -- CSDECODE_A => "000", CSDECODE_B => "000",
	    WRITEMODE_A => "WRITETHROUGH", WRITEMODE_B => "WRITETHROUGH",
	    GSR => "DISABLED", RESETMODE => "SYNC", 
	    REGMODE_A => "NOREG", REGMODE_B => "NOREG",
	    DATA_WIDTH_A => 18, DATA_WIDTH_B => 18
	)
	port map (
	    DIA0 => data_in(0), DIA1 => data_in(1),
	    DIA2 => data_in(2), DIA3 => data_in(3),
	    DIA4 => data_in(4), DIA5 => data_in(5),
	    DIA6 => data_in(6), DIA7 => data_in(7),
	    DIA8 => data_in(8), DIA9 => data_in(9),
	    DIA10 => data_in(10), DIA11 => data_in(11),
	    DIA12 => data_in(12), DIA13 => data_in(13),
	    DIA14 => data_in(14), DIA15 => data_in(15),
	    DIA16 => data_in(16), DIA17 => data_in(17),
	    DIB0 => data_in(18), DIB1 => data_in(19),
	    DIB2 => data_in(20), DIB3 => data_in(21),
	    DIB4 => data_in(22), DIB5 => data_in(23),
	    DIB6 => data_in(24), DIB7 => data_in(25),
	    DIB8 => data_in(26), DIB9 => data_in(27),
	    DIB10 => data_in(28), DIB11 => data_in(29),
	    DIB12 => data_in(30), DIB13 => data_in(31),
	    DIB14 => data_in(32), DIB15 => data_in(33),
	    DIB16 => data_in(34), DIB17 => data_in(35),

	    DOA0 => data_out(0), DOA1 => data_out(1), 
	    DOA2 => data_out(2), DOA3 => data_out(3), 
	    DOA4 => data_out(4), DOA5 => data_out(5), 
	    DOA6 => data_out(6), DOA7 => data_out(7), 
	    DOA8 => data_out(8), DOA9 => data_out(9), 
	    DOA10 => data_out(10), DOA11 => data_out(11), 
	    DOA12 => data_out(12), DOA13 => data_out(13), 
	    DOA14 => data_out(14), DOA15 => data_out(15), 
	    DOA16 => data_out(16), DOA17 => data_out(17), 
	    DOB0 => data_out(18), DOB1 => data_out(19), 
	    DOB2 => data_out(20), DOB3 => data_out(21), 
	    DOB4 => data_out(22), DOB5 => data_out(23), 
	    DOB6 => data_out(24), DOB7 => data_out(25), 
	    DOB8 => data_out(26), DOB9 => data_out(27), 
	    DOB10 => data_out(28), DOB11 => data_out(29), 
	    DOB12 => data_out(30), DOB13 => data_out(31), 
	    DOB14 => data_out(32), DOB15 => data_out(33), 
	    DOB16 => data_out(34), DOB17 => data_out(35), 

	    ADA0 => '1', ADA1 => '1', ADA2 => '0', ADA3 => '0',
	    ADA4 => addr(0), ADA5 => addr(1),
	    ADA6 => addr(2), ADA7 => addr(3),
	    ADA8 => addr(4), ADA9 => addr(5),
	    ADA10 => addr(6), ADA11 => addr(7),
	    ADA12 => addr(8), ADA13 => '0', 
	    ADB0 => '1', ADB1 => '1', ADB2 => '0', ADB3 => '0',
	    ADB4 => addr(0), ADB5 => addr(1),
	    ADB6 => addr(2), ADB7 => addr(3),
	    ADB8 => addr(4), ADB9 => addr(5),
	    ADB10 => addr(6), ADB11 => addr(7),
	    ADB12 => addr(8), ADB13 => '1', 

	    CEA => ce, CLKA => clk, WEA => we, RSTA => res, 
	    CSA0 => '0', CSA1 => '0', CSA2 => '0',
	    CEB => ce, CLKB => clk, WEB => we, RSTB => res, 
	    CSB0 => '0', CSB1 => '0', CSB2 => '0'
	);
end Structure;
