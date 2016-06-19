-- (c)EMARD
-- License=BSD

-- this is glue module with mmio bus interface to f32c cpu
-- only a few registers which provide

-- * address for load/store to/from RAM
-- * command to start vector functional units
-- * monitoring vector function progress
-- * interrupt flags

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.axi_pack.all;

entity vector is
  generic
  (
    C_addr_bits: integer := 3; -- don't touch: number of address bits for the registers
    C_axi: boolean := true; -- false: f32c bus for vector I/O, true: AXI bus for vector I/O
    C_bits: integer range 2 to 32 := 32  -- number of bits in each mmio register
  );
  port
  (
    ce, clk: in std_logic;
    bus_write: in std_logic;
    addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 registers of 32-bit
    byte_sel: in std_logic_vector(3 downto 0);
    bus_in: in std_logic_vector(31 downto 0);
    bus_out: out std_logic_vector(31 downto 0);
    axi_in: in T_axi_miso;
    axi_out: out T_axi_mosi;
    vector_irq: out std_logic
  );
end vector;

architecture arch of vector is
    constant C_mmio_registers: integer range 4 to 16 := 4; -- total number of memory backed mmio registers

    constant C_vectors: integer range 2 to 16 := 2; -- total number of vector registers (BRAM blocks)
    constant C_vectors_bits: integer range 1 to 4 := 1; -- number of bits to select the vector register 
    constant C_vaddr_bits: integer range 2 to 16 := 11; -- number of address bits for BRAM vector
    constant C_vdata_bits: integer range 32 to 64 := 32; -- number of data bits for each vector

    -- normal registers
    type T_mmio_regs is array (C_mmio_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: T_mmio_regs; -- register access from mmapped I/O  R: active register

    -- *** REGISTERS ***
    -- named constants for vector DMA control registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_vaddress:   integer   := 0; -- vector struct RAM address
    constant C_vdone_if:   integer   := 1; -- vector done interrupt flag
    constant C_vdone_ie:   integer   := 2; -- vector done interrupt enable
    constant C_vcounter:   integer   := 3; -- vector progress counter (write to select which register to monitor)
    constant C_vcommand:   integer   := 4; -- vector processor command

    -- *** VECTORS ***
    -- progress counter register array for all vectors
    type T_vaddr is array (C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits downto 0);
    signal VI: T_vaddr; -- VI-internal counter for functional units
    type T_vdata is array (C_vectors-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_vector_load, S_vector_store: T_vdata; -- vectors to RAM I/O lines

    -- *** RAM I/O ***
    signal S_io_bram_we: std_logic;
    signal S_io_bram_addr: std_logic_vector(C_vaddr_bits-1 downto 0); -- RAM address to load/store
    signal S_io_bram_rdata, S_io_bram_wdata: std_logic_vector(C_vdata_bits-1 downto 0); -- channel to RAM
    signal R_io_store_mode: std_logic; -- '0': load vectors from RAM, '1': store vector to RAM
    signal R_io_store_select: std_logic_vector(C_vectors_bits-1 downto 0); -- select one vector to store
    signal R_io_load_select, S_io_bram_we_select: std_logic_vector(C_vectors-1 downto 0); -- select multiple vectors load from the same RAM location
    signal R_io_request: std_logic; -- set to '1' during one clock cycle (not longer) to properly initiate RAM I/O
    signal S_io_done: std_logic;

    -- command decoder should load
    -- R_store_mode, R_store_select, R_load_select
    -- and issue a 1-clock pulse on S_start_io

    -- vector done detection register (unused, just 0)
    signal R_rising_edge: std_logic_vector(C_bits-1 downto 0) := (others => '0');
begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <=
        ext(x"DEBA66AA", 32)
          when C_vcommand,
        ext(R_io_request & S_io_done & S_io_bram_addr, 32)
          when C_vcounter,
        ext(R(conv_integer(addr)),32)
          when others;

    -- CPU core writes registers
    -- and edge interrupt flags handling
    -- interrupt flags can be reset by writing 1, writing 0 is nop -> see code "and not"
    G_writereg_intrflags:
    for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' then
            if ce = '1' and bus_write = '1' then
              if conv_integer(addr) = C_vdone_if
              then -- logical and for interrupt flag registers
                R(conv_integer(addr))(8*i+7 downto 8*i) <= -- only can clear intr. flag, never set
                R(conv_integer(addr))(8*i+7 downto 8*i) and not bus_in(8*i+7 downto 8*i);
              else -- normal write for every other register
                R(conv_integer(addr))(8*i+7 downto 8*i) <= bus_in(8*i+7 downto 8*i);
              end if;
            else
              R(C_vdone_if)(8*i+7 downto 8*i) <= -- only can set intr. flag, never clear
              R(C_vdone_if)(8*i+7 downto 8*i) or R_rising_edge(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;

    -- join all interrupt request bits into one bit
    vector_irq <= '1' when
                    (  ( R(C_vdone_ie)  and R(C_vdone_if)  )
                    ) /= ext("0",C_bits) else '0';

    -- command decoder
    process(clk)
    begin
      if rising_edge(clk) then
        -- command accepted only if written in 32-bit word
        if ce='1' and bus_write='1' and byte_sel="1111" then
          if conv_integer(addr) = C_vcommand then
            R_io_store_mode <= bus_in(23); -- RAM write cycle
            R_io_store_select <= bus_in(C_vectors_bits-1+0 downto 0); -- byte 0, vector number to store
            R_io_load_select <= bus_in(C_vectors-1+8 downto 8); -- byte 1 bitmask of vectors to load
            R_io_request <= '1';
          end if;
        else
          R_io_request <= '0';
        end if;
      end if;
    end process;

    G_vector_registers:
    for i in 0 to C_vectors-1 generate
      vector_bram: entity work.bram_true2p_1clk
      generic map
      (
        dual_port => True, -- one port takes data from RAM, other port outputs to video
        pass_thru_a => True, -- false allows simultaneous reading and erasing of old data
        pass_thru_b => True, -- false allows simultaneous reading and erasing of old data
        data_width => C_vdata_bits,
        addr_width => C_vaddr_bits
      )
      port map
      (
        clk => clk,
        we_a => S_io_bram_we_select(i),
        we_b => '0', -- VPU write
        addr_a => S_io_bram_addr, -- external address (RAM I/O)
        addr_b => VI(i)(C_vaddr_bits-1 downto 0), -- internal address (VECTOR PROCESSOR)
        data_in_a => S_io_bram_wdata,
        data_in_b => (others => '0'), -- to VPU
        data_out_a => S_vector_store(i),
        data_out_b => open -- to VPU
      );
      S_io_bram_we_select(i) <= R_io_load_select(i) and S_io_bram_we; -- counter out, disable write
    end generate;
    S_io_bram_rdata <= S_vector_store(conv_integer(R_io_store_select)); -- multiplexer

    -- load/store asymmetry:
    -- vector load: (1-to-many) all bus lines are connected to RAM data
    --              all vector registers can be loaded with the same RAM data
    -- vector store: (1-to-1) only one vector can be stored at a time

    G_axi_dma:
    if C_axi generate
      I_axi_vector_dma:
      entity work.axi_vector_dma
      generic map
      (
        C_vaddr_bits => C_vaddr_bits, -- number of bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
        C_vdata_bits => C_vdata_bits, -- number of data bits
        C_burst_max => 1 -- max burst allowed by DMA longer transfers will be split in no.of bursts
      )
      port map
      (
        clk => clk,

        -- vector processor control from mmio
        store_mode => R_io_store_mode, -- '0' load (read from RAM), '1' store (write to RAM)
        addr => R(C_vaddress)(29 downto 2), -- pointer to vector struct in RAM
        request => R_io_request, -- 1-cycle pulse to start a I/O request
        done => S_io_done, -- goes to 0 after accepting I/O request, returns to 1 when done

        -- bram interface
        bram_we => S_io_bram_we,
        bram_addr => S_io_bram_addr,
        bram_wdata => S_io_bram_wdata,
        bram_rdata => S_io_bram_rdata,

        -- axi interface
        axi_in => axi_in, axi_out => axi_out
      );
    end generate;


    -- functional units
    -- no working functional units yet
    -- this just rolls some VI counters
    process(clk)
    begin
      if rising_edge(clk) then
        VI(0) <= VI(0) + 1;
      end if;
    end process;

    process(clk)
    begin
      if rising_edge(clk) then
        VI(1) <= VI(1) - 1;
      end if;
    end process;

end;
