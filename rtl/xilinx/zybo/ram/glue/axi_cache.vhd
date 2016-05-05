-------------------------------------------------------------------------------
-- Attach in between a 32-bit wide bidirectional AXI Port and system.
-- System side reads first check the Cache, and if the entry is in there
-- we can save a read from AXI.
-- Burst length of all transactions on system side are restricted to 1.
-- (Just like Single Port BlockRAM)
-- Writes essentially pass straight through.
-- Cache is coherent by routing write commands to the cache as well, if
-- appropriate. 
--
-- Cache is 16 kBits (512 32-bit words), and each read burst is 64 words (256 bytes).
-- Read data from AXI/MCB goes to B-port of cache mem. System always reads A-port of cache mem.
--
-- AXI Read and write should be independent (full duplex)
-------------------------------------------------------------------------------
-- Adrian Jongenelen
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.blk_ram_pkg.all;

entity axi_cache is
  
  port (
    sys_clk            : in std_logic;                           -- system clock
    reset              : in std_logic;

    -- AXI4 Master IF
    m_axi_aresetn      : in  std_logic;
    m_axi_aclk         : in  std_logic;
    -- write addr
    m_axi_awid         : out std_logic_vector(0 downto 0);
    m_axi_awaddr       : out std_logic_vector(31 downto 0);
    m_axi_awlen        : out std_logic_vector(7 downto 0);
    m_axi_awsize       : out std_logic_vector(2 downto 0);
    m_axi_awburst      : out std_logic_vector(1 downto 0);
    m_axi_awlock       : out std_logic;
    m_axi_awcache      : out std_logic_vector(3 downto 0);
    m_axi_awprot       : out std_logic_vector(2 downto 0);
    m_axi_awqos        : out std_logic_vector(3 downto 0);
    m_axi_awvalid      : out std_logic;
    m_axi_awready      : in  std_logic;
    -- write data
    m_axi_wdata        : out std_logic_vector(31 downto 0);
    m_axi_wstrb        : out std_logic_vector(3 downto 0);
    m_axi_wlast        : out std_logic;
    m_axi_wvalid       : out std_logic;
    m_axi_wready       : in  std_logic;
    -- write response
    m_axi_bid          : in  std_logic_vector(0 downto 0); -- not used
    m_axi_bresp        : in  std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
    m_axi_bvalid       : in  std_logic;
    m_axi_bready       : out std_logic;
    -- read addr
    m_axi_arid         : out std_logic_vector(0 downto 0);
    m_axi_araddr       : out std_logic_vector(31 downto 0);
    m_axi_arlen        : out std_logic_vector(7 downto 0);
    m_axi_arsize       : out std_logic_vector(2 downto 0);
    m_axi_arburst      : out std_logic_vector(1 downto 0);
    m_axi_arlock       : out std_logic;
    m_axi_arcache      : out std_logic_vector(3 downto 0);
    m_axi_arprot       : out std_logic_vector(2 downto 0);
    m_axi_arqos        : out std_logic_vector(3 downto 0);
    m_axi_arvalid      : out std_logic;
    m_axi_arready      : in  std_logic;
    -- read data
    m_axi_rid          : in  std_logic_vector(0 downto 0); -- not used
    m_axi_rdata        : in  std_logic_vector(31 downto 0);
    m_axi_rresp        : in  std_logic_vector(1 downto 0); -- not used
    m_axi_rlast        : in  std_logic;
    m_axi_rvalid       : in  std_logic;
    m_axi_rready       : out std_logic;

    -- System Side
    addr_next    : in  std_logic_vector(31 downto 0);  -- system side byte address
    addr         : in  std_logic_vector(31 downto 0);  -- system side byte address
    din          : in  std_logic_vector(31 downto 0);
    wbe          : in  std_logic_vector(3 downto 0);   -- write byte enable
    i_en         : in  std_logic;                      -- enable
    dout         : out std_logic_vector(31 downto 0);
    readBusy     : out std_logic;                      -- busy filling the cache
    hitCount     : out std_logic_vector(31 downto 0);  -- debug
    readCount    : out std_logic_vector(31 downto 0);  -- debug
    debug        : out std_logic_vector(7 downto 0)
  );

end axi_cache;

architecture logic of axi_cache is

   -- cachable ram addr size - line size = cache_width
   -- all values as byte-address sizes
  constant CACHE_WIDTH : integer := 23;  -- part of address to be stored in table
  constant TABLE_WIDTH : integer := 7;   -- 128 lines 
  constant LINE_SIZE   : integer := 6;   -- 64 bytes per chache line

   type	  wstate_type			is (wsidle, wsaddr, wsdata, wsresp);
  
  -- sys_clk domain signals
  signal cache_wbe            : std_logic_vector(3 downto 0);             -- ddr_wbe gated with cache_hit
  signal cacheHit             : std_logic;                                -- cache_table output
  signal cache_addr_offset    : std_logic_vector(TABLE_WIDTH-1 downto 0); -- foundAddress, cache_table output, cache line
  signal prev_addr_offset     : std_logic_vector(TABLE_WIDTH-1 downto 0); -- cache_addr_offset sys_clk-registered
--  signal wbe_d                : std_logic_vector(3 downto 0);             -- wbe, sys_clk-registered
  signal re                   : std_logic;                                -- en gated with not wbe  
  signal re_d                 : std_logic;                                -- re, sys_clk-registered
  signal we                   : std_logic;
  signal we_d                 : std_logic;
  signal we_busy              : std_logic;
  signal ddr_re               : std_logic;                                -- same as insertAddr (ddr_re when not cacheHit)
  signal ddr_hold             : std_logic_vector(2 downto 0);             -- shift reg delay from ddr_re
  signal cache_din            : std_logic_vector(31 downto 0);            -- din, sys_clk-registered
  signal cache_dout           : std_logic_vector(31 downto 0);            -- A-port read data
  signal cache_addr           : std_logic_vector(TABLE_WIDTH +LINE_SIZE-1 downto 0); -- cache line + addr offset
  signal insertAddr           : std_logic;                                -- ddr_re gated with not cacheHit
  signal addrToInsert         : std_logic_vector(CACHE_WIDTH-1 downto 0); -- addr (page addr), sys_clk-registered
  signal busy                 : std_logic;                                -- combinat. mix of signals
--  signal addr_reg             : std_logic_vector(31 downto 0);            -- addr, sys_clk-registered
  signal cache_offset_changed : std_logic;                                -- new foundAddress

  signal hitCounter  : std_logic_vector(31 downto 0);                     -- stats, debug
  signal readCounter : std_logic_vector(31 downto 0);                     -- stats, debug

  -- mbi_rd_clk domain signals
  signal cache_pb_we      : std_logic_vector(3 downto 0);                 -- fill cache port B from ddr
  signal cache_pb_addr    : std_logic_vector(TABLE_WIDTH+LINE_SIZE-1 downto 0); -- cache_addr_offset & read counter, port B
  signal mbi_read_busy    : std_logic;                                    -- ddr read cycle running
  signal ddr_re_cmd2      : std_logic;                                    -- ddr_re_cmd, delayed
  signal mbi_rd_count     : unsigned(7 downto 0);                         -- rd_clk counter, not used

  -- domain crossing signals
  signal mbi_read_busy_sys : std_logic;                                   -- ddr read cycle running, rd_clk-registered
  signal mbi_addr_offset   : std_logic_vector(TABLE_WIDTH-1 downto 0);    -- cache_addr_offset, cache line to be read/reading from ddr
  signal ddr_re_cmd        : std_logic;                                   -- ddr_re2, rd_clk-registered

   signal mcb_wr_busy      : std_logic;  -- write busy
   signal mcb_wr_busy_d    : std_logic;  -- write busy
--   signal mcb_cmd_busy     : std_logic;  -- read busy
   signal en_d             : std_logic;

	-- AXI4 temp signals
   signal axi_awaddr       : std_logic_vector(31 downto 0);
   signal axi_awvalid      : std_logic;
   signal axi_wdata        : std_logic_vector(31 downto 0);
   signal axi_wstrb        : std_logic_vector(3 downto 0);
--   signal axi_wlast        : std_logic;
   signal axi_wvalid       : std_logic;
   signal axi_wvalid_d     : std_logic;
   signal axi_bready       : std_logic;
   signal axi_araddr       : std_logic_vector(31 downto 0);
   signal axi_arvalid      : std_logic;
   signal axi_rready       : std_logic;
   signal axi_wready       : std_logic; -- delayed 1 clk

   signal wstate           : wstate_type := wsidle;
   signal wstate_d         : wstate_type := wsidle;
   signal wtimeout         : unsigned(7 downto 0);
   signal wrsm_idle        : std_logic;
   signal we_edge_r        : std_logic;            -- write access memory
   signal we_dac           : std_logic;            -- we_d axi clk domain (for edge detection)
   signal new_addr         : std_logic;
   signal new_addr_d       : std_logic;
   signal new_wbe          : std_logic;
   signal new_wbe_d        : std_logic;

begin  -- logic
	m_axi_arid   <= "0";    -- not used
	m_axi_arlen  <= X"0f";  -- burst length, data beats-1 (16 x 32 bit)
	m_axi_arsize <= "010";  -- 32 bits, resp. 4 bytes
	m_axi_arburst <= "01";  -- burst type INCR - Incrementing address
	m_axi_arlock <= '0';    -- Exclusive access not supported
	m_axi_arcache <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
	m_axi_arprot <= "000";  -- Xilinx IP generally ignores
	m_axi_arqos  <= "0000"; -- QOS not supported

    m_axi_awid 	  <= "0";   -- not used
    m_axi_awlen  <= X"00";  -- data beats-1 (single access)
    m_axi_awsize <= "010";  -- 32 bits, resp. 4 bytes
    m_axi_awburst <= "01";  -- burst type INCR - Incrementing address
    m_axi_awlock <= '0';    -- Exclusive access not supported
    m_axi_awcache <= "0011"; -- Xilinx IP generally ignores
    m_axi_awprot <= "000";  -- Xilinx IP generally ignores
    m_axi_awqos  <= "0000"; -- QOS not supported


   re   <= i_en when wbe = X"0" else '0'; -- read enable
   we   <= i_en when wbe /= X"0" else '0'; -- write enable

   busy <= (re and not re_d)
          or (re_d and cache_offset_changed)
          or ddr_re
          or ddr_hold(0) or ddr_hold(1)
          or mbi_read_busy_sys;
          
   readBusy  <= busy 
          or we_busy
          or (new_addr and we)
          or (new_wbe and we) 
          or (we and not we_d);-- and not wrsm_idle);


--   m_axi_wstrb <= axi_wstrb; -- controls which of the bytes in the data bus are valid

--   mcb_wr_en   <= i_en when wbe /= X"0" else '0';

   cache_pb_we <= "1111" when m_axi_rvalid = '1' and axi_rready = '1' else "0000"; 

-- While a read is under way, the system side will be halted, so only one read at any time
  cache_mbi_read : process(m_axi_aclk)
  begin
  	if rising_edge(m_axi_aclk) then
  		if m_axi_aresetn = '0' then
--  			cache_pb_we   <= (others => '0');
--  			cache_pb_addr <= (others => '0');
  			mbi_read_busy <= '0';
  			mbi_rd_count  <= (others => '0');
	      axi_araddr    <= (others => '0');
	      axi_arvalid   <= '0';
	      axi_rready    <= '0';
  		else
  			-- start read with sending address
  			if ddr_re_cmd = '1' and ddr_re_cmd2 = '0'
  			   and axi_arvalid <= '0' then -- start DDR read
  				mbi_read_busy <= '1';
  				mbi_rd_count  <= (others => '0');
      	        axi_araddr       <= "000" & addr(CACHE_WIDTH +LINE_SIZE-1 downto LINE_SIZE) & B"00_0000";
  				axi_arvalid <= '1';
  			elsif m_axi_arready = '1' and axi_arvalid = '1' then
  				axi_arvalid <= '0';
  			end if;

            -- read completed
--  			if mbi_rd_count = std_logic_vector(to_unsigned(LINE_SIZE-1,8)) 
  		   if  m_axi_rvalid = '1' and m_axi_rlast = '1' then
  			    mbi_read_busy <= '0';
  			end if;

            -- write to chache control
  			if m_axi_rvalid = '1' and m_axi_rlast = '0' then
--  				cache_pb_we  <= (others => '1');
  				mbi_rd_count <= unsigned(mbi_rd_count) + "1";
--  			else
--  				cache_pb_we <= (others => '0');
  			end if;
  			
            -- axi read handshake
--	        if m_axi_rvalid = '1' and axi_rready = '0' then
--	      	   axi_rready <= '1';
--	        elsif axi_rready = '1' and m_axi_rlast = '1' then
	        if axi_rready = '1'
	        	and m_axi_rvalid = '1' 
	        	and m_axi_rlast = '1' then
	        	axi_rready <= '0';
	        else
	        	axi_rready <= '1';
	        end if;

            -- target chache line
--  			cache_pb_addr <= mbi_addr_offset & mbi_rd_count(1 downto 0) & "00";
  		end if;
  	end if;                           -- clk
  end process cache_mbi_read;

  cache_pb_addr <= mbi_addr_offset & std_logic_vector(mbi_rd_count(3 downto 0)) & "00";

  m_axi_rready  <= axi_rready; -- handshake (could also be activated before rvalid)
  m_axi_arvalid <= axi_arvalid;
  m_axi_araddr  <= axi_araddr;

  new_addr <= '1' when "000" & addr(CACHE_WIDTH + LINE_SIZE - 1 downto 2) & "00" /= axi_awaddr
                 else '0';
  new_wbe  <= '1' when wbe /= axi_wstrb else '0';
  
  -- AXI write 
  mbi_commands : process(m_axi_aclk)
  begin                                 -- process mbi_COMMANDS
  	if rising_edge(m_axi_aclk) then   -- rising clock edge
  		if m_axi_aresetn = '0' then
--	      mcb_cmd_en        <= '0';
--	      mcb_cmd_bl        <= "000000";
--	      mcb_cmd_instr     <= "000";
--	      o_awaddr <= (others => '0');
  			mcb_wr_busy <= '0';
  			mcb_wr_busy_d <= '0';
--	      mcb_wr_en         <= '0';
  			axi_awaddr  <= (others => '0');
  			axi_awvalid <= '0';
  			axi_wstrb   <= (others => '0');
  			axi_wdata   <= (others => '0');
  			axi_wvalid  <= '0';
  			axi_wvalid_d  <= '0';
  			axi_bready  <= '0';
  			m_axi_wlast <= '0';
  			axi_wready  <= '0';
  			wstate      <= wsidle;
  			wstate_d    <= wsidle;
  			wtimeout    <= (others => '0');
  			wrsm_idle   <= '0';
         we_edge_r   <= '0';
         we_dac       <= '0';
  		else
  		   we_dac <= we;
  			axi_wready  <= m_axi_wready;
  			mcb_wr_busy_d <= mcb_wr_busy;
  			axi_wvalid_d <= axi_wvalid;
  			wstate_d <= wstate;
  			
  			axi_bready  <= '1';

			case wstate is
				when wsidle	=> if (we = '1' and we_dac = '0') 
				                  or we_edge_r = '1'
				                  or (we = '1' and new_addr = '1')
				                  or (we = '1' and new_wbe = '1') then
									wstate <= wsaddr;
								end if;
				when wsaddr	=> if m_axi_awready = '1' then
								  wstate <= wsdata;
								elsif wtimeout(5) =  '1' then
					              wstate <= wsidle;
								end if;
				when wsdata => if m_axi_wready = '1' then
									wstate <= wsresp;
								elsif wtimeout(5) =  '1' then
					              wstate <= wsidle;
								end if;
				when wsresp => if m_axi_bvalid = '1' then
									wstate <= wsidle;
								elsif wtimeout(5) =  '1' then
					              wstate <= wsidle;
								end if;
--				when others => null;
			end case; -- wstate

         if wstate = wsidle and wstate_d /= wsidle then
--               if we = '0' then
  				   mcb_wr_busy <= (new_addr or new_wbe) and we;
		  			axi_awvalid <= '0';
		  			axi_wvalid  <= '0';
		  			axi_bready  <= '0';
		  			m_axi_wlast <= '0';
		  			axi_wready  <= '0';
-- 				end if;
  			end if;

  			if wstate = wsaddr and wstate_d = wsidle then
--  			if we = '1' and mcb_wr_busy = '0' and write_done = '0' then
  				mcb_wr_busy <= '1';
  				axi_awaddr  <= "000" & addr(CACHE_WIDTH + LINE_SIZE - 1 downto 2) & "00";
  				axi_awvalid <= '1';
  				axi_wdata   <= din;
  				axi_wstrb   <= wbe;
--  				axi_wvalid  <= '1';
--  				m_axi_wlast <= '1';
--  				write_done  <= '1';
  			end if;

  			if wstate = wsdata and wstate_d /= wsdata then
--  			if m_axi_awready = '1' and axi_awvalid = '1' then
  				axi_awvalid <= '0';
  				m_axi_wlast <= '1';
  				axi_wvalid  <= '1';
  			elsif wstate = wsdata and m_axi_wready = '1' then
  				axi_wvalid <= '0';
  			end if;

  			if wstate = wsresp and wstate_d /= wsresp then
--				if axi_wready = '1' 
--			   and m_axi_wready = '0' 
--			   and axi_wvalid_d = '1' then
				axi_wvalid <= '0';
				m_axi_wlast <= '0';
--  				mcb_wr_busy <= '0'; -- release busy here, so cpu can continue
			end if;

  			-- axi write response handshake
--  			if wstate = wsidle and wstate_d = wsresp then
--  			if m_axi_bvalid = '1' and axi_bready = '1' then
--  				axi_bready <= '0';
--				m_axi_wlast <= '0';
--  				mcb_wr_busy <= '0';
--  			else --if axi_bready = '1' then
--  				axi_bready <= '1';
--  			end if;

            -- prevent eternal wait (might mess up axi)
			if wstate = wsidle then
				wtimeout    <= (others => '0');
				wrsm_idle <= '1';
			else
				wrsm_idle <= '0';
				wtimeout <= wtimeout + "1";
			end if;

           -- store we edge until processed 
         if (we = '1' and we_dac = '0') then
	         we_edge_r <= '1';
	      elsif wstate = wsaddr then
	     	   we_edge_r <= '0';
	      end if;

  		end if;
  	end if;                           -- clk
  end process mbi_COMMANDS;

  m_axi_awaddr  <= axi_awaddr;
  m_axi_awvalid <= axi_awvalid;
  m_axi_wvalid  <= axi_wvalid; --when write_done = '1' else '1'; -- and axi_wvalid_d;
  m_axi_wdata   <= axi_wdata;
  m_axi_wstrb   <= axi_wstrb;
  m_axi_bready  <= axi_bready;


  CACHE_AND_mbi_WRITE : process (sys_clk, reset)
  begin  -- system side control
    if reset = '1' then
      en_d             <= '0';
--   	wbe_d            <= (others => '0');
      re_d             <= '0';
      we_d             <= '0';
      new_addr_d       <= '0';
      new_wbe_d        <= '0';
      we_busy          <= '0';
      cache_din        <= (others => '0');
      addrToInsert     <= (others => '0');
      prev_addr_offset <= (others => '0');
      ddr_hold         <= (others => '0');
    elsif rising_edge(sys_clk) then
  	   en_d             <= i_en;
--      wbe_d            <= wbe;
      re_d             <= re;
      we_d             <= we;
      new_addr_d       <= new_addr;
      new_wbe_d        <= new_wbe;
      cache_din        <= din;
      addrToInsert     <= addr(CACHE_WIDTH +LINE_SIZE-1 downto LINE_SIZE);
      prev_addr_offset <= cache_addr_offset;
--	  if re = '1' then
          ddr_hold <= ddr_hold(ddr_hold'left-1 downto 0) & ddr_re;
--	 end if;
	 
   	 -- on new write while mcb busy stop writer
      if (we = '1' and we_d = '0') 
         or (new_addr = '1' and new_addr_d = '0')
         or (new_wbe = '1' and new_wbe_d = '0') then         -- on we edge
         if mcb_wr_busy = '1' or wrsm_idle = '0' then
            we_busy <= '1';
         else                                 -- elsif wrsm_idle = '1' then
            we_busy <= '0';
         end if;
      elsif mcb_wr_busy = '0' then
         we_busy <= '0';
      elsif (wstate = wsdata or wstate = wsresp) and new_addr = '0' and new_wbe = '0' then
         we_busy <= '0';   
      end if;
      
      end if;
   end process CACHE_AND_mbi_WRITE;


  cache_offset_changed <= '1' when prev_addr_offset /= cache_addr_offset else '0';
  cache_wbe            <= wbe when cacheHit = '1' else X"0";
  cache_addr           <= cache_addr_offset & addr(LINE_SIZE-1 downto 0);
  insertAddr           <= re and re_d  when cacheHit = '0' else '0';
  ddr_re               <= insertAddr;
  dout                 <= cache_dout;

  CROSS_MIG_TO_SYS : process (sys_clk, reset)
  begin
    if reset = '1' then                 -- asynchronous reset (active high)
    	mbi_read_busy_sys <= '0';
    elsif rising_edge(sys_clk) then     -- rising clock edge
    	mbi_read_busy_sys <= mbi_read_busy;
    end if;
  end process CROSS_MIG_TO_SYS;

  CROSS_SYS_TO_MIG : process (m_axi_aclk)
  begin  -- process CROSS_SYS_TO_MIG
   if rising_edge(m_axi_aclk) then
    if m_axi_aresetn = '0' then
       mbi_addr_offset <= (others => '0');
       ddr_re_cmd      <= '0';
       ddr_re_cmd2     <= '0';
     else
       mbi_addr_offset <= prev_addr_offset; -- to be used to write data from mcb to cache (read-delayed)
       ddr_re_cmd      <= ddr_re;
       ddr_re_cmd2     <= ddr_re_cmd;
      end if;
    end if; -- clk
  end process CROSS_SYS_TO_MIG;

  STATS : process (sys_clk, reset)
  begin  -- process STATS
    if reset = '1' then                 -- asynchronous reset (active high)
      hitCounter  <= (others => '0');
      readCounter <= (others => '0');
    elsif rising_edge(sys_clk) then     -- rising clock edge
      if re='1' and re_d = '0' then
        readCounter <= std_logic_vector(unsigned(readCounter) + "1");
        if cacheHit = '1' then
          hitCounter <= std_logic_vector(unsigned(hitCounter) + "1");
        end if;
      end if;
    end if;
  end process STATS;

  hitCount  <= hitCounter;
  readCount <= readCounter;

  debug <= m_axi_rdata(3 downto 0) & cache_pb_addr(3 downto 0);

  -- Cache DPRAM
  -- A-Port: read/write to sys, B-Port: write only, from MCB
  u1_cache : blk_ram
    port map (
      clka   => sys_clk,
      wea    => cache_wbe,
      addra  => cache_addr(cache_addr'left downto 2),
      dina   => cache_din,
      douta  => cache_dout,

      clkb   => m_axi_aclk,
      web    => cache_pb_we,
      addrb  => cache_pb_addr(cache_pb_addr'left downto 2),
      dinb   => m_axi_rdata,
      doutb  => open              -- read not used
      );

  -- each time an addr is to be inserted, table offset is incremented (total 2^TABL_WDTH entries)
  u2_cacheTable : entity work.cache_table
    generic map (
      TABLE_WIDTH => TABLE_WIDTH, -- # of page/line address bits
      ADDR_WIDTH  => CACHE_WIDTH) -- # of ram data bits for address storage
    port map (
      clk          => sys_clk,
      reset        => reset,
      addrToFind   => addr(CACHE_WIDTH +LINE_SIZE-1 downto LINE_SIZE),  -- msb 256Mb DDR is 27
      cacheHit     => cacheHit,
      foundAddress => cache_addr_offset,
      insertAddr   => insertAddr,
      addrToInsert => addrToInsert);

end logic;

--eof
