-- (c) EMARD
-- License=BSD

-- burst capable reader (AXI master)
-- f32c compatible interface
-- which can read-only from AXI bus

-- uses simple FSM to generate AXI
-- handshake and flow control signals
-- which f32c doesn't have

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.ALL;

use work.axi_pack.all;
use work.sram_pack.all;

entity axi_read is
port
(
  axi_aresetn, axi_aclk: in std_logic;
  axi_in: in T_axi_miso;
  axi_out: out T_axi_mosi;

  -- f32c bus
  iaddr: in std_logic_vector(29 downto 2);
  iaddr_strobe: in std_logic;
  iburst: in std_logic_vector(7 downto 0);
  oready: out std_logic;
  odata: out std_logic_vector(31 downto 0);
  iread_ready: in std_logic
);
end entity;

architecture rtl of axi_read is
  signal mbi_read_busy     : std_logic; -- internal lock allows one request to complete until next is accepted

  -- AXI4 temp signals
  signal axi_araddr       : std_logic_vector(31 downto 0);
  signal axi_arvalid      : std_logic;
  signal axi_rready       : std_logic;
  signal axi_arlen        : std_logic_vector(7 downto 0) := x"00"; -- burst length, x"00":1x32bit, x"01":2x32bit etc..
begin
  axi_out.arid     <= "0";    -- not used
  -- burst length, data beats-1 should match ddr_rd_len adjusted by arsize
  -- axi_out.arlen    <= std_logic_vector(to_unsigned(ddr_rd_len-1,8));  -- burst length, data beats-1 should match ddr_rd_len
  --axi_out.arlen    <= axi_arlen;  -- no burst, just read single 32bit word
  axi_out.arsize   <= "010";  -- 32 bits, resp. 4 bytes
  axi_out.arburst  <= "01";   -- burst type INCR - Incrementing address
  axi_out.arlock   <= '0';    -- Exclusive access not supported
  axi_out.arcache  <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
  axi_out.arprot   <= "000";  -- Xilinx IP generally ignores
  axi_out.arqos    <= "0000"; -- QOS not supported

  axi_out.awid     <= "0";    -- not used
  axi_out.awlen    <= x"00";  -- data beats-1 (single access)
  axi_out.awsize   <= "010";  -- 32 bits, resp. 4 bytes
  axi_out.awburst  <= "01";   -- burst type INCR - Incrementing address
  axi_out.awlock   <= '0';    -- Exclusive access not supported
  axi_out.awcache  <= "0011"; -- Xilinx IP generally ignores
  axi_out.awprot   <= "000";  -- Xilinx IP generally ignores
  axi_out.awqos    <= "0000"; -- QOS not supported
  axi_out.awaddr  <= (others => '0');
  axi_out.awvalid <= '0';
  axi_out.wvalid  <= '0'; --when write_done = '1' else '1'; -- and axi_wvalid_d;
  axi_out.wdata   <= (others => '0');
  axi_out.wstrb   <= (others => '0');
  axi_out.wlast   <= '0';

  axi_out.bready  <= '0';

  -- count read cycles, update busy flag
  cache_mbi_read : process(axi_aclk)
  begin
    if rising_edge(axi_aclk) then
      if axi_aresetn = '0' and false then
            mbi_read_busy <= '0';
            axi_araddr    <= (others => '0');
            axi_arvalid   <= '0';
            axi_arlen     <= (others => '0');
      else
        if iaddr_strobe = '1' and mbi_read_busy = '0' and axi_arvalid='0' and iburst /= 0 then -- when previos request is finished, start new DDR read
            axi_araddr    <= "00" & iaddr(29 downto 2) & "00";
            axi_arvalid   <= '1'; -- read request: address valid (similar to f32c strobe)
            axi_arlen     <= iburst-1;
        else
          if axi_arvalid = '1' and axi_in.arready = '1' then
              mbi_read_busy <= '1';
              axi_arvalid <= '0'; -- we got address accepted signal, remove read request
          end if;
        end if;

        -- read completed
        -- axi_in.rlast indicates last word in a burst
        if mbi_read_busy = '1' and axi_in.rvalid = '1' and axi_in.rlast = '1' then
          mbi_read_busy <= '0';
        end if;

      end if;
    end if; -- clk
  end process cache_mbi_read;

  axi_out.rready  <= iread_ready; -- consumer module (compositing2_fifo) asserts ready, just pass thru
  axi_out.arvalid <= axi_arvalid; -- read request. address to read from is valid
  axi_out.araddr  <= axi_araddr; -- address to read from
  axi_out.arlen   <= axi_arlen;  -- no burst, just read single 32bit word

  odata <= axi_in.rdata; -- output data to f32c: read data
  oready <= axi_in.rvalid; -- acknowledge to f32c: read data valid
  --odata <= x"031CE000";
  --oready <= '1';

end rtl;
