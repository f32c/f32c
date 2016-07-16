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
    C_function_result_reg: boolean := true; -- register layer on functional unit result
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
    type T_vdata is array (C_vectors-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal S_vector_load, S_vector_store: T_vdata; -- vectors to RAM I/O lines
    signal S_VARG, R_VRES: T_vdata; -- switchbar connection for arguments and results
    signal R_VARG: T_vdata; -- switchbar connection for arguments and results
    -- Register to track length of vector. So shorter than max length vectors
    -- can be calculated faster
    type T_vector_length is array (C_vectors-1 downto 0) of std_logic_vector(C_vaddr_bits downto 0);
    signal R_vector_length, R_result_vector_length: T_vector_length; -- true length-1, 0 -> 1 element, 1 -> 2 elements ...
    signal R_vector_shift, R_result_vector_shift, S_io_bram_addr_shift: T_vector_length; -- true length-1, 0 -> 1 element, 1 -> 2 elements ...

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
    signal S_bram_clk_reg, S_bram_clk_io: std_logic;
    -- command decoder should load
    -- R_store_mode, R_store_select, R_load_select
    -- and issue a 1-clock pulse on R_io_request

    -- *** Functional multiplexing ***
    -- 4 main different functions
    -- a function can have modifier that selects one from many of similar functions
    constant C_functions: integer := 4; -- total number of functional units
    constant C_functions_bits: integer := ceil_log2(C_functions); -- total number bits to address one functional unit
    constant C_function_fpu_addsub: integer range 0 to C_functions-1 := 0; -- +,-
    constant C_function_fpu_multiply: integer range 0 to C_functions-1 := 1; -- *
    constant C_function_fpu_divide: integer range 0 to C_functions-1 := 2; -- /
    -- all functions will broadcast results
    type T_function_result is array (C_functions-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
    signal R_function_result, S_function_result: T_function_result;
    type T_vector_listen_to is array (C_vectors-1 downto 0) of std_logic_vector(C_functions_bits-1 downto 0);
    signal R_vector_listen_to: T_vector_listen_to := (others => (others => '1'));

    -- each function can have different pipeline propagation delay
    type T_function_propagation_delay is array (0 to C_functions-1) of integer;
    constant C_function_propagation_delay: T_function_propagation_delay :=
    (
      6, -- C_function_fpu_addsub +,-
      6, -- C_function_fpu_multiply *
     13, -- C_function_fpu_divide /
      1
    );
    type T_function_vector_select is array (0 to C_functions-1) of std_logic_vector(C_vectors_bits-1 downto 0);
    signal R_function_arg1_select, R_function_arg2_select: T_function_vector_select;

    -- simplify writing signals from command decoder
    signal S_cmd_result, S_cmd_arg1, S_cmd_arg2: std_logic_vector(C_vectors_bits-1 downto 0); -- command decoder
    signal SI_cmd_result, SI_cmd_arg1, SI_cmd_arg2: integer range 0 to C_vectors-1;
    signal S_cmd_function: std_logic_vector(C_functions_bits-1 downto 0);
    signal SI_cmd_function: integer range 0 to C_functions-1;

    -- *** floating point unit addsub functions ***
    signal R_fpu_addsub_mode: std_logic_vector(3 downto 0); -- select which float operation to execute

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

    process(clk)
    begin
      if rising_edge(clk) then
        -- command accepted only if written in 32-bit word
        if ce='1' and bus_write='1' and byte_sel="1111" then
          if conv_integer(addr) = C_vcommand then
            if bus_in(31 downto 28) = x"0" then -- command 0x0.. I/O
              R_io_store_mode <= bus_in(23); -- RAM write cycle
              R_io_store_select <= bus_in(C_vectors_bits-1+0 downto 0); -- byte 0, vector number to store
              R_io_load_select <= bus_in(C_vectors-1+8 downto 8); -- byte 1 bitmask of vectors to load
              R_io_request <= '1';
            end if;
            if true and bus_in(31 downto 28) = x"3" then -- command 0x3...
              R_fpu_addsub_mode <= bus_in(19 downto 16); -- Arith mode +,-
              -- set a vector to listen to results of the selected functional unit
              R_vector_listen_to(SI_cmd_result) <= S_cmd_function;
              -- set functional unit's argmuents to be read from selected vectors
              R_function_arg2_select(SI_cmd_function) <= S_cmd_arg2;
              R_function_arg1_select(SI_cmd_function) <= S_cmd_arg1;
              -- set result vector shift value (pipeline delay)
              -- TODO: this one can be omitted and taken from cmd arguments (needs 11 bits)
              R_result_vector_shift(SI_cmd_result) <= R_vector_shift(SI_cmd_result) +
                conv_std_logic_vector(C_function_propagation_delay(SI_cmd_function), C_vaddr_bits+1);
              -- vector length: result = arg1
              R_result_vector_length(SI_cmd_result) <= R_vector_length(SI_cmd_arg1);
              -- request Reset vector indexes
              R_vector_index_reset(SI_cmd_arg2) <= '1';
              R_vector_index_reset(SI_cmd_arg1) <= '1';
              R_vector_index_reset(SI_cmd_result) <= '1';
              -- request write to result vector
              R_vector_write_request(SI_cmd_result) <= '1';
            end if;
          end if;
        else
          R_io_request <= '0';
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
              R_vector_length(i) <= R_result_vector_length(i);
              R_vector_shift(i) <= R_result_vector_shift(i);
              R_vector_write(i) <= '1';
            end if;
          else -- not reset
            if R_vector_write(i) = '1' and R_vector_index(i) = S_vector_index_last(i) then
              R_vector_write(i) <= '0';
            end if;
            -- constantly running
            R_vector_index(i) <= R_vector_index(i)+1;
            if S_io_done_interrupt='1' and R_io_load_select(i)='1' and R_io_store_mode='0' then
              R_vector_length(i) <= S_io_bram_addr - 1; -- bram addr stops at true length, vector works with length-1
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
        fpu_op => R_fpu_addsub_mode(0 downto 0), -- float op 000 add, 001 sub
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
        dual_port => True, -- one port takes data from RAM, other port outputs to video
        pass_thru_a => False, -- false allows simultaneous reading and erasing of old data
        pass_thru_b => False, -- false allows simultaneous reading and erasing of old data
        data_width => C_vdata_bits,
        addr_width => C_vaddr_bits
      )
      port map
      (
        clk_a => S_bram_clk_io, -- BRAM on falling clk edge is a must for AXI burst write to RAM
        clk_b => S_bram_clk_reg, -- BRAM on falling clk edge works better for artix-7
        -- falling edge of the clock also reduced functional unit delay by 1 cycle
        -- note: the f32c core also works with BRAM on falling edge
        we_a => S_io_bram_we_select(i),
        we_b => R_vector_write(i), -- vector write enable from functional unit
        addr_a => S_io_bram_addr_shift(i)(C_vaddr_bits-1 downto 0), -- external address (RAM I/O)
        addr_b => R_vector_index(i)(C_vaddr_bits-1 downto 0), -- internal address from vector indexer
        data_in_a => S_io_bram_wdata,
        data_in_b => R_VRES(i), -- result from functional unit
        data_out_a => S_vector_store(i),
        data_out_b => S_VARG(i) -- argument to functional unit
      );
      S_io_bram_we_select(i) <= R_io_load_select(i) and S_io_bram_we; -- counter out, disable write
      S_io_bram_addr_shift(i) <= R_vector_shift(i) + S_io_bram_addr;
    end generate;
    S_io_bram_rdata <= S_vector_store(conv_integer(R_io_store_select)); -- multiplexer

    -- *** I/O DMA MODULE ***
    -- load/store asymmetry:
    -- vector load: (1-to-many) all bus lines are connected to RAM data
    --              all vector registers can be loaded with the same RAM data
    -- vector store: (1-to-1) only one vector can be stored at a time
    -- external connection to I/O module
    io_store_mode <= R_io_store_mode; -- '0' load (read from RAM), '1' store (write to RAM)
    io_addr <= R(C_vaddress)(29 downto 2); -- pointer to vector struct in RAM
    io_request <= R_io_request; -- 1-cycle pulse to start a I/O request
    S_io_done <= io_done; -- goes to 0 after accepting I/O request, returns to 1 when done
    S_io_bram_we <= io_bram_we;
    S_io_bram_addr <= io_bram_addr;
    S_io_bram_wdata <= io_bram_wdata;
    io_bram_rdata <= S_io_bram_rdata;
end;

-- command example
-- 0x00000100  load V(0) from RAM
-- 0x00800000  store V(0) to RAM
-- 0x00000200  load V(1) from RAM
-- 0x00800001  store V(1) to RAM
-- 0x00000400  load V(2) from RAM
-- 0x00800002  store V(2) to RAM
-- 0x00000800  load V(3) from RAM
-- 0x00800003  store V(3) to RAM
-- 0x30000210  V(0) = V(1) + V(2) float
-- 0x30010210  V(0) = V(1) - V(2) float
-- 0x31000210  V(0) = V(1) * V(2) float
-- 0x32000210  V(0) = V(1) / V(2) float

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

--  vector_ptr[0] = address_of_vector1;
--  vector_ptr[4] = 0x00000400; // load vector 1
--  delay(4);
--  vector_ptr[0] = address_of_vector2;
--  vector_ptr[4] = 0x00000200; // load vector 2
--  delay(4);
--  vector_ptr[4] = 0x30010210; // v(0) = v(1) - v(2)
--  delay(4);
--  vector_ptr[0] = address_of_vector0;
--  vector_ptr[4] = 0x00800000; // store vector 0 (vector number)


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

-- [ ] both BRAM ports should be clocked CPU clock synchrnous,
--     let AXI I/O and FPU handle the async and delays

-- [ ] move I/O from using separate BRAM port into a member of functional
--     units. I/O is slow and can be only 1 running at a time so it's a
--     waste of BRAM ports to use them all just for 1 IO
