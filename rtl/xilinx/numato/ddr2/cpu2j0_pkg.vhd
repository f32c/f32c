-- Interface Library for the HS-2J0 CPU core

library ieee;
use ieee.std_logic_1164.all;

package cpu2j0_pack is 
   type cpu_instruction_o_t is record
      en   : std_logic;
      a    : std_logic_vector(31 downto 1);
      jp   : std_logic;
   end record;
   constant NULL_INST_O : cpu_instruction_o_t := (en => '0', a => (others => '0'), jp => '0');

   type cpu_instruction_i_t is record
      d    : std_logic_vector(15 downto 0);
      ack  : std_logic;
   end record;

   type cpu_data_o_t is record
      en   : std_logic;
      a    : std_logic_vector(31 downto 0);
      rd   : std_logic;
      wr   : std_logic;
      we   : std_logic_vector(3 downto 0);
      d    : std_logic_vector(31 downto 0);
   end record;
   constant NULL_DATA_O : cpu_data_o_t := (en => '0', a => (others => '0'), rd => '0', wr => '0', we => "0000", d => (others => '0'));

   type cpu_data_i_t is record
      d    : std_logic_vector(31 downto 0);
      ack  : std_logic;
   end record;

   type cpu_debug_o_t is record
      ack  : std_logic;
      d    : std_logic_vector(31 downto 0);
      rdy  : std_logic;
   end record;

   type cpu_debug_cmd_t is (BREAK, STEP, INSERT, CONTINUE);

   type cpu_debug_i_t is record
      en   : std_logic;
      cmd  : cpu_debug_cmd_t;
      ir   : std_logic_vector(15 downto 0);
      d    : std_logic_vector(31 downto 0);
      d_en : std_logic;
   end record;
   constant CPU_DEBUG_NOP : cpu_debug_i_t := (en => '0', cmd => BREAK, ir => (others => '0'), d => (others => '0'), d_en => '0');

   type cpu_event_cmd_t is (INTERRUPT, ERROR, BREAK, RESET_CPU);

   type cpu_event_i_t is record
      en   : std_logic;
      cmd  : cpu_event_cmd_t;
      vec  : std_logic_vector(7 downto 0);
      msk  : std_logic;
      lvl  : std_logic_vector(3 downto 0);
   end record;
   constant NULL_CPU_EVENT_I : cpu_event_i_t := (en => '0',
                                                 cmd => INTERRUPT,
                                                 vec => (others => '0'),
                                                 msk => '0',
                                                 lvl => (others => '1'));

   type cpu_event_o_t is record
      ack  : std_logic;
      lvl  : std_logic_vector(3 downto 0);
      slp  : std_logic;
      dbg  : std_logic;
   end record;

   component cpu is port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      db_o         : out cpu_data_o_t;
      db_lock      : out std_logic;
      db_i         : in  cpu_data_i_t;
      inst_o       : out cpu_instruction_o_t;
      inst_i       : in  cpu_instruction_i_t;
      debug_o      : out cpu_debug_o_t;
      debug_i      : in  cpu_debug_i_t;
      event_o      : out cpu_event_o_t;
      event_i      : in  cpu_event_i_t);
   end component cpu;

   function loopback_bus(b : cpu_data_o_t) return cpu_data_i_t;
end cpu2j0_pack;

package body cpu2j0_pack is
   function loopback_bus(b : cpu_data_o_t) return cpu_data_i_t is
   variable r : cpu_data_i_t;
   begin
      r.ack := b.en;
      r.d := (others => '0');
      return r;
   end function loopback_bus;
end cpu2j0_pack;
