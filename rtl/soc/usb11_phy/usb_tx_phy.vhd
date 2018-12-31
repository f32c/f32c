--======================================================================================--
--          Verilog to VHDL conversion by Martin Neumann martin@neumnns-mail.de         --
--                                                                                      --
--          ///////////////////////////////////////////////////////////////////         --
--          //                                                               //         --
--          //  USB 1.1 PHY                                                  //         --
--          //  TX                                                           //         --
--          //                                                               //         --
--          //                                                               //         --
--          //  Author: Rudolf Usselmann                                     //         --
--          //          rudi@asics.ws                                        //         --
--          //                                                               //         --
--          //                                                               //         --
--          //  Downloaded from: http://www.opencores.org/cores/usb_phy/     //         --
--          //                                                               //         --
--          ///////////////////////////////////////////////////////////////////         --
--          //                                                               //         --
--          //  Copyright (C) 2000-2002 Rudolf Usselmann                     //         --
--          //                          www.asics.ws                         //         --
--          //                          rudi@asics.ws                        //         --
--          //                                                               //         --
--          //  This source file may be used and distributed without         //         --
--          //  restriction provided that this copyright statement is not    //         --
--          //  removed from the file and that any derivative work contains  //         --
--          //  the original copyright notice and the associated disclaimer. //         --
--          //                                                               //         --
--          //      THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY      //         --
--          //  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED    //         --
--          //  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS    //         --
--          //  FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR       //         --
--          //  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,          //         --
--          //  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES     //         --
--          //  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE    //         --
--          //  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR         //         --
--          //  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF   //         --
--          //  LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT   //         --
--          //  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT   //         --
--          //  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE          //         --
--          //  POSSIBILITY OF SUCH DAMAGE.                                  //         --
--          //                                                               //         --
--          ///////////////////////////////////////////////////////////////////         --
--======================================================================================--
--                                                                                      --
-- Change history                                                                       --
-- +-------+-----------+-------+------------------------------------------------------+ --
-- | Vers. | Date      | Autor | Comment                                              | --
-- +-------+-----------+-------+------------------------------------------------------+ --
-- |  2.0  | 3 Jul 2016|  MN   | Changed eop logic due to USB spec violation          | --
-- |  1.1  |23 Apr 2011|  MN   | Added missing 'rst' in process sensitivity lists     | --
-- |       |           |       | Added ELSE constructs in next_state process to       | --
-- |       |           |       |   prevent an undesired latch implementation.         | --
-- |  1.0  |04 Feb 2011|  MN   | Initial version                                      | --
--======================================================================================--
 
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
 
ENTITY usb_tx_phy is
  PORT (
    clk              : IN  STD_LOGIC;
    rst              : IN  STD_LOGIC;
    fs_ce            : IN  STD_LOGIC;
    phy_mode         : IN  STD_LOGIC; -- HIGH level for differential IO mode (else single-ended)
    -- Transciever Interface
    txdp, txdn, txoe : OUT STD_LOGIC;
    -- UTMI Interface
    DataOut_i        : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    TxValid_i        : IN  STD_LOGIC;
    TxReady_o        : OUT STD_LOGIC
  );
END usb_tx_phy;
 
ARCHITECTURE RTL of usb_tx_phy is
 
  SIGNAL hold_reg           : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL ld_data            : STD_LOGIC;
  SIGNAL ld_data_d          : STD_LOGIC;
  SIGNAL ld_sop_d           : STD_LOGIC;
  SIGNAL bit_cnt            : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL sft_done_e         : STD_LOGIC;
  SIGNAL any_eop_state      : STD_LOGIC;
  SIGNAL append_eop         : STD_LOGIC;
  SIGNAL data_xmit          : STD_LOGIC;
  SIGNAL hold_reg_d         : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL one_cnt            : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL sd_bs_o            : STD_LOGIC;
  SIGNAL sd_nrzi_o          : STD_LOGIC;
  SIGNAL sd_raw_o           : STD_LOGIC;
  SIGNAL sft_done           : STD_LOGIC;
  SIGNAL sft_done_r         : STD_LOGIC;
  SIGNAL state              : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL stuff              : STD_LOGIC;
  SIGNAL tx_ip              : STD_LOGIC;
  SIGNAL tx_ip_sync         : STD_LOGIC;
  SIGNAL txoe_r1, txoe_r2   : STD_LOGIC;
 
  CONSTANT IDLE_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
  CONSTANT SOP_STATE        : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
  CONSTANT DATA_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
  CONSTANT WAIT_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
  CONSTANT EOP0_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
  CONSTANT EOP1_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
  CONSTANT EOP2_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
  CONSTANT EOP3_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
  CONSTANT EOP4_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";
  CONSTANT EOP5_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1101";
 
BEGIN
 
--======================================================================================--
  -- Misc Logic                                                                         --
--======================================================================================--
 
  p_TxReady_o: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      TxReady_o <= '0';
    ELSIF rising_edge(clk) THEN
      TxReady_o <= ld_data_d AND TxValid_i;
    END IF;
  END PROCESS;
 
  p_ld_data: PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      ld_data <= ld_data_d;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Transmit in progress indicator                                                     --
--======================================================================================--
 
  p_tx_ip: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      tx_ip <= '0';
    ELSIF rising_edge(clk) THEN
      IF ld_sop_d  ='1' THEN
        tx_ip <= '1';
      ELSIF append_eop ='1' THEN
        tx_ip <= '0';
      END IF;
    END IF;
  END PROCESS;
 
  p_tx_ip_sync: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      tx_ip_sync <= '0';
    ELSIF rising_edge(clk) THEN
      IF fs_ce ='1' THEN
        tx_ip_sync <= tx_ip;
      END IF;
    END IF;
  END PROCESS;
 
  -- data_xmit helps us to catch cases where TxValid drops due to
  -- packet END and then gets re-asserted as a new packet starts.
  -- We might not see this because we are still transmitting.
  -- data_xmit should solve those cases ...
  p_data_xmit: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      data_xmit <= '0';
    ELSIF rising_edge(clk) THEN
      IF TxValid_i ='1' AND tx_ip ='0' THEN
        data_xmit <= '1';
      ELSIF TxValid_i = '0' THEN
        data_xmit <= '0';
      END IF;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Shift Register                                                                     --
--======================================================================================--
 
  p_bit_cnt: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      bit_cnt <= "000";
    ELSIF rising_edge(clk) THEN
      IF tx_ip_sync ='0' THEN
        bit_cnt <= "000";
      ELSIF fs_ce ='1' AND stuff ='0' THEN
        bit_cnt <= bit_cnt + 1;
      END IF;
    END IF;
  END PROCESS;
 
  p_sd_raw_o: PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF tx_ip_sync ='0' THEN
        sd_raw_o <= '0';
      ELSE
        sd_raw_o <= hold_reg_d(CONV_INTEGER(UNSIGNED(bit_cnt)));
      END IF;
    END IF;
  END PROCESS;
 
  p_sft_done: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      sft_done   <= '0';
      sft_done_r <= '0';
    ELSIF rising_edge(clk) THEN
      IF bit_cnt = "111" THEN
        sft_done <= NOT stuff;
      ELSE
        sft_done <= '0';
      END IF;
      sft_done_r <= sft_done;
    END IF;
  END PROCESS;
 
  sft_done_e <= sft_done AND NOT sft_done_r;
 
  -- Out Data Hold Register
  p_hold_reg: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
        hold_reg   <= X"00";
        hold_reg_d <= X"00";
    ELSIF rising_edge(clk) THEN
      IF ld_sop_d ='1' THEN
        hold_reg <= X"80";
      ELSIF ld_data ='1' THEN
        hold_reg <= DataOut_i;
      END IF;
      hold_reg_d <= hold_reg;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Bit Stuffer                                                                        --
--======================================================================================--
 
  p_one_cnt: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      one_cnt <= "000";
    ELSIF rising_edge(clk) THEN
      IF tx_ip_sync ='0' THEN
        one_cnt <= "000";
      ELSIF fs_ce ='1' THEN
        IF sd_raw_o ='0' OR stuff = '1' THEN
          one_cnt <= "000";
        ELSE
          one_cnt <= one_cnt + 1;
        END IF;
      END IF;
    END IF;
  END PROCESS;
 
  stuff   <= '1' WHEN one_cnt = "110" ELSE '0';
 
  p_sd_bs_o: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      sd_bs_o <= '0';
    ELSIF rising_edge(clk) THEN
      IF fs_ce ='1' THEN
        IF tx_ip_sync ='0' THEN
          sd_bs_o <= '0';
        ELSE
          IF stuff ='1' THEN
            sd_bs_o <= '0';
          ELSE
            sd_bs_o <= sd_raw_o;
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- NRZI Encoder                                                                       --
--======================================================================================--
 
  p_sd_nrzi_o: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      sd_nrzi_o <= '1';
    ELSIF rising_edge(clk) THEN
      IF tx_ip_sync ='0' OR txoe_r1 ='0' THEN
        sd_nrzi_o <= '1';
      ELSIF fs_ce ='1' THEN
        IF sd_bs_o ='1' THEN
          sd_nrzi_o <= sd_nrzi_o;
        ELSE
          sd_nrzi_o <= NOT sd_nrzi_o;
        END IF;
      END IF;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Output Enable Logic                                                                --
--======================================================================================--
 
  p_txoe: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      txoe_r1 <= '0';
      txoe_r2 <= '0';
      txoe    <= '1';
    ELSIF rising_edge(clk) THEN
      IF fs_ce ='1' THEN
        txoe_r1 <= tx_ip_sync;
        txoe_r2 <= txoe_r1;
        txoe    <= NOT (txoe_r1 OR txoe_r2);
      END IF;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Output Registers                                                                   --
--======================================================================================--
 
  p_txdpn: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      txdp <= '1';
      txdn <= '0';
    ELSIF rising_edge(clk) THEN
      IF fs_ce ='1' THEN
        IF phy_mode ='1' THEN
          txdp <= NOT append_eop AND     sd_nrzi_o;
          txdn <= NOT append_eop AND NOT sd_nrzi_o;
        ELSE
          txdp <= sd_nrzi_o;
          txdn <= append_eop;
        END IF;
      END IF;
    END IF;
  END PROCESS;
 
--======================================================================================--
  -- Tx Statemashine                                                                    --
--======================================================================================--
 
  any_eop_state <= state(3);
 
  p_state: PROCESS (clk, rst)
  BEGIN
    IF rst ='0' THEN
      state <= IDLE_STATE;
    ELSIF rising_edge(clk) THEN
      IF any_eop_state = '0' THEN
        CASE (state) IS
          WHEN IDLE_STATE => IF TxValid_i ='1' THEN
                               state <= SOP_STATE;
                             END IF;
          WHEN SOP_STATE  => IF sft_done_e ='1' THEN
                               state <= DATA_STATE;
                             END IF;
          WHEN DATA_STATE => IF data_xmit ='0' AND sft_done_e ='1' THEN
                               IF one_cnt = "101" AND hold_reg_d(7) = '1' THEN
                                 state <= EOP0_STATE;
                               ELSE
                                 state <= EOP1_STATE;
                               END IF;
                             END IF;
          WHEN WAIT_STATE => IF fs_ce = '1' THEN
                               state <= IDLE_STATE;
                             END IF;
          WHEN OTHERS => state <= IDLE_STATE;
        END CASE;
      ELSE
        IF fs_ce ='1' THEN
          IF state = EOP5_state THEN
            state <= WAIT_STATE;
          ELSE
            state <= unsigned(state) + 1;
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS;
 
  append_eop <= '1' WHEN state(3 DOWNTO 2) = "11" ELSE '0';  -- EOP4_STATE OR EOP5_STATE
  ld_sop_d   <= TxValid_i  WHEN state = IDLE_STATE ELSE '0';
  ld_data_d  <= sft_done_e WHEN state = SOP_STATE OR (state = DATA_STATE AND data_xmit ='1') ELSE '0';
 
END RTL;
