library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu2j0_pack.all;

package data_bus_pack is
  type data_bus_device_t is (
    DEV_DDR,
    DEV_SRAM,
    DEV_PERIPH,
    DEV_CPU
  );
  type data_bus_i_t is array(data_bus_device_t'left to data_bus_device_t'right)
    of cpu_data_i_t;
  type data_bus_o_t is array(data_bus_device_t'left to data_bus_device_t'right)
    of cpu_data_o_t;

  type instr_bus_device_t is (
    DEV_DDR,
    DEV_SRAM
  );
  type instr_bus_i_t is array(instr_bus_device_t'left to instr_bus_device_t'right)
    of cpu_instruction_i_t;
  type instr_bus_o_t is array(instr_bus_device_t'left to instr_bus_device_t'right)
    of cpu_instruction_o_t;

  function to_bit(b : boolean)
    return std_logic;

  procedure splice_instr_data_bus(signal instr_o : in  cpu_instruction_o_t;
                                  signal instr_i : out cpu_instruction_i_t;
                                  signal data_o  : out cpu_data_o_t;
                                  signal data_i  : in  cpu_data_i_t);
  function loopback_bus(b : cpu_instruction_o_t) return cpu_instruction_i_t;
  function mask_data_o(d: cpu_data_o_t; en : std_logic)
    return cpu_data_o_t;

  type cache_ctrl_t is record
    en  : std_logic;
    inv : std_logic;
  end record;
end;

package body data_bus_pack is
  -- convert boolean to std_logic
  function to_bit(b : boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function to_bit;

  -- Connect an instruction bus to a data bus. The instruction bus is on the
  -- master side. The data bus is on the slave side.
  procedure splice_instr_data_bus(signal instr_o : in  cpu_instruction_o_t;
                                  signal instr_i : out cpu_instruction_i_t;
                                  signal data_o  : out cpu_data_o_t;
                                  signal data_i  : in  cpu_data_i_t) is
  begin
    -- request path
    data_o.en <= instr_o.en;
    data_o.a <= instr_o.a(31 downto 1) & "0";
    data_o.rd <= instr_o.en;
    data_o.wr <= '0';
    data_o.we <= "0000"; -- WE is "0000" for reads
    data_o.d <= (others => '0');

    -- reply path
    instr_i.ack <= data_i.ack;
    if instr_o.a(1) = '0' then
      instr_i.d <= data_i.d(31 downto 16);
    else
      instr_i.d <= data_i.d(15 downto 0);
    end if;
  end;

  function loopback_bus(b : cpu_instruction_o_t) return cpu_instruction_i_t is
   variable r : cpu_instruction_i_t;
   begin
      r.ack := b.en;
      r.d := (others => '0');
      return r;
   end function;

  -- return a cpu_data_o_t with the en, rd, and wr bits masked by the given en bit
  function mask_data_o(d: cpu_data_o_t; en : std_logic)
  return cpu_data_o_t is
    variable r : cpu_data_o_t := d;
  begin
    r.en := en and d.en;
    r.rd := en and d.rd;
    r.wr := en and d.wr;
    return r;
  end function;
end package body;
