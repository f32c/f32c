--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
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
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

-- vendor-specific module for differential HDMI output 
-- on Xilinx (Spartan-6) 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity hdmi_out is
    port (
	tmds_in_clk: in std_logic; -- 25 MHz pixel clock single ended
	tmds_out_clk_p, tmds_out_clk_n: out std_logic; -- output 25 MHz differential
	tmds_in_rgb: in std_logic_vector(2 downto 0); -- input (250 MHz single ended)
	tmds_out_rgb_p, tmds_out_rgb_n: out std_logic_vector(2 downto 0) -- output 250 MHz differential
    );
end hdmi_out;

architecture Behavioral of hdmi_out is
    signal obuf_tmds_clock: std_logic;
begin
    -- vendor-specific differential output buffering for HDMI clock and video
    
    hdmi_clock: obufds
      --generic map(IOSTANDARD => "DEFAULT")
      port map(i => tmds_in_clk, o => tmds_out_clk_p, ob => tmds_out_clk_n);

    hdmi_video: for i in 0 to 2 generate
      tmds_video: obufds
        --generic map(IOSTANDARD => "DEFAULT")
        port map(i => tmds_in_rgb(i), o => tmds_out_rgb_p(i), ob => tmds_out_rgb_n(i));
    end generate;

end Behavioral;
