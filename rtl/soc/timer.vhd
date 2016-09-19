--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

-- EMARD advanced timer

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity timer is
    generic (
        -- warning: C_ocps + C_icps = 4
        C_ocps: integer range 0 to 4 := 2;  -- number of ocp units 0-4
        C_icps: integer range 0 to 2 := 2;  -- number of icp units 0-2
        C_period_frac: integer range 0 to 16 := 0;     -- period resolution enhancement bits (1-16)
        C_have_afc: boolean := true; -- if you don't need AFC, set to false and save some LUTs
        C_afc_immediate_sp: boolean := true; -- set to true to save some LUTs, setpoint will be compared against Rtmp instead of R - apply not needed 
        C_have_intr: boolean := true;
        -- setting C_period_frac to 0 will disable both period and frac
        -- period and frac registers can be used for AFC limits
        C_pres: integer range 0 to 32 := 10; -- number of prescaler bits (0-32)
	C_bits: integer range 2 to 32 := 12  -- bit size of the timer (2-32)
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	addr: in std_logic_vector(3 downto 0); -- address 16 registers
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	timer_irq: out std_logic; -- interrut requuest line (active level high)
	sign: out std_logic; -- output MSB (sign) bit
	icp_enable: out std_logic_vector(C_icps-1 downto 0); -- input enable bits
	ocp_enable: out std_logic_vector(C_ocps-1 downto 0); -- output enable bits
	icp: in std_logic_vector(C_icps-1 downto 0); -- input capture signals
	ocp: out std_logic_vector(C_ocps-1 downto 0) -- output compare signals
    );
end timer;

architecture arch of timer is
    constant C_addr_bits: integer := 4; -- number of register address bits
    constant C_registers: integer := 16; -- total number of timer registers
    -- register R(0) counter is kept in separated register so it
    -- can be incremented in  processs block seprate from R(x)
    -- R(15) is apply and it doesn't need to be kept in memory
    -- however we will create all 16 registers and leave it up
    -- to optimizer to reduce unused rather than make code more complex
    constant C_ext_registers: integer := 3; -- total number of extended registers by C_pres bits
    -- normal registers
    type timer_reg_type is array (C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R, Rtmp: timer_reg_type; -- register access from mmapped I/O  R: active register, Rtmp temporary
    -- extended registers
    type timer_ext_reg_type is array (C_ext_registers-1 downto 0) of std_logic_vector(C_pres-1 downto 0);
    signal Rx, Rxtmp: timer_ext_reg_type; -- register access from mmapped I/O  Rx: active register, Rxtmp temporary
    -- active registers for the timer logic (copied when writing to apply register
    signal commit: std_logic; -- detects a write cycle to apply register
    -- period enhancement register and its next value
    signal R_fractional, L_fractional_next: std_logic_vector(C_period_frac downto 0);
    constant C_ctrl_bits: integer := 24; -- number of control bits
    -- extension for increment register for missing prescaler bits in addressable storage
    -- extended increment register naming
    signal R_increment, R_inc_min, R_inc_max, R_increment_faster, R_increment_slower: 
      std_logic_vector(C_bits+C_pres-1 downto 0);
    -- aggregate signal to run increment faster or slower
    signal R_faster, R_slower: std_logic;
    -- extension for control register (this extension is different than C_ext_registers)
    signal Rtmp_ctrl_ext, R_ctrl_ext: std_logic_vector(C_ctrl_bits-C_bits-1 downto 0);
    -- complete control register (extended if needed)
    signal Rtmp_control, R_control: std_logic_vector(C_ctrl_bits-1 downto 0);
    
    -- max number of ocp/icp units determined by fixed
    -- register locations in address space - to allocate address space
    constant C_icps_max:   integer   := 2;
    constant C_ocps_max:   integer   := 4;
    -- max combined icps and ocps. Condition:
    -- C_iocps_max >= C_icps_max
    -- C_iocps_max >= C_ocps_max
    -- C_iocps_max <= C_icps_max+C_ocps_max
    constant C_iocps_max:  integer   := 4;

    -- *** REGISTERS ***
    -- named constants for the timer registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_counter:    integer   := 0;
    constant C_increment:  integer   := 1;
    constant C_inc_min:    integer   := 2; -- used as minimum AFC increment
    constant C_inc_max:    integer   := 3; -- used as maximum AFC increment
    constant C_period:     integer   := C_inc_min; -- unused if C_period_frac=0
    constant C_fractional: integer   := C_inc_max; -- unused if C_period_frac=0
    type ocp_array is array (0 to C_ocps_max-1) of integer range 0 to C_registers-1;
    constant C_ocpn_start: ocp_array := (4, 6, 8, 10);
    constant C_ocpn_stop:  ocp_array := (5, 7, 9, 11);
    type icp_array is array (0 to C_icps_max-1) of integer range 0 to C_registers-1;
    constant C_icpn_start: icp_array := (10, 8);  -- numbering goes downwards
    constant C_icpn_stop:  icp_array := (11, 9);
    constant C_icpn:       icp_array := (12, 13); -- 2 input capture registers, memory used for AFC ICP setpoint

    constant C_control:    integer   := 14;
    constant C_apply:      integer   := 15; -- no need for memory
    
    -- extended registers by C_pres bits
    -- array of registers R and Rtmp that have extension
    -- required in the for-generate loop for register extension
    type ext_array is array (0 to C_ext_registers-1) of integer range 0 to C_registers-1;
    constant C_ext:        ext_array := (C_increment, C_inc_min, C_inc_max);
    -- named indexes of the Rx extended registers
    constant C_xincrement: integer   := 0;
    constant C_xinc_min:   integer   := 1;
    constant C_xinc_max:   integer   := 2;
    
    -- *** CONTROL BITS ***
    -- constants to name bit position in control register
    type ctrl_ocp_array is array (0 to C_ocps_max-1) of integer range 0 to C_ctrl_bits-1;
    type ctrl_icp_array is array (0 to C_icps_max-1) of integer range 0 to C_ctrl_bits-1;
    constant C_ocpn_intr:   ctrl_ocp_array := (0,1,2,3);     -- ocp interrupt flags (must occupy lowest index)
    constant C_icpn_intr:   ctrl_icp_array := (3,2);         -- icp interrupt flags (must occupy lowest index)
    constant C_ocpn_and:    ctrl_ocp_array := (4,5,6,7);     -- ocp 1=and,0=or condition (for wraparound)
    constant C_icpn_and:    ctrl_icp_array := (7,6);         -- icp 1=and,0=or condition (for wraparound)
    constant C_ocpn_ie:     ctrl_ocp_array := (8,9,10,11);   -- ocp interrupt enable
    constant C_icpn_ie:     ctrl_icp_array := (11,10);       -- icp interrupt enable
    constant C_ocpn_xor:    ctrl_ocp_array := (12,13,14,15); -- ocp xor 1=inverted,0=normal
    constant C_icpn_xor:    ctrl_icp_array := (15,14);       -- icp xor 1=inverted,0=normal
    constant C_icpn_afcen:  ctrl_icp_array := (16,18);       -- enable ICP AFC
    constant C_icpn_afcinv: ctrl_icp_array := (17,19);       -- invert ICP AFC logic
    constant C_ocpn_enable: ctrl_ocp_array := (20,21,22,23); -- ocp physical output enable bits
    constant C_icpn_enable: ctrl_icp_array := (23,22);       -- icp physical input enable bits

    signal R_counter: std_logic_vector(C_bits+C_pres-1 downto 0); -- handled specificaly (auto-increments)

    -- input capture related registers
    type icp_reg_type is array (0 to C_icps-1) of std_logic_vector(C_bits-1 downto 0);
    signal R_icp: icp_reg_type;
    constant C_icp_sync_depth: integer := 3; -- number of shift register stages (default 3) for icp clock synchronization
    type T_icp_sync_shift is array (0 to C_icps-1) of std_logic_vector(C_icp_sync_depth-1 downto 0); -- icp synchronizer type
    signal R_icp_sync_shift: T_icp_sync_shift;
    signal R_icp_rising_edge: std_logic_vector(C_icps-1 downto 0);
    signal R_icp_hit: std_logic_vector(C_icps-1 downto 0); -- becomes 1 when icp condition is met
    signal R_icp_lt_sp: std_logic_vector(C_icps-1 downto 0); -- becomes 1 when icp is less than setpoint
    signal R_icp_wants_faster: std_logic_vector(C_icps-1 downto 0);
    signal R_icp_wants_slower: std_logic_vector(C_icps-1 downto 0);


    -- output compare related registers
    --type ocp_reg_type is array (0 to C_ocps_max-1) of std_logic_vector(C_bits-1 downto 0);
    --signal R_ocp_start, R_ocp_stop: ocp_reg_type;
    constant C_ocp_sync_depth: integer := 2; -- number of shift register stages (default 2) for ocp edge detection
    type T_ocp_sync_shift is array (0 to C_ocps-1) of std_logic_vector(C_ocp_sync_depth-1 downto 0); -- ocp synchronizer type
    signal R_ocp_sync_shift: T_ocp_sync_shift;
    signal R_ocp_rising_edge: std_logic_vector(C_ocps-1 downto 0);
    signal R_ocp: std_logic_vector(C_ocps-1 downto 0);

    -- interrupt flag register (both icp and ocp)
    -- addressed by C_ocpn_intr and C_icpn_intr
    signal Rintr: std_logic_vector(C_iocps_max-1 downto 0);
    
    signal internal_ocp: std_logic_vector(C_ocps-1 downto 0); -- non-inverted ocp signal
    
    -- both true and false should provide the same result
    -- with different number of LUTs used
    constant C_afc_joint_register : boolean := true;
    -- true: afc joint register is true combinatorial logic
    -- false: if optimizer is good it will produce combinatorial logic
    
    -- function to join all interrupt bits into one
    impure function interrupt(n_ocps, n_icps: integer) return std_logic is
      variable i: integer;
      variable intr: std_logic;
    begin
      intr := '0';
      if C_have_intr then
      for i in 0 to n_ocps-1 loop
        intr := intr or (R_control(C_ocpn_ie(i)) and Rintr(C_ocpn_intr(i)));
      end loop;
      for i in 0 to n_icps-1 loop
        intr := intr or (R_control(C_icpn_ie(i)) and Rintr(C_icpn_intr(i)));
      end loop;
      end if;
      return intr;
    end interrupt;
    
    -- function to return value to the bus when reading registers
    -- flexible for variable number of icps
    impure function busoutput(a: std_logic_vector(C_addr_bits-1 downto 0)) return std_logic_vector is
      variable i, adr: integer;
      variable retval: std_logic_vector(31 downto 0);
    begin
      adr := conv_integer(a);
      retval := ext(Rtmp(adr),32); -- default value
      if adr = C_counter then
        -- counter is separate from R
        retval := ext(R_counter(C_bits+C_pres-1 downto C_pres), 32);
      end if;
      if adr = C_increment then
        -- increment is separate from R
        retval := ext(R_increment, 32);
      end if;
      if adr = C_control then
        -- control has extended bits - separate from R
        retval := ext(Rtmp_control(C_ctrl_bits-1 downto C_iocps_max) & Rintr,32);
      end if;
      for i in 0 to C_icps-1 loop
        -- input capture value is read (from R)
        -- setpoint in Rtmp is unreadable
        if adr = C_icpn(i) then
          retval := ext(R_icp(i), 32);
        end if;
      end loop;
      return retval;
    end busoutput;

begin
    bus_out <= busoutput(addr);
    
    sign <= R_counter(C_bits+C_pres-1); -- output sign (MSB bit of the counter)
    
    -- this will save us some typing
    commit <= '1' when ce = '1' and bus_write = '1' and addr = C_apply else '0';
    
    -- next value of the enhancement register
    next_fractional_value: if C_period_frac > 0 generate
      with R_fractional(C_period_frac) select
        L_fractional_next <= R_fractional - ('0' & R(C_fractional)(C_period_frac-1 downto 0)) + ('1' & (C_period_frac-1 downto 0 => '0')) when '1',
                             R_fractional - ('0' & R(C_fractional)(C_period_frac-1 downto 0)) when others;
    end generate;
    
    -- extended increment
    R_increment <= Rx(C_xincrement) & R(C_increment);

    -- AFC increment control and extended limits
    afc_faster_slower: if C_have_afc generate
      R_inc_min <= Rx(C_xinc_min) & R(C_inc_min);
      R_inc_max <= Rx(C_xinc_max) & R(C_inc_max);
      R_increment_faster <= R_increment+1;
      R_increment_slower <= R_increment-1;
    end generate;

    faster_slower_afc: if C_have_afc and C_afc_joint_register generate
    -- takes more LUT than old_faster_slower_afc?
    for_icp_afc: for i in 0 to C_icps-1 generate
        R_icp_wants_faster(i) <= '1' 
          when R_icp_hit(i) = '1' -- icp hit
          -- previous icp value less than the setpoint
          and ( R_icp_lt_sp(i)='1' xor R_control(C_icpn_afcinv(i))='1' )  
          and R_control(C_icpn_afcen(i)) = '1' -- and afc is enabled
          else '0';
        R_icp_wants_slower(i) <= '1' 
          when R_icp_hit(i) = '1' -- icp hit
          -- previous icp value greater than the setpoint 
          and ( R_icp_lt_sp(i)='0' xor R_control(C_icpn_afcinv(i))='1' )
          and R_control(C_icpn_afcen(i)) = '1' -- and afc is enabled
          else '0';
    end generate;
    R_faster <= '1' when R_increment < R_inc_max and R_icp_wants_faster /= 0 else '0';
    R_slower <= '1' when R_increment > R_inc_min and R_icp_wants_slower /= 0 else '0';
    end generate;
    
    old_faster_slower_afc: if C_have_afc and not C_afc_joint_register generate
      -- looks like it could be written shorter
      -- optimizer should recognize this as combinatorial logic
      process(clk)
        variable faster : std_logic;
        variable slower : std_logic;
      begin
        faster := '0';
        slower := '0';
        for i in 0 to C_icps-1 loop
          if R_icp_hit(i) = '1' -- afc hit
            -- previous icp value less than the setpoint
            and ( R_icp_lt_sp(i)='1' xor R_control(C_icpn_afcinv(i))='1' )  
            and R_control(C_icpn_afcen(i)) = '1' -- and afc is enabled
          then
            faster := '1';
          end if;
          if R_icp_hit(i) = '1' -- afc hit
            -- previous icp value less than the setpoint
            and ( R_icp_lt_sp(i)='0' xor R_control(C_icpn_afcinv(i))='1' )  
            and R_control(C_icpn_afcen(i)) = '1' -- and afc is enabled
          then
            slower := '1';
          end if;
        end loop;
        if R_increment < R_inc_max and faster = '1' then
          R_faster <= '1';
        else
          R_faster <= '0';
        end if;
        if R_increment > R_inc_min and slower = '1' then
          R_slower <= '1';
        else 
          R_slower <= '0';
        end if;
      end process;
    end generate;

    -- extended control register
    extended_control_register: if C_ctrl_bits > C_bits generate
      R_control <= R_ctrl_ext & R(C_control);
      Rtmp_control <= Rtmp_ctrl_ext & Rtmp(C_control);
    end generate;
    
    trimmed_control_register: if C_ctrl_bits <= C_bits generate
      R_control <= R(C_control)(C_ctrl_bits-1 downto 0);
      Rtmp_control <= Rtmp(C_control)(C_ctrl_bits-1 downto 0);
    end generate;

    -- join all interrupt request bits into one bit
    timer_irq <= interrupt(C_ocps, C_icps);
    
    -- counter
    process(clk)
    begin
    if rising_edge(clk) then
        -- writing bit in apply register will commit change to counter
        if commit = '1' and bus_in(C_counter)='1' then
          R_counter(C_bits+C_pres-1 downto C_pres) <= Rtmp(C_counter); -- write from temporary to counter
        else
          if C_period_frac = 0 then
            R_counter <= R_counter + R_increment;
          else
            if R_counter(C_bits+C_pres-1 downto C_pres) < R(C_period) + R_fractional(C_period_frac) then
              R_counter <= R_counter + R_increment;
            else
              R_counter <= (others => '0');
              R_fractional <= L_fractional_next;
            end if;
          end if;
        end if;
        -- debug purpose: increment when reading LSB
        -- if ce = '1' and bus_write = '0' and byte_sel(0) = '1' then
        --     R(counter) <= R(counter) + 1;
        -- end if;
    end if;
    end process;

    output_compare: for i in 0 to C_ocps-1 generate
    internal_ocp(i) <= '1' when
         ( R_control(C_ocpn_and(i))='0' 
           and ( R_counter(C_bits+C_pres-1 downto C_pres) >= R(C_ocpn_start(i)) 
             or  R_counter(C_bits+C_pres-1 downto C_pres) <  R(C_ocpn_stop(i)) ) )
      or ( R_control(C_ocpn_and(i))='1' 
           and ( R_counter(C_bits+C_pres-1 downto C_pres) >= R(C_ocpn_start(i)) 
             and R_counter(C_bits+C_pres-1 downto C_pres) <  R(C_ocpn_stop(i)) ) )
      else '0';
    glitchfree_ocp_if_not_have_interrupt:
    if not C_have_intr generate
      process(clk)
      begin
        -- Store the OCP in output register to avoid possible nanosecond glitch
        -- in "OR" mode at zero-crossing of the counter. Glitch is a side-effect of
        -- propagation delay in the combinatorial logic of internal_ocp(i).
        if rising_edge(clk) then
          R_ocp(i) <= internal_ocp(i) xor R_control(C_ocpn_xor(i)); -- output optionally inverted
        end if;
      end process;
      ocp(i) <= R_ocp(i);
    end generate;
    glitchfree_ocp_if_have_interrupt:
    if C_have_intr generate
      -- similar as above but with less LUTs
      -- R_ocp_sync_shift(i)(0) is internal_ocp(i) stored in register
      -- and it should be glitch-free
      ocp(i) <= R_ocp_sync_shift(i)(0) xor R_control(C_ocpn_xor(i)); -- output optionally inverted
    end generate;
    ocp_enable(i) <= R_control(C_ocpn_enable(i));

    ocp_interrupt: if C_have_intr generate
    -- ocp synchronizer (2-stage shift register)
    process(clk)
    begin
      if rising_edge(clk) then
        R_ocp_sync_shift(i)(C_ocp_sync_depth-1 downto 1) <= R_ocp_sync_shift(i)(C_ocp_sync_depth-2 downto 0);
        R_ocp_sync_shift(i)(0) <= internal_ocp(i); -- non-iverted ocp is fed here
      end if;
    end process;

    -- difference in 2 last bits of the shift register detect synchronous rising edge
    -- when at C_ocp_sync_depth-1 is 0, and one clock earlier at C_ocp_sync_depth-2 is 1
    R_ocp_rising_edge(i) <= '1' when 
         R_ocp_sync_shift(i)(C_ocp_sync_depth-1) = '0' -- it was 0 
     and R_ocp_sync_shift(i)(C_ocp_sync_depth-2) = '1' -- 1 is coming after 0
     else '0';

    -- *** OCP INTERRUPT ***
    -- write cycle with bits 0 to Rtmp(C_control) register will reset interrupt flag
    -- no write to apply register is needed to clear the flag
    process(clk)
    begin
      if rising_edge(clk) then
        -- chack for rising edge of ocp
        if R_ocp_rising_edge(i) = '1' then
          Rintr(C_ocpn_intr(i)) <= '1';
        else
          -- writing 1 to Rtmp(C_control)(C_ocpn_intr(i))
          -- will immediately reset interrupt flags
          -- (without need for writing to apply register)
          if ce = '1' and bus_write = '1' and addr = C_control 
            and bus_in(C_ocpn_intr(i)) = '1' and byte_sel(C_ocpn_intr(i)/8) = '1' then
            Rintr(C_ocpn_intr(i)) <= '0';
          end if;
        end if;
      end if;
    end process;
    end generate; -- end ocp_interrupt
    end generate; -- end output_compare

    -- warning - asynchronous external icp rising edge
    -- should be passed to async->sync filter to match
    -- the input clock and then be processed.
    -- here is theory and schematics about 3-stage shift register
    -- https://www.doulos.com/knowhow/fpga/synchronisation/
    -- here is vhdl implementation of the 3-stage shift register
    -- http://www.bitweenie.com/listings/vhdl-shift-register/
    input_capture: for i in 0 to C_icps-1 generate    
    icp_enable(i) <= R_control(C_icpn_enable(i));
    -- icp synchronizer (3-stage shift register)
    process(clk)
    begin
      if rising_edge(clk) then
        R_icp_sync_shift(i)(C_icp_sync_depth-1 downto 1) <= R_icp_sync_shift(i)(C_icp_sync_depth-2 downto 0);
        R_icp_sync_shift(i)(0) <= icp(i);
      end if;
    end process;

    -- difference in 2 last bits of the shift register detect synchronous rising edge
    -- when at C_icp_sync_depth-1 is 0, and one clock earlier at C_icp_sync_depth-2 is 1
    R_icp_rising_edge(i) <= '1' when 
         (R_icp_sync_shift(i)(C_icp_sync_depth-1) = ('0' xor R_control(C_icpn_xor(i))) ) -- it was 0 
     and (R_icp_sync_shift(i)(C_icp_sync_depth-2) = ('1' xor R_control(C_icpn_xor(i))) ) -- 1 is coming after 0
     else '0';
     
    -- detect ICP HIT condition
    R_icp_hit(i) <= '1' when R_icp_rising_edge(i) = '1' and
        (    ( R_control(C_icpn_and(i))='0'  -- OR combination
               and ( R_counter(C_bits+C_pres-1 downto C_pres) >= R(C_icpn_start(i)) 
                 or  R_counter(C_bits+C_pres-1 downto C_pres) <  R(C_icpn_stop(i)) ) )
          or ( R_control(C_icpn_and(i))='1'  -- AND combination
               and ( R_counter(C_bits+C_pres-1 downto C_pres) >= R(C_icpn_start(i)) 
                and  R_counter(C_bits+C_pres-1 downto C_pres) <  R(C_icpn_stop(i)) ) )
        ) else '0';

    -- process based on clock synchronous icp
    process(clk)
    begin
      -- icp-initiated copying of R_counter register must be
      -- clock synchronous. When content of R_counter
      -- becomes stable then it can be copied to R_icp(i)
      if rising_edge(clk) then
        if R_icp_hit(i) = '1' then
          R_icp(i) <= R_counter(C_bits+C_pres-1 downto C_pres);
        end if;
      end if;
    end process;

    icp_interrupt: if C_have_intr generate
    -- *** ICP INTERRUPT ***
    -- write cycle with bits 0 to Rtmp(C_control) register will reset interrupt flag
    -- no write to apply register is needed to clear the flag
    process(clk)
    begin
      if rising_edge(clk) then
        -- chack for rising edge of ocp
        if R_icp_rising_edge(i) = '1' then
          Rintr(C_icpn_intr(i)) <= '1';
        else
          -- writing 1 to Rtmp(C_control)(C_icpn_intr(i))
          -- will immediately reset interrupt flags
          -- (without need for writing to apply register)
          if ce = '1' and bus_write = '1' and addr = C_control 
           and bus_in(C_icpn_intr(i)) = '1' and byte_sel(C_icpn_intr(i)/8) = '1' then
            Rintr(C_icpn_intr(i)) <= '0';
          end if;
        end if;
      end if;
    end process;
    end generate; -- end icp_interrupt

    applied_sp: if C_have_afc and not C_afc_immediate_sp generate
    -- AFC: compare actual ICP value (R_icp) with setpoint (R), need apply to activate
    R_icp_lt_sp(i) <= '1' when R_icp(i) < R(C_icpn(i)) else '0'; -- test: is icp less than setpoint?
    end generate;

    immediate_sp: if C_have_afc and C_afc_immediate_sp generate
    -- AFC: compare actual ICP value (R_icp) with setpoint (Rtmp), immediately active, no apply
    R_icp_lt_sp(i) <= '1' when R_icp(i) < Rtmp(C_icpn(i)) else '0'; -- test: is icp less than setpoint?
    end generate;

    end generate; -- end input capture
    
    -- writing from temporary registers to active registers
    -- this is 'apply' register actually this is not a real register
    -- just a location to write
    commit_Rtmp_to_R: for i in 0 to C_registers-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if commit = '1' then
          if bus_in(i) = '1' and byte_sel(i/8) = '1' then
            R(i) <= Rtmp(i);
          end if;
        else
          -- if not commit (begin)
          -- if ICP hit, copy counter value to active register
          -- emard: doin this here is dirty but allows to write ICP
          --for j in 0 to C_icps-1 loop
          --  if i = C_icpn(j) then
          --    if R_icp_hit(j) = '1' then
          --      R(i) <= R_counter(C_bits+C_pres-1 downto C_pres);
          --    end if;
          --  end if;
          --end loop;

          -- special case for AFC
          -- AFC of the increment step using ICP
          -- R(C_increment) contains lower bits
          if C_have_afc then
            if i = C_increment then
              if R_faster = '1' and R_slower = '0' then
                R(i) <= R_increment_faster(C_bits-1 downto 0);
              end if;
              if R_slower = '1' and R_faster = '0' then
                R(i) <= R_increment_slower(C_bits-1 downto 0);
              end if;
            end if;
          end if;
          -- if not commit (end)
        end if;
      end if;
    end process;
    end generate; -- end writing Rtmp to R

    -- commit extra prescaler bits for increment
    commit_extended_Rtmp_to_R: for i in 0 to C_ext_registers-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if commit = '1' then
          if bus_in(C_ext(i)) = '1' and byte_sel(C_ext(i)/8) = '1' then
            Rx(i) <= Rxtmp(i);
          end if;
        end if;
        -- special case for AFC
        -- Rx(C_xincrement) contains extended higher bits
        if C_have_afc and i = C_xincrement then
          if R_faster = '1' and R_slower = '0' then
            Rx(i) <= R_increment_faster(C_bits+C_pres-1 downto C_bits);
          end if;
          if R_slower = '1' and R_faster = '0' then
            Rx(i) <= R_increment_slower(C_bits+C_pres-1 downto C_bits);
          end if;
        end if;
      end if;
    end process;
    end generate; -- end writing Rxtmp to Rx

    -- commit extra control bits for increment
    commit_extra_control_bits: if C_ctrl_bits > C_bits generate
    process(clk)
    begin
      if rising_edge(clk) then
        if commit = '1' then
          if bus_in(C_control) = '1' and byte_sel(C_control/8) = '1' then
            R_ctrl_ext <= Rtmp_ctrl_ext;
          end if;
        end if;
      end if;
    end process;
    end generate;

    -- writing from bus to temporary registers
    process(clk)
    variable i: integer := 0;
    begin
    if rising_edge(clk) then
        if ce = '1' and bus_write = '1' then
            byte_write: for i in 0 to C_bits/8-1 loop
            if byte_sel(i) = '1' then
              Rtmp(conv_integer(addr))(8*i+7 downto 8*i) <= bus_in(8*i+7 downto 8*i);
            end if;
            end loop;
            -- partial byte remaining?
            if (C_bits mod 8) > 0 then
              if byte_sel(C_bits/8) = '1' then
                Rtmp(conv_integer(addr))(C_bits-1 downto (C_bits/8)*8) <= bus_in(C_bits-1 downto (C_bits/8)*8);
              end if;
            end if;
        end if;
    end if;
    end process;

    -- write extended temporary bits to Rxtmp(i)(C_pres-1 downto 0)
    -- TODO/FIXME do we need byte_write here, same as above?
    write_Rxtmp: for i in 0 to C_ext_registers-1 generate
    process(clk)
    begin
    if rising_edge(clk) then
        if ce = '1' and bus_write = '1' and addr = C_ext(i) then
            Rxtmp(i)(C_pres-1 downto 0) <= bus_in(C_bits+C_pres-1 downto C_bits);
        end if;
    end if;
    end process;
    end generate;

    -- write extra control bits to Rtmp_ctrl_ext(C_ctrl_bits-C_bits-1 downto 0)
    write_Rtmp_extra_control_bits: if C_ctrl_bits > C_bits generate
    process(clk)
    begin
    if rising_edge(clk) then
        if ce = '1' and bus_write = '1' and addr = C_control then
            Rtmp_ctrl_ext(C_ctrl_bits-C_bits-1 downto 0) <= bus_in(C_ctrl_bits-1 downto C_bits);
        end if;
    end if;
    end process;
    end generate;
end;

-- todo

-- additional resolution for the period
-- extra 4 or 8 bits 

-- timer registers can be up to 32 bits,
-- lower bit width is possible
-- they can be written with a single 32-bit write

-- registers (multply C_register_name by 4 to get byte offset)

-- timer control register
-- 1: R_timer_control

-- *** byte 0 : interrupts flags, output mixing ***
-- bit 0: interrupt ocp0 flag 1=pending 0=resolved (write 1 to resolve)
-- bit 1: interrupt ocp1 flag 1=pending 0=resolved (write 1 to resolve)
-- bit 2: interrupt icp1 flag 1=pending 0=resolved (write 1 to resolve)
-- bit 3: interrupt icp0 flag 1=pending 0=resolved (write 1 to resolve)
-- bit 4: output compare 0 filter select 1=and 0=or (ocpc1)
--        0 (or):  ocpc1 = (R_counter >= R_ocp0_start or  R_counter < R_ocp1_start)
--        1 (and): ocpc1 = (R_counter >= R_ocp1_start and R_counter < R_ocp1_start)
-- bit 5: output compare 1 filter select 1=and 0=or (ocpc2 similar as above)
-- bit 6: input  capture 1 filter select 1=and 0=or (icp0 as above)
-- bit 7: input  capture 0 filter select 1=and 0=or (icp1 as above)

-- *** byte 1 : interrupt enable, AFC enable *** 
-- bit 0: interrupt ocp0 1=enable 0=disable
-- bit 1: interrupt ocp1 1=enable 0=disable
-- bit 2: interrupt icp1 1=enable 0=disable
-- bit 3: interrupt icp0 1=enable 0=disable
-- bit 4: interrupt ocp0 xor (physical output line invert)
-- bit 5: interrupt ocp1 xor (pyhsical output line invert)
-- bit 6: interrupt icp1 xor 0-rising edge, 1-falling edge
-- bit 7: interrupt icp0 xor 0-rising edge, 1-falling edge

-- *** byte 2 : input/output inverters ***
-- bit 0: AFC icp0 enable. 0=Off 1=On
-- bit 1: AFC icp0 invert. 0=normal 1=inverted
-- bit 2: AFC icp1 enable. 0=Off 1=On
-- bit 3: AFC icp1 invert. 0=normal 1=inverted


-- apply: registar to apply timer changes
-- writing bit 1 to this register will apply changes
-- to appropriate timer register
-- except itself, applied immediately :)
-- bit 0: counter
-- bit 1: period
-- ...
-- etc. bits, the same order as in the register R()


-- output compare register components muxing to physical output:
-- hardcoded in hdl
-- physical output A = ocpc1 or  ocpc2
-- physical output B = ocpc1 and ocpc2

-- filter for input capture (lower and upper limit register)
-- input capture will happen in selectable and/or condition
-- when counter is within this range
-- R_icp_low <= counter < R_icp_high

-- purpose of AND/OR:
-- when R_icp_low < R_icp_high, use AND
-- when R_icp_low > R_icp_high, use OR (outputs signal during wraparound phase)

-- todo
-- [x] selectable inverter for input
-- [ ] input inverter testing
-- [x] selectable inverter for output
-- [ ] output inverter testing
-- [x] make variable C_bits work for values other than 32
-- [x] generate icp/ocp units: if no units, all registers are generated
--       can save some LE to also leave out unused registers
-- [x] signals for interrupts
-- [x] prescaler for R_increment
-- [x] different number of bits for control and apply register
-- [x] separate temporary and active registers, apply to copy
-- [x] the period, with resolution enhancement
-- [x] generalized apply to registers, one for-generate loop
-- [x] can leave out period and fractional
-- [ ] optionally with or without Rtmp and apply
-- [x] different number of bits for increment,
--     different number of control, apply
-- [ ] possible optimizations in R, Rtmp
--     counter, period, apply, control -- some memory is not used
-- [x] AFC icp -> increment steering
-- [x] AFC control bits for AFC icp
-- [x] AFC upper and lower limits of increment
-- [x] replace R(C_control) with R_control
-- [x] R_control needs testing
-- [x] afc controlled icrement is now readable
-- [x] flags to enable/disable icp/ocp interrupts
-- [x] extend afc limit registers, remove C_afc_limit_shift
-- [ ] 8-bit write maybe doesn't work for extended registers - need testing
-- [x] reorder registers: ocp rising addr, icp falling addr 
-- [x] AFC setpoint in icp hidden memory, one ICP sufficient for AFC
-- [x] inverse AFC
-- [ ] one-shot operation
-- [x] R_icp_intr_flag has different numbering than C_icpn_intr
-- [ ] allow interrupt at stop of ocp
-- [ ] separate register write for control word
-- [ ] allow shared use of ocp and icp registers (e.g. 3 ocp and 1 icp)
-- [ ] support bus_out for 0-2 icps (now errors if C_icps not 2)
