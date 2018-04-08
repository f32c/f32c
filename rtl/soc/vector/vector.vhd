-- (c)EMARD
-- License=BSD

-- f32c vector processor module
-- supports chaining, aliases, ranges and constants
-- supports all types of expressions
-- normal: A=B+C
-- compound: A=A+B, A=A+A
-- with full FPU and f32c I/O, uses 3148 LUTs on Artix-7

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
    C_bram_pass_thru: boolean := false; -- false: default, altera Cyclone-V needs true but c2_vector_fast won't work
    C_vectors: integer range 2 to 8 := 8; -- total number of vector registers (BRAM blocks)
    C_float_addsub: boolean := true; -- instantiate floating point addsub (+,-)
    C_float_multiply: boolean := true; -- instantiate floating point divider (*)
    C_float_divide: boolean := true; -- instantiate floating point divider (/) (LUT and DSP eater)
    C_bram_in_reg: boolean := false; -- not used
    C_bram_out_reg: boolean := false; -- not used
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


    -- *** MMIO REGISTERS ***
    constant C_mmio_registers: integer range 4 to 16 := 4; -- total number of memory backed mmio registers
    -- CPU interface: memory-mapped registers
    type T_mmio_regs is array (C_mmio_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: T_mmio_regs; -- register access from mmapped I/O  R: active register
    -- named constants for vector DMA control registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_vaddress:   integer   := 0; -- vector struct RAM address
    constant C_vdone_if:   integer   := 1; -- vector done interrupt flag
    constant C_vdone_ie:   integer   := 2; -- vector done interrupt enable
    constant C_vcounter:   integer   := 3; -- unused, placeholder for vector progress counter (write to select which register to monitor)
    constant C_vcommand:   integer   := 4; -- vector processor command


    -- *** RAM I/O ***
    signal S_io_bram_we: std_logic;
    signal S_io_bram_next: std_logic;
    signal S_io_bram_addr: std_logic_vector(C_vaddr_bits downto 0); -- RAM address to load/store
    signal R_io_bram_wdata: std_logic_vector(C_vdata_bits-1 downto 0); -- channel to RAM
    signal R_io_store_mode: std_logic; -- '0': load vectors from RAM, '1': store vector to RAM
    signal R_io_request: std_logic; -- set to '1' during one clock cycle (not longer) to properly initiate RAM I/O
    signal S_io_done: std_logic;
    signal R_io_done: std_logic_vector(1 downto 0) := (others => '1');
    signal S_io_done_interrupt: std_logic;


    -- *** VECTOR REGISTERS ***
    -- We will act as we have 2x more vectors.
    -- Each port is treated as separate vector, an alias of the same data
    -- separately addressable for double parallel run
    constant C_vectors_bits: integer range 1 to 3 := ceil_log2(C_vectors); -- number of bits to select the vector
    type T_VR_addr_2port is array (2*C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits-1 downto 0);
    signal R_VR_addr, R_VR_addr_start, R_VR_addr_stop: T_VR_addr_2port;
    type T_VR_data_2port is array (2*C_vectors-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_VR_data_in, S_VR_data_out: T_VR_data_2port;
    signal R_VR_index_reset: std_logic_vector(2*C_vectors-1 downto 0);
    signal R_VR_write, R_VR_write_request: std_logic_vector(2*C_vectors-1 downto 0);
    signal R_VR_write_prev_cycle: std_logic_vector(2*C_vectors-1 downto 0); -- falling edge tracking
    constant C_increment_delay_bits: integer := 5; -- must fit 2* max propagation delay
    type T_VR_increment_delay is array (2*C_vectors-1 downto 0) of std_logic_vector(C_increment_delay_bits-1 downto 0);
    signal R_VR_increment_delay, R_VR_increment_delay_start: T_VR_increment_delay := (others => (others => '1')); -- starts negative and increments
    signal R_VR_io_flowcontrol: std_logic_vector(2*C_vectors-1 downto 0) := (others => '0');
    signal S_VR_done_interrupt: std_logic_vector(2*C_vectors-1 downto 0);

    -- *** FUNCTIONAL UNITS ***
    -- 4 main different functions
    constant C_functions: integer := 4; -- total number of functional units
    constant C_functions_bits: integer := ceil_log2(C_functions); -- total number bits to address one functional unit
    -- IMPORTANT: reordering functional units will not only change ISA but will
    -- also make signifcant change in FPGA placment and routing.
    -- This can affect fmax performance.
    -- Best order can be determined only from the experiment.
    constant C_function_fpu_addsub: integer range 0 to C_functions-1 := 0; -- +,-
    constant C_function_fpu_multiply: integer range 0 to C_functions-1 := 1; -- *
    constant C_function_fpu_divide: integer range 0 to C_functions-1 := 2; -- /
    constant C_function_io: integer range 0 to C_functions-1 := 3; -- I/O
    -- each function can have different pipeline propagation delay
    --type T_function_propagation_delay is array (0 to C_functions-1) of integer;
    --constant C_function_propagation_delay: T_function_propagation_delay :=
    --(
    --  6, -- C_function_fpu_addsub (+,-)
    --  6, -- C_function_fpu_multiply (*)
    -- 13, -- C_function_fpu_divide (/)
    --  0  -- C_function_io (RAM DMA) this affects load, not store
    --);
    -- a function can have modifier that selects one from many of similar functions
    signal R_fpu_addsub_mode: std_logic_vector(0 downto 0); -- select float A+B or A-B to execute
    -- the data interface
    type T_FU_data is array (C_functions-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_FU_result_data, S_FU_arg1_data, S_FU_arg2_data: T_FU_data;
    -- the function-register data crossbar
    type T_FU2VR is array (C_functions-1 downto 0) of integer range 0 to 2*C_vectors-1;
    signal R_FU2VR_arg1, R_FU2VR_arg2: T_FU2VR;
    type T_VR2FU_result is array (2*C_vectors-1 downto 0) of integer range 0 to C_functions-1;
    signal R_VR2FU_result: T_VR2FU_result;

    -- simplify writing signals from command decoder
    signal S_cmd_result, S_cmd_arg1, S_cmd_arg2: std_logic_vector(C_vectors_bits downto 0); -- command decoder, 2*vectors
    signal SI_cmd_result, SI_cmd_arg1, SI_cmd_arg2: integer range 0 to 2*C_vectors-1;
    signal S_cmd_function: std_logic_vector(C_functions_bits-1 downto 0);
    signal SI_cmd_function: integer range 0 to C_functions-1;
    signal S_cmd_store: std_logic;
    signal S_cmd_addsub_mode: std_logic;
    signal S_cmd_vector_start, S_cmd_vector_stop: std_logic_vector(C_vaddr_bits-1 downto 0);
    signal S_cmd_pipe_delay: std_logic_vector(C_increment_delay_bits-1 downto 0);

    -- vector done detection register
    signal S_interrupt_edge: std_logic_vector(C_bits-1 downto 0) := (others => '0');
begin
    -- *** MMIO interface ***
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <=
        ext(x"DEBA66AA", 32)
          when C_vcommand,
        --ext(R_io_request & S_io_done, 32)
        --  when C_vcounter,
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
        R_VR_write_prev_cycle <= R_VR_write;
        R_io_done <= S_io_done & R_io_done(1);
      end if;
    end process;
    -- falling edge of functional vector write enable signal "S_vector_we" indicates
    -- the completion of vector operation (vdone interrupt)
    S_VR_done_interrupt <= R_VR_write_prev_cycle and not R_VR_write; -- '1' on falling edge
    S_interrupt_edge(2*C_vectors-1 downto 0) <= S_VR_done_interrupt; -- S_interrupt_edge is larger (32-bit)
    -- rising edge of "S_io_done" indicates
    -- the completion of vector I/O operation
    S_io_done_interrupt <= R_io_done(1) and not R_io_done(0); -- '1' on rising edge
    S_interrupt_edge(16) <= S_io_done_interrupt;


    -- *** MMIO command decoder ***
    -- signals introduced only for readability
    -- common to all
    S_cmd_function <= bus_in(C_functions_bits-1+24 downto 24);
    SI_cmd_function <= conv_integer(S_cmd_function);
    -- common, but used only for I/O
    S_cmd_store <= bus_in(23);
    -- common, but used only for arithmetic add/sub
    S_cmd_addsub_mode <= bus_in(22);
    -- specific to "E" command (execute)
    S_cmd_pipe_delay <= bus_in(C_increment_delay_bits-1+12 downto 12);
    S_cmd_arg2 <= bus_in(C_vectors_bits+8 downto 8);
    SI_cmd_arg2 <= conv_integer(S_cmd_arg2);
    S_cmd_arg1 <= bus_in(C_vectors_bits+4 downto 4);
    SI_cmd_arg1 <= conv_integer(S_cmd_arg1);
    -- specific to "A" command (address range)
    S_cmd_vector_start <= bus_in(C_vaddr_bits-1+4 downto 4);
    S_cmd_vector_stop <= bus_in(C_vaddr_bits-1+16 downto 16);
    -- common to all
    S_cmd_result <= bus_in(C_vectors_bits+0 downto 0);
    SI_cmd_result <= conv_integer(S_cmd_result);

    process(clk)
    begin
      if rising_edge(clk) then
        -- command accepted only if written in 32-bit word
        if ce='1' and bus_write='1' and byte_sel="1111" then
          if conv_integer(addr) = C_vcommand then
            case bus_in(31 downto 28) is -- main command decode execute...
            when x"A" => -- address range: set vector start and stop address
              R_VR_addr_start(SI_cmd_result) <= S_cmd_vector_start;
              R_VR_addr_stop(SI_cmd_result) <= S_cmd_vector_stop;
            when x"E" => -- execute functional unit
              if S_cmd_function = C_function_io then
                R_io_request <= '1'; -- trigger start of RAM I/O module
                -- Normally arg1 and result should be set to the same value here.
                -- A redundancy, but it allows to reuse crossbar
                -- and part of command decoding for arithmetic.
                R_io_store_mode <= S_cmd_store; -- RAM write cycle
                -- this will let I/O control increment of vector index
                R_VR_io_flowcontrol(SI_cmd_result) <= '1';
                -- request Reset vector indexr
                R_VR_index_reset(SI_cmd_result) <= '1';
                -- increment delay taken from command parameter
                R_VR_increment_delay_start(SI_cmd_result) <= S_cmd_pipe_delay;
              else
                -- for arithmetic disable I/O_flowcontrol
                R_VR_io_flowcontrol(SI_cmd_arg1) <= '0';
                R_VR_io_flowcontrol(SI_cmd_arg2) <= '0';
                R_VR_io_flowcontrol(SI_cmd_result) <= '0';
                -- request Reset all used vector indexes
                R_VR_index_reset(SI_cmd_arg1) <= '1';
                R_VR_index_reset(SI_cmd_arg2) <= '1';
                R_VR_index_reset(SI_cmd_result) <= '1';
                -- increment delay taken from command parameter
                R_VR_increment_delay_start(SI_cmd_result) <= S_cmd_pipe_delay;
                -- after result, if the arg1 = result, then following lines
                -- will disable increment delay (A=A+B can't have inc. delay)
                -- no increment delay to arguments (set msb)
                R_VR_increment_delay_start(SI_cmd_arg1)(C_increment_delay_bits-1) <= '1'; -- no delay
                R_VR_increment_delay_start(SI_cmd_arg2)(C_increment_delay_bits-1) <= '1'; -- no delay
              end if;
              -- choose add or sub (it is set always but only affects addsub function)
              R_fpu_addsub_mode(0) <= S_cmd_addsub_mode; -- ADD/SUB mode 0:+,1:-
              -- set functional unit's argmuents to be read from selected vectors
              R_FU2VR_arg1(SI_cmd_function) <= SI_cmd_arg1;
              R_FU2VR_arg2(SI_cmd_function) <= SI_cmd_arg2;
              -- set a vector to listen to results of the selected functional unit
              R_VR2FU_result(SI_cmd_result) <= SI_cmd_function;
              -- for the store mode write is disabled, a special case.
              R_VR_write_request(SI_cmd_result) <= not S_cmd_store;
            when others =>
              -- nothing
            end case;
          end if; -- mmio command register decode
        else
          R_io_request <= '0';
          R_VR_index_reset <= (others => '0');
          R_VR_write_request <= (others => '0');
        end if;
      end if;
    end process;


    -- *** VECTOR INDEXER ***
    -- if reset, set vector index and delay to their start values
    -- if not reset, coundown delay, start index incrementing,
    -- for I/O do the flow control
    G_vector_indexer:
    for i in 0 to 2*C_vectors-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if R_VR_index_reset(i)='1' then
            R_VR_addr(i) <= R_VR_addr_start(i);
            R_VR_increment_delay(i) <= R_VR_increment_delay_start(i);
            R_VR_write(i) <= R_VR_write_request(i);
          else -- not reset
            -- Flow control can enable/disable vector index increment.
            if R_VR_io_flowcontrol(i)='0' or S_io_bram_next='1' then
              if R_VR_increment_delay(i)(C_increment_delay_bits-1)='0' then
                R_VR_increment_delay(i) <= R_VR_increment_delay(i)-1;
              else
                if R_VR_addr(i) = R_VR_addr_stop(i) then
                  -- end of run for this vector, disable write
                  R_VR_write(i) <= '0';
                else
                  R_VR_addr(i) <= R_VR_addr(i)+1;
                end if; -- end if stop reached
              end if; -- end if increment delay
            end if; -- end if flowcontrol
          end if; -- if reset
        end if; -- rising edge
      end process;
    end generate;

    -- *** FUNCTIONAL UNITS ***

-- this adder has signal latency problems

--    G_fpu_addsub:
--    if C_float_addsub generate
--      I_fpu_addsub:
--      entity work.fpu
--      port map
--      (
--        clk => clk,
--        rmode => "00", -- round to nearest even
--        fpu_op => R_fpu_addsub_mode, -- float op 000 add, 001 sub
--        opa => S_FU_arg1_data(C_function_fpu_addsub),
--        opb => S_FU_arg2_data(C_function_fpu_addsub),
--        fpout => S_FU_result_data(C_function_fpu_addsub)
--      );
--    end generate;

    G_fpu_addsub_emiraga:
    if C_float_addsub generate
      I_fpu_addsub_emiraga:
      entity work.add_sub_emiraga
      port map
      (
        clock_in => clk,
        add_sub_bit => R_fpu_addsub_mode(0), -- 0 add, 1 sub
        inputA => S_FU_arg1_data(C_function_fpu_addsub),
        inputB => S_FU_arg2_data(C_function_fpu_addsub),
        outputC => S_FU_result_data(C_function_fpu_addsub)
      );
    end generate;

    G_fpu_multiply:
    if C_float_multiply generate
      I_fpu_multiply:
      entity work.fpmul
      port map
      (
        clk => clk,
        FP_A => S_FU_arg1_data(C_function_fpu_multiply),
        FP_B => S_FU_arg2_data(C_function_fpu_multiply),
        FP_Z => S_FU_result_data(C_function_fpu_multiply)
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
        X => S_FU_arg1_data(C_function_fpu_divide),
        Y => S_FU_arg2_data(C_function_fpu_divide),
        Q => S_FU_result_data(C_function_fpu_divide)
      );
    end generate;

    -- *** I/O functional unit ***
    -- connection to external I/O module
    io_store_mode <= R_io_store_mode; -- '0' load (read from RAM), '1' store (write to RAM)
    io_addr <= R(C_vaddress)(29 downto 2); -- pointer to vector struct in RAM
    io_request <= R_io_request; -- 1-cycle pulse to start a I/O request
    S_io_done <= io_done; -- goes to 0 after accepting I/O request, returns to 1 when done
    S_io_bram_we <= io_bram_we;
    io_bram_rdata <= S_FU_arg1_data(C_function_io); -- for vector store
    process(clk)
    begin
      if rising_edge(clk) then
        -- as RAM may change 16-bit half on falling edge,
        -- we must capture valid data on rising edge.
        if io_bram_we='1' then
          R_io_bram_wdata <= io_bram_wdata; -- for vector load
        end if;
      end if;
    end process;
    -- load/store asymmetry
    -- store: vector should place data on the bram bus
    -- and wait for ready, immediately after ready arrives, new data
    -- should be placed and do index increment.
    -- load: bram bus at the same cycle has valid data and bram_write_enable signal
    -- vector should sample data when write_enable=1 and load it to vector register
    -- io_bram_next must be correctly timed in I/O module
    -- for proper increment of vector index
    -- Corner cases like first and last element or jump to next struct
    -- can make it really difficult to debug.
    S_io_bram_next <= io_bram_next;
    S_FU_result_data(C_function_io) <= R_io_bram_wdata; -- for vector load


    -- *** VECTOR CROSSBARS ***
    G_vector_out_to_function_in_crossbar:
    for i in 0 to C_functions-1 generate
      S_FU_arg1_data(i) <= S_VR_data_out(R_FU2VR_arg1(i));
      S_FU_arg2_data(i) <= S_VR_data_out(R_FU2VR_arg2(i));
    end generate;
    G_function_out_to_vector_in_crossbar:
    for i in 0 to 2*C_vectors-1 generate
      S_VR_data_in(i) <= S_FU_result_data(R_VR2FU_result(i));
    end generate;


    -- *** VECTOR REGISTERS (BRAM) ***
    G_vector_registers:
    for i in 0 to C_vectors-1 generate
      vector_bram: entity work.bram_true2p_1clk
      generic map
      (
        dual_port => True, -- port A connected to DMA I/O, port B connected to Vector FPU
        pass_thru_a => C_bram_pass_thru, -- false allows simultaneous reading and writing
        pass_thru_b => C_bram_pass_thru, -- false allows simultaneous reading and writing
        data_width => C_vdata_bits,
        addr_width => C_vaddr_bits
      )
      port map
      (
        clk => clk,
        we_a => R_VR_write(2*i), -- vector write enable from functional unit
        we_b => R_VR_write(2*i+1),
        addr_a => R_VR_addr(2*i), -- internal address from vector indexer
        addr_b => R_VR_addr(2*i+1),
        data_in_a => S_VR_data_in(2*i), -- result from functional unit
        data_in_b => S_VR_data_in(2*i+1),
        data_out_a => S_VR_data_out(2*i), -- argument to functional unit
        data_out_b => S_VR_data_out(2*i+1)
      );
    end generate;
end;

-- vector range
-- 0xA7FF0002
--   A - set vector 2 range 000:start 7FF:stop

-- command example
---0xE1004CBA
--   E execute always E
--    1 choose functional unit: 0:+- 1:* 2:/ 3:I/O
--     0 for I/O, load/store 0:load 8:store, for add/sub 0:+ 4:-
--      0 disable pipeline delay: 0:have delay, 1: no delay
--       4 pipeline delay: "4" for (+,-,*), "B" for (/)
--        C vector id arg2 - right hand side
--         B vector id arg1 - left hand side
--          A vector id result (A = B <oper> C)
--
-- 0xA0090090  select vector 0 element 9 (constant)
-- 0xE3009000  load V(0) from RAM
-- 0xE381F000  store V(0) to RAM
-- 0xA1FF1001  select vector 1 elements 256-511 (inclusive)
-- 0xE3000011  load V(1) from RAM
-- 0xE381F011  store V(1) to RAM
-- 0xA7FF0002  select vector 2 elements 0-2047 (inclusive)
-- 0xE3000022  load V(2) from RAM
-- 0xE381F022  store V(2) to RAM
-- 0xA0037FD3  select vector 3 elements 2045-3 (2045,2046,2047,0,1,2,3)
-- 0xE3000033  load V(3) from RAM
-- 0xE381F033  store V(3) to RAM
-- 0xE0004420  V(0) = V(2) + V(4) float (4: pipeline delay 5)
-- 0xE0404420  V(0) = V(2) - V(4) float (4: pipeline delay 5)
-- 0xE1004420  V(0) = V(2) * V(4) float (4: pipeline delay 5)
-- 0xE200B420  V(0) = V(2) / V(4) float (B: pipeline delay 12)

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
--  vector_mmio[4] = 0xA7FF0001; // select vector 1 range 0-2047
--  vector_mmio[4] = 0xE3000011; // load vector 1 from RAM
--  wait_vector_mask(1<<1); // bit 16 waits for vector 1
--  vector_mmio[0] = address_of_vector2; // pointer to struct vector_header_s
--  vector_mmio[4] = 0xA7FF0002; // select vector 2 range 0-2047
--  vector_mmio[4] = 0xE3000022; // load vector 2 from RAM
--  wait_vector_mask(1<<2); // bit 2 waits for vector 2
--  vector_mmio[4] = 0xA7FF0000; // select vector 0 range 0-2047
--  vector_mmio[4] = 0xE0404210; // v(0) = v(1) - v(2) // calculate in-place sub, alias v(0)=v(1)
--  wait_vector_mask(1<<0); // bit 0 waits for vector 0
--  vector_mmio[0] = address_of_vector0;
--  vector_mmio[4] = 0xE381F000; // store vector 0 to RAM
--  wait_vector_mask(1<<16); // bit 16 waits for I/O store (store bit is special)


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

-- [ ] clean up commands (I/O now needs 2 indentical arg1=result parameters
--     to reuse code from arithmeitc. Maybe it can cleaner use 1 parameter.

-- [*] fine-grained vector address control, one hardware vector
--     can handle many short vectors
-- [*] half: (arguments from second half, result to first half)
-- [*] constant: (don't increment arguments.
--     e.g. enabling I/O control flow without any I/O prevents increment

-- [ ] unifiy store interrupt. Other vector interrupts track write
--     signal, while store has no write to vector so it's on a special flag

