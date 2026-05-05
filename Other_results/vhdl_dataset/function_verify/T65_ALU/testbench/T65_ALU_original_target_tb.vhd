-- =============================================================================
-- Testbench: T65_ALU_original_target_tb.vhd
--
-- DUT: T65_ALU (65xx ALU module)
-- Source: T65_ALU_original.vhd
--
-- BLOCKER:
--   T65_ALU uses custom enumeration type T_ALU_OP (and associated constants
--   Flag_C, Flag_V, Flag_N, Flag_Z, Flag_D, Flag_I, Flag_B, Flag_E) defined
--   in the work.T65_Pack package. The package file (T65_Pack.vhd) is NOT
--   present in the T65_ALU source folder. It must be located in the T65 core
--   source directory and compiled into the 'work' library before this
--   testbench or the DUT can be elaborated.
--
--   Compilation order required:
--     1. T65_Pack.vhd       -> compiled into 'work' library
--     2. T65_ALU_original.vhd
--     3. This testbench
--
--   Without T65_Pack.vhd, elaboration will fail with an unresolved reference
--   to work.T65_Pack. This testbench is written assuming T65_Pack is available.
--
-- Target Logic:
--   The T65_ALU implements the full 6502 ALU: ADC, SBC, AND, ORA, EOR, ASL,
--   LSR, ROL, ROR, INC, DEC, BIT, CMP, etc. The Op input (T_ALU_OP type)
--   selects the operation. Key observable outputs are Q (result) and P_Out
--   (processor status flags: N, V, B, D, I, Z, C).
--
-- Test strategy:
--   Drive combinational inputs directly and check Q and P_Out immediately.
--   Tests cover: ADC (binary and BCD), SBC, AND, ORA, EOR, ASL, LSR.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.T65_Pack.all;   -- BLOCKER: requires T65_Pack.vhd in work library

entity T65_ALU_original_target_tb is
end entity T65_ALU_original_target_tb;

architecture tb of T65_ALU_original_target_tb is

  -- -------------------------------------------------------------------------
  -- DUT interface signals (all combinational - no clock on T65_ALU)
  -- -------------------------------------------------------------------------
  signal Mode  : std_logic_vector(1 downto 0) := "00";  -- 6502
  signal BCD_en: std_logic := '1';
  signal Op    : T_ALU_OP  := ALU_OP_OR;      -- default to ORA
  signal BusA  : std_logic_vector(7 downto 0) := (others => '0');
  signal BusB  : std_logic_vector(7 downto 0) := (others => '0');
  signal P_In  : std_logic_vector(7 downto 0) := (others => '0');
  signal P_Out : std_logic_vector(7 downto 0);
  signal Q     : std_logic_vector(7 downto 0);

  -- Processor status flag bit positions (from T65_Pack)
  -- Flag_C=0, Flag_Z=1, Flag_I=2, Flag_D=3, Flag_B=4, Flag_V=6, Flag_N=7
  constant C_BIT : integer := Flag_C;
  constant Z_BIT : integer := Flag_Z;
  constant N_BIT : integer := Flag_N;
  constant V_BIT : integer := Flag_V;

  -- Small delay for combinational settling
  constant PROP_DELAY : time := 5 ns;

begin

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.T65_ALU
    port map (
      Mode   => Mode,
      BCD_en => BCD_en,
      Op     => Op,
      BusA   => BusA,
      BusB   => BusB,
      P_In   => P_In,
      P_Out  => P_Out,
      Q      => Q
    );

  -- -------------------------------------------------------------------------
  -- Stimulus and assertion process (combinational DUT, no clock needed)
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- -----------------------------------------------------------------------
    -- Test 1: ORA  0x0F | 0xF0 = 0xFF, N=1, Z=0
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_OR;
    BusA <= x"0F";
    BusB <= x"F0";
    P_In <= x"00";
    wait for PROP_DELAY;
    assert Q = x"FF"
      report "FAIL ORA: expected Q=0xFF, got " & to_hstring(Q) severity error;
    assert P_Out(N_BIT) = '1'
      report "FAIL ORA: expected N=1" severity error;
    assert P_Out(Z_BIT) = '0'
      report "FAIL ORA: expected Z=0" severity error;
    report "PASS: ORA 0x0F|0xF0 = 0xFF" severity note;

    -- -----------------------------------------------------------------------
    -- Test 2: AND  0xFF & 0x55 = 0x55, N=0, Z=0
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_AND;
    BusA <= x"FF";
    BusB <= x"55";
    P_In <= x"00";
    wait for PROP_DELAY;
    assert Q = x"55"
      report "FAIL AND: expected Q=0x55, got " & to_hstring(Q) severity error;
    assert P_Out(N_BIT) = '0'
      report "FAIL AND: expected N=0" severity error;
    report "PASS: AND 0xFF&0x55 = 0x55" severity note;

    -- -----------------------------------------------------------------------
    -- Test 3: EOR  0xFF ^ 0xFF = 0x00, Z=1
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_EOR;
    BusA <= x"FF";
    BusB <= x"FF";
    P_In <= x"00";
    wait for PROP_DELAY;
    assert Q = x"00"
      report "FAIL EOR: expected Q=0x00, got " & to_hstring(Q) severity error;
    assert P_Out(Z_BIT) = '1'
      report "FAIL EOR: expected Z=1" severity error;
    report "PASS: EOR 0xFF^0xFF = 0x00 (Z=1)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 4: ADC (binary)  0x01 + 0x01 + C=0 = 0x02, C=0, Z=0, N=0, V=0
    -- -----------------------------------------------------------------------
    BCD_en <= '1';
    Op   <= ALU_OP_ADC;
    BusA <= x"01";
    BusB <= x"01";
    P_In <= x"00";   -- C=0
    wait for PROP_DELAY;
    assert Q = x"02"
      report "FAIL ADC: expected Q=0x02, got " & to_hstring(Q) severity error;
    assert P_Out(C_BIT) = '0'
      report "FAIL ADC: expected C=0" severity error;
    report "PASS: ADC 0x01+0x01=0x02 (no carry)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 5: ADC  0xFF + 0x01 + C=0 = 0x00, C=1, Z=1
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_ADC;
    BusA <= x"FF";
    BusB <= x"01";
    P_In <= x"00";  -- C=0
    wait for PROP_DELAY;
    assert Q = x"00"
      report "FAIL ADC carry: expected Q=0x00, got " & to_hstring(Q) severity error;
    assert P_Out(C_BIT) = '1'
      report "FAIL ADC carry: expected C=1" severity error;
    assert P_Out(Z_BIT) = '1'
      report "FAIL ADC carry: expected Z=1" severity error;
    report "PASS: ADC 0xFF+0x01=0x00 (carry out, zero)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 6: ASL  0x80 << 1 = 0x00, C=1 (shifted out), Z=1
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_ASL;
    BusA <= x"80";
    BusB <= x"00";
    P_In <= x"00";
    wait for PROP_DELAY;
    assert Q = x"00"
      report "FAIL ASL: expected Q=0x00, got " & to_hstring(Q) severity error;
    assert P_Out(C_BIT) = '1'
      report "FAIL ASL: expected C=1 (MSB shifted into carry)" severity error;
    report "PASS: ASL 0x80 = 0x00 (C=1)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 7: LSR  0x01 >> 1 = 0x00, C=1, Z=1
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_LSR;
    BusA <= x"01";
    BusB <= x"00";
    P_In <= x"00";
    wait for PROP_DELAY;
    assert Q = x"00"
      report "FAIL LSR: expected Q=0x00, got " & to_hstring(Q) severity error;
    assert P_Out(C_BIT) = '1'
      report "FAIL LSR: expected C=1 (LSB shifted into carry)" severity error;
    report "PASS: LSR 0x01 = 0x00 (C=1)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 8: SBC  0x10 - 0x01, C=1 (borrow clear) = 0x0F
    -- 6502 SBC: result = A - B - (1 - C), so C=1 means no borrow
    -- -----------------------------------------------------------------------
    Op   <= ALU_OP_SBC;
    BusA <= x"10";
    BusB <= x"01";
    P_In <= (others => '0');
    P_In(C_BIT) <= '1';  -- carry set = no borrow
    wait for PROP_DELAY;
    assert Q = x"0F"
      report "FAIL SBC: expected Q=0x0F, got " & to_hstring(Q) severity error;
    report "PASS: SBC 0x10-0x01 (C=1) = 0x0F" severity note;

    report "INFO: T65_ALU combinational tests complete." severity note;
    report "NOTE: BLOCKER: T65_Pack.vhd (work.T65_Pack) must be compiled into" &
           " 'work' before elaboration of DUT and this testbench." severity note;

    wait;
  end process stim_proc;

end architecture tb;
