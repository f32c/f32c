-- Copyright=EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.ALL;

use work.sram_pack.all;

entity axidma is
   port(
      -- AXI4 Master IF
      m_axi_aresetn        : in  std_logic;
      m_axi_aclk           : in  std_logic;
      -- write addr
      m_axi_awid           : out std_logic_vector(0 downto 0);
      m_axi_awaddr         : out std_logic_vector(31 downto 0);
      m_axi_awlen          : out std_logic_vector(7 downto 0);
      m_axi_awsize         : out std_logic_vector(2 downto 0);
      m_axi_awburst        : out std_logic_vector(1 downto 0);
      m_axi_awlock         : out std_logic;
      m_axi_awcache        : out std_logic_vector(3 downto 0);
      m_axi_awprot         : out std_logic_vector(2 downto 0);
      m_axi_awqos          : out std_logic_vector(3 downto 0);
      m_axi_awvalid        : out std_logic;
      m_axi_awready        : in  std_logic;                    -- not used
      -- write data
      m_axi_wdata          : out std_logic_vector(31 downto 0);
      m_axi_wstrb          : out std_logic_vector(3 downto 0);
      m_axi_wlast          : out std_logic;
      m_axi_wvalid         : out std_logic;
      m_axi_wready         : in  std_logic;                    -- not used
      -- write response
      m_axi_bid            : in  std_logic_vector(0 downto 0); -- not used
      m_axi_bresp          : in  std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
      m_axi_bvalid         : in  std_logic;                    -- not used
      m_axi_bready         : out std_logic;
      -- read addr
      m_axi_arid           : out std_logic_vector(0 downto 0);
      m_axi_araddr         : out std_logic_vector(31 downto 0);
      m_axi_arlen          : out std_logic_vector(7 downto 0);
      m_axi_arsize         : out std_logic_vector(2 downto 0);
      m_axi_arburst        : out std_logic_vector(1 downto 0);
      m_axi_arlock         : out std_logic;
      m_axi_arcache        : out std_logic_vector(3 downto 0);
      m_axi_arprot         : out std_logic_vector(2 downto 0);
      m_axi_arqos          : out std_logic_vector(3 downto 0);
      m_axi_arvalid        : out std_logic;
      m_axi_arready        : in  std_logic;
      -- read data
      m_axi_rid            : in  std_logic_vector(0 downto 0); -- not used
      m_axi_rdata          : in  std_logic_vector(31 downto 0);
      m_axi_rresp          : in  std_logic_vector(1 downto 0); -- not used, (1): error?, (0): data transfer?
      m_axi_rlast          : in  std_logic;
      m_axi_rvalid         : in  std_logic;
      m_axi_rready         : out std_logic;

      -- f32c bus
      iaddr: in std_logic_vector(29 downto 2);
      iaddr_strobe: in std_logic;
      iburst: in std_logic_vector(7 downto 0);
      oready: out std_logic;
      odata: out std_logic_vector(31 downto 0);
      iread_ready: in std_logic
   );
end entity;

architecture rtl of axidma is
  signal mbi_read_busy     : std_logic; -- internal lock allows one request to complete until next is accepted

  -- AXI4 temp signals
  signal axi_araddr       : std_logic_vector(31 downto 0);
  signal axi_arvalid      : std_logic;
  signal axi_rready       : std_logic;
  signal axi_arlen        : std_logic_vector(7 downto 0) := x"00"; -- burst length, x"00":1x32bit, x"01":2x32bit etc..
begin
  m_axi_arid     <= "0";    -- not used
  -- burst length, data beats-1 should match ddr_rd_len adjusted by arsize
  -- m_axi_arlen    <= std_logic_vector(to_unsigned(ddr_rd_len-1,8));  -- burst length, data beats-1 should match ddr_rd_len
  --m_axi_arlen    <= axi_arlen;  -- no burst, just read single 32bit word
  m_axi_arsize   <= "010";  -- 32 bits, resp. 4 bytes
  m_axi_arburst  <= "01";   -- burst type INCR - Incrementing address
  m_axi_arlock   <= '0';    -- Exclusive access not supported
  m_axi_arcache  <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
  m_axi_arprot   <= "000";  -- Xilinx IP generally ignores
  m_axi_arqos    <= "0000"; -- QOS not supported

  m_axi_awid     <= "0";    -- not used
  m_axi_awlen    <= x"00";  -- data beats-1 (single access)
  m_axi_awsize   <= "010";  -- 32 bits, resp. 4 bytes
  m_axi_awburst  <= "01";   -- burst type INCR - Incrementing address
  m_axi_awlock   <= '0';    -- Exclusive access not supported
  m_axi_awcache  <= "0011"; -- Xilinx IP generally ignores
  m_axi_awprot   <= "000";  -- Xilinx IP generally ignores
  m_axi_awqos    <= "0000"; -- QOS not supported
  m_axi_awaddr  <= (others => '0');
  m_axi_awvalid <= '0';
  m_axi_wvalid  <= '0'; --when write_done = '1' else '1'; -- and axi_wvalid_d;
  m_axi_wdata   <= (others => '0');
  m_axi_wstrb   <= (others => '0');
  m_axi_wlast   <= '0';

  m_axi_bready  <= '0';

  -- count read cycles, update busy flag
  cache_mbi_read : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if m_axi_aresetn = '0' and false then
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
          if axi_arvalid = '1' and m_axi_arready = '1' then
              mbi_read_busy <= '1';
              axi_arvalid <= '0'; -- we got address accepted signal, remove read request
          end if;
        end if;

        -- read completed
        -- m_axi_rlast indicates last word in a burst
        if mbi_read_busy = '1' and m_axi_rvalid = '1' and m_axi_rlast = '1' then
          mbi_read_busy <= '0';
        end if;

      end if;
    end if; -- clk
  end process cache_mbi_read;

  m_axi_rready  <= iread_ready; -- consumer module (compositing2_fifo) asserts ready, just pass thru
  m_axi_arvalid <= axi_arvalid; -- read request. address to read from is valid
  m_axi_araddr  <= axi_araddr; -- address to read from
  m_axi_arlen   <= axi_arlen;  -- no burst, just read single 32bit word

  odata <= m_axi_rdata; -- output data to f32c: read data
  oready <= m_axi_rvalid; -- acknowledge to f32c: read data valid
  --odata <= x"031CE000";
  --oready <= '1';

end rtl;
