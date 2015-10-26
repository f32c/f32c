--
-- Copyright (c) 2014-2015 Valentin Angelovski
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--	notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--	notice, this list of conditions and the following disclaimer in the
--	documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.	IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

--
-- Module Name:		simple_ADC.vhd
-- Module Version:	0.1
-- Module author:	Valentin Angelovski
-- Module date:		14/09/2014
-- Project IDE:		Lattice Diamond ver. 3.1.0.96
--
-- Version release history
-- 14/09/2014 v0.1 (Initial beta pre-release)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_ADC is
	port(
		clk:			in	STD_LOGIC;		-- sample clock
		reset:			in	STD_LOGIC;		-- reset

		Sampler_Q:		buffer std_logic;	-- Sigma Delta ADC - Comparator result
		Sampler_D:		in	std_logic;		-- Sigma Delta ADC - RC circuit driver out

		adc_output:		out	std_logic_vector(15 downto 0)	-- ~10-bit ADC output
	);
end;

architecture Behavioral of simple_ADC is
	-- Declare registers and signals needed for the sigma-delta ADC (Analog-to-Digital Converter)
	signal adc_rawout: signed (13 downto 0);
	signal adc_filout: signed (13 downto 0);

begin
	-- Sigma-Delta ADC sampling and processing loop
	PROCESS (clk, reset)
	begin

		if reset = '1' then -- ADC reset
			adc_rawout <= (others => '0');
			Sampler_Q <='0';
		else -- Sigma-delta ADC sampling loop
			if(clk'event and clk='1') then
				Sampler_Q <= Sampler_D; -- sample ADC comparator value
				-- Add the signed difference (Delta) between the previous sample and current one
				adc_rawout <= adc_rawout + shift_right((("00" & Sampler_Q & "00000000000") - adc_rawout), 6) ;
				adc_output <= "00000" & std_logic_vector(adc_rawout(10 downto 0));
			end if;
		end if;
	end process;
end Behavioral;
