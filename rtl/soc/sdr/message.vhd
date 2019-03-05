-- automatically generated with rds_msg
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
package message is
type rds_msg_type is array(0 to 259) of std_logic_vector(7 downto 0);
-- PI=0xCAFE
-- STEREO=No
-- TA=No
-- AF=107.9 MHz
-- PS="TEST1234"
-- RT="ABCDEFGHIJKLMNOPQRSTUVWXYZ    ABCDEFGHIJKLMNOPQRSTUVWXYZ    1234"
constant rds_msg_map: rds_msg_type := (
x"ca",x"fe",x"a0",x"01",x"00",x"2e",x"8e",x"1c",x"c2",x"31",x"51",x"15",x"fb",
x"ca",x"fe",x"a0",x"01",x"00",x"75",x"1c",x"dc",x"da",x"cd",x"4d",x"51",x"e9",
x"ca",x"fe",x"a0",x"01",x"00",x"99",x"ac",x"dc",x"da",x"cc",x"c4",x"cb",x"c6",
x"ca",x"fe",x"a0",x"01",x"00",x"c2",x"3c",x"dc",x"da",x"cc",x"cc",x"d2",x"51",
x"ca",x"fe",x"a0",x"09",x"00",x"14",x"74",x"14",x"20",x"59",x"0d",x"11",x"5d",
x"ca",x"fe",x"a0",x"09",x"00",x"4f",x"e4",x"54",x"60",x"ed",x"1d",x"22",x"73",
x"ca",x"fe",x"a0",x"09",x"00",x"a3",x"54",x"94",x"a1",x"31",x"2d",x"31",x"07",
x"ca",x"fe",x"a0",x"09",x"00",x"f8",x"c4",x"d4",x"e1",x"85",x"3d",x"41",x"96",
x"ca",x"fe",x"a0",x"09",x"01",x"21",x"a5",x"15",x"22",x"89",x"4d",x"51",x"e9",
x"ca",x"fe",x"a0",x"09",x"01",x"7a",x"35",x"55",x"62",x"3d",x"5d",x"62",x"c7",
x"ca",x"fe",x"a0",x"09",x"01",x"96",x"85",x"95",x"a3",x"e0",x"80",x"80",x"dc",
x"ca",x"fe",x"a0",x"09",x"01",x"cd",x"12",x"02",x"00",x"01",x"05",x"08",x"ca",
x"ca",x"fe",x"a0",x"09",x"02",x"24",x"44",x"34",x"46",x"05",x"15",x"18",x"e7",
x"ca",x"fe",x"a0",x"09",x"02",x"7f",x"d4",x"74",x"8a",x"bd",x"25",x"28",x"90",
x"ca",x"fe",x"a0",x"09",x"02",x"93",x"64",x"b4",x"c7",x"6d",x"35",x"38",x"bd",
x"ca",x"fe",x"a0",x"09",x"02",x"c8",x"f4",x"f5",x"05",x"29",x"45",x"48",x"7e",
x"ca",x"fe",x"a0",x"09",x"03",x"11",x"95",x"35",x"44",x"d5",x"55",x"58",x"53",
x"ca",x"fe",x"a0",x"09",x"03",x"4a",x"05",x"75",x"88",x"6d",x"65",x"68",x"24",
x"ca",x"fe",x"a0",x"09",x"03",x"a6",x"b2",x"02",x"00",x"00",x"80",x"80",x"dc",
x"ca",x"fe",x"a0",x"09",x"03",x"fd",x"23",x"13",x"2c",x"68",x"cc",x"d2",x"51",
others => (others => '0')
);
end message;
