----------------------------------------------------------------------------------
-- Engineer: <mfield@concepts.co.nz
-- 
-- Description: Send register writes over an I2C-like interface
--
-- Changed to adv7513 init by emu.(AN-1720)
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_sender is
    Port ( clk    : in    STD_LOGIC;    
           resend : in    STD_LOGIC;
           sioc   : out   STD_LOGIC;
           siod   : inout STD_LOGIC
    );
end i2c_sender;

architecture Behavioral of i2c_sender is
   signal   divider           : unsigned(7 downto 0)  := (others => '0'); 
    -- this value gives nearly 200ms cycles before the first register is written
   signal   initial_pause     : unsigned(22 downto 0) := (others => '0');
   signal   finished          : std_logic := '0';
   signal   address           : std_logic_vector(7 downto 0)  := (others => '0');
   signal   clk_first_quarter : std_logic_vector(28 downto 0) := (others => '1');
   signal   clk_last_quarter  : std_logic_vector(28 downto 0) := (others => '1');
   signal   busy_sr           : std_logic_vector(28 downto 0) := (others => '1');
   signal   data_sr           : std_logic_vector(28 downto 0) := (others => '1');
   signal   tristate_sr       : std_logic_vector(28 downto 0) := (others => '0');
   signal   reg_value         : std_logic_vector(15 downto 0)  := (others => '0');
   constant i2c_wr_addr       : std_logic_vector(7 downto 0)  := x"72";
   type T_writereg is
   record
     reg, val: std_logic_vector(7 downto 0);
   end record;
   type T_init_sequence is array(0 to 25) of T_writereg;
   constant C_init_sequence: T_init_sequence :=
   (
     --(reg => x"01", val => x"00"), --  0 Set N Value(6144)
     --(reg => x"02", val => x"18"), --  1 Set N Value(6144)
     --(reg => x"03", val => x"00"), --  2 Set N Value(6144)
     (reg => x"01", val => x"00"), --  0 Set N Value(0) default
     (reg => x"02", val => x"00"), --  1 Set N Value(0) default
     (reg => x"03", val => x"00"), --  2 Set N Value(0) default
     (reg => x"15", val => x"00"), --  3 Input 444 (RGB or YCrCb) with Separate Syncs
     --(reg => x"16", val => x"61"), --  4 44.1kHz fs, YPrPb 444
     (reg => x"16", val => x"00"), --  4 0 default
     (reg => x"18", val => x"46"), --  5 CSC disabled
     --(reg => x"40", val => x"80"), --  6 General Control Packet Enable
     (reg => x"40", val => x"00"), --  6 0 default
     (reg => x"41", val => x"10"), --  7 Power Down control
     --(reg => x"48", val => x"48"), --  8 Reverse bus, Data right justified
     --(reg => x"48", val => x"a8"), --  9 Set Dither Mode 12 to 10 bit
     (reg => x"48", val => x"00"), --  9 0 default
     --(reg => x"4c", val => x"06"), -- 10 12-bit Output
     (reg => x"4c", val => x"00"), -- 10 0 default
     (reg => x"55", val => x"00"), -- 11 0 default
     --(reg => x"55", val => x"08"), -- 12 Set active format Aspect
     --(reg => x"96", val => x"20"), -- 13 HPD Interrupt clear
     (reg => x"96", val => x"00"), -- 13 0 default
     (reg => x"98", val => x"03"), -- 14 ADI required Write
     (reg => x"98", val => x"02"), -- 15 ADI required Write
     (reg => x"9c", val => x"30"), -- 16 ADI required Write
     --(reg => x"9d", val => x"61"), -- 17 Set clock divide
     (reg => x"9d", val => x"00"), -- 17 0 default
     (reg => x"a2", val => x"a4"), -- 18 ADI required Write
     (reg => x"43", val => x"a4"), -- 19 ADI required Write
     --(reg => x"af", val => x"16"), -- 20 Set HDMI Mode
     (reg => x"af", val => x"00"), -- 20 0 default
     (reg => x"ba", val => x"60"), -- 21 No clock delay
     (reg => x"de", val => x"9c"), -- 22 ADI required write
     (reg => x"e4", val => x"60"), -- 23 ADI required Write
     (reg => x"fa", val => x"7d"), -- 24 Nbr of times to search for good phase
     others => (reg => x"ff", val => x"ff")  -- 25 FFFF end of sequence
   );
begin

registers: process(clk)
   begin
      if rising_edge(clk) then
        reg_value <= C_init_sequence(to_integer(unsigned(address))).reg
                   & C_init_sequence(to_integer(unsigned(address))).val;
      end if;
   end process;
   
i2c_tristate: process(data_sr, tristate_sr)
   begin
      if tristate_sr(tristate_sr'length-1) = '0' then
         siod <= data_sr(data_sr'length-1);
      else
         siod <= 'Z';
      end if;
   end process;
   
   with divider(divider'length-1 downto divider'length-2) 
      select sioc <= clk_first_quarter(clk_first_quarter'length -1) when "00",
                     clk_last_quarter(clk_last_quarter'length -1)   when "11",
                     '1' when others;
                     
i2c_send:   process(clk)
   begin
      if rising_edge(clk) then
         if resend = '1' and finished = '1' then 
         -- if resend = '1' then 
            address           <= (others => '0');
            clk_first_quarter <= (others => '1');
            clk_last_quarter  <= (others => '1');
            busy_sr           <= (others => '0');
            divider           <= (others => '0');
            initial_pause     <= (others => '0');
            finished <= '0';
         end if;

         if busy_sr(busy_sr'length-1) = '0' then
            if initial_pause(initial_pause'length-1) = '0' then
               initial_pause <= initial_pause+1;
            elsif finished = '0' then
               if divider = "11111111" then
                  divider <= (others =>'0');
                  if reg_value(15 downto 8) = "11111111" then
                     finished <= '1';
                  else
                     -- move the new data into the shift registers
                     clk_first_quarter <= (others => '0'); clk_first_quarter(clk_first_quarter'length-1) <= '1';
                     clk_last_quarter <= (others => '0');  clk_last_quarter(0) <= '1';
                     
                     --             Start    Address        Ack        Register           Ack          Value         Ack    Stop
                     tristate_sr <= "0" & "00000000"  & "1" & "00000000"             & "1" & "00000000"             & "1"  & "0";
                     data_sr     <= "0" & i2c_wr_addr & "1" & reg_value(15 downto 8) & "1" & reg_value( 7 downto 0) & "1"  & "0";
                     busy_sr     <= (others => '1');
                     address     <= std_logic_vector(unsigned(address)+1);
                  end if;
               else
                  divider <= divider+1; 
               end if;
            end if;
         else
            if divider = "11111111" then   -- divide clkin by 255 for I2C
               tristate_sr       <= tristate_sr(tristate_sr'length-2 downto 0) & '0';
               busy_sr           <= busy_sr(busy_sr'length-2 downto 0) & '0';
               data_sr           <= data_sr(data_sr'length-2 downto 0) & '1';
               clk_first_quarter <= clk_first_quarter(clk_first_quarter'length-2 downto 0) & '1';
               clk_last_quarter  <= clk_last_quarter(clk_first_quarter'length-2 downto 0) & '1';
               divider           <= (others => '0');
            else
               divider <= divider+1;
            end if;
         end if;
      end if;
   end process;
end Behavioral;
