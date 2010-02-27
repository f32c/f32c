--
-- Copyright 2008 University of Zagreb, Croatia.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity mult is
	generic(
		technology: string := "mult18x18"
	);
	port(
		reg1, reg2: in std_logic_vector(31 downto 0);
		op_major: in std_logic_vector(1 downto 0);
		funct: in std_logic_vector(5 downto 0);
		hilo_out: out std_logic_vector(63 downto 0);
		busy: out boolean;
		clk: in std_logic
	);
end mult;

architecture Behavioral of mult is
	signal hilo: std_logic_vector(63 downto 0);
	signal pending_op: std_logic;
	-- multiplication
	signal a, b: std_logic_vector(32 downto 0);
	signal ah, al, bh, bl, b_in_1, b_in_2: std_logic_vector(17 downto 0);
	signal p0, p1: std_logic_vector(35 downto 0);
	signal p0_t, p1_t: std_logic_vector(35 downto 0);
	signal tsum: std_logic_vector(33 downto 0);
	signal t1: std_logic_vector(63 downto 0);
	-- division
	signal divisor, div_sub: std_logic_vector(31 downto 0);
	signal remainder: std_logic_vector(63 downto 0);
	signal cyclecnt: std_logic_vector(5 downto 0);
	signal negate: boolean;
begin

	div_sub <= remainder(63 downto 32) - divisor;
	hilo_out <= hilo;
	
	process(clk)
	begin
		if rising_edge(clk) then
			busy <= cyclecnt /= "000000"; -- XXX revisit
			if op_major = "11" then -- mul/div/mthi/mtlo/mfhi/mflo in EX
				if funct(3) = '1' then -- mul or div in EX
					pending_op <= funct(1);
					if funct(1) = '1' then -- begin a new division sequence
						remainder <= x"0000000" & "000" & reg1 & '0';
						divisor <= reg2;
						if funct(0) = '1' then -- unsigned division
							negate <= false;
							cyclecnt <= "100000";
						else -- signed division
							if reg1(31) = reg2(31) then -- complement the result when done
								negate <= false;
							else
								negate <= true;
							end if;
							cyclecnt <= "100001";
						end if;
					else -- begin a new multiplication sequence
						cyclecnt <= "000011";
					end if;
				else -- mthi/mtlo/mfhi/mflo in EX
					-- XXX do nothing, but mthi/mtlo should be implemented here
				end if;
			elsif cyclecnt = "100001" then
				-- negate operands if necessary
				if divisor(31) = '1' then
					divisor <= 0 - divisor;
				end if;
				if remainder(32) = '1' then
					remainder(32 downto 1) <= 0 - remainder(32 downto 1);
				end if;
				cyclecnt <= cyclecnt - 1;
			elsif cyclecnt /= "000000" then -- continue processing current operation
				if div_sub(31) = '1' then
					remainder <= remainder(62 downto 0) & '0';
				else
					remainder <= div_sub(30 downto 0) & remainder(31 downto 0) & '1';
				end if;
				cyclecnt <= cyclecnt - 1;
			else -- cyclecnt = "000000": operation done, store result
				if negate then -- XXX not implemented yet!!!
					hilo <= '0' & remainder(63 downto 33) & remainder(31 downto 0);
				else
					hilo <= '0' & remainder(63 downto 33) & remainder(31 downto 0);
				end if;
			end if;
		end if;
	end process;
	

xxx_mult: if false generate begin
	-- Implementation inspired by "Using Embedded Multipliers in
	-- Spartan-3 FPGAa", Xilinx document XAPP467 v1.1

	a <= reg1(31) & reg1 when funct(0) = '0' else '0' & reg1;
	b <= reg2(31) & reg2 when funct(0) = '0' else '0' & reg2;	

	m18x18:
	if technology = "mult18x18" generate
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				if op_major = "11" then
					ah <= a(32) & a(32 downto 16);
					al <= "00" & a(15 downto 0);
					bh <= b(32) & b(32 downto 16);
					bl <= "00" & b(15 downto 0);
				else
					bh <= bl;
					bl <= bh;
				end if;
			end if;
		end process;
	
		mult0: MULT18X18
			port map (
				P => p0_t, -- 36-bit multiplier output
				A => ah, -- 18-bit multiplier input
				B => bl -- 18-bit multiplier input
			);
		
		mult1: MULT18X18
			port map (
				P => p1_t, -- 36-bit multiplier output
				A => al, -- 18-bit multiplier input
				B => bh -- 18-bit multiplier input
			);
		
		process(clk)
		begin
			if rising_edge(clk) then
				p0 <= p0_t;
				p1 <= p1_t;
			end if;
		end process;
	end generate; -- m18x18
	
	m18x18sio:
	if technology = "mult18x18sio" generate
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				if op_major = "11" then
					ah <= a(32) & a(32 downto 16);
					al <= "00" & a(15 downto 0);
					bh <= b(32) & b(32 downto 16);
					bl <= "00" & b(15 downto 0);
				else
					bh <= bl;
					bl <= bh;
				end if;
			end if;
		end process;
	
		MULT18X18SIO_inst0 : MULT18X18SIO
			generic map (
				AREG => 0, -- Enable the input registers on the A port (1=on, 0=off)
				BREG => 0, -- Enable the input registers on the B port (1=on, 0=off)
				B_INPUT => "DIRECT", -- B cascade input "DIRECT" or "CASCADE"
				PREG => 1) -- Enable the input registers on the P port (1=on, 0=off)
			port map (
				BCOUT => open, -- 18-bit cascade output
				P => p0, -- 36-bit multiplier output
				A => ah, -- 18-bit multiplier input
				B => bl, -- 18-bit multiplier input
				BCIN => "000000000000000000", -- 18-bit cascade input
				CEA => '0', -- Clock enable input for the A port
				CEB => '0', -- Clock enable input for the B port
				CEP => '1', -- Clock enable input for the P port
				CLK => CLK, -- Clock input
				RSTA => '0', -- Synchronous reset input for the A port
				RSTB => '0', -- Synchronous reset input for the B port
				RSTP => '0' -- Synchronous reset input for the P port
			);

		MULT18X18SIO_inst1 : MULT18X18SIO
			generic map (
				AREG => 0, -- Enable the input registers on the A port (1=on, 0=off)
				BREG => 0, -- Enable the input registers on the B port (1=on, 0=off)
				B_INPUT => "DIRECT", -- B cascade input "DIRECT" or "CASCADE"
				PREG => 1) -- Enable the input registers on the P port (1=on, 0=off)
			port map (
				BCOUT => open, -- 18-bit cascade output
				P => p1, -- 36-bit multiplier output
				A => al, -- 18-bit multiplier input
				B => bh, -- 18-bit multiplier input
				BCIN => "000000000000000000", -- 18-bit cascade input
				CEA => '0', -- Clock enable input for the A port
				CEB => '0', -- Clock enable input for the B port
				CEP => '1', -- Clock enable input for the P port
				CLK => CLK, -- Clock input
				RSTA => '0', -- Synchronous reset input for the A port
				RSTB => '0', -- Synchronous reset input for the B port
				RSTP => '0' -- Synchronous reset input for the P port
			);
	end generate; -- m18x18sio
	
	process(clk)
	begin
		if rising_edge(clk) then
			tsum <= p0(33 downto 0) + p1(33 downto 0);
		end if;
	end process;
	
	t1 <= tsum(33) & tsum(33) & tsum(33) & tsum(33) &
		tsum(33) & tsum(33) & tsum(33) & tsum(33) & 
		tsum(33) & tsum(33) & tsum(33) & tsum(33) &
		tsum(33) & tsum(33) & tsum & x"0000";

	hilo <= (p0(31 downto 0) & p1(31 downto 0)) + t1;

end generate; -- xxx_mult


end Behavioral;

