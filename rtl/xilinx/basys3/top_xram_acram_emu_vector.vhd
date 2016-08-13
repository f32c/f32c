-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity basys3 is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;

	-- Main clock:
	C_clk_freq: integer := 100; -- MHz

        -- axi cache ram
	C_acram: boolean := true;

        -- warning: 2K, 16K, 32K cache produces timing critical warnings at 100MHz cpu clock
        -- no errors for 4K or 8K
        C_icache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

	-- SoC configuration options
	C_bram_size: integer := 16;

        C_vector: boolean := true; -- vector processor unit
        C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_vaddr_bits: integer := 11;
        C_vector_vdata_bits: integer := 32;
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

        C_sio: integer := 1;   -- 1 UART channel
        C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
        C_timer: boolean := true; -- false: no timer
        C_gpio: integer := 32; -- 0: disabled, 32:32 GPIO bits
        C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
    );
    port (
	clk: in std_logic; -- 100 MHz
	RsTx: out std_logic; -- FTDI UART
	RsRx: in std_logic; -- FTDI UART
	JA, JB, JC: inout std_logic_vector(7 downto 0); -- PMODs
	seg: out std_logic_vector(6 downto 0); -- 7-segment display
	dp: out std_logic; -- 7-segment display
	an: out std_logic_vector(3 downto 0); -- 7-segment display
	led: out std_logic_vector(15 downto 0);
	sw: in std_logic_vector(15 downto 0);
	btnC, btnU, btnD, btnL, btnR: in std_logic
    );
end basys3;

architecture Behavioral of basys3 is
    signal rs232_break: std_logic;
    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0);
    signal ram_address        : std_logic_vector(29 downto 2);
    signal ram_data_write     : std_logic_vector(31 downto 0);
    signal ram_data_read      : std_logic_vector(31 downto 0);
    signal ram_ready          : std_logic := '0';
    signal btns: std_logic_vector(15 downto 0);
    signal lcd_7seg: std_logic_vector(15 downto 0);
    signal clk_25MHz, clk_30MHz, clk_40MHz, clk_45MHz, clk_50MHz, clk_65MHz,
           clk_100MHz, clk_108MHz, clk_112M5Hz, clk_125MHz, clk_150MHz,
           clk_200MHz, clk_216MHz, clk_225MHz, clk_250MHz,
           clk_325MHz, clk_541MHz: std_logic := '0';

    component clk_d100_100_200_125_25MHz is
    Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_125mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_125_25MHz;

begin
    -- generic BRAM glue[C
    glue_xram_vector: entity work.glue_xram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
        C_acram => C_acram,
        C_icache_size => C_icache_size,
        C_dcache_size => C_dcache_size,
        C_cached_addr_bits => C_cached_addr_bits,
	C_bram_size => C_bram_size,
        C_vector => C_vector,
        C_vector_axi => C_vector_axi,
        C_vector_registers => C_vector_registers,
        C_vector_vaddr_bits => C_vector_vaddr_bits,
        C_vector_vdata_bits => C_vector_vdata_bits,
        C_vector_float_addsub => C_vector_float_addsub,
        C_vector_float_multiply => C_vector_float_multiply,
        C_vector_float_divide => C_vector_float_divide,
        C_gpio => C_gpio,
        C_timer => C_timer,
        C_sio => C_sio,
        C_spi => C_spi
    )
    port map (
	clk => clk,
	acram_en => ram_en,
	acram_addr => ram_address,
	acram_byte_we => ram_byte_we,
	acram_data_rd => ram_data_read,
	acram_data_wr => ram_data_write,
	acram_ready => ram_ready,
	sio_txd(0) => rstx, sio_rxd(0) => rsrx, sio_break(0) => rs232_break,
	gpio(7 downto 0) => ja, gpio(15 downto 8) => jb,
	gpio(23 downto 16) => jc, gpio(127 downto 24) => open,
	simple_out(15 downto 0) => led, simple_out(22 downto 16) => seg,
	simple_out(23) => dp, simple_out(27 downto 24) => an,
	simple_out(31 downto 28) => open,
	simple_in(15 downto 0) => btns, simple_in(31 downto 16) => sw,
	spi_miso => (others => '0')
    );
    btns <= x"00" & "000" & btnc & btnu & btnd & btnl & btnr;

    res: startupe2
    generic map (
	prog_usr => "FALSE"
    )
    port map (
	clk => clk,
	gsr => rs232_break,
	gts => '0',
	keyclearb => '0',
	pack => '1',
	usrcclko => clk,
	usrcclkts => '0',
	usrdoneo => '1',
	usrdonets => '0'
    );

    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 15
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(16 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
    );

    -- If ram_data_read is tied to a constant, any
    -- read from ACRAM locations from 0x80000000 must
    -- show this constant. axi_cache is bypassed
    -- and the constant is just placed on multiport bus.

    -- check it:
    -- Serial.println(*((uint32_t *) 0x80000000), HEX);
    -- must print
    -- 01234567

    --ram_data_read <= x"01234567"; -- debug purpose

end Behavioral;
