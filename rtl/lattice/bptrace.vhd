
library IEEE;
use IEEE.std_logic_1164.all;

library xp2;
use xp2.components.all;

entity bptrace is
    port (
        DataInA: in std_logic_vector(1 downto 0); 
        DataInB: in std_logic_vector(1 downto 0); 
        AddressA: in std_logic_vector(12 downto 0); 
        AddressB: in std_logic_vector(12 downto 0); 
        ClockA: in std_logic; 
        ClockB: in std_logic; 
        ClockEnA: in std_logic; 
        ClockEnB: in std_logic; 
        WrA: in std_logic; 
        WrB: in std_logic; 
        ResetA: in std_logic; 
        ResetB: in std_logic; 
        QA: out std_logic_vector(1 downto 0); 
        QB: out std_logic_vector(1 downto 0));
end bptrace;

architecture Structure of bptrace is

begin

    bptrace_0_0_0: DP16KB
        generic map (
		-- CSDECODE_B => "000", CSDECODE_A=> "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 2, DATA_WIDTH_A => 2
	)
        port map (
		DIA0 => '0', DIA1 => DataInA(1), DIA2 => '0', DIA3 => '0',
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => DataInA(0), 
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15=> '0',
		DIA16 => '0', DIA17 => '0', 
		ADA0 => '0', ADA1 => AddressA(0), ADA2 => AddressA(1), ADA3=>AddressA(2),
		ADA4 => AddressA(3), ADA5 => AddressA(4), ADA6 => AddressA(5), ADA7 => AddressA(6),
		ADA8 => AddressA(7), ADA9 => AddressA(8), ADA10 => AddressA(9), ADA11 => AddressA(10), 
		ADA12 => AddressA(11), ADA13 => AddressA(12),
		CEA => ClockEnA, CLKA => ClockA, WEA => WrA,
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => ResetA,
		DIB0 => '0', DIB1 => DataInB(1), DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0',
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => DataInB(0),
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0',
		DIB16 => '0', DIB17 => '0',
		ADB0 => '0', ADB1 => AddressB(0), ADB2 => AddressB(1), ADB3 => AddressB(2), 
		ADB4 => AddressB(3), ADB5 => AddressB(4), ADB6 => AddressB(5), ADB7=>AddressB(6),
		ADB8 => AddressB(7), ADB9 => AddressB(8), ADB10 => AddressB(9), ADB11 => AddressB(10),
		ADB12 => AddressB(11), ADB13 => AddressB(12),
		CEB => ClockEnB, CLKB => ClockB, WEB => WrB, 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => ResetB,
		DOA0 => QA(0), DOA1 => QA(1), DOA2=> open, DOA3 => open,
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open, 
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open, 
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open, 
		DOA16 => open, DOA17 => open,
		DOB0 => QB(0), DOB1 => QB(1), DOB2 => open, DOB3 => open,
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open, 
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open, 
		DOB16 => open, DOB17 => open
	);

end Structure;
