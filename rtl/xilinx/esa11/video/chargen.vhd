library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity charactergenerator is
	generic (
		xstart : in integer := 0;
		ystart : in integer := 0;
		xstop : in integer := 640;
		ystop : in integer := 480;
		border : in integer := 4
	);
	port (
		clk : in std_logic;
		reset : in std_logic;
		xpos : in unsigned(9 downto 0);
		ypos : in unsigned(9 downto 0);
		pixel_clock : in std_logic;
		pixel : out std_logic;
		window : out std_logic;
		-- Character RAM interface
		addrin : in std_logic_vector(10 downto 0);
		datain : in std_logic_vector(7 downto 0);
		dataout : out std_logic_vector(7 downto 0);
		rw : in std_logic
	);
end entity;

architecture rtl of charactergenerator is
--signal charaddr : unsigned(9 downto 0);
signal romaddr : std_logic_vector(9 downto 0);
signal messageaddr : unsigned(10 downto 0);
signal rowaddr : unsigned(10 downto 0);
signal messagechar : std_logic_vector(7 downto 0);
signal chardata : std_logic_vector(7 downto 0);
signal chardatashift : std_logic_vector(7 downto 0);
signal ycounter : unsigned(2 downto 0);
signal upd : std_logic;
signal rw_n : std_logic;

begin

	mycharrom : entity work.CharROM_ROM
		generic map (
			addrbits => 10
		)
		port map (
			clock => clk,
			address => std_logic_vector(romaddr),
			q => chardata
	  );

    rw_n <= not rw;
    
--  	mymessagerom : entity work.CharRAM
  	mymessagerom : entity work.DualPortRAM
	generic map (
		addrbits => 11,
		databits => 8
	)
	port map (
		clock => clk,
		address_a => std_logic_vector(rowaddr),
		address_b => addrin,	-- Port b is used to write new data to the char ram.
		data_a => X"00",
		data_b => datain,
		q_a => messagechar,
		q_b => dataout,
		wren_b => rw_n
  );

	process(clk, reset)
	begin
	
		if reset = '1' then
			window<='0';
			pixel<='0';
--			charaddr<=X"00" & "00";
			messageaddr<=X"00" & "111" ;
			romaddr<=X"00" & "00";
			chardatashift<=X"00";
			upd<='0';
			ycounter <="000";
		elsif rising_edge(clk) then
			romaddr<=messagechar(6 downto 0) & std_logic_vector(ycounter);

			if pixel_clock='1' then
				-- Create a window $border pixels beyond the text, which the design
				-- can use to shade out if it wishes.

				window<='0';
				if xpos>=(xstart-border-1) and xpos<(xstop+border-2)
					and ypos>=(ystart-border) and ypos<(ystop+border) then
					window<='1';
				end if;
			
--				if upd='1' then	-- Draw new pixel
--					pixel<=chardata(7);
--					chardatashift<=chardata(6 downto 0) & "0";
--					upd<='0';
--				else
--					pixel<=chardatashift(7);
--				end if;

				if xpos=0 and ypos=ystop then -- new frame
					messageaddr<=X"00" & "000";
					rowaddr<=X"00" & "000";
--					upd<='1';
					ycounter<="000";
				elsif ypos>ystart and ypos<ystop then
					if xpos=xstop then -- new line
						ycounter<=ycounter+1;
						if ycounter="111" then
							messageaddr<=rowaddr;
						else
							rowaddr<=messageaddr;
						end if;
						upd<='1';
					elsif xpos>=xstart and xpos<xstop then -- new pixel
						pixel<=chardatashift(7);
						chardatashift<=chardatashift(6 downto 0) & '0';
						if xpos(2 downto 0)="000" then
							rowaddr<=rowaddr+1;
							pixel<=chardata(7);
							chardatashift<=chardata(6 downto 0) & "0";
						end if;
					else
						pixel<='0';
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture;
