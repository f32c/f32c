-- Copyright=EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

use work.sram_pack.all;

entity axidma is
   port(
      clk                  : in std_logic;                     -- system and MCB cmd clk

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

      -- DMA channel address strobes
      --chns_from_host       : in DMAChannels_FromHost := DMAChannels_FromHost_INIT;
      --channels_to_host     : out DMAChannels_ToHost;
      
      -- f32c bus
      iaddr: in std_logic_vector(29 downto 2);
      iaddr_strobe: in std_logic;
      oready: out std_logic;
      odata: out std_logic_vector(31 downto 0)
   );
end entity;

architecture rtl of axidma is

  constant ddr_rd_len : integer := 32; -- number of 32 bit words to read per external ram access

  type inputstate_t is (rd1,rcv1,rcv2,upd1);
  signal inputstate : inputstate_t := rd1;

-- DMA channel state information
--  type DMAChannel_Internal is record
--     addr        : std_logic_vector(31 downto 0);       -- Current RAM address
--     count       : unsigned(16 downto 0);               -- Number of words to transfer.
--  end record;

--  type DMAChannels_Internal is array (integer range <>) of DMAChannel_Internal;
--  type arr_slv_15_0 is array (integer range <>) of std_logic_vector(15 downto 0);
--  type arr_slv_31_0 is array (integer range <>) of std_logic_vector(31 downto 0);

--  signal internals : DMAChannels_Internal(0 to DMACache_MaxChannel-1);
--  signal act_ch_wr: integer range 0 to DMACache_MaxChannel-1 := 0;
--  signal act_ch_rd: integer range 0 to DMACache_MaxChannel-1 := 0;
--  signal m_act_ch_wr: integer range 0 to DMACache_MaxChannel-1 := 0;

  -- dma interface, sys_clk domain signals
  signal ddr_re               : std_logic;                                -- same as insertAddr (ddr_re when not cacheHit)
  signal ddr_hold             : std_logic_vector(2 downto 0);             -- shift reg delay from ddr_re
  signal busy                 : std_logic;                                -- combinat. mix of signals
--  signal addr_reg             : std_logic_vector(31 downto 0);            -- addr, sys_clk-registered

  -- mcb interface, mbi_rd_clk domain signals
--  signal mbi_re            : std_logic;                                    -- not mig_rd_empty
  signal mbi_read_busy     : std_logic;                                    -- ddr read cycle running
  signal mbi_rd_count      : unsigned(7 downto 0);                         -- rd_clk counter

  -- AXI4 temp signals
  signal axi_araddr       : std_logic_vector(31 downto 0);
  signal axi_arvalid      : std_logic;
  signal axi_rready       : std_logic;

begin

  m_axi_arid     <= "0";    -- not used
  -- burst length, data beats-1 should match ddr_rd_len adjusted by arsize
  -- m_axi_arlen    <= std_logic_vector(to_unsigned(ddr_rd_len-1,8));  -- burst length, data beats-1 should match ddr_rd_len
  m_axi_arlen    <= x"00";  -- no burst, just read single 32bit word
  m_axi_arsize   <= "010";  -- 32 bits, resp. 4 bytes
  m_axi_arburst  <= "01";   -- burst type INCR - Incrementing address
  m_axi_arlock   <= '0';    -- Exclusive access not supported
  m_axi_arcache  <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
  m_axi_arprot   <= "000";  -- Xilinx IP generally ignores
  m_axi_arqos    <= "0000"; -- QOS not supported

  m_axi_awid     <= "0";    -- not used
  m_axi_awlen    <= X"00";  -- data beats-1 (single access)
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

  ddr_re <= iaddr_strobe;
  busy <= ddr_re -- or (re_d and cache_offset_changed)
          or mbi_read_busy;

  -- count read cycles, update busy flag
  cache_mbi_read : process(m_axi_aclk)
  begin
    if rising_edge(m_axi_aclk) then
      if m_axi_aresetn = '0' then
            mbi_read_busy <= '0';
            mbi_rd_count  <= (others => '0');
            axi_araddr    <= (others => '0');
            axi_arvalid   <= '0';
            axi_rready    <= '0';
      else
        if ddr_re = '1' and mbi_read_busy = '0' then -- when previos request is finished, start new DDR read
            mbi_read_busy <= '1';
            mbi_rd_count  <= (others => '0');
            axi_araddr    <= "00" & iaddr(29 downto 2) & "00";
            axi_arvalid   <= '1'; -- read request: address valid (similar to f32c strobe)
        end if;
        if m_axi_arready = '1' and axi_arvalid = '1' then
            axi_arvalid   <= '0'; -- we got ready signal, remove read request
        end if;

        -- read completed
        -- m_axi_rlast indicates last packet in a burst
        if m_axi_rvalid = '1' and m_axi_rlast = '1' then
           mbi_read_busy <= '0';
        end if;

        -- write to cache control
        -- not yet end of burst, more data to follow
        -- increment number of words transferred
        if m_axi_rvalid = '1' and m_axi_rlast = '0' then
            mbi_rd_count <= unsigned(mbi_rd_count) + "1";
        end if;

        if axi_rready = '1' and m_axi_rvalid = '1' 
                            and m_axi_rlast = '1' then
            axi_rready <= '0'; -- end of burst, no acknowledge
        else
            axi_rready <= '1'; -- the acknowledge during burst to memory controller
        end if;

        if mbi_read_busy = '0' then
            mbi_rd_count <= (others => '0'); -- idle, keep counter at 0
        end if;

      end if;
    end if; -- clk
  end process cache_mbi_read;

  m_axi_rready  <= axi_rready; -- reader ready: acknowledge for each word to memory controller (could also be activated before rvalid)
  m_axi_arvalid <= axi_arvalid; -- read request. address to read from is valid
  m_axi_araddr  <= axi_araddr; -- address to read from

  odata <= m_axi_rdata; -- output data to f32c: read data
  oready <= m_axi_rvalid; -- acknowledge to f32c: read data valid
  --odata <= x"031CE000";
  --oready <= '1';

end rtl;
