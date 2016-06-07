library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu2j0_pack.all;
use work.config.all;

package ddrc_cnt_pack is

--   for state machine ----
constant DDR_ADDR_WIDTH  : natural := 15;
constant DDR_DATA_WIDTH  : natural := 16;
constant DDR_DATA_BYTES  : natural := 2;
constant DDR_CAS_LATENCY : natural := 3;  -- DDR-I and LPDDR-I at 200MHz

constant DDR_BURST_LENGTH : natural := 16;  -- for cache line zise & DMAC
constant DDR_MAX_WAIT_BIT : natural := 3     ;  -- JustNow 8 cycles is enough
constant DDR_MAX_WAIT     : natural := 2**DDR_MAX_WAIT_BIT - 1     ;  -- JustNow 8 cycles is enough

--   for counter  70usec, ACT-ACT , wait for all  ----
constant DDR_CK_CYCLE    : natural := CFG_DDR_CK_CYCLE;
constant C70_WIDTH_BITS  : natural := 14;    -- 70,000 / 5ns = 14000
constant C14_WIDTH_BITS  : natural := 4;     -- 15cycle counter for COMMAND-COMMAND
constant CMNC_WIDTH_BITS : natural := 4;     -- instead of 16 burst

constant C70_MAX         : natural := (70000/DDR_CK_CYCLE) - 1 ;  -- this is real one
constant C70_MAX2        : natural := 500 - 1 ;  -- CAUTION Please delete !! when real
constant CMNC_MAX        : natural := 2**CMNC_WIDTH_BITS-1;
constant CL_2            : natural := 2 ;
constant CL_3            : natural := 0 ;
constant CL_4            : natural := 1 ;

---   for AC caracteristics   --
constant  tMRD           : natural := 2-1 ;  --  LOAD MODE REGISTER command cycle time ;
constant  tRAS_min       : natural := (40+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ; --  ACTIVE to PRECHARGE
constant  tRAS_max       : natural := (70000+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ; --  ACTIVE to PRECHARGE
constant  tRC            : natural := (55+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- ACT to ACT/ACT to AUTPREFRESH§
constant  tRCD           : natural := (15+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- ACT to READ/WRITE
constant  tREFI          : natural := (7800+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- refresh interval
constant  tRFC           : natural := (72+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- refresh period
constant  tRP            : natural := (15+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- PRECHARGE PERIOD
constant  tRRD           : natural := (10+DDR_CK_CYCLE-1)/DDR_CK_CYCLE ;   -- ACT banka to Actbank b
constant  tWR            : natural := (15+DDR_CK_CYCLE-1)/DDR_CK_CYCLE +1 ;   -- Write recovery time
constant  tWTR           : natural := 2-1 ;    -- cycle : internal WRITE to READ command delay
constant  tDAL           : natural  := ((tWR+DDR_CK_CYCLE-1)/DDR_CK_CYCLE+1) + ((tRP+DDR_CK_CYCLE-1)/DDR_CK_CYCLE+1) ; ---   each round up needed

type v_a_t is array(3 downto 0) of std_logic;
type bnk_a_t   is array(3 downto 0) of std_logic_vector(27 downto 13);

constant	V_BNK_A_INIT : v_a_t   := ('0','0','0','0') ;
constant        BNK_A_INIT   : bnk_a_t := ( "000"& x"000", "000"& x"000", "000"&x"000", "000"& x"000");

type sd_data_i_t is record
         dq_latp    : std_logic_vector(15 downto 0);
         dq_latn    : std_logic_vector(15 downto 0);
         dm_latp    : std_logic_vector(1 downto 0);
         dm_latn    : std_logic_vector(1 downto 0);
         dq_lat_en  : std_logic;
         dqs_lat_en : std_logic;
         rd_lat_en  : std_logic;
         cko_enable : std_logic;
end record;

constant SD_DATA_FIXHI : sd_data_i_t := (
         dq_latp    => (others => '1'), -- (15 downto 0);
         dq_latn    => (others => '1'), -- (15 downto 0);
         dm_latp    => (others => '1'), --  (1 downto 0);
         dm_latn    => (others => '1'), --  (1 downto 0);
         dq_lat_en  =>            '0' , -- 3-state enable (negative) 0<->drive
         dqs_lat_en =>            '0' , -- 3-state enable (negative)
         rd_lat_en  =>            '0' , -- dqs pin data
         cko_enable =>            '0'
         );
constant SD_DATA_FIXLO : sd_data_i_t := (
         dq_latp    => (others => '0'), -- (15 downto 0);
         dq_latn    => (others => '0'), -- (15 downto 0);
         dm_latp    => (others => '0'), --  (1 downto 0);
         dm_latn    => (others => '0'), --  (1 downto 0);
         dq_lat_en  =>            '0' , -- 3-state enable (negative)
         dqs_lat_en =>            '0' , -- 3-state enable (negative)
         rd_lat_en  =>            '0' , -- dqs pin data
         cko_enable =>            '0'
         );

type sd_data_o_t is record
         dqo_lat    : std_logic_vector(31 downto 0);
end record;

type dr_data_i_t is record
         dqi        : std_logic_vector(15 downto 0);
         dqsi       : std_logic_vector(1 downto 0);
end record;

type dr_data_o_t is record
         dqo        : std_logic_vector(15 downto 0);
         dmo        : std_logic_vector(1 downto 0);
         dqso       : std_logic_vector(1 downto 0);
         dq_outen   : std_logic_vector(17 downto 0);
         dqs_outen  : std_logic_vector(1 downto 0);
end record;

type sd_ctrl_t is record
         a          : std_logic_vector(14 downto 0);
         ba         : std_logic_vector(1 downto 0);
         cke        : std_logic;
         cs         : std_logic;
         ras        : std_logic;
         cas        : std_logic;
         we         : std_logic;
end record;

constant SD_CTRL_FIXHI : sd_ctrl_t := (
         a          => (others => '1') , -- (14 downto 0);
         ba         => (others => '1') , --  (1 downto 0);
         cke => '1' , cs  => '1' , ras => '1' , cas => '1' , we  => '1' );
constant SD_CTRL_FIXLO : sd_ctrl_t := (
         a          => (others => '0') , -- (14 downto 0);
         ba         => (others => '0') , --  (1 downto 0);
         cke => '0' , cs  => '0' , ras => '0' , cas => '0' , we  => '0' );

type ddr_smcmd_t is record
         act       : std_logic;
         read      : std_logic;
         write     : std_logic;
         idle      : std_logic;
end record;

  type ddrc_fsm is (
     st_power_on, 
     st_wait, 
     st_PREA, 
     st_PREA2, 
     st_LMR,   
     st_LMR2,   
     st_idle, 
     st_ACT,
     st_RCD_wait,
     st_READB, 
     st_READB2, 
     st_rdn, 
     st_READS, 
     st_READS2, 
     st_WRITES, 
     st_WRITEW, 
     st_WRITEE, 
     st_WRITEEE, 
     st_PRECHG, 
     st_REFRESH , 
     st_wr_wait);

--   ck event --
type fsm_reg_t is record
    state   : ddrc_fsm;
    CL_No   : integer range 0 to 2 ;
    c70c    : integer range 0 to 2**C70_WIDTH_BITS-1;
    c70c_zero : std_logic ;
    c14c    : integer range 0 to 2**C14_WIDTH_BITS-1;
    cmnc    : integer range 0 to 2**CMNC_WIDTH_BITS-1;
    cadr    : integer range 0 to 7 ;
    ctwr    : integer range 0 to 4 ;
    we      : std_logic_vector( 3 downto 0) ;
    we_d    : std_logic_vector( 3 downto 0) ;
    do      : std_logic_vector( 31 downto 0) ;
    do_d    : std_logic_vector( 31 downto 0) ;
    row_a   : std_logic_vector( 14 downto 0) ;
    clm_a   : std_logic_vector( 14 downto 0) ;
    b_id    : integer range 0 to 3 ;
    rack    : std_logic ;
    rack_d  : std_logic ;
    rack_dd : std_logic ;
    rack_ddd: std_logic ;  -- final read ack for READ_SAMPLE_TM = 2 - 6
    rack_dddd: std_logic ; -- final read ack for READ_SAMPLE_TM = 7 - 10
    eack    : std_logic;
    eack_d  : std_logic;
    v       : v_a_t ;
    b_a     : bnk_a_t;
end record;

--   ck_  event  for addess & write operation---

constant FSM_REG_RESET : fsm_reg_t := (
    			state   => st_power_on, 
                        CL_No   =>  0   ,
                        c70c    =>  0   ,
                        c70c_zero    =>  '0'   ,
                        c14c    =>  0   ,
                        cmnc    =>  0   , 
                        cadr    =>  0   ,
                        ctwr    =>  0   ,
                        we      =>  (others => '0'),
                        we_d    =>  (others => '0'),
                        do      =>  (others => '0'),
                        do_d    =>  (others => '0'),
                        row_a   =>  (others => '0'),
                        clm_a   =>  (others => '0'),
                        b_id    =>  0   ,
			rack    => '0'  ,
			rack_d  => '0'  ,
			rack_dd => '0'  ,
			rack_ddd => '0'  ,
			rack_dddd => '0'  ,       --debug only
    			eack    => '0'  ,
    			eack_d  => '0'  ,
			v       => V_BNK_A_INIT    ,
                        b_a     => BNK_A_INIT     
                        ) ;
constant PHY_REG_RESET : sd_ctrl_t := (
                        a     => (others => '0') ,
                        ba    => (others => '0') ,
                        cke   => '0' ,
                        cs    => '1' ,
                        ras   => '1' ,
                        cas   => '1' ,
                        we    => '1' 
                        ) ;


subtype support_cmd is std_logic_vector(2 downto 0); 
     constant cmd_IDLE      : support_cmd := "111";
     constant cmd_SR        : support_cmd := "001";
     constant cmd_LMR       : support_cmd := "000";
     constant cmd_PREA      : support_cmd := "010";
     constant cmd_ACT       : support_cmd := "011";
     constant cmd_AUTORF    : support_cmd := "001";
     constant cmd_READ      : support_cmd := "101";
     constant cmd_WRITE     : support_cmd := "100";
     constant cmd_AR        : support_cmd := "001";
     constant cmd_PREBNK    : support_cmd := "010";

component N_BUF is port (
      I  : in std_logic;
      O  : out std_logic);
end component ;

component  N_TBUF is port (
      OE  : in std_logic;
      I   : in std_logic;
      O  : out std_logic
      );
end component ;

component MT46V16M16
    GENERIC (                                   -- Timing for -75Z CL2
        tCK       : TIME    ;
        tCH       : TIME    ;
        tCL       : TIME    ;
        tDH       : TIME    ;
        tDS       : TIME    ;
        tIH       : TIME    ;
        tIS       : TIME    ;
        tMRD      : TIME    ;
        tRAS      : TIME    ;
        tRAP      : TIME    ;
        tRC       : TIME    ;
        tRFC      : TIME    ;
        tRCD      : TIME    ;
        tRP       : TIME    ;
        tRRD      : TIME    ;
        tWR       : TIME    ;
        addr_bits : INTEGER ;
        data_bits : INTEGER ;
        cols_bits : INTEGER
    );
    PORT (
        Dq    : INOUT STD_LOGIC_VECTOR (data_bits - 1 DOWNTO 0) := (OTHERS => 'Z');
        Dqs   : INOUT STD_LOGIC_VECTOR (1 DOWNTO 0) := "ZZ";
        Addr  : IN    STD_LOGIC_VECTOR (addr_bits - 1 DOWNTO 0);
        Ba    : IN    STD_LOGIC_VECTOR (1 DOWNTO 0);
        Clk   : IN    STD_LOGIC;
        Clk_n : IN    STD_LOGIC;
        Cke   : IN    STD_LOGIC;
        Cs_n  : IN    STD_LOGIC;
        Ras_n : IN    STD_LOGIC;
        Cas_n : IN    STD_LOGIC;
        We_n  : IN    STD_LOGIC;
        Dm    : IN    STD_LOGIC_VECTOR (1 DOWNTO 0)
    );
end component ;

component ddr_fsm
   generic ( READ_SAMPLE_TM : integer range 2 to 10 := 2 );
    port(
         clk_2x        : in std_logic ;
         clk           : in  std_logic;
         clk_90        : in  std_logic;
         reset_in      : in  std_logic;
--         Xreset_in      : in  std_logic;   debug for MANY PRECHARGE
         i             : in  cpu_data_o_t;
         bst           : in  std_logic ;
         o_d           : out cpu_data_i_t ;
         fix_pinhi     : in  std_logic;
         fix_pinlo     : in  std_logic;
         s_i           : in  sd_data_o_t;
         s_o           : out sd_data_i_t ;
         s_c           : out sd_ctrl_t;
         eack          : out std_logic
     );

end component;

component ddr_phy
   generic ( READ_SAMPLE_TM : integer range 2 to 10 := 2 );
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


end component;

-- ddr_phy_expboost existed in targets/boads/soc_2v0_evb_2v1_expboost.
-- Temporarily component is defined.
component ddr_phy_expboost
   generic ( READ_SAMPLE_TM : integer range 2 to 10 := 2 );
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


end component;

component  DDRC_PAD port (
      ck2    : in std_logic  ;
      rst    : in std_logic  ;
      dr_i   : in dr_data_o_t ;
      dr_o   : out dr_data_i_t ;
      dr_c   : in sd_ctrl_t   ;

      dq    : inout  std_logic_vector (15 downto 0) := (others => 'Z');
      dqs   : inout  std_logic_vector (1 downto 0) := "ZZ";
      addr  : out    std_logic_vector (14 downto 0);
      ba    : out    std_logic_vector (1 downto 0);
      cke   : out    std_logic ;
      cs    : out    std_logic ;
      ras   : out    std_logic ;
      cas   : out    std_logic ;
      we    : out    std_logic ;
      dm    : out    std_logic_vector (1 downto 0) ) ;

end component ;


end package;


package body ddrc_cnt_pack is


end ddrc_cnt_pack;
