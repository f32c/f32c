--
-- XC3SPROG ISF File for Trenz Electronic TE0741 Kintex module
-- Author: Antti Lukats
-- converted from V5 version
--
-- Green user LED will be steady ON
-- Red user LED will be ON during SPI Chip select activation
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity bscan_ffm_a7100 is port (
		RLED	 : out std_logic;
		GLED	 : out std_logic;
		
		MOSI_ext : out std_logic;
		MISO_ext : in std_logic;
		
		IO2		 : inout std_logic; -- WP
		IO3		 : inout std_logic; -- HOLD/RESET
		
		CSB_ext	 : out std_logic
	);
end;

architecture Behavioral of bscan_ffm_a7100 is
	signal CAPTURE: std_logic;
	signal UPDATE: std_logic;
	signal DRCK1: std_logic;
	signal TDI: std_logic;
	signal TDO1: std_logic;
	signal CSB: std_logic := '1';
	signal header: std_logic_vector(47 downto 0);
	signal len: std_logic_vector(15 downto 0);
	signal have_header : std_logic := '0';
	signal MISO: std_logic;
	signal MOSI: std_logic;
	signal SEL1: std_logic;
	signal SHIFT: std_logic;
	signal RESET: std_logic;
	signal CS_GO: std_logic := '0';
	signal CS_GO_PREP: std_logic := '0';
	signal CS_STOP: std_logic := '0';
	signal CS_STOP_PREP: std_logic := '0';
	signal RAM_RADDR: std_logic_vector(13 downto 0);
	signal RAM_WADDR: std_logic_vector(13 downto 0);
	signal DRCK1_INV : std_logic;
	signal RAM_DO: std_logic_vector(0 downto 0);
	signal RAM_DI: std_logic_vector(0 downto 0);
	signal RAM_WE: std_logic := '0';
begin

	IO2 <= '1';
	IO3 <= '1';
	
	RLED <= not CSB;
	GLED <= '1';

    MISO        <= MISO_ext;
	MOSI_ext	<= MOSI;
	CSB_ext		<= CSB;

	DRCK1_INV <= not DRCK1;

   RAMB16_S1_S1_inst : RAMB16_S1_S1
   port map (
	   DOA => RAM_DO,      -- Port A 1-bit Data Output
      DOB => open,      -- Port B 1-bit Data Output
      ADDRA => RAM_RADDR,  -- Port A 14-bit Address Input
      ADDRB => RAM_WADDR,  -- Port B 14-bit Address Input
      CLKA => DRCK1_inv,    -- Port A Clock
      CLKB => DRCK1,    -- Port B Clock
      DIA => "0",      -- Port A 1-bit Data Input
      DIB => RAM_DI,      -- Port B 1-bit Data Input
      ENA => '1',      -- Port A RAM Enable Input
      ENB => '1',      -- PortB RAM Enable Input
      SSRA => '0',    -- Port A Synchronous Set/Reset Input
      SSRB => '0',    -- Port B Synchronous Set/Reset Input
      WEA => '0',      -- Port A Write Enable Input
      WEB => RAM_WE       -- Port B Write Enable Input
   );

   BSCANE2_inst : BSCANE2
   generic map (
      JTAG_CHAIN => 1  -- Value for USER command.
   )
   port map (
      CAPTURE => CAPTURE, -- 1-bit output: CAPTURE output from TAP controller.
      DRCK    => DRCK1,   -- 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or
                          -- SHIFT are asserted.

      RESET   => RESET,   -- 1-bit output: Reset output for TAP controller.
      RUNTEST => open,    -- 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
      SEL     => SEL1,    -- 1-bit output: USER instruction active output.
      SHIFT   => SHIFT,   -- 1-bit output: SHIFT output from TAP controller.
      TCK     => open,    -- 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
      TDI     => TDI,     -- 1-bit output: Test Data Input (TDI) output from TAP controller.
      TMS     => open,    -- 1-bit output: Test Mode Select output. Fabric connection to TAP.
      UPDATE  => UPDATE,  -- 1-bit output: UPDATE output from TAP controller
      TDO     => TDO1     -- 1-bit input: Test Data Output (TDO) input for USER function.
   );

   STARTUPE2_inst : STARTUPE2
   generic map (
      PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
      SIM_CCLK_FREQ => 0.0  -- Set the Configuration Clock Frequency(ns) for simulation.
   )
   port map (
      CFGCLK => open,         -- 1-bit output: Configuration main clock output
      CFGMCLK => open,        -- 1-bit output: Configuration internal oscillator clock output
      EOS => open,            -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ => open,           -- 1-bit output: PROGRAM request to fabric output
      CLK => '0',             -- 1-bit input: User start-up clock input
      GSR => '0',             -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS => '0',             -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0' ,      -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK => '1',            -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO => DRCK1,      -- 1-bit input: User CCLK input
      USRCCLKTS => '0',       -- 1-bit input: User CCLK 3-state enable input
      USRDONEO => '1',        -- 1-bit input: User DONE pin output control
      USRDONETS => '1'       -- 1-bit input: User DONE 3-state enable output
   );



	MOSI <= TDI;
	
	CSB <= '0' when CS_GO = '1' and CS_STOP = '0' else '1';

	RAM_DI <= MISO & "";

	TDO1 <= RAM_DO(0);

	-- falling edges
	process(DRCK1, CAPTURE, RESET, UPDATE, SEL1)
	begin
	
		if CAPTURE = '1' or RESET='1' or UPDATE='1' or SEL1='0' then
		
			have_header <= '0';
			
			-- disable CSB
			CS_GO_PREP <= '0';
			CS_STOP <= '0';
									
		elsif falling_edge(DRCK1) then
					
			-- disable CSB?
			CS_STOP <= CS_STOP_PREP;
			
			-- waiting for header?
			if have_header='0' then
				
				-- got magic + len
				if header(46 downto 15) = x"59a659a6" then
					len <= header(14 downto 0) & "0";
					have_header <= '1';
										
					-- enable CSB on rising edge (if len > 0?)
					if (header(14 downto 0) & "0") /= x"0000" then
						CS_GO_PREP <= '1';
					end if;
					
				end if;

			elsif len /= x"0000" then
				len <= len - 1;
			
			end if;
			
		end if;
		
	end process;
	
	-- rising edges
	process(DRCK1, CAPTURE, RESET, UPDATE, SEL1)
	begin
	
		if CAPTURE = '1' or RESET='1' or UPDATE='1' or SEL1='0' then
	
			-- disable CSB
			CS_GO <= '0';
			CS_STOP_PREP <= '0';
			
			RAM_WADDR <= (others => '0');
			RAM_RADDR <= (others => '0');
			RAM_WE <= '0';
				
		elsif rising_edge(DRCK1) then
					
			RAM_RADDR <= RAM_RADDR + 1;
			
			RAM_WE <= not CSB;
			
			if RAM_WE='1' then
				RAM_WADDR <= RAM_WADDR + 1;
			end if;
			
			header <= header(46 downto 0) & TDI;
			
			-- enable CSB?
			CS_GO <= CS_GO_PREP;
			
			-- disable CSB on falling edge
			if CS_GO = '1' and len = x"0000" then
				CS_STOP_PREP <= '1';
			end if;
			
		end if;
	
	end process;
	
end Behavioral;