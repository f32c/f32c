library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddrc_cnt_pack.all;
use work.cache_pack.all;
use work.cpu2j0_pack.all;
use work.attr_pack.all;

entity ddr_fsm is
    generic ( READ_SAMPLE_TM : integer range 2 to 10 := 2 );
    port(

         clk_2x    : in  std_logic;
         clk       : in  std_logic;
         clk_90    : in  std_logic;
         reset_in  : in  std_logic;
         i         : in  cpu_data_o_t;
         bst       : in  std_logic;
         o_d       : out cpu_data_i_t;
         fix_pinhi : in  std_logic;
         fix_pinlo : in  std_logic;
         s_i       : in  sd_data_o_t;
         s_o       : out sd_data_i_t;
         s_c       : out sd_ctrl_t;
         eack      : out std_logic
    );

  attribute sei_port_global_name of reset_in : signal is "reset";
  attribute sei_port_global_name of s_o : signal is "ddr_sd_data_i";
  attribute sei_port_global_name of s_i : signal is "ddr_sd_data_o";
  attribute sei_port_global_name of s_c : signal is "ddr_sd_pre_ctrl";
  attribute sei_port_global_name of i : signal is "ddr_bus_o";
  attribute sei_port_global_name of o_d : signal is "ddr_bus_i";
  attribute sei_port_global_name of bst : signal is "ddr_burst";
end;

architecture logic of ddr_fsm is
   signal this_c : fsm_reg_t ;
   signal this_r : fsm_reg_t ;

-- signals to observer wave viewer (gtk) ---
   signal cycle_count  : integer range 0 to 100000 ; 
   signal Xnxt : fsm_reg_t;
   signal Xc_io : support_cmd;
   signal Xrd_en : std_logic;
   signal Xwait_cnt : integer range 0 to 15 ;
   signal Xcnt_set : std_logic ;
   signal Xburst : std_logic ;
   signal Xc70 : std_logic;
   signal Xc70s : std_logic;
   signal Xc14 : std_logic;
   signal Xc14s : std_logic;
   signal Xctwrz : std_logic  ;
   signal Xncnt : std_logic;
   signal Xcmncs : std_logic;
   signal Xcaset : std_logic;
   signal Xcaen : std_logic;
   signal Xbaen : std_logic;
   signal Xtadr : std_logic_vector(2 downto 0);
   signal Xwack : std_logic;
   signal Xbnkmis : std_logic;
   signal Xin_en : std_logic;
   signal Xpadr  : std_logic_vector(14 downto 0);
   signal Xwr_oe : std_logic;
   signal Xwr_en : std_logic;
   signal Xpre_all : std_logic;
-- end for debug ---

   -- future input signal
   signal md2kc_opt     : std_logic := '0';
                   -- mode to optimize performance for 2k column (2Gb mem chip)

begin
  ddr_trans: process (this_r, reset_in, i, s_i, clk, bst, clk_90, cycle_count, clk_2x, fix_pinhi, fix_pinlo, md2kc_opt )

   variable nxt : fsm_reg_t ;

   variable padr : std_logic_vector(14 downto 0);
   variable c_io : support_cmd;
   variable rd_en : std_logic;
   variable wait_cnt : integer range 0 to 15 ;
   variable cnt_set : std_logic ;
   variable burst : std_logic ;
   variable c70 : std_logic;
   variable c70s : std_logic;
   variable c14 : std_logic;
   variable c14s : std_logic;
   variable ctwrz : std_logic;
   variable ncnt : std_logic;
   variable cmncs : std_logic;
   variable caset : std_logic;
   variable caen : std_logic;
   variable baen : std_logic;
   variable tadr : std_logic_vector(2 downto 0);
   variable wack : std_logic;
   variable bnkmis : std_logic;
   variable in_en : std_logic;
   variable sq_en : std_logic;
   variable sq_vld : std_logic;
   variable wr_oe : std_logic;
   variable wr_en : std_logic;
   variable pre_all : std_logic;
   variable dmy_cke : std_logic;
   variable s_o_pre : sd_data_i_t ; -- data ready for s_o, but some members


   begin

        nxt := this_r;
---- initial condition for variable ----
   c_io := cmd_IDLE ;
   burst := bst ;
   c70s := '0' ;
   c14s := '0' ;
   ctwrz := '0' ;
   cmncs := '0' ;
   caset := '0' ;
   caen := '0' ;
   baen := '0' ;
   burst := bst ;
   wack := '0' ;
   in_en := '0' ;
   sq_en := '0' ;
   sq_vld := '0' ;
   wr_oe := '0' ;
   pre_all := '0' ;
   wait_cnt := 0 ;
   wr_en   := '0' ;

   nxt.rack_dddd := this_r.rack_ddd;
   nxt.rack_ddd  := this_r.rack_dd;
   nxt.rack_dd   := this_r.rack_d ;
   nxt.rack_d    := this_r.rack ;
   nxt.rack      := '0' ;
   nxt.eack_d    := this_r.eack ;
   nxt.eack      := '0' ;

   -- ---------------------------------------------------------------
   -- Addres multiplex for LPDDR for 2Gb, 1Gb, and 512Mb (x16) ---
   -- ---------------------------------------------------------------
   -- 2Gb      14 13 12 11 10 .9 .8 .7 .6 .5 .4 .3 .2 .1 .0 = pin_name
   --   column -- -- --  C --  C  C  C  C  C  C  C  C  C  C  = 11
   --   row    --  R  R  R  R  R  R  R  R  R  R  R  R  R  R  = 14
   -- ---------------------------------------------------------------
   -- 1Gb      14 13 12 11 10 .9 .8 .7 .6 .5 .4 .3 .2 .1 .0
   --   column -- -- -- *- --  C  C  C  C  C  C  C  C  C  C  = 10
   --   row    --  R  R  R  R  R  R  R  R  R  R  R  R  R  R  = 14
   -- ---------------------------------------------------------------
   -- 512Mb    14 13 12 11 10 .9 .8 .7 .6 .5 .4 .3 .2 .1 .0
   --   column -- -- -- -- --  C  C  C  C  C  C  C  C  C  C  = 10
   --   row    -- *-  R  R  R  R  R  R  R  R  R  R  R  R  R  = 13
   -- ---------------------------------------------------------------
   --          |  |  |  |  |   |                         |
   nxt.clm_a :=      -- |  |   |                         | 
               "000" &  '0' &    --  <--  this '0' is overwrriten, see 4L below
                           '0' &                     --  |
                               i.a(10 downto 2) &        '0' ;
   if(md2kc_opt = '0') then
     nxt.clm_a(11) := i.a(27);
     nxt.row_a     :=       i.a(27 downto 13);
   else
     nxt.clm_a(11) := i.a(13);
     nxt.row_a     := '0' & i.a(27 downto 14);
   end if;

   -- bank check ----
   nxt.b_id := to_integer(unsigned(i.a(12 downto 11)));
   if ((this_r.v(nxt.b_id) = '1') and nxt.row_a = this_r.b_a(nxt.b_id)) then
        bnkmis := '0';
   else bnkmis := '1';
   end if;

   -- enable mask ---
   in_en := i.en ;
   rd_en := in_en and i.rd and not this_r.rack_dd and not this_r.rack_ddd ;
   if( READ_SAMPLE_TM > 6 ) then
     rd_en := rd_en and not this_r.rack_dddd; end if; -- one more and
   wr_en := in_en and i.wr ;

   -- make qs & qm and dataout enable ---
      if (this_r.state = st_WRITES ) then 
          sq_en := '1' ;
      end if;
      if (this_r.state = st_WRITEW or this_r.state = st_WRITEE) then 
          sq_vld := '1' ;
          sq_en := '1' ;
      end if;

---- counter for 70usec, ACT-ACT , general wait time, and addres counter for read burst ----

      if this_r.c70c_zero = '1' then c70 := '1' ;
      else c70 := '0' ;
      end if;
      if this_r.c70c = 0 then -- none
      else nxt.c70c := this_r.c70c -1 ;
      end if;

      if this_r.c14c = 0 then c14 := '1' ;
      else c14 := '0' ; nxt.c14c := this_r.c14c -1 ;
      end if;

      if this_r.cmnc = 0 then ncnt := '1' ;
      else ncnt := '0' ; nxt.cmnc := this_r.cmnc -1 ;
      end if;
      if this_r.ctwr = 0 then ctwrz := '1' ;
      else ctwrz := '0' ; nxt.ctwr := this_r.ctwr -1 ;
      end if;


--- make IO data using the state machine -----
   -- DDR state machine to determine this_r.state and command

      case this_r.state is

         when st_power_on =>
            nxt.state := st_wait;
            cmncs := '1' ;
            wait_cnt := tMRD ;

         when st_wait =>
            if ncnt='1' and c70='1' then
               nxt.state := st_PREA ;
            elsif ncnt = '1' and wr_en = '1' and c70='0' then
               nxt.state := st_LMR ;
               wack := '1';
            elsif ncnt = '1' and rd_en = '1' and c70='0' then
               nxt.state := st_ACT ;
            else
               nxt.state := st_wait ;
            end if;

         when st_PREA =>
            pre_all := '1' ;
            c_io := cmd_PREA ;
            nxt.state := st_PREA2;

         when st_PREA2 =>
            nxt.state := st_wait;
            c70s := '1' ;
            cmncs := '1' ;
            wait_cnt := tMRD ;

         when st_LMR =>
            c_io := i.a(6 downto 4) ;
            nxt.state := st_LMR2;

         when st_LMR2 =>
            nxt.state := st_wait;
            cmncs := '1' ;
            wait_cnt := tMRD ;

         when st_idle =>
            if c70='1' and c14 = '1' and ncnt ='1' then
               nxt.state := st_REFRESH ;
            elsif c70='0' and c14 = '1' and ncnt ='1' and in_en = '1' then
               nxt.state := st_ACT ;
            else
               nxt.state := st_idle ;
            end if;

         when st_ACT =>
            nxt.state := st_RCD_wait ;
            c_io := cmd_ACT ;
            wait_cnt := tRCD ;
            cmncs := '1' ;
            c14s := '1' ;
            nxt.v(this_r.b_id) := '1';
            nxt.b_a(this_r.b_id) := this_r.row_a ;

         when st_RCD_wait =>
            if c70='1' or (  c14='1' and bnkmis='1' and in_en = '1' ) then
               nxt.state := st_PRECHG ;
            elsif c70='0' and ncnt='1' and bnkmis='0' and rd_en = '1' and burst='0' then
               nxt.state := st_READS ;
            elsif c70='0' and ncnt='1' and bnkmis='0' and rd_en = '1' and burst='1' then
               nxt.state := st_READB ;
            elsif c70='0' and ncnt='1' and bnkmis='0' and wr_en = '1' then
               nxt.state := st_WRITES;
               wack := '1' ;
            else
               nxt.state := st_RCD_wait ;
            end if;

         when st_READB =>
               nxt.state := st_READB2 ;
               c_io := cmd_READ ;
               caset := '1' ;
               caen := '1' ;

         when st_READB2 =>
               nxt.state := st_rdn ;
               c_io := cmd_READ ;
               wait_cnt := DDR_BURST_LENGTH/2 - 2;
               baen := '1' ;
               cmncs := '1' ;
               caen := '1' ;
               nxt.rack := '1' ;

         when st_rdn =>
            nxt.rack := '1' ;
            if this_r.cmnc = 1 then nxt.eack := '1' ;
            else
            end if;
            if ncnt='0' then
               nxt.state := st_rdn ;
               c_io := cmd_READ ;
            elsif c70='1' then
               nxt.state := st_PRECHG ;
               wait_cnt := 5 ;
               cmncs := '1' ;
            else
               nxt.state := st_RCD_wait ;
               c_io := cmd_IDLE ;
            end if;
            baen := '1' ;
            caen := '1' ;

         when st_READS =>
            nxt.state := st_READS2 ;
            c_io := cmd_READ ;

         when st_READS2 =>
            nxt.rack := '1' ;
           if c70='1' then
            nxt.state := st_PRECHG ;
            wait_cnt := 1 ;
            cmncs := '1' ;
           else
            nxt.state := st_RCD_wait ;
               wait_cnt := 2 ;
               cmncs := '1' ;
           end if;
            

         when st_WRITES =>
            c_io := cmd_WRITE ;
            if bnkmis='0' and wr_en ='1' and c70='0' then
               nxt.state := st_WRITEW ;
               wack := '1' ;
            else
               nxt.state := st_WRITEE ;
            end if;

         when st_WRITEW =>
            wr_oe := '1' ;
               c_io := cmd_WRITE ;
            if bnkmis='0' and wr_en ='1' and c70='0'then
               nxt.state := st_WRITEW ;
               c_io := cmd_WRITE ;
               wack := '1' ;
            else
               nxt.state := st_WRITEE ;
            end if;
            if this_r.cmnc = 3 then nxt.eack := '1' ;
            else
            end if;

         when st_WRITEE =>
            c_io := cmd_IDLE ;
            wr_oe := '1' ;
            nxt.ctwr := tWR ;
           if bnkmis='0' and wr_en ='1' and c70 ='0' then
               nxt.state := st_WRITES ;
               wack := '1' ;
               if burst = '1' then
                   wait_cnt := 7 ;
                   cmncs := '1' ;
               else
               end if;
            elsif bnkmis='0' and rd_en ='1' and c70='0' then
               nxt.state := st_wr_wait ;
            elsif (bnkmis='1' and in_en='1') or c70 ='1' then
               nxt.state := st_PRECHG ;
            elsif in_en='0' then
               nxt.state := st_RCD_wait ;
            end if;

         when st_wr_wait =>
            if ncnt='0' then
               nxt.state := st_wr_wait ;
            elsif ncnt='1' and burst='1' then
               nxt.state := st_READB ;
            else
               nxt.state := st_READS ;
            end if;


         when st_PRECHG =>
               if (c70 = '1' and ncnt='0') or ( c14 = '0') or ( ctwrz = '0') then 
                  nxt.state := st_PRECHG ;
               else 
                  if( C70 = '1' ) then 
                    pre_all :='1' ;
                    nxt.v := V_BNK_A_INIT ;
                  else 
                    pre_all :='0' ;
                    nxt.v(this_r.b_id) := '0' ;
                  end if ;
                  nxt.state := st_idle ;
                  c_io := cmd_PREA ;
                  cmncs := '1' ;
                  wait_cnt := tRP ;
              end if ;

         when st_REFRESH =>
               if (ncnt='0') or ( c14 = '0') then 
                  c_io := cmd_idle ;
                  nxt.state := st_REFRESH ;
               else 
                  c_io := cmd_AUTORF ;
                  nxt.state := st_idle ;
                  c70s := '1' ;
                  cmncs := '1' ;
                  wait_cnt := tRFC ;
               end if ;

         when others =>
            nxt.state := st_idle;
      end case;

---- counter for 70usec, ACT-ACT , general wait time, and addres counter for read burst ----

--      if c70s = '1' and xreset_in ='1' then nxt.c70c := C70_MAX ;
--      elsif c70s = '1' and xreset_in  = '0' then nxt.c70c := C70_MAX2 ;
--      end if;
      if c70s = '1' then nxt.c70c := C70_MAX ;
      end if;

      if nxt.c70c = 0 then nxt.c70c_zero := '1';
      else                 nxt.c70c_zero := '0'; end if;

      if c14s = '1' then nxt.c14c := tRFC ;
      end if;

      if cmncs = '1' then nxt.cmnc := wait_cnt ;
      end if ;

      if    (caset = '1' and caen = '1') then
        nxt.cadr := (vtoi(i.a(4 downto 2)) +1) mod 8 ;
      elsif (caset = '0' and caen = '1') then
        nxt.cadr := (this_r.cadr + 1 )         mod 8 ;
      else
      end if;
      tadr(2 downto 0) := std_logic_vector(to_unsigned(this_r.cadr,3)) ;

--- make IO data using the state machine -----
--- First data to DDR -----
     if(this_r.state = st_LMR ) then
                                padr := this_r.row_a ;
     elsif(this_r.state = st_PREA or this_r.state = st_PRECHG) then 
       if (pre_all = '1' ) then padr := this_r.row_a or  ("000" & x"400");
       else                     padr := this_r.row_a and ("111" & x"bff");
       end if ;
     elsif(this_r.state = st_ACT ) then
                                padr := this_r.row_a ;
     else
       if baen = '0' then       padr := this_r.clm_a ;
       else                     padr := this_r.clm_a(14 downto 4) & 
                                          tadr      ( 2 downto 0) & '0';
       end if;
     end if;

     if   (fix_pinhi = '1') then nxt.do_d := (others => '1'); -- copy pkgconst
     elsif(fix_pinlo = '1') then nxt.do_d := (others => '0');
     else                        nxt.do_d := this_r.do; end if;

     nxt.do := i.d;
     if   (fix_pinhi = '1') then nxt.we_d := (others => '1'); -- copy pkgconst
     elsif(fix_pinlo = '1') then nxt.we_d := (others => '0');
     else                        nxt.we_d := this_r.we; end if;

     if(wr_en = '1' ) then nxt.we := (not i.we);
                      else nxt.we := "0000" ;
     end if ;


--- fifth : from ddr data ----
     if(reset_in = '1' ) then dmy_cke := '0' ;
                         else dmy_cke := '1' ;
     end if;

--- last : connect register to output ---

     if   (fix_pinhi = '1') then
       s_c            <= SD_CTRL_FIXHI;
       s_o_pre        := SD_DATA_FIXHI;
                             -- here large vector16+16+2+2 will be not used too
                             -- much fix-sig -> endpoint fanout may have
                             --  difficulty in static timing analysis
                             -- For this reason, 16+16+2+2 signal fix is done
                             -- before flip-flop.
     elsif(fix_pinlo = '1') then
       s_c            <= SD_CTRL_FIXLO;
       s_o_pre        := SD_DATA_FIXLO;
     else
       s_c.a          <= padr ; -- s_c seven members
       s_c.ba         <= itov(this_r.b_id ,2);
       s_c.cke        <= dmy_cke ;
       s_c.cs         <= not dmy_cke ;
       s_c.ras        <= c_io(2) ;
       s_c.cas        <= c_io(1) ;
       s_c.we         <= c_io(0) ;
       s_o_pre.dq_lat_en  := not wr_oe ;
       s_o_pre.dqs_lat_en := not sq_en ;
       s_o_pre.rd_lat_en  := sq_vld ;
       s_o_pre.cko_enable := '1';
     end if;

     s_o.dq_lat_en  <= s_o_pre.dq_lat_en ; -- s_o 5-8/8
     s_o.dqs_lat_en <= s_o_pre.dqs_lat_en;
     s_o.rd_lat_en  <= s_o_pre.rd_lat_en ;
     s_o.cko_enable <= s_o_pre.cko_enable;
     
     s_o.dq_latp    <= this_r.do_d(31 downto 16); -- s_o 1-4/8
     s_o.dq_latn    <= this_r.do_d(15 downto 0);
     s_o.dm_latp    <= this_r.we_d(3 downto 2);
     s_o.dm_latn    <= this_r.we_d(1 downto 0);
     
     o_d.d <= s_i.dqo_lat(31 downto 0)  ;    --  change for syn
     if(READ_SAMPLE_TM <= 6) then
          o_d.ack <= this_r.rack_ddd  or wack;
     else o_d.ack <= this_r.rack_dddd or wack; end if;
     --                             * (one more character)
     eack <= this_r.eack_d ;

-- for debug only for gtk ---
   Xc_io <= c_io ;
   Xrd_en <= rd_en ;
   Xwait_cnt <= wait_cnt ;
   Xcnt_set <= cnt_set ;
   Xburst <= burst ;
   Xc70 <= c70 ;
   Xc70s <= c70s ;
   Xc14 <= c14 ;
   Xc14s <= c14s ;
   Xncnt <= ncnt ;
   Xcmncs <= cmncs ;
   Xcaset <= caset ;
   Xcaen <= caen ;
   Xbaen <= baen ;
   Xtadr <= tadr ;
   Xwack <= wack ;
   Xbnkmis <= bnkmis ;
   Xin_en <= in_en ;
   Xnxt <= nxt ;
   Xpadr <= padr ;
   Xwr_en <= wr_en ;
   Xwr_oe <= wr_oe;
--   for dummy useage clk_2x  --
  if ((this_r.state = st_wait ) and (cycle_count = 99999)) then
      nxt.do := (others => '1') ;
  end if;

   if reset_in = '1' then
         cycle_count <= 0;
   elsif rising_edge(clk_2x) then
         --Cycle_count
         if (cycle_count /= 100000 ) then
              cycle_count <= cycle_count + 1;
         else cycle_count <= 0;
         end if;
  end if ;


-- end dummy ---



   this_c <= nxt ;


   end process; --ddr_trans

   ddr_trans_r0 : process(clk, reset_in)
   begin
      if clk = '1' and clk'event then
         if reset_in = '1' then
            this_r <= FSM_REG_RESET ;
         else
            this_r <= this_c;
         end if;
      end if;
   end process;


end; --architecture logic
