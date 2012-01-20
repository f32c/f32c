--
-- Copyright 2008, 2011 University of Zagreb.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity idecode is
    generic(
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_movn_movz: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle, branch_likely: out boolean;
	jump_cycle, jump_register: out boolean;
	reg1_zero, reg2_zero: out boolean;
	reg1_addr, reg2_addr, target_addr: out std_logic_vector(4 downto 0);
	immediate_value: out std_logic_vector(31 downto 0);
	sign_extension: out std_logic_vector(15 downto 0);
	sign_extend: out boolean;
	op_major: out std_logic_vector(1 downto 0);
	op_minor: out std_logic_vector(2 downto 0);
	use_immediate, ignore_reg2: out boolean;
	cmov_cycle, cmov_condition: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic;
	latency: out std_logic_vector(1 downto 0);
	seb_seh_cycle: out boolean;
	seb_seh_select: out std_logic
    );  
end idecode;

architecture Behavioral of idecode is
    signal opcode, fncode: std_logic_vector(5 downto 0);
    signal type_code: std_logic_vector(1 downto 0);
    signal imm_extension: std_logic_vector(15 downto 0);
    signal cond_move: boolean;
    signal x_reg2_zero, x_special, x_special3, sign_extend_imm: boolean;
    signal x_branch1, x_branch2: boolean;
begin

    opcode <= instruction(31 downto 26);
    fncode <= instruction(5 downto 0);
    mem_read_sign_extend <= not opcode(2);

    reg1_addr <= instruction(25 downto 21);
    reg2_addr <= instruction(20 downto 16);

    reg1_zero <= reg1_addr = "00000";
    x_reg2_zero <= reg2_addr = "00000";
    reg2_zero <= x_reg2_zero;

    -- beq, bne, blez, bgtz
    x_branch1 <= opcode(5) = '0' and opcode(3 downto 2) = "01";
    -- bgez, bltz
    x_branch2 <= opcode = "000001";
    x_special <= opcode = "000000";
    x_special3 <= opcode(5 downto 3) = "011" and opcode(0) = '1';

    seb_seh_cycle <= C_sign_extend and x_special3;
    seb_seh_select <= instruction(9) when C_sign_extend else '0';
    cmov_cycle <= C_movn_movz and cond_move;
    cmov_condition <= (instruction(0) = '0');
    branch_cycle <= x_branch1 or x_branch2;
    branch_likely <= C_branch_likely and ((x_branch1 and opcode(4) = '1') or
      (x_branch2 and instruction(17) = '1'));
    jump_cycle <= opcode(5 downto 1) = "00001";
    jump_register <= x_special and fncode(4 downto 1) = "0100";

    -- type_code for target register address calculation
    process(opcode)
    begin
	case opcode is
	when "000000" => type_code <= "00"; -- R-type - special
	when "011111" => type_code <= "00"; -- R-type - special3
	when "000001" => type_code <= "01"; -- J-t - bgez, bgezal, bltz, bltzal
	when "000010" => type_code <= "01"; -- J-type - j
	when "000011" => type_code <= "01"; -- J-type - jal
	when "000100" => type_code <= "01"; -- J-type - beq
	when "000101" => type_code <= "01"; -- J-type - bne
	when "000110" => type_code <= "01"; -- J-type - blez
	when "000111" => type_code <= "01"; -- J-type - bgtz
	when "010100" => type_code <= "01"; -- J-type - beql
	when "010101" => type_code <= "01"; -- J-type - bnel
	when "010110" => type_code <= "01"; -- J-type - blezl
	when "010111" => type_code <= "01"; -- J-type - bgtzl
	when "101000" => type_code <= "10"; -- S-type - sb
	when "101001" => type_code <= "10"; -- S-type - sh
	when "101010" => type_code <= "10"; -- S-type - unimplemented
	when "101011" => type_code <= "10"; -- S-type - sw
	when others   => type_code <= "11"; -- I-type
	end case;
    end process;

    use_immediate <= opcode(5 downto 3) = "001" or opcode(5) = '1' or
	(C_movn_movz and cond_move);

    process(type_code, opcode, instruction)
    begin
	case type_code is
	when "01" =>	-- J-type
	    if (opcode = "000001" and instruction(20) = '1') or
	      opcode = "000011" then
		target_addr <= "11111"; -- bgezal / bltzal / jal
	    else
		target_addr <= "00000";
	    end if;
	when "10" =>	-- S-type
	    target_addr <= "00000";
	when "11" =>	-- I-type
	    target_addr <= instruction(20 downto 16);
	when others =>	-- R-type
	    target_addr <= instruction(15 downto 11);
	end case;
    end process;

    -- reg2 relevant for load-use or produce-use hazard checking or not?
    ignore_reg2 <= x_reg2_zero or
      -- immediate instructions
      opcode(5 downto 3) = "001" or
      -- load instructions
      (opcode(5) = '1' and opcode(3) = '0') or
      -- j, jal, blez, bgtz
      (opcode(5 downto 3) = "000" and opcode(1) = '1'); 

    -- op_major: 00 ALU, 01 SLT, 10 shift, 11 mul_et_al
    process(x_special, x_special3, opcode, fncode, instruction)
    begin
	op_major <= "00"; -- ALU
	op_minor <= "000"; -- ADD
	mem_cycle <= '0'; -- not a memory operation
	latency <= "00"; -- result available immediately after EX stage
	sign_extend_imm <= true;
	cond_move <= false;

	if x_special then
	    op_minor <= fncode(2 downto 0);
	    if C_movn_movz and fncode(5 downto 1) = "00101" then
		cond_move <= true; -- MOVN / MOVZ
		op_major <= "10"; -- route register through shifter logic
		latency <= "01";
	    end if;
	    if fncode(5 downto 3) = "101" then -- SLT / SLTU
		op_major <= "01";
		op_minor <= "---";
		if fncode(0) = '1' then
		    sign_extend_imm <= false; -- SLTU
		end if;
	    end if;
	    if fncode(5 downto 3) = "000" then -- shift
		op_major <= "10"; -- shift
		op_minor <= "---";
		latency <= "01";
	    end if;
	    if fncode(5 downto 4) = "01" then -- MUL/DIV/MFHI/MFLO/MTHI/MTLO
		op_major <= "11"; -- mul_et_al
		op_minor <= "---";
	    end if;
	elsif x_special3 then
	    op_minor <= "110"; -- logic, xor cycle, for seb
	end if;

	if opcode(5 downto 3) = "001" then
	    op_minor <= opcode(2 downto 0);
	    if opcode(2) = '1' or opcode(1 downto 0) = "11" then
		sign_extend_imm <= false; -- for logic and SLTIU
	    end if;
	    if opcode(2 downto 0) = "111" then -- LUI
		op_minor <= "000"; -- ADD
	    end if;
	    if opcode(2 downto 1) = "01" then
		op_major <= "01"; -- SLTI / SLTIU
	    end if;
	end if;

	if opcode(5 downto 4) = "10" then
	    mem_cycle <= '1';
	    -- There's no need set latency only for loads, because for saves
	    -- the target register is $0 (zero), so latency is ignored
	    latency(0) <= '1'; -- resolve load-use hazard
	    latency(1) <= not mem_size(1); -- resolve load aligner hazard
	end if;
    end process;

    imm_extension <= x"ffff" when sign_extend_imm and instruction(15) = '1'
      else x"0000";
    sign_extension <= imm_extension;

    process(opcode, instruction, imm_extension, cond_move)
    begin
	case opcode is
	when "000000" => -- special (for MOVN / MOVZ)
	    if (C_movn_movz and cond_move) then
		immediate_value <= x"00000000";
	    else
		immediate_value <= imm_extension & instruction(15 downto 0);
	    end if;
	when "001111" => -- lui, XXX revisit: use barrel shifter?
	    immediate_value <= instruction(15 downto 0) & x"0000";
	when others =>
	    immediate_value <= imm_extension & instruction(15 downto 0);
	end case;
    end process;

    branch_condition <=
      '1' & opcode(1 downto 0) when x_branch1 -- beq, bne, blez, bgtz
      else "01" & instruction(16) when x_branch2 -- bgez, bltz
      else "000";

    mem_write <= opcode(3);
    mem_size <= opcode(1 downto 0);

    sign_extend <= sign_extend_imm; -- for the SLT family
end Behavioral;

