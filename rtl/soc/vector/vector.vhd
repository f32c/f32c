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
--use ieee.numeric_std.all;

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
    addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 mmio registers of 32-bit
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

    constant C_vectors: integer range 2 to 16 := 8; -- total number of vector registers (BRAM blocks)
    constant C_vectors_bits: integer range 1 to 4 := 3; -- number of bits to select the vector register
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
    type T_vaddr is array (C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits-1 downto 0);
    signal S_VI: T_vaddr; -- VI-internal counter register for functional units
    --signal R_VI_increment, R_VI_reset: std_logic_vector(C_vectors-1 downto 0); -- bit mask which VI do increment
    type T_vdata is array (C_vectors-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_vector_load, S_vector_store: T_vdata; -- vectors to RAM I/O lines
    signal S_VARG, S_VRES: T_vdata; -- switchbar connection for arguments and results
    -- each vector has its write enable signal
    signal S_vector_we: std_logic_vector(C_vectors-1 downto 0);
    signal R_vector_we: std_logic_vector(C_vectors-1 downto 0); -- rising edge tracking
    signal S_vdone_interrupt: std_logic_vector(C_vectors-1 downto 0);
    -- Register to track length of vector. So shorter than max length vectors
    -- can be calculated faster
    type T_vector_length is array (C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits downto 0);
    signal R_vector_length: T_vector_length;

    -- *** RAM I/O ***
    signal S_io_bram_we: std_logic;
    signal S_io_bram_addr: std_logic_vector(C_vaddr_bits downto 0); -- RAM address to load/store
    signal S_io_bram_rdata, S_io_bram_wdata: std_logic_vector(C_vdata_bits-1 downto 0); -- channel to RAM
    signal R_io_store_mode: std_logic; -- '0': load vectors from RAM, '1': store vector to RAM
    signal R_io_store_select: std_logic_vector(C_vectors_bits-1 downto 0); -- select one vector to store
    signal R_io_load_select, S_io_bram_we_select: std_logic_vector(C_vectors-1 downto 0); -- select multiple vectors load from the same RAM location
    signal R_io_request: std_logic; -- set to '1' during one clock cycle (not longer) to properly initiate RAM I/O
    signal S_io_done: std_logic;
    signal R_io_done: std_logic_vector(1 downto 0) := (others => '1');
    signal S_io_done_interrupt: std_logic;
    -- command decoder should load
    -- R_store_mode, R_store_select, R_load_select
    -- and issue a 1-clock pulse on R_io_request

    -- *** Functional multiplexing ***
    -- 4 main different functions
    -- a function can have modifier that selects one from many of similar functions
    constant C_functions: integer := 4; -- total number of functional units
    constant C_functions_bits: integer := 2; -- total number bits to address one functional unit
    constant C_function_fpu_arith: integer range 0 to C_functions-1 := 0; -- +,-,*,/,i2f,f2i
    constant C_function_fpu_divide: integer range 0 to C_functions-1 := 1; -- <,>,...
    constant C_function_int_add: integer range 0 to C_functions-1 := 2; -- a=b+c, a=b-c
    constant C_function_int_mul: integer range 0 to C_functions-1 := 3; -- a=b*c
    -- all functions will broadcast results
    type T_function_result is array (C_functions-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal R_function_result, S_function_result: T_function_result;
    -- each functional unit will have 2 vector index counters for the argument and the result
    -- even counter is the result, odd counter is the argument
    -- using 1 bit more (actual bit length is C_vaddr_bits+1)
    -- so vector can start negative and MSB bit can be used as write enable and
    -- simplifying length arithmetic comparisons
    type T_function_vi is array (2*C_functions-1 downto 0) of std_logic_vector(C_vaddr_bits downto 0);
    signal R_function_vi: T_function_vi := (others => (others =>'1'));
    -- each vector can become a 'listener' to one of the selected results
    -- twice as many functions are the number of possible vector indexers
    -- each function has its argument and result counter
    type T_vector_indexed_by is array (C_vectors-1 downto 0) of std_logic_vector(C_functions_bits downto 0);
    -- which function's index will run index for vector i
    -- indexes are x2, even are arguments, odd are results
    -- set all to 1 to initially avoid unwanted results to get written
    signal R_vector_indexed_by: T_vector_indexed_by := (others => (others => '1'));

    signal S_add_arg_vi: integer range 0 to C_vaddr_bits-1;
    signal R_function_request, R_function_busy: std_logic_vector(C_functions-1 downto 0);
    -- each function can have different pipeline propagation delay
    type T_function_propagation_delay is array (0 to C_functions-1) of integer;
    constant C_function_propagation_delay: T_function_propagation_delay :=
    (
      5, -- C_function_fpu_arith +,-,*
      7, -- C_function_fpu_divide /
      1, -- C_function_int_add
      1  -- C_function_int_mul
    );
    signal S_function_last_element: std_logic_vector(C_functions-1 downto 0); -- is function indexing the last element of result vector
    type T_function_vector_select is array (0 to C_functions-1) of std_logic_vector(C_vectors_bits-1 downto 0);
    signal R_function_result_select, R_function_arg1_select, R_function_arg2_select: T_function_vector_select;

    -- *** integer ADD function ***
    signal R_add_mode: std_logic_vector(3 downto 0); -- bit0: 0:+  1:-
    signal S_add_operator_result, S_add_operator_plus, S_add_operator_minus: std_logic_vector(C_vdata_bits-1 downto 0);

    -- *** integer MULTIPLY function ***
    signal R_mul_mode: std_logic_vector(3 downto 0); -- bit0: 0:unsigned 1:signed
    signal S_mul_operator_result: std_logic_vector(2*C_vdata_bits-1 downto 0);
    --signal S_muls_arg1, S_muls_arg2: signed(C_vdata_bits-1 downto 0);
    --signal S_muls_result: signed(2*C_vdata_bits-1 downto 0);

    -- *** floating point unit arithmetic functions ***
    signal R_fpu_arith_mode: std_logic_vector(3 downto 0); -- select which float operation to execute
    signal S_fpu_arith_operator_result: std_logic_vector(C_vdata_bits-1 downto 0);

    -- vector done detection register
    signal S_interrupt_edge: std_logic_vector(C_bits-1 downto 0) := (others => '0');
begin
    -- *** MMIO interface ***

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
          if byte_sel(i) = '1'
          and ce = '1' and bus_write = '1'
          and conv_integer(addr) = C_vdone_if
          then
            R(C_vdone_if)(8*i+7 downto 8*i) <= -- only can clear intr. flag, never set
            R(C_vdone_if)(8*i+7 downto 8*i) and not bus_in(8*i+7 downto 8*i); -- write 1's to clear flags
          else
            if byte_sel(i) = '1'
            and ce = '1' and bus_write = '1'
            and conv_integer(addr) /= C_vdone_if
            then
              R(conv_integer(addr))(8*i+7 downto 8*i) <= bus_in(8*i+7 downto 8*i);
            else
              R(C_vdone_if)(8*i+7 downto 8*i) <= -- only can set intr. flag, never clear
              R(C_vdone_if)(8*i+7 downto 8*i) or S_interrupt_edge(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;

    -- join all interrupt request bits into one output bit (reduction-or)
    vector_irq <= '1' when
                    (  ( R(C_vdone_ie)  and R(C_vdone_if)  )
                    ) /= ext("0",C_bits) else '0';

    -- *** interrupts ***
    -- storing old value to register has purpuse
    -- to detect edge and generate single clock cycle pulse
    -- which is used to raise interrupt flags
    process(clk)
    begin
      if rising_edge(clk) then
        R_vector_we <= S_vector_we;
        R_io_done <= S_io_done & R_io_done(1);
      end if;
    end process;
    -- falling edge of functional vector write enable signal "S_vector_we" indicates
    -- the completion of vector operation (vdone interrupt)
    S_vdone_interrupt <= R_vector_we and not S_vector_we; -- '1' on falling edge
    S_interrupt_edge(C_vectors-1 downto 0) <= S_vdone_interrupt; -- S_interrupt_edge is larger (32-bit)
    -- rising edge of "S_io_done" indicates
    -- the completion of vector I/O operation
    S_io_done_interrupt <= R_io_done(1) and not R_io_done(0); -- '1' on rising edge
    S_interrupt_edge(16) <= S_io_done_interrupt;



    -- *** MMIO command decoder ***
    process(clk)
    begin
      if rising_edge(clk) then
        -- command accepted only if written in 32-bit word
        if ce='1' and bus_write='1' and byte_sel="1111" then
          if conv_integer(addr) = C_vcommand then
            if bus_in(31 downto 24) = x"01" then -- command 0x01 I/O
              R_io_store_mode <= bus_in(23); -- RAM write cycle
              R_io_store_select <= bus_in(C_vectors_bits-1+0 downto 0); -- byte 0, vector number to store
              R_io_load_select <= bus_in(C_vectors-1+8 downto 8); -- byte 1 bitmask of vectors to load
              R_io_request <= '1';
            end if;
            if bus_in(31 downto 24) = x"21" then -- command 0x21 integer add
              R_add_mode <= bus_in(19 downto 16); -- Add mode
              -- select which vector will listen to results of 'add' functional unit
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+0 downto 0))) <= -- result
                conv_std_logic_vector(C_function_int_add, C_functions_bits) & '1'; -- func result index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+4 downto 4))) <= -- arg1
                conv_std_logic_vector(C_function_int_add, C_functions_bits) & '0'; -- func arg index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+8 downto 8))) <= -- arg2
                conv_std_logic_vector(C_function_int_add, C_functions_bits) & '0'; -- func arg index
              -- which vector indexes values will be selected by core function
              --R_add_result_select <= bus_in(C_vectors_bits-1+8 downto 8);
              R_function_result_select(C_function_int_add) <= bus_in(C_vectors_bits-1+0 downto 0);
              --R_add_arg1_select <= bus_in(C_vectors_bits-1+4 downto 4);
              R_function_arg1_select(C_function_int_add) <= bus_in(C_vectors_bits-1+4 downto 4);
              --R_add_arg2_select <= bus_in(C_vectors_bits-1+0 downto 0);
              R_function_arg2_select(C_function_int_add) <= bus_in(C_vectors_bits-1+8 downto 8);
              -- start functional unit
              R_function_request(C_function_int_add) <= '1';
            end if;
            if bus_in(31 downto 24) = x"23" then -- command 0x23 integer multiply
              --R_mul_mode <= bus_in(19 downto 16); -- Add mode
              -- select which vector will listen to results of 'add' functional unit
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+0 downto 0))) <= -- result
                conv_std_logic_vector(C_function_int_mul, C_functions_bits) & '1'; -- func result index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+4 downto 4))) <= -- arg1
                conv_std_logic_vector(C_function_int_mul, C_functions_bits) & '0'; -- func arg index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+8 downto 8))) <= -- arg2
                conv_std_logic_vector(C_function_int_mul, C_functions_bits) & '0'; -- func arg index
              -- which vector indexes values will be selected by core function
              --R_mul_result_select <= bus_in(C_vectors_bits-1+8 downto 8);
              R_function_result_select(C_function_int_mul) <= bus_in(C_vectors_bits-1+0 downto 0);
              --R_mul_arg1_select <= bus_in(C_vectors_bits-1+4 downto 4);
              R_function_arg1_select(C_function_int_mul) <= bus_in(C_vectors_bits-1+4 downto 4);
              --R_mul_arg2_select <= bus_in(C_vectors_bits-1+0 downto 0);
              R_function_arg2_select(C_function_int_mul) <= bus_in(C_vectors_bits-1+8 downto 8);
              -- start functional unit
              R_function_request(C_function_int_mul) <= '1';
            end if;
            if bus_in(31 downto 24) = x"33" then -- command 0x33 fpu arithmetic
              R_fpu_arith_mode <= bus_in(19 downto 16); -- Add mode
              -- select which vector will listen to results of 'fpu arith' functional unit
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+0 downto 0))) <= -- result
                conv_std_logic_vector(C_function_fpu_arith, C_functions_bits) & '1'; -- func result index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+4 downto 4))) <= -- arg1
                conv_std_logic_vector(C_function_fpu_arith, C_functions_bits) & '0'; -- func arg index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+8 downto 8))) <= -- arg2
                conv_std_logic_vector(C_function_fpu_arith, C_functions_bits) & '0'; -- func arg index
              -- which vector indexes values will be selected by core function
              --R_fpu_arith_result_select <= bus_in(C_vectors_bits-1+8 downto 8);
              R_function_result_select(C_function_fpu_arith) <= bus_in(C_vectors_bits-1+0 downto 0);
              --R_fpu_arith_arg1_select <= bus_in(C_vectors_bits-1+4 downto 4);
              R_function_arg1_select(C_function_fpu_arith) <= bus_in(C_vectors_bits-1+4 downto 4);
              --R_fpu_arith_arg2_select <= bus_in(C_vectors_bits-1+0 downto 0);
              R_function_arg2_select(C_function_fpu_arith) <= bus_in(C_vectors_bits-1+8 downto 8);
              -- start functional unit
              R_function_request(C_function_fpu_arith) <= '1';
            end if;
            if bus_in(31 downto 24) = x"34" then -- command 0x34 fpu divide
              -- select which vector will listen to results of 'fpu divide' functional unit
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+0 downto 0))) <= -- result
                conv_std_logic_vector(C_function_fpu_divide, C_functions_bits) & '1'; -- func result index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+4 downto 4))) <= -- arg1
                conv_std_logic_vector(C_function_fpu_divide, C_functions_bits) & '0'; -- func arg index
              R_vector_indexed_by(conv_integer(bus_in(C_vectors_bits-1+8 downto 8))) <= -- arg2
                conv_std_logic_vector(C_function_fpu_divide, C_functions_bits) & '0'; -- func arg index
              -- which vector indexes values will be selected by core function
              --R_fpu_arith_result_select <= bus_in(C_vectors_bits-1+8 downto 8);
              R_function_result_select(C_function_fpu_divide) <= bus_in(C_vectors_bits-1+0 downto 0);
              --R_fpu_arith_arg1_select <= bus_in(C_vectors_bits-1+4 downto 4);
              R_function_arg1_select(C_function_fpu_divide) <= bus_in(C_vectors_bits-1+4 downto 4);
              --R_fpu_arith_arg2_select <= bus_in(C_vectors_bits-1+0 downto 0);
              R_function_arg2_select(C_function_fpu_divide) <= bus_in(C_vectors_bits-1+8 downto 8);
              -- start functional unit
              R_function_request(C_function_fpu_divide) <= '1';
            end if;
          end if;
        else
          R_io_request <= '0';
          R_function_request <= (others => '0');
        end if;
        -- this is needed to keep vector from being unwantedly
        -- overwritten by next run of the same functional unit
        for i in 0 to C_vectors-1 loop
          if S_vdone_interrupt(i)='1' then
            R_vector_indexed_by(i)(0) <= '0'; -- detach this vector from functional unit write
          end if;
        end loop;
      end if;
    end process;


    -- *** I/O DMA MODULE ***
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
        C_burst_read_max => 64, -- max burst allowed by DMA. longer transfers will be split in many bursts
        C_burst_write_max => 64
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


    -- *** VECTOR LENGTH ***
    -- 1. set result length when function is done ("S_vdone_interrupt")
    -- 2. set arg length when I/O vector load operation is done
    G_vector_length:
    for i in 0 to C_vectors-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if S_vdone_interrupt(i)='1' then
            R_vector_length(i) <= S_VI(i); -- after function done, store S_VI index of the vector into the register
          else
            if S_io_done_interrupt='1' and R_io_load_select(i)='1' and R_io_store_mode='0' then
              R_vector_length(i) <= S_io_bram_addr;
            end if;
          end if;
        end if;
      end process;
    end generate;


    -- *** functions indexer ***
    -- accepts requests to start a functional unit
    -- R_function_vi: 2*i+1 for argument, 2*i for result
    G_functions_indexer:
    for i in 0 to C_functions-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if R_function_request(i)='1' and R_function_busy(i)='0' then
            R_function_busy(i) <= '1';
            R_function_vi(2*i) <= (others => '0'); -- argument counter start from 0
            -- result counter starts with negative propagation delay
            R_function_vi(2*i+1) <= conv_std_logic_vector(-C_function_propagation_delay(i), C_vaddr_bits+1);
          else
            if R_function_busy(i)='1' then
              R_function_vi(2*i) <= R_function_vi(2*i) + 1; -- arg counter
              R_function_vi(2*i+1) <= R_function_vi(2*i+1) + 1; -- result counter
              if S_function_last_element(i)='1' then
                R_function_busy(i) <= '0';
              end if;
            end if;
          end if;
        end if;
      end process;
      S_function_last_element(i) <= '1'
        when R_function_vi(2*i+1) -- result index
           = R_vector_length(conv_integer(R_function_arg1_select(i))) -- arg vector size
                               else '0';
    end generate; -- G_functions_indexer


    -- *** functional units ***
    -- core funtions
    -- operations with optional modifiers generate the results
    S_add_operator_plus  <= S_VARG(conv_integer(R_function_arg1_select(C_function_int_add)))
                          + S_VARG(conv_integer(R_function_arg2_select(C_function_int_add)));
    S_add_operator_minus <= S_VARG(conv_integer(R_function_arg1_select(C_function_int_add)))
                          - S_VARG(conv_integer(R_function_arg2_select(C_function_int_add)));
    S_function_result(C_function_int_add) <= S_add_operator_plus when R_add_mode(0) = '0'
                                        else S_add_operator_minus;

    --S_muls_arg1 <= (S_VARG(conv_integer(R_function_arg1_select(C_function_int_mul))), C_vdata_bits);
    --S_muls_arg2 <= (S_VARG(conv_integer(R_function_arg2_select(C_function_int_mul))), C_vdata_bits);
    --S_muls_result <= S_muls_arg1 * S_muls_arg2;

    S_mul_operator_result <= S_VARG(conv_integer(R_function_arg1_select(C_function_int_mul)))
                           * S_VARG(conv_integer(R_function_arg2_select(C_function_int_mul)));
    S_function_result(C_function_int_mul) <= S_mul_operator_result(C_vdata_bits-1 downto 0);

    I_fpu_arithmetic:
    entity work.fpu_vhd
    port map
    (
      clk => clk,
      rmode => "00", -- round to nearest even
      fpu_op => R_fpu_arith_mode(2 downto 0), -- float op 000 add, 010 multiply
      opa => S_VARG(conv_integer(R_function_arg1_select(C_function_fpu_arith))),
      opb => S_VARG(conv_integer(R_function_arg2_select(C_function_fpu_arith))),
      result => S_function_result(C_function_fpu_arith)
    );

    I_fpu_divide:
    entity work.float_divide_goldschmidt
    port map
    (
      clk => clk,
      X => S_VARG(conv_integer(R_function_arg1_select(C_function_fpu_divide))),
      Y => S_VARG(conv_integer(R_function_arg2_select(C_function_fpu_divide))),
      Q => S_function_result(C_function_fpu_divide)
    );

    -- registering for fmax improvement
    -- result from each core function is
    -- moved to temporary register array "R_function_result" in 1 clock cycle delay
    -- the outputs from temporary regisers are broadcast (collected later by listeners)
    -- this will add 1 extra cycle delay to the
    -- functional unit pipeline delay
    G_registered_results:
    for i in 0 to C_functions-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          -- R_function_resulut will be valid 1 cycle later
          R_function_result(i) <= S_function_result(i);
        end if;
      end process;
    end generate;


    -- *** cross-switching from functional unit registers to vector registers ***
    -- concept of listeners
    -- each vector can 'listen' to result of any functional unit
    G_listeners:
    for i in 0 to C_vectors-1 generate
      S_VRES(i) <= R_function_result(conv_integer(R_vector_indexed_by(i)(C_functions_bits downto 1)));
      S_VI(i) <= R_function_vi(conv_integer(R_vector_indexed_by(i)))(C_vaddr_bits-1 downto 0);
      -- if vector-indexing function is busy
      -- and if vector is indexed by result register (odd number, LSB=1)
      -- then set "write enable" to the vector register
      -- important: R_vector_indexed_by should be set LSB='0' after the function is done
      -- otherwise previously written vector will be accidentaly overwritten by next function
      S_vector_we(i) <= R_function_busy(conv_integer(R_vector_indexed_by(i)(C_functions_bits downto 1)))
                        and R_vector_indexed_by(i)(0); -- indexed by LSB=1 means indexed by function result register
    end generate; -- G_listeners

    -- *** VECTOR REGISTERS BRAM storage ***
    G_vector_registers:
    for i in 0 to C_vectors-1 generate
      vector_bram: entity work.bram_true2p_1clk
      generic map
      (
        dual_port => True, -- one port takes data from RAM, other port outputs to video
        pass_thru_a => False, -- false allows simultaneous reading and erasing of old data
        pass_thru_b => False, -- false allows simultaneous reading and erasing of old data
        data_width => C_vdata_bits,
        addr_width => C_vaddr_bits
      )
      port map
      (
        clk => not clk, -- BRAM on falling clk edge is a must for AXI burst write to RAM
        -- falling edge of the clock also reduced functional unit delay by 1 cycle
        -- note: the f32c core also works with BRAM on falling edge
        we_a => S_io_bram_we_select(i),
        we_b => S_vector_we(i), -- vector write enable from functional unit
        addr_a => S_io_bram_addr(C_vaddr_bits-1 downto 0), -- external address (RAM I/O)
        addr_b => S_VI(i), -- internal address from functional unit
        data_in_a => S_io_bram_wdata,
        data_in_b => S_VRES(i), -- result from functional unit
        data_out_a => S_vector_store(i),
        data_out_b => S_VARG(i) -- argument to functional unit
      );
      S_io_bram_we_select(i) <= R_io_load_select(i) and S_io_bram_we; -- counter out, disable write
    end generate;
    S_io_bram_rdata <= S_vector_store(conv_integer(R_io_store_select)); -- multiplexer


end;

-- command example
-- 0x01000100  load V(0) from RAM
-- 0x01800000  store V(0) to RAM
-- 0x01000200  load V(1) from RAM
-- 0x01800001  store V(1) to RAM
-- 0x01000400  load V(2) from RAM
-- 0x01800002  store V(2) to RAM
-- 0x01000800  load V(3) from RAM
-- 0x01800003  store V(3) to RAM
-- 0x21000123  V(3) = V(2) + V(1)
-- 0x21000201  V(1) = V(0) + V(2)
-- 0x21010201  V(1) = V(0) - V(2)
-- 0x23000201  V(1) = V(0) * V(2)
-- 0x33000210  V(0) = V(1) + V(2) float
-- 0x33010210  V(0) = V(1) - V(2) float
-- 0x33020210  V(0) = V(1) * V(2) float
-- 0x34000210  V(0) = V(1) / V(2) float
-- 0x33040210  V(0) = i2f(V(1))   int->float
-- 0x33050210  V(0) = f2i(V(1))   float->int

--  C usage

-- volatile uint32_t *vector_ptr = (volatile uint32_t *)0xFFFFFC20;
-- void wait_vector(void)
-- {
--   uint32_t a;
--   do
--   {
--     a = vector_ptr[1];
--   } while(a == 0);
--   vector_ptr[1] = a; // clear interrupt flag(s)
-- }

--  vector_ptr[0] = red_green+200*256;
--  vector_ptr[4] = 0x01000400; // load vector 1
--  delay(4);
--  vector_ptr[0] = green_blue;
--  vector_ptr[4] = 0x01000200; // load vector 2
--  delay(4);
--  vector_ptr[4] = 0x21000210; // v(0) = v(1) + v(2)
--  delay(4);
--  vector_ptr[0] = green_blue+128*256;
--  vector_ptr[4] = 0x01800000; // store vector 0 (vector number)


-- TODO:

-- [*] I/O vector length for load
-- [ ] I/O vector length for store
-- [ ] I/O should interprete linked list (now it does simple linear block)

-- [*] indexer to control vector lengths and write signals
-- [*] simplify indexer with for loop and indexed registers
-- [*] indexer should count function pipeline delay cycles
-- [*] indexer should handle pipeline delay
-- [*] indexer should count vector lengths

-- [ ] 64/32/16 bit mode: element size is 64-bit
--     1 parallel 64-bit unit
--     2 parallel 32-bit units
--     4 parallel 16-bit units

-- [*] interrupt flag set on function done
-- [*] at end of function, un-listen the result "indexed_by" setting LSB=0
-- [*] interrupt flag set for I/O done
-- [ ] rewrite command decoding to avoid sequential register writes
-- [ ] signed integer multiply
-- [ ] fix FPU divide "/" (propagation delay problem)
