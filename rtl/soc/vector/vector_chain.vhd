-- (c)EMARD
-- License=BSD

-- f32c vector processor module
-- supports all types of expressions
-- normal: A=B+C
-- compound: A=A+B, A=A+A

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
--use ieee.numeric_std.all;
use ieee.math_real.all; -- to calculate log2 bit size

entity vector is
  generic
  (
    C_addr_bits: integer := 3; -- don't touch: number of address bits for the registers
    C_vaddr_bits: integer range 2 to 16 := 11; -- number of address bits for BRAM vector
    C_vdata_bits: integer range 32 to 64 := 32; -- number of data bits for each vector
    C_vectors: integer range 2 to 16 := 8; -- total number of vector registers (BRAM blocks)
    C_float_addsub: boolean := true; -- instantiate floating point addsub (+,-)
    C_float_multiply: boolean := true; -- instantiate floating point divider (*)
    C_float_divide: boolean := true; -- instantiate floating point divider (/) (LUT and DSP eater)
    C_invert_bram_clk_reg: boolean := false; -- esa11 artix7-axi needs true, spartan6-f32c needs false
    C_invert_bram_clk_io: boolean := false; -- both artix7-axi and spartan6-f32c work with false
    C_bram_in_reg: boolean := false; -- extra register layer on vector bram in
    C_bram_out_reg: boolean := false; -- extra register layer on vector bram out
    C_function_result_reg: boolean := false; -- register layer on functional unit result
    C_bits: integer range 2 to 32 := 32  -- don't touch, number of bits in each mmio register
  );
  port
  (
    ce, clk: in std_logic;
    bus_write: in std_logic;
    addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 mmio registers of 32-bit
    byte_sel: in std_logic_vector(3 downto 0);
    bus_in: in std_logic_vector(31 downto 0);
    bus_out: out std_logic_vector(31 downto 0);

    -- the vector I/O module interface
    io_store_mode: out std_logic;
    io_addr: out std_logic_vector(29 downto 2);
    io_request: out std_logic;
    io_done: in std_logic;
    io_bram_we: in std_logic;
    io_bram_next: in std_logic;
    io_bram_addr: in std_logic_vector(C_vaddr_bits downto 0);
    io_bram_wdata: in std_logic_vector(C_vdata_bits-1 downto 0);
    io_bram_rdata: out std_logic_vector(C_vdata_bits-1 downto 0);

    -- f32c interrupt
    vector_irq: out std_logic
  );
end vector;

architecture arch of vector is
    -- useful for conversion from KB to number of address bits
    function ceil_log2(x: integer)
      return integer is
    begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
    end ceil_log2;

    constant C_mmio_registers: integer range 4 to 16 := 4; -- total number of memory backed mmio registers

    constant C_vectors_bits: integer range 1 to 4 := ceil_log2(C_vectors); -- number of bits to select the vector register

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
    signal R_vector_index, S_vector_index_last: T_vaddr; -- VI-internal counter register for functional units
    signal R_vector_index_reset, R_vector_write, R_vector_write_request: std_logic_vector(C_vectors-1 downto 0); -- signals to reset vector index
    signal R_vector_write_prev_cycle: std_logic_vector(C_vectors-1 downto 0); -- rising edge tracking
    signal S_vdone_interrupt: std_logic_vector(C_vectors-1 downto 0);
    signal S_vector_index_run: std_logic_vector(C_vectors-1 downto 0);
    type T_vdata is array (C_vectors-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_vector_load, S_vector_store: T_vdata; -- vectors to RAM I/O lines
    signal S_VARG, R_VRES: T_vdata; -- switchbar connection for arguments and results
    signal R_VARG: T_vdata; -- switchbar connection for arguments and results
    -- Register to track length of vector. So shorter than max length vectors
    -- can be calculated faster
    type T_vector_length is array (C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits downto 0);
    signal R_vector_length, R_result_vector_length: T_vector_length; -- true length-1, 0 -> 1 element, 1 -> 2 elements ...
    signal R_vector_shift, R_result_vector_shift, S_io_bram_addr_shift: T_vector_length; -- points to 1st element in vector
    signal R_delay_vector_length: std_logic_vector(C_vectors-1 downto 0) := (others => '0');
    signal R_vector_load_request: std_logic_vector(C_vectors-1 downto 0) := (others => '0');
    signal R_vector_io_flowcontrol: std_logic_vector(C_vectors-1 downto 0) := (others => '0');

    -- *** RAM I/O ***
    signal S_io_bram_we: std_logic;
    signal S_io_bram_next: std_logic;
    signal R_io_bram_next: std_logic;
    signal S_io_bram_addr: std_logic_vector(C_vaddr_bits downto 0); -- RAM address to load/store
    signal S_io_bram_rdata, R_io_bram_wdata: std_logic_vector(C_vdata_bits-1 downto 0); -- channel to RAM
    signal R_io_bram_rdata: std_logic_vector(C_vdata_bits-1 downto 0); -- channel to RAM
    signal R_io_store_mode: std_logic; -- '0': load vectors from RAM, '1': store vector to RAM
    signal R_io_store_select: std_logic_vector(C_vectors_bits-1 downto 0); -- select one vector to store
    signal R_io_load_select, S_io_bram_we_select: std_logic_vector(C_vectors-1 downto 0); -- select multiple vectors load from the same RAM location
    signal R_io_request: std_logic; -- set to '1' during one clock cycle (not longer) to properly initiate RAM I/O
    signal S_io_done: std_logic;
    signal R_io_done: std_logic_vector(1 downto 0) := (others => '1');
    signal S_io_done_interrupt: std_logic;
    signal S_bram_clk_reg, S_bram_clk_io: std_logic;
    -- command decoder should load
    -- R_store_mode, R_store_select, R_load_select
    -- and issue a 1-clock pulse on R_io_request

    -- *** Functional multiplexing ***
    -- 4 main different functions
    -- a function can have modifier that selects one from many of similar functions
    constant C_functions: integer := 4; -- total number of functional units
    constant C_functions_bits: integer := ceil_log2(C_functions); -- total number bits to address one functional unit
    constant C_function_io: integer range 0 to C_functions-1 := 3; -- I/O
    constant C_function_fpu_addsub: integer range 0 to C_functions-1 := 0; -- +,-
    constant C_function_fpu_multiply: integer range 0 to C_functions-1 := 1; -- *
    constant C_function_fpu_divide: integer range 0 to C_functions-1 := 2; -- /
    -- all functions will broadcast results
    type T_function_result is array (C_functions-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal R_function_result, S_function_result: T_function_result;
    type T_vector_listen_to is array (C_vectors-1 downto 0) of std_logic_vector(C_functions_bits-1 downto 0);
    signal R_vector_listen_to: T_vector_listen_to := (others => (others => '1'));
    --signal S_function_run: std_logic_vector(C_functions-1 downto 0) := (others => '1');

    -- each function can have different pipeline propagation delay
    type T_function_propagation_delay is array (0 to C_functions-1) of integer;
    constant C_function_propagation_delay: T_function_propagation_delay :=
    (
      5, -- C_function_fpu_addsub (+,-)
      5, -- C_function_fpu_multiply (*)
     12, -- C_function_fpu_divide (/)
      1  -- C_function_io (RAM DMA) this affects load, not store
    );
    type T_function_vector_select is array (0 to C_functions-1) of std_logic_vector(C_vectors_bits-1 downto 0);
    signal R_function_arg1_select, R_function_arg2_select: T_function_vector_select;
    signal R_fpu_addsub_mode: std_logic_vector(0 downto 0); -- select float A+B or A-B to execute

    -- simplify writing signals from command decoder
    signal S_cmd_result, S_cmd_arg1, S_cmd_arg2: std_logic_vector(C_vectors_bits-1 downto 0); -- command decoder
    signal SI_cmd_result, SI_cmd_arg1, SI_cmd_arg2: integer range 0 to C_vectors-1;
    signal S_cmd_function: std_logic_vector(C_functions_bits-1 downto 0);
    signal SI_cmd_function: integer range 0 to C_functions-1;
    signal S_cmd_store: std_logic;
    signal S_cmd_addsub_mode: std_logic;
    signal S_cmd_length: std_logic_vector(C_vaddr_bits-1 downto 0);

    -- vector done detection register
    signal S_interrupt_edge: std_logic_vector(C_bits-1 downto 0) := (others => '0');
begin
    -- *** MMIO interface ***
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <=
        ext(x"DEBA66AA", 32)
          when C_vcommand,
        ext(R_io_request & S_io_done, 32)
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
            and conv_integer(addr) < C_mmio_registers
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
        R_vector_write_prev_cycle <= R_vector_write;
        R_io_done <= S_io_done & R_io_done(1);
      end if;
    end process;
    -- falling edge of functional vector write enable signal "S_vector_we" indicates
    -- the completion of vector operation (vdone interrupt)
    S_vdone_interrupt <= R_vector_write_prev_cycle and not R_vector_write; -- '1' on falling edge
    S_interrupt_edge(C_vectors-1 downto 0) <= S_vdone_interrupt; -- S_interrupt_edge is larger (32-bit)
    -- rising edge of "S_io_done" indicates
    -- the completion of vector I/O operation
    S_io_done_interrupt <= R_io_done(1) and not R_io_done(0); -- '1' on rising edge
    S_interrupt_edge(16) <= S_io_done_interrupt;


    -- *** MMIO command decoder ***
    -- signals introduced only for readability
    S_cmd_result <= bus_in(C_vectors_bits-1+0 downto 0);
    SI_cmd_result <= conv_integer(S_cmd_result);
    S_cmd_arg1 <= bus_in(C_vectors_bits-1+4 downto 4);
    SI_cmd_arg1 <= conv_integer(S_cmd_arg1);
    S_cmd_arg2 <= bus_in(C_vectors_bits-1+8 downto 8);
    SI_cmd_arg2 <= conv_integer(S_cmd_arg2);
    S_cmd_function <= bus_in(C_functions_bits-1+24 downto 24);
    SI_cmd_function <= conv_integer(S_cmd_function);
    S_cmd_store <= bus_in(23);
    S_cmd_addsub_mode <= bus_in(16);
    S_cmd_length <= bus_in(C_vaddr_bits-1+8 downto 8);

    process(clk)
    begin
      if rising_edge(clk) then
        -- command accepted only if written in 32-bit word
        if ce='1' and bus_write='1' and byte_sel="1111" then
          if conv_integer(addr) = C_vcommand then
            --if bus_in(31 downto 28) = x"3" then -- command 0x3...
              if S_cmd_function = C_function_io then
                R_io_request <= '1'; -- trigger start of RAM I/O module
                -- Normally arg1 and result should be set to the same value here.
                -- A redundancy, but it allows to reuse
                -- part of command decoding in arithmetic.
                R_io_store_mode <= S_cmd_store; -- RAM write cycle
                -- this will let I/O control increment of vector indexes
                R_vector_io_flowcontrol(SI_cmd_arg1) <= '1';
                R_vector_io_flowcontrol(SI_cmd_result) <= '1';
                -- request Reset vector indexes (2 operands, only 1 used), I/O never uses arg2
                R_vector_index_reset(SI_cmd_arg1) <= '1';
                R_vector_index_reset(SI_cmd_result) <= '1';
                -- I/O module can know vector length only when it reads
                -- last header (too late), we need here to know vector length
                -- in advance. Here CPU must "help" by passing vector length in I/O command
                -- this simplifies vector_indexer.
                R_vector_length(SI_cmd_result) <= '0' & S_cmd_length;
              else
                -- we need separate R_vector_flowcontrol
                R_vector_io_flowcontrol(SI_cmd_arg2) <= '0';
                R_vector_io_flowcontrol(SI_cmd_arg1) <= '0';
                R_vector_io_flowcontrol(SI_cmd_result) <= '0';
                -- request Reset all used vector indexes
                R_vector_index_reset(SI_cmd_arg2) <= '1';
                R_vector_index_reset(SI_cmd_arg1) <= '1';
                R_vector_index_reset(SI_cmd_result) <= '1';
                -- vector length: result = arg1
                R_vector_length(SI_cmd_result) <= R_vector_length(SI_cmd_arg1);
              end if;
              R_fpu_addsub_mode(0) <= S_cmd_addsub_mode; -- ADD/SUB mode 0:+,1:-
              -- set functional unit's argmuents to be read from selected vectors
              R_function_arg2_select(SI_cmd_function) <= S_cmd_arg2;
              R_function_arg1_select(SI_cmd_function) <= S_cmd_arg1;
              -- set result vector shift value (pipeline delay)
              -- vector shift is needed to handle compound operations like A=A+B
              -- Pipeline has delay and there is only one address for R and W to the vector BRAM.
              -- To read data, pass thru functional unit and write to the same register,
              -- the only way is to write result "shifted" by N positions.
              -- N is pipeline propagation delay. So result will appear N positions shifted
              -- relative to original vector data position and we just set result pointer
              -- to new start of the result data.
              R_result_vector_shift(SI_cmd_result) <= R_vector_shift(SI_cmd_result) +
                conv_std_logic_vector(C_function_propagation_delay(SI_cmd_function), C_vaddr_bits+1);
              -- set a vector to listen to results of the selected functional unit
              R_vector_listen_to(SI_cmd_result) <= S_cmd_function;
              -- request write to result vector (the data it listens to get written)
              -- for the store mode write is disabled, a special case.
              R_vector_write_request(SI_cmd_result) <= not S_cmd_store;
            --end if;
          end if;
        else
          R_io_request <= '0';
          R_vector_load_request <= (others => '0');
          R_vector_index_reset <= (others => '0');
          R_vector_write_request <= (others => '0');
        end if;
      end if;
    end process;


    -- *** VECTOR INDEXER ***
    -- if reset, set vector index to current vector shift position
    -- if write request, update length and shift with result value
    -- if not reset, keep index constantly incrementing
    -- update length when I/O vector load operation is done
    G_vector_indexer:
    for i in 0 to C_vectors-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if R_vector_index_reset(i)='1' then
            -- R_vector_shift contains current pointer to 1st element of a vector
            R_vector_index(i) <= R_vector_shift(i);
            if R_vector_write_request(i)='1' then
              -- Result data is being written to this vector.
              -- Data will appear shifted to new position
              -- because of pipeline propagation delay.
              -- This sets new shift position
              R_vector_shift(i) <= R_result_vector_shift(i);
              R_vector_write(i) <= '1';
            end if;
          else -- not reset
            -- end of write for func. unit
            if R_vector_write(i) = '1' and R_vector_index(i) = S_vector_index_last(i) then
              R_vector_write(i) <= '0';
            end if;
            -- Flow control can prevent vector index increment.
            -- Used only for I/O, arithmetic function run index constantly
            if R_vector_io_flowcontrol(i)='0' or S_io_bram_next='1' then
              R_vector_index(i) <= R_vector_index(i)+1;
            end if;
          end if; -- if reset
        end if; -- rising edge
      end process;
      S_vector_index_last(i) <= R_vector_shift(i) + R_vector_length(i);
    end generate;

    -- *** FUNCTIONAL UNITS ***
    G_fpu_addsub:
    if C_float_addsub generate
      I_fpu_addsub:
      entity work.fpu
      port map
      (
        clk => clk,
        rmode => "00", -- round to nearest even
        fpu_op => R_fpu_addsub_mode, -- float op 000 add, 001 sub
        opa => R_VARG(conv_integer(R_function_arg1_select(C_function_fpu_addsub))),
        opb => R_VARG(conv_integer(R_function_arg2_select(C_function_fpu_addsub))),
        fpout => S_function_result(C_function_fpu_addsub)
      );
    end generate;

    G_fpu_multiply:
    if C_float_multiply generate
      I_fpu_multiply:
      entity work.fpmul
      port map
      (
        clk => clk,
        FP_A => R_VARG(conv_integer(R_function_arg1_select(C_function_fpu_multiply))),
        FP_B => R_VARG(conv_integer(R_function_arg2_select(C_function_fpu_multiply))),
        FP_Z => S_function_result(C_function_fpu_multiply)
      );
    end generate;

    G_fpu_divide:
    if C_float_divide generate
      I_fpu_divide:
      entity work.float_divide_goldschmidt
      generic map
      (
        C_pipe_stages => 6
      )
      port map
      (
        clk => clk,
        X => R_VARG(conv_integer(R_function_arg1_select(C_function_fpu_divide))),
        Y => R_VARG(conv_integer(R_function_arg2_select(C_function_fpu_divide))),
        Q => S_function_result(C_function_fpu_divide)
      );
    end generate;

    -- *** I/O functional unit ***
    -- connection to external I/O module
    io_store_mode <= R_io_store_mode; -- '0' load (read from RAM), '1' store (write to RAM)
    io_addr <= R(C_vaddress)(29 downto 2); -- pointer to vector struct in RAM
    io_request <= R_io_request; -- 1-cycle pulse to start a I/O request
    S_io_done <= io_done; -- goes to 0 after accepting I/O request, returns to 1 when done
    S_io_bram_we <= io_bram_we;
    io_bram_rdata <= R_VARG(conv_integer(R_function_arg1_select(C_function_io))); -- for vector store
    process(clk)
    begin
      if rising_edge(clk) then
        -- as RAM will change 16-bit partial on falling edge,
        -- we must capture valid data on rising edge.
        if io_bram_we='1' then
          R_io_bram_wdata <= io_bram_wdata; -- for vector load
        end if;
      end if;
    end process;
    -- load/store asymmetry
    -- store: vector should place data on the bram bus
    -- and wait for ready, immediately after ready arrives, new data
    -- should be placed and 0-cycle delay signal index increment.
    -- load: bram bus at the same cycle has valid data and bram_write_enable signal
    -- vector should sample data when write_enable=1 and load it to vector register
    -- io_bram_next must be correctly timed in I/O module
    -- for proper increment of vector index
    -- Corner cases like first and last element or jump to next struct
    -- can make it really difficult to debug.
    S_io_bram_next <= io_bram_next;
    S_function_result(C_function_io) <= R_io_bram_wdata; -- for vector load

    -- registering for fmax improvement
    G_registered_results:
    for i in 0 to C_functions-1 generate
      G_yes_function_result_reg:
      if C_function_result_reg generate
        process(clk)
        begin
          if rising_edge(clk) then
            -- add 1 clock delay
            R_function_result(i) <= S_function_result(i);
          end if;
        end process;
      end generate;
      G_no_function_result_reg:
      if not C_function_result_reg generate
        R_function_result(i) <= S_function_result(i);
      end generate;
    end generate;


    -- *** BRAM optional extra registers ***
    G_listeners:
    for i in 0 to C_vectors-1 generate
      -- register on BRAM input
      G_yes_bram_in_reg:
      if C_bram_in_reg generate
        process(clk)
        begin
          if rising_edge(clk) then
            -- add 1 clock delay
            R_VRES(i) <= R_function_result(conv_integer(R_vector_listen_to(i)(C_functions_bits-1 downto 0)));
          end if;
        end process;
      end generate;
      G_no_bram_in_reg:
      if not C_bram_in_reg generate
        R_VRES(i) <= R_function_result(conv_integer(R_vector_listen_to(i)(C_functions_bits-1 downto 0)));
      end generate;
      -- register on BRAM output
      G_yes_bram_out_reg:
      if C_bram_out_reg generate
        process(clk)
        begin
          if rising_edge(clk) then
            -- add 1 clock delay
            R_VARG(i) <= S_VARG(i);
          end if;
        end process;
      end generate;
      G_no_bram_out_reg:
      if not C_bram_out_reg generate
        R_VARG(i) <= S_VARG(i);
      end generate;
    end generate;


    -- *** VECTOR REGISTERS (BRAM) ***
    G_normal_clk_io:
    if not C_invert_bram_clk_io generate
      S_bram_clk_io <= clk;
    end generate;
    G_inverted_clk_io:
    if C_invert_bram_clk_io generate
      S_bram_clk_io <= not clk;
    end generate;
    G_normal_clk_reg:
    if not C_invert_bram_clk_reg generate
      S_bram_clk_reg <= clk;
    end generate;
    G_inverted_clk_reg:
    if C_invert_bram_clk_reg generate
      S_bram_clk_reg <= not clk;
    end generate;
    G_vector_registers:
    for i in 0 to C_vectors-1 generate
      vector_bram: entity work.bram_true2p_2clk
      generic map
      (
        dual_port => False, -- port A connected to DMA I/O, port B connected to Vector FPU
        pass_thru_a => False, -- false allows simultaneous reading and writing
        pass_thru_b => False, -- false allows simultaneous reading and writing
        data_width => C_vdata_bits,
        addr_width => C_vaddr_bits
      )
      port map
      (
        clk_a => S_bram_clk_reg, -- BRAM on FPU side should normally be clocked on rising edge (normal clk)
        clk_b => '0',
        we_a => R_vector_write(i), -- vector write enable from functional unit
        we_b => '0',
        addr_a => R_vector_index(i)(C_vaddr_bits-1 downto 0), -- internal address from vector indexer
        addr_b => (others => '0'),
        data_in_a => R_VRES(i), -- result from functional unit
        data_in_b => (others => '0'),
        data_out_a => S_VARG(i), -- argument to functional unit
        data_out_b => open
      );
    end generate;
end;

-- command example
---0x1234ABCD
--   1 operation always 3
--    2 choose functional unit: 0:+- 1:* 2:/ 3:I/O
--     3 for I/O, choose load/store 0:load 8:store
--      4 for add/sub choose +/- 0:+ 1:-
--       A not used
--        B vector id arg 2
--         C vector id arg 1
--          D vector id result (D = C <oper> B)
--
-- 0x03009000  load V(0) from RAM length=10
-- 0x03800000  store V(0) to RAM
-- 0x0300A111  load V(1) from RAM length=11
-- 0x03800111  store V(1) to RAM
-- 0x03010222  load V(2) from RAM length=17
-- 0x03800222  store V(2) to RAM
-- 0x037FF333  load V(3) from RAM length=2048
-- 0x03800333  store V(3) to RAM
-- 0x00000210  V(0) = V(1) + V(2) float
-- 0x00010210  V(0) = V(1) - V(2) float
-- 0x01000210  V(0) = V(1) * V(2) float
-- 0x02000210  V(0) = V(1) / V(2) float
-- 0x03000222  load V(2) from RAM length=1
-- 0x03800222  store V(2) to RAM

--  C usage

-- RAM representation of a vector segment
-- one vector can have any number of segments so
-- the data can be scattered around the RAM
-- but maximum of 2**C_vaddr_bits float elements
-- can be loaded in one hardware vector (excess elements
-- in RAM will not be read nor written by single vector I/O).
-- If long vector has to be processed, application in C should
-- loop over this, splitting it to multiple I/O and Vector operations.

-- // MMIO hardware vector control interface to the CPU
-- volatile uint32_t *vector_mmio = (volatile uint32_t *)0xFFFFFC20;

-- struct vector_header_s
-- {
--   uint16_t length; // length=0 means 1 element, length=1 means 2 elements etc.
--   uint16_t type; // not used
--   float *data; // sequential datta
--   volatile struct vector_header_s *next; // NULL if this is the last
-- };

-- // wait for vector operation to finish
-- // busy waiting for interrupt flag
-- void wait_vector_mask(uint32_t mask)
-- {
--   uint32_t i=0, a;
--   do
--   {
--     a = vector_mmio[1];
--   } while((a & mask) != mask && ++i < 200000); // some large timeout just in case...
--   vector_mmio[1] = a; // clear interrupt flag(s)
-- }

--  vector_mmio[0] = address_of_vector1; // pointer to struct vector_header_s
--  vector_mmio[4] = 0x00000200; // load vector 1 from RAM
--  wait_vector_mask(1<<16); // bit 16 waits for I/O
--  vector_mmio[0] = address_of_vector2; // pointer to struct vector_header_s
--  vector_mmio[4] = 0x00000400; // load vector 2 from RAM
--  wait_vector_mask(1<<16); // bit 16 waits for I/O
--  vector_mmio[4] = 0x30010210; // v(0) = v(1) - v(2) // calculate
--  wait_vector_mask(1<<0); // bit 0 waits for vector 0
--  vector_mmio[0] = address_of_vector0;
--  vector_mmio[4] = 0x00800000; // store vector 0 to RAM (vector number)
--  wait_vector_mask(1<<16); // bit 16 waits for I/O


-- TODO:

-- [*] I/O vector length for load
-- [*] I/O vector length for store
-- [*] I/O interpretes linked list

-- [*] indexer to control vector lengths and write signals
-- [*] simplify indexer with for loop and indexed registers
-- [*] indexer should count function pipeline delay cycles
-- [*] indexer should handle pipeline delay
-- [*] indexer should count vector lengths

-- [*] interrupt flag set on function done
-- [*] interrupt flag set for I/O done
-- [*] rewrite command decoding to avoid sequential register writes
-- [*] fix FPU divide "/" (propagation delay problem)

-- [*] it is better to have each index counter sitting of each
--     BRAM address port insted of having multiplexer for functional
--     unit indexers.

-- [*] support A=A+B and A+=B compound expressions, but introducing a
--     index to start of valid data in the vector, as such operation will
--     shift elements in the vector due to pipeline delay

-- [ ] mixed precision 64/32/16 mode

-- [ ] find/make a suckless divide module FPU LUT/DSP usage friendly

-- [*] both BRAM ports should be clocked CPU clock synchrnous,
--     let AXI I/O and FPU handle the async and delays

-- [*] move I/O from using separate BRAM port into a member of functional
--     units. I/O is slow and can be only 1 running at a time so it's a
--     waste of BRAM ports to use them all just for 1 IO

-- [*] flow control: introduce run/stop signal for vector indexer
--     intended for I/O module to be used as a functional unit.
--     slow functional unit can drop run this signal to 0,
--     so index will not advance, waiting until data ready

-- [ ] renumber functional units: 0: I/O, 1:+/-, 2:*, 3:/

-- [ ] clean up commands (I/O now needs 2 indentical arg1=result parameters
--     to reuse code from arithmeitc. Maybe it can cleaner use 1 parameter.

-- [ ] fine-grained commmands to manipulate shfit/length/increment
-- [ ] half: (arguments from second half, result to first half)
-- [ ] constant: (don't increment arguments.
--     e.g. enabling I/O control flow without any I/O prevents increment
