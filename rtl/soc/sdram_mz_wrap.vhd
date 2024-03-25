----------------------------------------------------------------------------------
-- COPYRIGHT=EMARD
-- LICENSE=BSD
-- glue_xram compatible wrapper for sdram_mz.vhd
-- converts new bus format sdram_port_array to old sram.vhd format
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.sram_pack.all;
use work.sdram_pack.all;

entity sdram_mz_wrap is
  generic
  (
    C_ports: integer;
    C_prio_port: integer := -1;
    C_ras: integer range 2 to 3 := 2;
    C_cas: integer range 2 to 3 := 2;
    C_pre: integer range 2 to 3 := 2;
    C_clock_range: integer range 0 to 5 := 2; -- default:2, (read delay, for every 2 shift delay line increases by 1)
    C_ready_point: integer range 0 to 1 := 1; -- shift delay reg bit index when data ready is sent, default:1
    C_done_point: integer range 0 to 1 := 1; -- shift delay reg bit index when new transaction is accepted, default:1
    C_write_ready_delay: integer range 1 to 3 := 2; -- shift delay reg bit to set for write, default:2
    C_shift_read: boolean := false; -- if false use phase read (no shifting)
    C_allow_back2back: boolean := true;
    sdram_address_width: natural;
    sdram_column_bits: natural;
    sdram_startup_cycles: natural;
    cycles_per_refresh: natural
  );
  port
  (
    clk: in  STD_LOGIC;
    reset: in  STD_LOGIC;

    -- To internal bus / logic blocks
    data_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
    ready_out: out sram_ready_array; -- one bit per port
    snoop_addr: out std_logic_vector(31 downto 2);
    snoop_cycle: out std_logic;
    -- Inbound multi-port bus connections
    bus_in: in sram_port_array;

    -- SDRAM signals to physical RAM chip
    sdram_clk: out STD_LOGIC;
    sdram_cke: out STD_LOGIC;
    sdram_cs: out STD_LOGIC;
    sdram_ras: out STD_LOGIC;
    sdram_cas: out STD_LOGIC;
    sdram_we: out STD_LOGIC;
    sdram_dqm: out STD_LOGIC_VECTOR( 1 downto 0);
    sdram_addr: out STD_LOGIC_VECTOR(12 downto 0);
    sdram_ba: out STD_LOGIC_VECTOR( 1 downto 0);
    sdram_data: inout STD_LOGIC_VECTOR(15 downto 0)
  );
end sdram_mz_wrap;

architecture Behavioral of sdram_mz_wrap is
    signal req: sdram_req_array;
    signal resp: sdram_resp_array;
begin
    -- for data output signals all ports are the same
    -- port 0 is used but any should work
    data_out <= resp(0).data_out;
    all_ports: for i in 0 to C_ports-1 generate
      req(i).strobe <= bus_in(i).addr_strobe;
      req(i).addr <= "10" & bus_in(i).addr;
      req(i).burst_len <= bus_in(i).burst_len(2 downto 0);
      req(i).write <= bus_in(i).write;
      req(i).data_in <= bus_in(i).data_in;
      req(i).byte_sel <= bus_in(i).byte_sel;
      ready_out(i) <= resp(i).data_ready;
    end generate;
    
    sdram: entity work.sdram_controller -- sdram_mz.vhd
    generic map
    (
      C_ports => C_ports,
      C_prio_port => C_prio_port,
      C_ras => C_ras,
      C_cas => C_cas,
      C_pre => C_pre,
      C_clock_range => C_clock_range,
      sdram_address_width => sdram_address_width,
      sdram_column_bits => sdram_column_bits,
      sdram_startup_cycles => sdram_startup_cycles,
      cycles_per_refresh => cycles_per_refresh
    )
    port map
    (
      clk => clk, reset => reset,
      -- internal connections
      req => req, resp => resp,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- external SDRAM interface
      sdram_addr => sdram_addr, sdram_data => sdram_data,
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
      sdram_ras => sdram_ras, sdram_cas => sdram_cas,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk,
      sdram_we => sdram_we, sdram_cs => sdram_cs
    );

end Behavioral;
