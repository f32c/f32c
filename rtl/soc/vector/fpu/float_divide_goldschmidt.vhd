-- (c)EMARD
-- license = BSD

-- Goldschmit approximate integer division, pipelined.

-- to calculate q = x/y,
-- in each iteration it multiplies both x and y with
-- a number which makes y approach to 1*(2^n)
-- and then x becomes result q = x/y * (2^n)/(2^n)

-- at start both x and y must be normalized, having MSB=1
-- 1 <= x < 2, 1 <= y < 2
-- this is the normalized mantissa in floating point
-- with leading bit '1' revealed

-- convergence algorithm
--
-- x = xn.xn-1 ... x0: 1 <= x < 2
-- y = yn.yn-1 ... y0: 1 <= y < 2
-- q = x/y
-- m steps
-- internally: p bits
-- p > n


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity float_divide_goldschmidt is
  generic
  (
    C_pipe_stages: integer range 2 to 20 := 6; -- number of pipelined iteration steps
    C_float_mode: boolean := true; -- true: default float mode, false: integer mode (no renormalization)
    -- 1+8+23 = IEEE 754 32-bit single precision float
    C_exponent_bits: integer := 8;
    C_mantissa_bits: integer := 23;
    C_precision_bits: integer := 27 -- internal precision
  );
  port
  (
    clk: in std_logic;
    -- x, inv_x bit count: 1+C_exponent_bits+C_mantissa_bits
    x, y: in std_logic_vector(C_exponent_bits+C_mantissa_bits downto 0);
    q: out std_logic_vector(C_exponent_bits+C_mantissa_bits downto 0)
  );
end float_divide_goldschmidt;


architecture rtl of float_divide_goldschmidt is
   -- IEEE standard exponent offset
   -- here is a bitwise cocktail that
   -- creates 2^(N-1)-2 integer for exponent offset:
   constant C_exponent_offset1: std_logic_vector(C_exponent_bits-3 downto 0) := (others => '1');
   constant C_exponent_offset: std_logic_vector(C_exponent_bits-1 downto 0) := '0' & C_exponent_offset1 & '0';
   -- elementary data which transit from one
   -- pipeline stage to another
   type T_pipe_element is
   record
     sign: std_logic;
     exponent: std_logic_vector(C_exponent_bits-1 downto 0);
     mantissa_a: std_logic_vector(C_precision_bits-1 downto 0);
     mantissa_b: std_logic_vector(C_precision_bits downto 0);
   end record;
   type T_pipe_data is array (0 to C_pipe_stages-1) of T_pipe_element;
   signal R_pipe_data: T_pipe_data;
   -- intermedia results for goldschmidt's algorithm
   type T_a is array (0 to C_pipe_stages-1) of std_logic_vector(C_precision_bits-1 downto 0);
   signal a, not_a, next_a: T_a;
   -- b is 1 bit larger for overflow detection and mantissa renormalization
   type T_b is array (0 to C_pipe_stages-1) of std_logic_vector(C_precision_bits downto 0);
   signal b, c, next_b: T_b;
   type T_ac is array (0 to C_pipe_stages-1) of std_logic_vector(2*C_precision_bits downto 0);
   signal ac: T_ac;
   type T_R_ac is array (0 to C_pipe_stages-1) of std_logic_vector(2*C_precision_bits-1 downto C_precision_bits);
   signal R_ac: T_R_ac;
   type T_bc is array (0 to C_pipe_stages-1) of std_logic_vector(2*C_precision_bits+1 downto 0);
   signal bc: T_bc;
   type T_R_bc is array (0 to C_pipe_stages-1) of std_logic_vector(2*C_precision_bits+1 downto C_precision_bits);
   signal R_bc: T_R_bc;
   type T_exponent is array (0 to C_pipe_stages-1) of std_logic_vector(C_exponent_bits-1 downto 0);
   signal exponent, R_exponent, next_exponent: T_exponent;
   signal sign, R_sign, next_sign: std_logic_vector(C_pipe_stages-1 downto 0);
begin
   -- the pipeline
   G_goldschmidt_pipeline:
   for i in 0 to C_pipe_stages-1 generate
     -- combinatorial logic
     -- calculates next stage of the pipeline
     -- using the goldschmidt algorithm
     G_goldschmidt_combinatorial:
     if i > 0 generate
       sign(i) <= R_pipe_data(i-1).sign;
       next_sign(i) <= R_sign(i);
       exponent(i) <= R_pipe_data(i-1).exponent;
       a(i) <= R_pipe_data(i-1).mantissa_a;
       next_a(i) <= R_ac(i)(2*C_precision_bits-1 downto C_precision_bits);
       b(i) <= R_pipe_data(i-1).mantissa_b;
       -- c is guesstimated for "a" to approach towards "100...000" binary
       -- originally it should be c = '1' & ((not a(i))+1), but
       -- here is removed +1 to improve fmax. It is ok because
       -- numerically it does approximately the same.
       c(i)(C_precision_bits downto 0) <= '1' & not a(i);
       ac(i) <= a(i)*c(i);
       bc(i) <= b(i)*c(i);
       G_float_mode:
       if C_float_mode generate
         -- float mode:
         -- renormalize mantissa "b" if the bit in bc at position of
         -- next_b(C_precision_bits) becomes 1
         -- shifting it 1 bit more to the right in order not to loose MSB
         next_b(i) <= R_bc(i)(2*C_precision_bits   downto C_precision_bits)
                 when R_bc(i)(2*C_precision_bits)='0' -- renormalization test
                 else R_bc(i)(2*C_precision_bits+1 downto C_precision_bits+1);
         -- renormalization divides mantissa by 2. To keep the
         -- same floating point number we must add 1 to the exponent
         -- in case of renormalization. (exponent represents power of 2)
         next_exponent(i) <= R_exponent(i)
                        when R_bc(i)(2*C_precision_bits)='0' -- renormalization test
                        else R_exponent(i) + 1;
       end generate;
       G_integer_mode:
       if not C_float_mode generate
         -- integer mode doesn't renormalize
         next_b(i) <= R_bc(i)(2*C_precision_bits downto C_precision_bits);
         next_exponent(i) <= R_exponent(i);
       end generate;
     end generate;
     -- registers logic is moving data thru the pipeline
     process(clk)
     begin
       if rising_edge(clk) then
         if i = 0 then
           -- data enter at pipe stage 0
           R_pipe_data(i).sign     <= x(C_exponent_bits+C_mantissa_bits)
                                  xor y(C_exponent_bits+C_mantissa_bits);
           R_pipe_data(i).exponent <= x(C_exponent_bits+C_mantissa_bits-1 downto C_mantissa_bits)
                                    - y(C_exponent_bits+C_mantissa_bits-1 downto C_mantissa_bits)
                                    + C_exponent_offset;
           -- load mantissa and reveal its hidden MSB bit '1'
           R_pipe_data(i).mantissa_a(C_precision_bits-1 downto C_precision_bits-C_mantissa_bits-1)
                                  <= '1' & y(C_mantissa_bits-1 downto 0);
           R_pipe_data(i).mantissa_a(C_precision_bits-C_mantissa_bits-2 downto 0) <= (others => '0');
           -- b is the same as a, but it has one bit more precision
           -- intially loaded with '0' (when it becomes 1 then renormalization should be done)
           -- following bits are unhidden MSB and the rest of mantissa
           R_pipe_data(i).mantissa_b(C_precision_bits downto C_precision_bits-C_mantissa_bits-1)
                                  <= "01" & x(C_mantissa_bits-1 downto 0);
           R_pipe_data(i).mantissa_b(C_precision_bits-C_mantissa_bits-2 downto 0) <= (others => '0');
         else
           -- pipelined data processing
           -- one extra register layer to infer pipelined multiplication
           R_sign(i) <= sign(i);
           R_exponent(i) <= exponent(i);
           R_ac(i) <= ac(i)(2*C_precision_bits-1 downto C_precision_bits);
           R_bc(i) <= bc(i)(2*C_precision_bits+1 downto C_precision_bits);
           -- all below next_* signals are combinatorial based on above R_* registers
           R_pipe_data(i).sign       <= next_sign(i);
           R_pipe_data(i).exponent   <= next_exponent(i);
           R_pipe_data(i).mantissa_a <= next_a(i);
           R_pipe_data(i).mantissa_b <= next_b(i);
         end if;
       end if;
     end process;
   end generate;
   
   -- calculation must be done so that in the last stage
   -- the number is normalized
   -- because we must hide mantissa MSB bit at the output

   -- last stage of pipeline is the output
   q <= R_pipe_data(C_pipe_stages-1).sign
      & R_pipe_data(C_pipe_stages-1).exponent
      & R_pipe_data(C_pipe_stages-1).mantissa_b(C_precision_bits-2 downto C_precision_bits-C_mantissa_bits-1); -- again hide MSB bit
end;
