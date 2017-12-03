-- AUTHOR=EMARD
-- LICENSE=BSD

-- On input reset rising edge, start the preload using DMA.
-- Primary use is to preload bootloader code.
-- Also it can be used to autostart any application.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

entity boot_preloader is
    generic
    (
      -- ROM data bits
      C_rom_data_bits: integer := 32; -- bits in the ROM
      -- ROM size in addr bits
      -- SoC configuration options
      C_boot_addr_bits: integer := 8 -- 8: 256x4-byte = 1K bootloader size
    );
    port
    (
      clk: in std_logic;
      reset_in: in std_logic := '0';
      reset_out: out std_logic; -- to CPU initially 1
      -- to ROM
      rom_reset, rom_next_data: out std_logic;
      rom_data: in std_logic_vector(C_rom_data_bits-1 downto 0);
      rom_valid: in std_logic;
      -- to DMA
      addr: out std_logic_vector(C_boot_addr_bits-1 downto 0);
      strobe: out std_logic; -- f32c DMA strobe
      data: out std_logic_vector(31 downto 0);
      -- write: out std_logic := '1';
      -- byte_sel: out std_logic_vector(3 downto 0) := "1111"; -- always 32-bit mode
      ready: in std_logic
    );
end;

architecture Behavioral of boot_preloader is
  constant C_slowdown: integer := 1; -- don't touch, must be 1
  constant C_onchip_addr_bits: integer := C_boot_addr_bits+1;
  signal R_prev_reset_in: std_logic := '0'; -- track reset rising edge
  signal R_onchip_addr      : std_logic_vector(C_onchip_addr_bits-1+C_slowdown downto 0) := (others => '0');
  signal S_onchip_read      : std_logic := '1';
  signal S_onchip_rd_valid  : std_logic;
  signal S_onchip_rd_data   : std_logic_vector(31 downto 0);
  signal S_onchip_done      : std_logic;
  signal R_strobe: std_logic := '0';
  signal R_data: std_logic_vector(31 downto 0);
  signal R_addr: std_logic_vector(C_boot_addr_bits-1 downto 0);
  signal R_rom_reset: std_logic := '0';
begin
  rom_reset <= reset_in and not R_prev_reset_in;
  rom_next_data <= R_strobe and ready; -- ready signal from DMA after DMA write request will activate ROM next data fetch
  S_onchip_rd_data <= rom_data;
  S_onchip_rd_valid <= rom_valid;
  -- S_onchip_rd_valid <= '1'; -- debugging

    S_onchip_done <= R_onchip_addr(C_boot_addr_bits+C_slowdown);
    S_onchip_read <= (R_onchip_addr(C_slowdown-1)) and (not S_onchip_done);
    addr <= R_onchip_addr(C_boot_addr_bits+C_slowdown-1 downto C_slowdown);
    data <= R_data; -- output data from latch register
    strobe <= R_strobe; -- request DMA transaction
    reset_out <= not S_onchip_done; -- hold reset until done
    process(clk)
    begin
      if rising_edge(clk) then
        R_prev_reset_in <= reset_in;
        if reset_in = '1' and R_prev_reset_in = '0' then -- reset rising edge
          R_onchip_addr <= (others => '0');
        else
          if S_onchip_done = '0' then
            if (R_onchip_addr(C_slowdown-1) = '0' and R_strobe = '0' and S_onchip_rd_valid = '1') -- data arrived after being requested
            or (R_onchip_addr(C_slowdown-1) = '1' and R_strobe = '1' and ready = '1') -- have been written
            then
              R_onchip_addr <= R_onchip_addr + 1; -- LSB bit 0 is not part of address
            end if;
          end if;
        end if;
      end if;
    end process;

    -- sample flash data exactly on clock instance when
    -- valid=1 and don't change anything on DMA bus until
    -- DMA transaction is signaled as complete with ready=1    
    process(clk)
    begin
      if rising_edge(clk) then
        if R_strobe = '0' then
          if S_onchip_rd_valid = '1' and S_onchip_done = '0' then
            -- not done, valid data (after reset or next_data)
            R_data <= S_onchip_rd_data;
            R_strobe <= '1'; -- issue DMA request
          end if;
        else -- R_strobe = '1'
          -- todo: if too long waiting for ready, set strobe = 0
          if ready = '1' then
            R_strobe <= '0'; -- release DMA request
          end if;
        end if;
      end if;
    end process;
end Behavioral;
