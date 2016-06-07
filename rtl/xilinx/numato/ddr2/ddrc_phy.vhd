library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.VCOMPONENTS.all;

use work.ddrc_cnt_pack.all;
use work.attr_pack.all;
use work.util_pack.all;

-- definition of READ_SAMPLE_TM = period from clock output edge
--                                       to   read data sample
--                                        by 1/4 x ddr output clock

-- setting exmple (latency depends on ASIC/FPGA chip and board)
-- +----------------+-------------------------+
-- | READ_SAMPLE_TM | ddr frequency           |
-- |                |      [MHz] (total lat)  |
-- +----------------+-------------------------+
-- |         2      |      50.0 (lat=10.0ns)  | lat[ns] = (250 x TM) / freq
-- |         2      |      62.5 (lat= 8.0ns)  |
-- |         3      |      83.3 (lat= 9.0ns)  |
-- |         4      |     125.0 (lat= 8.0ns)  |
-- |         5      |     167.7 (lat= 7.5ns)  |
-- |         6      |     200.0 (lat= 7.5ns)  |
-- |         7      |     208.0 (lat= 8.41ns) |
-- |         8      |     208.0 (lat= 9.62ns) |
-- |         9      |                         |
-- |        10      |                         |
-- +----------------+-------------------------+
-- default parameter = 2 <-> that is for 50 MHz
-- phy READ_SAMPLE_TM 7-10 is same function READ_SAMPLE_TM 3-6, respectively
-- (7-10) <-> (3-6) control is done by ddrc_fsm.
                  
entity ddr_phy is
  generic ( 
    READ_SAMPLE_TM : integer range 2 to 10 := 2 );
  port (
    RST   : in    std_logic;
    s_o   : out   sd_data_o_t;
    s_i   : in    sd_data_i_t ;
    s_c   : in    sd_ctrl_t;
    --
    ck2x0 : in    std_logic;
    ck2x90: in    std_logic;
    --
    ck_p  : out   std_logic;
    ck_n  : out   std_logic;
    d_di  : in    dr_data_i_t ;
    d_do  : out   dr_data_o_t ;
    d_c   : out   sd_ctrl_t ) ;

  attribute sei_port_global_name of s_o : signal is "ddr_sd_data_o";
  attribute sei_port_global_name of s_i : signal is "ddr_sd_data_i";
  attribute sei_port_global_name of s_c : signal is "ddr_sd_pre_ctrl";
  attribute sei_port_global_name of d_di : signal is "dr_data_i";
  attribute sei_port_global_name of d_do : signal is "dr_data_o";
  attribute sei_port_global_name of d_c : signal is "ddr_sd_ctrl";
end ddr_phy;

architecture beh of ddr_phy is

   signal ck2x0f_p  : std_logic ; -- "f" with pin fix
   signal ck2x0f_n  : std_logic ; -- "f" with pin fix
   signal ck2x90f_p : std_logic ; -- "f" with pin fix
   signal ck2x90f_n : std_logic ; -- "f" with pin fix
   signal sq_en90  : std_logic ;
   signal sq_enmx  : std_logic ;
   signal dqo_l    : std_logic_vector (15 downto 0) ;
   signal dmo_l    : std_logic_vector (1 downto 0) ;
   signal dqn      : std_logic_vector (15 downto 0) ;
   signal dqp      : std_logic_vector (15 downto 0) ;
   signal dqn_1del  : std_logic_vector (15 downto 0) ;
   signal dqn_2del  : std_logic_vector (15 downto 0) ;
   signal dqp_1del  : std_logic_vector (15 downto 0) ;
   signal dqs_lat_en_hdel : std_logic;
   signal dummy_zero_for_xil : std_logic;
        -- to escape fix value drive Xilinx tool limitation

begin

   -- pin fix 
   ck2x0f_p  <= ck2x0  and s_i.cko_enable;
   ck2x0f_n  <= not ck2x0f_p;
   ck2x90f_p <= ck2x90 and s_i.cko_enable;
   ck2x90f_n <= not ck2x90f_p;

   sq_enmx  <=  s_i.dq_lat_en               ; 

   IDDR2_FFS : for i in 0 to 15 generate
     IDDR2_inst : ddr_input
       generic map(DDR_ALIGNMENT => "OPPOSITE_EDGE",
                   INIT_Q1       => '0',  -- Sets initial state of the Q1 output to '0' or '1'
                   INIT_Q2       => '0',  -- Sets initial state of the Q2 output to '0' or '1'
                   SRTYPE        => "ASYNC")  -- Specifies "SYNC" or "ASYNC" set/reset
       port map (Q1  => dqp(i),       -- 1-bit output captured with clock
                 Q2  => dqn(i),       -- 1-bit output captured with not(clock)
                 clk => ck2x0,        --  when critical , ck2x0  need timing check of FPGA
                 d   => d_di.dqi(i),  -- 1-bit data input
                 rst => '0');         -- 1-bit set input
   end generate;

   ODDR2_DQ_OE_FFS : for i in 0 to 15 generate
     ODDR2_DQ_OE_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dq_outen(i),
                 clk => ck2x0,
                 d1  => sq_enmx,
                 d2  => sq_enmx,
                 rst => '0');
   end generate;
   ODDR2_DM_OE_FFS : for i in 16 to 17  generate
     ODDR2_DM_OE_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dq_outen(i),
                 clk => ck2x0,
                 d1  => dummy_zero_for_xil,
                 d2  => dummy_zero_for_xil,
                 rst => '0');
   end generate;
   dummy_zero_for_xil <= RST;

   ODDR2_DQS_OE_FFS : for i in 0 to 1 generate
     ODDR2_DQS_OE_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dqs_outen(i),
                 clk => ck2x90,
                 d1  => dqs_lat_en_hdel,
                 d2  => s_i.dqs_lat_en,
                 rst => '0');
   end generate;

   ODDR2_DQS_FFS : for i in 0 to 1 generate
     ODDR2_DQS_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dqso(i),
                 clk => ck2x90,
                 d1  => '0',
                 d2  => s_i.rd_lat_en,
                 rst => '0');
   end generate;

   ODDR2_DM_FFS : for i in 0 to 1 generate
     ODDR2_DM_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dmo(i),
                 clk => ck2x0,
                 d1  => dmo_l(i),
                 d2  => s_i.dm_latp(i),
                 rst => '0');
   end generate;

   ODDR2_DQ_FFS : for i in 0 to 15 generate
     ODDR2_DQ_inst : ddr_output
       generic map (DDR_ALIGNMENT => "OPPOSITE_EDGE",
                    SRTYPE        => "ASYNC")
       port map (q   => d_do.dqo(i),
                 clk => ck2x0,
                 d1  => dqo_l(i),
                 d2  => s_i.dq_latp(i),
                 rst => '0');
   end generate;

--   clock output (delay (as cycle count) dependent)
   gen_oclock_0deg : 
     if(READ_SAMPLE_TM = 2) or (READ_SAMPLE_TM = 4) or
       (READ_SAMPLE_TM = 6) or (READ_SAMPLE_TM = 8) or
       (READ_SAMPLE_TM = 10) generate
       u_ck_ddrp : clock_output 
         port map (q   => ck_p,
                   clk => ck2x0f_p,
                   rst => '0');
       u_ck_ddrn : clock_output
          port map (Q   => ck_n,
                   clk => ck2x0f_n,
                   rst => '0');
   end generate;

   gen_oclock_90deg : 
     if(READ_SAMPLE_TM = 3) or (READ_SAMPLE_TM = 5) or
       (READ_SAMPLE_TM = 7) or (READ_SAMPLE_TM = 9) generate
       u_ck_ddrp : clock_output 
         port map (q   => ck_p,
                   clk => ck2x90f_p,
                   rst => '0');
       u_ck_ddrn : clock_output
          port map (Q   => ck_n,
                   clk => ck2x90f_n,
                   rst => '0');
    end generate;

--   read data sampling timing (delay (as cycle count) dependent)
    read_data_sample_2 :
      if (READ_SAMPLE_TM = 2) generate
     s_o.dqo_lat <= dqn_2del & dqp_1del;
    end generate;

    read_data_sample_4 :
      if (READ_SAMPLE_TM = 3) or (READ_SAMPLE_TM = 4) or
         (READ_SAMPLE_TM = 7) or (READ_SAMPLE_TM = 8) generate
     s_o.dqo_lat <=            dqp_1del & dqn_1del;
    end generate;

    read_data_sample_6 :
      if (READ_SAMPLE_TM = 5) or (READ_SAMPLE_TM = 6) or
         (READ_SAMPLE_TM = 9) or (READ_SAMPLE_TM = 10) generate
     s_o.dqo_lat <= dqn_1del & dqp;
    end generate;

phy_dsq : process(ck2x90, RST,s_i.dq_lat_en )
   begin
      if ck2x90 = '1' and ck2x90'event then
         if RST = '1' then
            sq_en90  <= '1' ;
         else
            sq_en90 <= s_i.dq_lat_en ;
         end if;
      end if;
end process;
phy_ctrl : process(ck2x0, RST,s_c)
   begin
      if ck2x0 = '0' and ck2x0'event then
         if RST = '1' then
            dqo_l    <= ( others => '0' ); 
            dmo_l    <= ( others => '0' ); 
            d_c  <= PHY_REG_RESET ;
            dqs_lat_en_hdel <= '1';
         else
            dqo_l   <=  s_i.dq_latn ; 
            dmo_l   <=  s_i.dm_latn ;
            d_c <= s_c ;
            dqs_lat_en_hdel <= s_i.dqs_lat_en;
         end if;
      end if;
end process;

rd_del1 : process(ck2x0 , RST)
  begin
      if ck2x0 = '1' and ck2x0'event then
         if RST = '1' then
            dqn_2del <= ( others => '0' );
            dqn_1del <= ( others => '0' );
            dqp_1del <= ( others => '0' );
         else
            dqn_2del <= dqn_1del;
            dqn_1del <= dqn;
            dqp_1del <= dqp;
         end if;
      end if;
end process;

end beh;

configuration ddr_phy_spartan6 of ddr_phy is
  for beh
    for IDDR2_FFS
      for all : ddr_input
        use entity work.ddr_input(spartan6);
      end for;
    end for;
    for ODDR2_DQ_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for ODDR2_DM_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for ODDR2_DQS_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for ODDR2_DQS_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for ODDR2_DM_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for ODDR2_DQ_FFS
      for all : ddr_output
        use entity work.ddr_output(spartan6);
      end for;
    end for;
    for gen_oclock_0deg
      for all : clock_output
        use entity work.clock_output(spartan6);
      end for;
    end for;
    for gen_oclock_90deg
      for all : clock_output
        use entity work.clock_output(spartan6);
      end for;
    end for;
  end for;
end configuration;

configuration ddr_phy_kintex7 of ddr_phy is
  for beh
    for IDDR2_FFS
      for all : ddr_input
        use entity work.ddr_input(kintex7);
      end for;
    end for;
    for ODDR2_DQ_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for ODDR2_DM_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for ODDR2_DQS_OE_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for ODDR2_DQS_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for ODDR2_DM_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for ODDR2_DQ_FFS
      for all : ddr_output
        use entity work.ddr_output(kintex7);
      end for;
    end for;
    for gen_oclock_0deg
      for all : clock_output
        use entity work.clock_output(kintex7);
      end for;
    end for;
    for gen_oclock_90deg
      for all : clock_output
        use entity work.clock_output(kintex7);
      end for;
    end for;
  end for;
end configuration;
