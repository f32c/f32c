-------------------------------------------------------------------------------
-- Maintains a cache table, keeping track of oldest locations, etc.
-- Essentially a Content-Addressable Memory (CAM).
-- Replacement policy is a simple counter.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_table is
  generic (
    TABLE_WIDTH : integer := 3;
    ADDR_WIDTH  : integer := 10);
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    addrToFind   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    cacheHit     : out std_logic;
    foundAddress : out std_logic_vector(TABLE_WIDTH-1 downto 0);
    insertAddr   : in  std_logic;
    addrToInsert : in  std_logic_vector(ADDR_WIDTH-1 downto 0)
    );

end cache_table;

architecture logic of cache_table is

  constant LEN : integer := (2**TABLE_WIDTH);
  type     AddressTable is array (0 to LEN-1) of std_logic_vector(ADDR_WIDTH-1 downto 0);

  signal table      : AddressTable := (others => (others => '1'));
--  signal tableValid : std_logic_vector(LEN-1 downto 0) := (others => '0');
  signal nextLineToReplace : unsigned(TABLE_WIDTH-1 downto 0) := (others => '0');
  
begin  -- logic

  --CAM_READ : process (clk, reset)
  CAM_READ : process (addrToFind, table)
    variable found : std_logic                                := '0';
    variable addr  : std_logic_vector(TABLE_WIDTH-1 downto 0) := (others => '0');
  begin  -- process CAM_READ
    --if reset = '1' then                 -- asynchronous reset (active high)
      foundAddress <= (others => '0');
      cacheHit     <= '0';
    --elsif rising_edge(clk) then         -- rising clock edge
      cacheHit <= '0';
      found    := '0';
      addr     := (others => '0');
      for i in 0 to LEN-1 loop
--        if tableValid(i) = '1' and addrToFind = table(i) then
        if addrToFind = table(i) then
          found := '1';
          -- only one address should be found...
          addr  := std_logic_vector(to_unsigned(i, TABLE_WIDTH));
        end if;
      end loop;  -- i
      cacheHit     <= found;
      foundAddress <= addr;
    --end if;
  end process CAM_READ;

  CAM_WRITE : process (clk)
    variable i : integer := 0;
  begin  -- process CAM_WRITE
    if rising_edge(clk) then
      i := to_integer(nextLineToReplace);
      if reset = '1' then
--         tableValid <= (others => '0');
      nextLineToReplace <= (others => '0');
      elsif insertAddr = '1' then
        table(i)          <= addrToInsert;
--        tableValid(i)     <= '1';
        nextLineToReplace <= nextLineToReplace+"1";
      end if;
    end if;
  end process CAM_WRITE;



end logic;
