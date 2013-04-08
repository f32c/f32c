library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;

entity spi is
    generic (
	C_fixed_speed: boolean := true;
	C_turbo_mode: boolean := true
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	spi_sck, spi_si, spi_cen: out std_logic;
	spi_so: in std_logic
    );
end spi;

--
-- SPI -> CPU data word:
--  31..9  unused & undefined
--      8  set if rx_byte is available, cleared on writing tx_byte
--   7..0  rx_byte
--
-- CPU -> SPI data word:
-- 31..16  unused
--  15..8  clock divisor (writing deactivates ce and generates one clock pulse)
--   7..0  tx_byte (writing activates ce)
--
architecture Behavioral of spi is
    signal R_bit_cnt: std_logic_vector(3 downto 0);
    signal R_spi_byte: std_logic_vector(7 downto 0);
    signal R_clk_div, R_clk_acc: std_logic_vector(7 downto 0);
    signal R_cen: std_logic;

begin
    bus_out(31 downto 9) <= (others => '-');
    bus_out(8) <= R_bit_cnt(3);
    bus_out(7 downto 0) <= R_spi_byte;

    spi_cen <= R_cen;
    spi_sck <= not clk and not R_bit_cnt(3) when C_turbo_mode else R_clk_acc(7);
    spi_si <= R_spi_byte(7);

    process(clk)
	variable clk_acc_next: std_logic_vector(7 downto 0);
    begin
	if not C_turbo_mode then
	    if C_fixed_speed then
		clk_acc_next := R_clk_acc xor x"80";
	    else
		clk_acc_next := R_clk_acc + R_clk_div;
	    end if;
	end if;

	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' and bus_write = '1' then
		if byte_sel(1) = '1' then
		    if not C_fixed_speed then
			R_clk_div <= bus_in(15 downto 8);
		    end if;
		    R_clk_acc <= (others => '0');
		    R_cen <= '1';
		    R_bit_cnt <= x"7";
		elsif byte_sel(0) = '1' then
		    R_spi_byte <= bus_in(7 downto 0);
		    R_bit_cnt <= x"0";
		    R_cen <= '0';
		end if;
	    end if;

	    -- tx / rx logic
	    if R_bit_cnt(3) = '0' then
		if C_turbo_mode then
		    R_spi_byte <= R_spi_byte(6 downto 0) & spi_so;
		    R_bit_cnt <= R_bit_cnt + 1;
		else
		    -- sample input on falling clock edge
		    if clk_acc_next(7) = '0' and R_clk_acc(7) = '1' then
			R_spi_byte <= R_spi_byte(6 downto 0) & spi_so;
			R_bit_cnt <= R_bit_cnt + 1;
		    end if;
		end if;
		R_clk_acc <= clk_acc_next;
	    end if;
	end if;
    end process;
end Behavioral;

