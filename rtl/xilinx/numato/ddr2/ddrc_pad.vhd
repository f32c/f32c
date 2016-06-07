library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddrc_cnt_pack.all;
library unisim;
use unisim.VCOMPONENTS.all;

entity DDRC_PAD is port (
      ck2    : in std_logic ;
      RST    : in std_logic ;
      dr_i   : in dr_data_o_t ;
      dr_o   : out dr_data_i_t ;
      dr_c   : in sd_ctrl_t   ;

      dq    : inout STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => 'Z');
      dqs   : inout STD_LOGIC_VECTOR (1 DOWNTO 0) := "ZZ";
      addr  : out    STD_LOGIC_VECTOR (14 DOWNTO 0);
      ba    : out    STD_LOGIC_VECTOR (1 DOWNTO 0);
      cke   : out    STD_LOGIC;
      cs    : out    STD_LOGIC;
      ras   : out    STD_LOGIC;
      cas   : out    STD_LOGIC;
      we    : out    STD_LOGIC;
      dm    : out    STD_LOGIC_VECTOR (1 DOWNTO 0)
     );
end entity DDRC_PAD;

architecture rtl of DDRC_PAD is


begin

   DDR2_PD_SQ : for i in 0 to 1  generate
       DDR2_PAD_SQ : IOBUF
         generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_i.dqso(i), T => dr_i.dqs_outen(i), O => dr_o.dqsi(i), IO => dqs(i));
--     port map ( I => dqs(i), O => dr_o.dqsi(i) );
--     port map (OE => dr_i.dqs_outen(i), I => dr_i.dqso(i), O => dqs(i) );
   end generate;

   DDR2_PD_DT : for i in 0 to 15  generate
       DDR2_PAD_DT : IOBUF
          generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_i.dqo(i), T => dr_i.dq_outen(i), O => dr_o.dqi(i), IO => dq(i));
--     port map ( I => dq(i), O => dr_o.dqi(i) );
--     port map (OE => dr_i.dq_outen(i), I => dr_i.dqo(i), O => dq(i) );
   end generate;

   DDR2_PD_DM : for i in 0 to 1  generate
       DDR2_PAD_DM : OBUFT
          generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_i.dmo(i), T => dr_i.dq_outen(i+16), O => dm(i));
--         port map (OE => dr_i.dq_outen(i+15), I => dr_i.dmo(i), O => dm(i) );
   end generate;

  --   after this, only driver   --   
   DR_PD_AD : for i in 0 to 14  generate
       DR_PAD_AD : OBUF
        generic map ( IOSTANDARD => "MOBILE_DDR")
        port map ( I => dr_c.a(i), O => addr(i));
--         port map ( I => dr_c.a(i), O => addr(i) );
   end generate;

   DR_PD_BA : for i in 0 to 1  generate
       DR_PAD_BA : OBUF
        generic map ( IOSTANDARD => "MOBILE_DDR")
        port map ( I => dr_c.ba(i), O => ba(i));
---    port map ( I => dr_c.ba(i), O => ba(i) );
   end generate;

   DR_CKE_CE : OBUF
       generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_c.cke, O => cke);
   DR_CS_CE  : OBUF
       generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_c.cs, O => cs );
   DR_RS_CE  : OBUF
       generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_c.ras, O => ras );
   DR_CAS_CE : OBUF
       generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_c.cas, O => cas );
   DR_WE_CE  : OBUF
       generic map ( IOSTANDARD => "MOBILE_DDR")
       port map ( I => dr_c.we, O => we );

--qd_dt : process(ck2, RST, dq_del )
--   begin
--      if ck2 = '1' and ck2'event then
--         if RST = '1' then
--            dr_o.dqi(15 downto 0)  <= (others => '0' );
--         else
--            dr_o.dqi(15 downto 0)  <= dq_del ;
--         end if;
--      end if;
--end process;


end rtl;

