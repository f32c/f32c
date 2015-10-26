-- ps2.vhd
--
-- Copyright (c) 2015 Ken Jordan
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- PS/2 port controller. Based largely on info from http://www.computer-engineering.org/ps2protocol/

entity ps2 is
	generic (
		C_clk_freq: integer		 -- clock frequency in MHz
	);
	port (
		clk:			in	std_logic;
		reset:			in	std_logic;
		ce:				in	std_logic;
		bus_write:		in	std_logic;
		byte_sel:		in	std_logic_vector(3 downto 0);
		bus_in:			in	std_logic_vector(31 downto 0);
		bus_out:		out	std_logic_vector(31 downto 0);
		--
		ps2_clk_in:		in	std_logic;
		ps2_dat_in:		in	std_logic;
		ps2_clk_out:	out	std_logic;
		ps2_dat_out:	out	std_logic
	);
end ps2;

architecture rtl of ps2 is

	-- two registers each one byte wide
	constant C_data:			integer	:= 0;	-- read is last byte read, write is byte to send
	constant C_status:			integer	:= 1;	-- read (7)=read_byte_ready (6)=ready_to_send (5)=send_error, read or write access clears read_byte_ready and send_error

	type ps2_state_t is (idle, rx_byte, rx_parity, rx_stop, tx_start, tx_waitstart, tx_byte, tx_parity, tx_stop, tx_waitack, tx_error);
	signal	ps2_state:			ps2_state_t := idle;
	
	signal	read_data_ready:	std_logic := '0';						-- true if read_data valid
	signal	ready_to_send:		std_logic := '0';						-- true if keyboard in idle state
	signal	send_data_ready:	std_logic := '0';						-- true if write_data has valid data to send
	signal	send_error:			std_logic := '0';						-- true if last read had parity or timeout error
	
	signal	read_data:			std_logic_vector(7 downto 0);			-- last byte read
	signal	write_data:			std_logic_vector(7 downto 0);			-- byte to send

	signal	bitnum:				unsigned(2 downto 0);
	signal	data:				std_logic_vector(7 downto 0);
	signal	parity:				std_logic;
	
	signal	usec5_strobe:		std_logic;
	signal	usec5_counter:		integer range 0 to (C_clk_freq*5)-1;
	signal	timeout_count:		integer range 0 to 4095;

	signal	ps2_clk_ff:			std_logic;								-- synchronization flip-flop for clock
	signal	ps2_clk_last:		std_logic;
	signal	ps2_clk_count:		integer range 0 to 3;
	signal	ps2_dat_ff:			std_logic;								-- synchronization flip-flop for data
	signal	ps2_dat_last:		std_logic;
	signal	ps2_dat_count:		integer range 0 to 3;

	signal	ps2_clk_r:			std_logic;
	signal	ps2_clk_p_r:		std_logic;
	signal	ps2_clk_fallingedge: std_logic;
	signal	ps2_dat_r:			std_logic;

	signal	ps2_clk_out_r:		std_logic;
	signal	ps2_dat_out_r:		std_logic;
begin

	-- 1 usec timer strobe
	process(clk)
	begin
		if reset='1' then
			usec5_strobe <= '0';
			usec5_counter <= 0;
		elsif rising_edge(clk) then
			if usec5_counter = 0 then
				usec5_counter <= (C_clk_freq*5) - 1;
				usec5_strobe <= '1';
			else
				usec5_counter <= usec5_counter - 1;
				usec5_strobe <= '0';
			end if;
		end if;
	end process;

	-- clean input signals
	process(clk)
	begin
		if reset='1' then
			ps2_clk_p_r <= '0';
		elsif rising_edge(clk) then
			ps2_clk_ff <= ps2_clk_in;
			if ps2_clk_ff = ps2_clk_last then
				if ps2_clk_count = 0 then
					ps2_clk_r <= ps2_clk_last;
				else
					ps2_clk_count <= ps2_clk_count - 1;
				end if;
			else
				ps2_clk_last <= ps2_clk_ff;
				ps2_clk_count <= 3;
			end if;

			-- preserve last clock for edge detection
			ps2_clk_p_r <= ps2_clk_r;

			ps2_dat_ff <= ps2_dat_in;
			if ps2_dat_ff = ps2_dat_last then
				if ps2_dat_count = 0 then
					ps2_dat_r <= ps2_dat_last;
				else
					ps2_dat_count <= ps2_dat_count - 1;
				end if;
			else
				ps2_dat_last <= ps2_dat_ff;
				ps2_dat_count <= 3;
			end if;
		end if;
	end process;
	
	process(clk)
	begin
		if reset='1' then
			ps2_clk_out <= '1';
			ps2_clk_out_r <= '1';
			ps2_dat_out <= '1';
			ps2_dat_out_r <= '1';
			ps2_state <= idle;
			read_data_ready <= '0';
			write_data <= (others => '1');
			send_data_ready <= '1';
			send_error <= '0';
		elsif rising_edge(clk) then
			-- register write access
			if ce = '1' then 
				if bus_write = '1' AND byte_sel(C_data) = '1' then
					if ready_to_send = '1' then
						write_data <= bus_in(7 downto 0);
						send_data_ready <= '1';
					end if;
				end if;
				if byte_sel(C_status) = '1' then
					read_data_ready <= '0';
					send_error <= '0';
				end if;
			end if;
			
			-- timeout counter
			if usec5_strobe = '1' AND timeout_count /= 0 then
				timeout_count <= timeout_count - 1;
			end if;

			-- output registered signals
			ps2_clk_out	<=	ps2_clk_out_r;
			ps2_dat_out	<=	ps2_dat_out_r;

			-- state machine
			case ps2_state is
				when idle =>
					ps2_state <= idle;
					bitnum <= "000";
					parity <= '0';
					ps2_clk_out_r <= '1';
					ps2_dat_out_r <= '1';
					timeout_count <= (2005/5);					-- ~2 ms timeout to read byte
					if ps2_clk_fallingedge = '1' AND ps2_dat_r='0' then
						ps2_state <= rx_byte;
					elsif send_data_ready = '1' then
						send_data_ready <= '0';
						ps2_state <= tx_start;
					end if;
				when rx_byte =>
					ps2_state <= rx_byte;
					if ps2_clk_fallingedge = '1' then
						data <= ps2_dat_r & data(7 downto 1);
						parity <= parity XOR ps2_dat_r;
						bitnum <= bitnum + 1;
						if bitnum = 7 then
							ps2_state <= rx_parity;
						else
							ps2_state <= rx_byte;
						end if;
					elsif timeout_count = 0 then
						ps2_state <= idle;
					end if;
				when rx_parity =>
					ps2_state <= rx_parity;
					if ps2_clk_fallingedge = '1' then
						parity <= parity XOR ps2_dat_r;
						ps2_state <= rx_stop;
					elsif timeout_count = 0 then
						ps2_state <= idle;
					end if;
				when rx_stop =>
					ps2_state <= rx_stop;
					if ps2_clk_fallingedge = '1' then
						if parity = '1' AND ps2_dat_r = '1' then -- ignore data if bad parity or low stop bit
							read_data <= data;
							read_data_ready <= '1';
						end if;
						ps2_state <= idle;
					elsif timeout_count = 0 then
						ps2_state <= idle;
					end if;
				when tx_start =>
					ps2_state <= tx_waitstart;
					data <= write_data;
					ps2_clk_out_r <= '0';
					timeout_count <= (105/5);					-- ~110 us time to assert clock low for send
				when tx_waitstart =>
					ps2_state <= tx_waitstart;
					if timeout_count = 0 then
						ps2_clk_out_r <= '1';
						ps2_dat_out_r <= '0';
						timeout_count <= (17005/5);				-- ~17 ms total timeout to wait for character
						ps2_state <= tx_byte;
					end if;
				when tx_byte =>
					ps2_state <= tx_byte;
					if ps2_clk_fallingedge = '1' then
						ps2_dat_out_r <= data(0);
						parity <= parity XOR data(0);
						data <= '-' & data(7 downto 1);
						bitnum <= bitnum + 1;
						if bitnum = 7 then
							ps2_state <= tx_parity;
						end if;
					elsif timeout_count = 0 then
						ps2_state <= tx_error;
					end if;
				when tx_parity =>
					ps2_state <= tx_parity;
					if ps2_clk_fallingedge = '1' then
						ps2_dat_out_r <= NOT parity;
						ps2_state <= tx_stop;
					elsif timeout_count = 0 then
						ps2_state <= tx_error;
					end if;
				when tx_stop =>
					ps2_state <= tx_stop;
					if ps2_clk_fallingedge = '1' then
						ps2_dat_out_r <= '1';
						ps2_state <= tx_waitack;
					elsif timeout_count = 0 then
						ps2_state <= tx_error;
					end if;
				when tx_waitack =>
					ps2_state <= tx_waitack;
					if ps2_clk_fallingedge = '1' then
						send_error <= ps2_dat_r;				-- should be set low by device ACK
						ps2_state <= idle;
					elsif timeout_count = 0 then
						ps2_state <= tx_error;
					end if;
				when tx_error =>
					ps2_state <= idle;
					send_error <= '1';
				when others =>
					ps2_state <= idle;
			end case;
		end if;
	end process;

	ps2_clk_fallingedge <= '1' when ps2_clk_p_r = '1' AND ps2_clk_r = '0' else '0';

	ready_to_send <= '1' when ps2_state=idle AND ps2_clk_r = '1' AND ps2_dat_r = '1' else '0';

	-- register read access
	bus_out <= "----------------" & read_data_ready & ready_to_send & send_error & "00000" & read_data;

end rtl;
