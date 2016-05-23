library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package DMACache_pkg is
	constant DMACache_MaxChannel : integer :=2;
	constant DMACache_MaxCacheBit : integer := 5;

	type DMAChannel_FromHost is record
		addr : std_logic_vector(31 downto 0);
		setaddr : std_logic;
		reqlen : unsigned(15 downto 0);
		setreqlen : std_logic;
		req : std_logic;
	end record;

	type DMAChannel_ToHost is record
		valid : std_logic;
	end record;

	type DMAChannels_FromHost is array(0 to DMACache_MaxChannel-1) of DMAChannel_FromHost;
	type DMAChannels_ToHost is array (0 to DMACache_MaxChannel-1) of DMAChannel_ToHost;

   constant DMAChannels_FromHost_INIT : DMAChannels_FromHost := (others =>
            (
               addr => (others =>'X'),
               setaddr => '0',
               reqlen => (others =>'X'),
               setreqlen => '0',
               req => '0'
            ));
    
end package;
