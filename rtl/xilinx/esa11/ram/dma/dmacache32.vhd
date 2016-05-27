library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

use work.DMACache_pkg.ALL;

entity dmacache32 is
   port(
      clk                  : in std_logic;                     -- system and MCB cmd clk
      reset                : in std_logic;
      tst_dbg              : in std_logic_vector(3 downto 0);

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
      chns_from_host       : in DMAChannels_FromHost := DMAChannels_FromHost_INIT;
      channels_to_host     : out DMAChannels_ToHost;

      data_out             : out std_logic_vector(31 downto 0);
      readBusy             : out std_logic;                    -- debug
      debug                : out std_logic_vector(7 downto 0)
   );
end entity;

architecture rtl of dmacache32 is

  constant ddr_rd_len : integer := 32; -- number of 32 bit words to read per external ram access

  type inputstate_t is (rd1,rcv1,rcv2,upd1);
  signal inputstate : inputstate_t := rd1;

-- DMA channel state information
  type DMAChannel_Internal is record
--   valid       : std_logic;                           -- testing valid flag
--   valid_d     : std_logic;                           -- Used to delay the valid flag
     addr        : std_logic_vector(31 downto 0);       -- Current RAM address
     count       : unsigned(16 downto 0);               -- Number of words to transfer.
--   pending     : std_logic;                           -- Host has a request pending on this channel
--   fill        : std_logic;                           -- Add a word to the FIFO
--   full        : std_logic;                           -- Is the FIFO full?
--   drain       : std_logic;                           -- Drain a word from the FIFO
--   empty       : std_logic;                           -- Is the FIFO completely empty?
--   dout        : std_logic_vector(15 downto 0);
  end record;

  type DMAChannels_Internal is array (integer range <>) of DMAChannel_Internal;
  type arr_slv_15_0 is array (integer range <>) of std_logic_vector(15 downto 0);
  type arr_slv_31_0 is array (integer range <>) of std_logic_vector(31 downto 0);

  signal internals : DMAChannels_Internal(0 to DMACache_MaxChannel-1);
  signal act_ch_wr : integer range 0 to DMACache_MaxChannel-1 := 0;
  signal act_ch_rd : integer range 0 to DMACache_MaxChannel-1 := 0;
  signal m_act_ch_wr        : integer range 0 to DMACache_MaxChannel-1 := 0;

  -- dma interface, sys_clk domain signals
  signal ddr_re               : std_logic;                                -- same as insertAddr (ddr_re when not cacheHit)
  signal ddr_hold             : std_logic_vector(2 downto 0);             -- shift reg delay from ddr_re
  signal busy                 : std_logic;                                -- combinat. mix of signals
--  signal addr_reg             : std_logic_vector(31 downto 0);            -- addr, sys_clk-registered

  -- mcb interface, mbi_rd_clk domain signals
--  signal mbi_re            : std_logic;                                    -- not mig_rd_empty
  signal mbi_read_busy     : std_logic;                                    -- ddr read cycle running
  signal ddr_re_rc2        : std_logic;                                    -- ddr_re_cmd, delayed
  signal mbi_rd_count      : unsigned(7 downto 0);                         -- rd_clk counter

  -- domain crossing signals
  signal mbi_read_busy_sys : std_logic;                                   -- ddr read cycle running, rd_clk-registered
  signal ddr_re_rck        : std_logic;                                   -- ddr_re2, rd_clk-registered

   -- AXI4 temp signals
   signal axi_araddr       : std_logic_vector(31 downto 0);
   signal axi_arvalid      : std_logic;
   signal axi_rready       : std_logic;

   signal addr              : std_logic_vector(31 downto 0);               -- address to be read from DDR
--  signal serv_ch           : integer range 0 to DMACache_MaxChannel-1;    -- current channel to be serviced

--  signal en   : std_logic;
--  signal mcb_rd_empty_sys   : std_logic;
--  signal mcb_rd_empty_d     : std_logic;
  
   signal tmp_full           : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_full_d         : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_empty          : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_fill           : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_drain          : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_pend           : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_valid          : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal tmp_rst            : std_logic_vector(DMACache_MaxChannel-1 downto 0);
   signal tmp_dout           : arr_slv_31_0(DMACache_MaxChannel-1 downto 0);
   signal fifo_din           : arr_slv_31_0(DMACache_MaxChannel-1 downto 0);
   --signal tmp_cnt            : arr_slv_15_0(DMACache_MaxChannel-1 downto 0) := (others => (others => '0'));
   signal tmp_split          : std_logic_vector(DMACache_MaxChannel-1 downto 0); -- workaround
   signal serv_act_d         : std_logic;
   signal valid_d            : std_logic;
   signal update_fwft        : std_logic;

begin
   m_axi_arid     <= "0";    -- not used
    -- burst length, data beats-1 should match ddr_rd_len adjusted by arsize
   m_axi_arlen    <= std_logic_vector(to_unsigned(ddr_rd_len-1,8));  -- burst length, data beats-1 should match ddr_rd_len
--	m_axi_arlen    <= std_logic_vector(to_unsigned((ddr_rd_len/2)-1, m_axi_arlen'length));
   m_axi_arsize   <= "010";  -- 32 bits, resp. 4 bytes
   m_axi_arburst  <= "01";  -- burst type INCR - Incrementing address
   m_axi_arlock   <= '0';    -- Exclusive access not supported
   m_axi_arcache  <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
   m_axi_arprot   <= "000";  -- Xilinx IP generally ignores
   m_axi_arqos    <= "0000"; -- QOS not supported

   m_axi_awid     <= "0";   -- not used
   m_axi_awlen    <= X"00";  -- data beats-1 (single access)
   m_axi_awsize   <= "010";  -- 32 bits, resp. 4 bytes
   m_axi_awburst  <= "01";  -- burst type INCR - Incrementing address
   m_axi_awlock   <= '0';    -- Exclusive access not supported
   m_axi_awcache  <= "0011"; -- Xilinx IP generally ignores
   m_axi_awprot   <= "000";  -- Xilinx IP generally ignores
   m_axi_awqos    <= "0000"; -- QOS not supported


   busy <= ddr_re -- or (re_d and cache_offset_changed)
          or ddr_hold(0) or ddr_hold(1) 
          or mbi_read_busy_sys;
   readBusy  <= busy;

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
        ddr_re_rc2 <= ddr_re_rck;
        if ddr_re_rck = '1' and ddr_re_rc2 = '0'
                            and axi_arvalid <= '0' then -- start DDR read
            mbi_read_busy <= '1';
            mbi_rd_count  <= (others => '0');
            axi_araddr    <= "00" & addr(29 downto 2) & "00";
            axi_arvalid   <= '1';
        elsif m_axi_arready = '1' and axi_arvalid = '1' then
            axi_arvalid   <= '0';
        end if;

         -- read completed
--	      if mbi_rd_count = to_unsigned(ddr_rd_len /4 -1, mbi_rd_count'length) then  -- read length
        if  m_axi_rvalid = '1' and m_axi_rlast = '1' then
           mbi_read_busy <= '0';
        end if;

         -- write to cache control
        if m_axi_rvalid = '1' and m_axi_rlast = '0' then
            mbi_rd_count <= unsigned(mbi_rd_count) + "1";
        end if;
   
         -- axi read handshake
--	        if m_axi_rvalid = '1' and axi_rready = '0' then
--	      	   axi_rready <= '1';
--	        elsif axi_rready = '1' and m_axi_rlast = '1' then
        if axi_rready = '1' and m_axi_rvalid = '1' 
                          and m_axi_rlast = '1' then
            axi_rready <= '0';
        else
            axi_rready <= '1';
        end if;

        if mbi_read_busy = '0' then
            mbi_rd_count <= (others => '0');
        end if;
   
         -- target chache line
   --      cache_pb_addr <= mbi_addr_offset(16 downto 6) & mbi_rd_count(5 downto 0);
   --      mbi_rd_dout <= mcb_rd_data;
      end if;
    end if;                           -- clk
  end process cache_mbi_read;

  m_axi_rready  <= axi_rready; -- handshake (could also be activated before rvalid)
  m_axi_arvalid <= axi_arvalid;
  m_axi_araddr  <= axi_araddr;

  m_axi_awaddr  <= (others => '0');
  m_axi_awvalid  <= '0';
  m_axi_wvalid  <= '0'; --when write_done = '1' else '1'; -- and axi_wvalid_d;
  m_axi_wdata   <= (others => '0');
  m_axi_wstrb   <= (others => '0');
  m_axi_bready  <= '0';
  m_axi_wlast   <= '0';

  CROSS_MIG_TO_SYS : process (clk, reset)
  begin  -- process CROSS_MIG_TO_SYS
    if reset = '1' then                 -- asynchronous reset (active high)
      mbi_read_busy_sys <= '0';
      tmp_full_d <= (others => '0');
      ddr_hold         <= (others => '0');
    elsif rising_edge(clk) then         -- rising clock edge
      mbi_read_busy_sys <= mbi_read_busy;
      tmp_full_d <= tmp_full;
      ddr_hold <= ddr_hold(ddr_hold'left-1 downto 0) & ddr_re;
    end if;
  end process CROSS_MIG_TO_SYS;

  CROSS_SYS_TO_MIG : process (m_axi_aclk)
  begin  -- process CROSS_SYS_TO_MIG
    if rising_edge(m_axi_aclk) then
      if m_axi_aresetn = '0' then
        ddr_re_rck      <= '0';
        m_act_ch_wr     <= 0;
      else
        ddr_re_rck      <= ddr_re;
        m_act_ch_wr     <= act_ch_wr;
      end if;
    end if; -- clk
  end process CROSS_SYS_TO_MIG;


   ChannelFIFOs: for ch in 0 to DMACache_MaxChannel-1 generate
      tmp_rst(ch) <= chns_from_host(ch).setaddr; 
--                     or chns_from_host(ch).setreqlen;

      fifo_din(ch) <= m_axi_rdata when tst_dbg(2) = '0' else chns_from_host(ch).addr;

      tmp_fill(ch) <= m_axi_rvalid when m_act_ch_wr = ch else '0'; -- fifo write enable

   -- FWFT: When data is available in the FIFO, the first word falls through the FIFO and 
   -- appears (5+2 clk delay) on the output bus (DOUT). Once the first word appears on DOUT,
   -- EMPTY is deasserted indicating one or more readable words in the FIFO, and VALID is
   -- asserted, indicating a valid word is present on DOUT.
      myfifo : entity work.cache_fifo
         PORT MAP (
            WR_CLK         => m_axi_aclk,
            RD_CLK         => clk,
            RST            => tmp_rst(ch),
            VALID          => tmp_valid(ch),    -- rd
            PROG_FULL      => tmp_full(ch),     -- wr
            WR_EN          => tmp_fill(ch),     --cache_wren, -- wr
            RD_EN          => tmp_drain(ch),    -- rd
            DIN            => fifo_din(ch),     -- wr
            DOUT           => tmp_dout(ch),     -- rd
            FULL           => open,             -- wr
            EMPTY          => tmp_empty(ch)     -- rd
         );

--      myfifo : entity work.fifo_conf
--      generic map(
--         NA           => 4,
--         NB           => 4,
--         M            => 6,  -- 64 0x40
--         FALL_THROUGH => '1')
--      port map(
--         wr_rst        => tmp_rst(ch),
--         wr_clk        => m_axi_aclk,
--         rd_rst        => tmp_rst(ch),
--         rd_clk        => clk,
--         din           => fifo_din(ch),
--         wr_en         => tmp_fill(ch),
--         rd_en         => tmp_drain(ch),
--         dout          => tmp_dout(ch),
--         full          => open, -- tmp_full(ch),
--         empty         => tmp_empty(ch),
--         rd_data_count => open,
--         wr_data_count => tmp_cnt(ch)(5 downto 0)
--      );

----      tmp_full(ch) <= tmp_cnt(ch)(5) and tmp_cnt(ch)(4); -- 75% full limit, 25% spare
--      tmp_full(ch) <= tmp_cnt(ch)(5); -- 50% full limit, 50% spare
--      tmp_valid(ch) <= not tmp_empty(ch);
   end generate;


   -- active channel mux
   addr <= internals(act_ch_wr).addr; -- address to read from DDR
   
   -- Read from RAM to FIFO control
   -- system (and ddr_cmd) clock domain
   fillcache : process(clk, reset)
   begin
      if reset = '1' then
         inputstate <= rd1;
         for ch in 0 to DMACache_MaxChannel-1 loop
           internals(ch).count <= (others => '0');
           internals(ch).addr  <= (others => '0');
         end loop;
         ddr_re <= '0';
         act_ch_wr <= 0;
--         mcb_rd_empty_d <= '1';
         debug <= (others => '0');
      elsif rising_edge(clk) then
--         ddr_re <= '0'; --default
--         mcb_rd_empty_d <= mcb_rd_empty_sys;
      
         -- Request and receive data from RAM:
         case inputstate is
            -- First state: Read.  Check the channels in priority order.
            -- VGA has absolute priority, and the others won't do anything until the
            -- VGA buffer is full.
            when rd1 =>
--               ddr_re <= '0'; --default
               for ch in DMACache_MaxChannel-1 downto 0 loop
--                  if internals(ch).full /= '1'
                  if (tmp_full_d(ch) = '0')
                        and (internals(ch).count /= to_unsigned(0, internals(ch).count'length)) -- not zero
                        and (internals(ch).count(internals(ch).count'high) = '0') then -- no overflow ("negative")
                     act_ch_wr <= ch;
                     inputstate <= rcv1;
                     ddr_re <= '1';
                  end if;
--                  tmp_fill(ch)<='0'; -- default all clear
               end loop;
            debug(3 downto 0) <= "0001";

            -- Wait for RAM, fill first word.
            when rcv1 =>
               ddr_re <= '0';
               if m_axi_rvalid = '1' then
                  inputstate <= rcv2;
               elsif busy = '0' then
--                  if mcb_rd_empty_sys='1' then -- Back out of a read request if the cycle's not serviced
                  inputstate <= rd1;    -- (Allows priorities to be reconsidered.)
               end if;
            debug(3 downto 0) <= "0010";

            when rcv2 =>
               if busy = '0' then                 -- read n x 32bit
                   inputstate <= upd1;
               end if;
            debug(3 downto 0) <= "0100";

            when upd1 =>  -- read from MCB finished, update address for next cmd
               internals(act_ch_wr).addr <= std_logic_vector(unsigned(internals(act_ch_wr).addr) + to_unsigned(ddr_rd_len * 4,32)); -- byte address
               internals(act_ch_wr).count <= internals(act_ch_wr).count - to_unsigned(ddr_rd_len,17);  -- read length in 16 bit words
                inputstate <= rd1;
            debug(3 downto 0) <= "1000";
--            when others =>
--               null;
         end case;
   
         for ch in 0 to DMACache_MaxChannel-1 loop
            if chns_from_host(ch).setaddr = '1' then
               internals(ch).addr       <= chns_from_host(ch).addr;
               internals(ch).count      <= (others=>'0');
            end if;
           
            if chns_from_host(ch).setreqlen = '1' then
               internals(ch).count <= '0' & chns_from_host(ch).reqlen;
            end if;
         end loop;
         
         debug(4) <= m_axi_rresp(0);
         debug(5) <= m_axi_rresp(1);
         debug(6) <= tmp_empty(0);
         debug(7) <= tmp_empty(1);
      end if; -- clk
   end process;

--   tmp_dr_edge <= tmp_drain and not tmp_drain_d;
   
   channelservice : process(clk, reset)
   variable serv_ch : integer range 0 to DMACache_MaxChannel-1;
   variable serviceactive : std_logic;
   begin
      if reset = '1' then
         for ch in 0 to DMACache_MaxChannel-1 loop -- Channel 0 has priority, so is never held pending.
            tmp_pend(ch) <= '0';
            tmp_drain(ch) <= '0';
            tmp_split(ch) <= '0';
            channels_to_host(ch).valid <= '0';
            data_out <= (others => '0');
         end loop;

         update_fwft <= '0';
         serv_act_d <= '0';

      elsif rising_edge(clk) then

   -- Handle timeslicing of output registers
   -- We prioritise simply by testing in order of priority.
   -- req signals should always be a single pulse; need to latch all but VGA, since it may be several
   -- cycles since they're serviced.
   -- latch on requestor side one clock after request (data always ready because of fwft)
         serviceactive := '0';
         serv_ch := 0;
         for ch in DMACache_MaxChannel-1 downto 0 loop -- Channel 0 has priority, so is never held pending.
            tmp_drain(ch) <= '0';         -- clear any FIFO rd_en after one clock
            channels_to_host(ch).valid <= '0';
         
            if chns_from_host(ch).setaddr = '1' then
               tmp_pend(ch) <= '0';       -- Reset read pointers when a new address is set
               tmp_drain(ch) <= '0';
               tmp_split(ch) <= '0';
            elsif chns_from_host(ch).req='1' then
               tmp_pend(ch) <= '1';
            end if;

            -- priority:  lowest-ch valid winns
            if chns_from_host(ch).req = '1' or tmp_pend(ch) = '1' then
               if tmp_valid(ch) = '1' then
                  serviceactive := '1';
                  serv_ch := ch;
               end if;
            end if;
         end loop; -- every channel

         valid_d <= tmp_valid(0);

         if tmp_valid(0) = '1' and valid_d = '0' then
            update_fwft <= '1';
         end if;

         if serv_ch /= 0 then
            serv_act_d <= tmp_valid(0);
         end if;

         -- active channel
         if serviceactive='1' then
            if serv_ch = 0 then
               update_fwft <= '0';
               serv_act_d <= '0';
            end if;
            --if tmp_split(serv_ch) = '0' then 
            --   if tmp_valid(serv_ch) = '1' then           -- FWFT: read data available if valid
            --      tmp_drain(serv_ch) <= '0';              -- FIFO rd_en for next data ('ACK' for current data)
            --      tmp_pend(serv_ch) <= '0';
            --      tmp_split(serv_ch) <= '1';
            --      data_out <= tmp_dout(serv_ch)(15 downto 0);
            --      channels_to_host(serv_ch).valid <= '1'; -- FIFO valid
            --   end if;
            --else
            -- fix to split fifo output in two words, until fifo is updated to do the conversion
               if tmp_valid(serv_ch) = '1' and tmp_drain(serv_ch) = '0' then -- FWFT: read data available if valid
                  tmp_drain(serv_ch) <= '1';              -- get next data from fifo
                  tmp_pend(serv_ch) <= '0';
                  data_out <= tmp_dout(serv_ch)(31 downto 0);
                  channels_to_host(serv_ch).valid <= '1'; -- FIFO valid
               end if;
            --end if;
         elsif serv_act_d = '1' or update_fwft = '1' then
            update_fwft <= '0';
            serv_act_d <= '0';

--            if tmp_split(0) = '0' then -- default output ch 0 (valid becaus of fall through-fifo)
               data_out <= tmp_dout(0)(31 downto 0);
--            else
--               data_out <= tmp_dout(0)(31 downto 16);
--            end if;
         end if;

--         act_ch_rd <= serv_ch;

         -- update valid for all ch
         for ch in DMACache_MaxChannel-1 downto 0 loop
            -- split update (drain is one clk puls only)
            if tmp_drain(ch) = '1' then
               tmp_split(ch) <= '0';
            end if;            
         end loop;

      end if; -- clk
   end process;

end rtl;

-- eof
