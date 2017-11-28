-- AUTHOR=EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

entity max10_boot_preloader is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	-- Main clock: 25/83/100 MHz
	C_clk_freq: integer := 83; -- MHz
	-- SoC configuration options
	C_boot_addr_bits: integer := 8 -- 8: 256x4-byte = 1K
    );
    port (
	clk: in std_logic;
	reset_in: in std_logic;
	reset_out: out std_logic := '0';
	addr: out std_logic_vector(C_boot_addr_bits-1 downto 0);
	strobe: out std_logic;
	data: out std_logic_vector(31 downto 0);
	write: out std_logic;
	ready: in std_logic
    );
end;

architecture Behavioral of max10_boot_preloader is
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic := '1';
  signal S_onchip_reset_n   : std_logic := '0';
  signal R_onchip_addr      : std_logic_vector(16 downto 0) := (others => '0');
  signal S_onchip_read      : std_logic := '1';
  signal S_onchip_rd_valid  : std_logic;
  signal S_onchip_rd_data   : std_logic_vector(31 downto 0);
  signal S_onchip_done      : std_logic;
begin
    S_onchip_reset_n <= not reset_in;
    -- vendor specific onchip flash interface module
    onchip_flash_interface: entity work.onchip_flash
    port map (
      clock => clk,
      avmm_csr_addr => '0', -- always 0
      avmm_csr_read => '0', -- always 0
      avmm_csr_writedata => x"00000000", -- not used
      avmm_csr_write => '0', -- always 0
      avmm_csr_readdata => open, -- not used
      avmm_data_addr => R_onchip_addr, -- addr_counter goes here
      avmm_data_read => S_onchip_read, -- read request signal
      avmm_data_writedata => x"00000000", -- not used, we only read
      avmm_data_write => '0', -- always 0
      avmm_data_readdata => S_onchip_rd_data, -- data going out here
      avmm_data_waitrequest => open,
      avmm_data_readdatavalid => S_onchip_rd_valid,
      avmm_data_burstcount => "01",
      reset_n => S_onchip_reset_n
    );
    addr <= R_onchip_addr(C_boot_addr_bits-1 downto 0);
    strobe <= S_onchip_rd_valid;
    write <= S_onchip_rd_valid;
    data <= S_onchip_rd_data;
    S_onchip_done <= R_onchip_addr(C_boot_addr_bits);
    reset_out <= not S_onchip_done;
    process(clk)
    begin
      if rising_edge(clk) then
        if reset_in = '1' then
          R_onchip_addr <= (others => '0');
        else
          if S_onchip_done = '0' and ready = '1' then
            R_onchip_addr <= R_onchip_addr + 1;
          end if;
        end if;
      end if;
    end process;
end Behavioral;
