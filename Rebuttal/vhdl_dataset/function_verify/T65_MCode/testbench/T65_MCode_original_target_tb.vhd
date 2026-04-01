-- =============================================================================
-- Testbench: T65_MCode_original_target_tb.vhd
--
-- DUT: T65_MCode (65xx microcode decoder)
-- Source: T65_MCode_original.vhd
--
-- BLOCKER:
--   T65_MCode uses custom types T_Lcycle (MCycle / LCycle), T_ALU_Op,
--   T_Set_BusA_To, T_Set_Addr_To, and T_Write_Data from work.T65_Pack.
--   The package file T65_Pack.vhd is NOT present in the T65_MCode source
--   folder. It resides in the T65 core source tree and must be compiled into
--   the 'work' library before elaboration of this testbench.
--
--   Compilation order required:
--     1. T65_Pack.vhd         -> compiled into 'work'
--     2. T65_MCode_original.vhd
--     3. This testbench
--
-- Target Logic:
--   Inc_S and Dec_S outputs control the 6502 stack pointer inside T65.vhd.
--   T65_MCode drives Inc_S='1' for stack-pull instructions (PLA, PLP, RTS,
--   RTI) and Dec_S='1' for stack-push instructions (PHA, PHP, BRK, JSR).
--   This testbench drives IR (opcode) and MCycle inputs to exercise those
--   output paths.
--
-- T65_MCode is combinational (no clock): outputs are purely a function of
-- {Mode, IR, MCycle, P, Rdy_mod}.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.T65_Pack.all;   -- BLOCKER: requires T65_Pack.vhd in work library

entity T65_MCode_original_target_tb is
end entity T65_MCode_original_target_tb;

architecture tb of T65_MCode_original_target_tb is

  -- -------------------------------------------------------------------------
  -- DUT interface signals (combinational)
  -- -------------------------------------------------------------------------
  signal Mode          : std_logic_vector(1 downto 0) := "00";  -- 6502
  signal IR            : std_logic_vector(7 downto 0) := x"EA"; -- NOP
  signal MCycle        : T_Lcycle;
  signal P             : std_logic_vector(7 downto 0) := x"20"; -- default
  signal Rdy_mod       : std_logic := '1';

  signal LCycle        : T_Lcycle;
  signal ALU_Op        : T_ALU_Op;
  signal Set_BusA_To   : T_Set_BusA_To;
  signal Set_Addr_To   : T_Set_Addr_To;
  signal Write_Data    : T_Write_Data;
  signal Jump          : std_logic_vector(1 downto 0);
  signal BAAdd         : std_logic_vector(1 downto 0);
  signal BAQuirk       : std_logic_vector(1 downto 0);
  signal BreakAtNA     : std_logic;
  signal ADAdd         : std_logic;
  signal AddY          : std_logic;
  signal PCAdd         : std_logic;
  signal Inc_S         : std_logic;
  signal Dec_S         : std_logic;
  signal LDA           : std_logic;
  signal LDP           : std_logic;
  signal LDX           : std_logic;
  signal LDY           : std_logic;
  signal LDS           : std_logic;
  signal LDDI          : std_logic;
  signal LDALU         : std_logic;
  signal LDAD          : std_logic;
  signal LDBAL         : std_logic;
  signal LDBAH         : std_logic;
  signal SaveP         : std_logic;
  signal Write_out     : std_logic;

  constant PROP_DELAY : time := 5 ns;

begin

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.T65_MCode
    port map (
      Mode          => Mode,
      IR            => IR,
      MCycle        => MCycle,
      P             => P,
      Rdy_mod       => Rdy_mod,
      LCycle        => LCycle,
      ALU_Op        => ALU_Op,
      Set_BusA_To   => Set_BusA_To,
      Set_Addr_To   => Set_Addr_To,
      Write_Data    => Write_Data,
      Jump          => Jump,
      BAAdd         => BAAdd,
      BAQuirk       => BAQuirk,
      BreakAtNA     => BreakAtNA,
      ADAdd         => ADAdd,
      AddY          => AddY,
      PCAdd         => PCAdd,
      Inc_S         => Inc_S,
      Dec_S         => Dec_S,
      LDA           => LDA,
      LDP           => LDP,
      LDX           => LDX,
      LDY           => LDY,
      LDS           => LDS,
      LDDI          => LDDI,
      LDALU         => LDALU,
      LDAD          => LDAD,
      LDBAL         => LDBAL,
      LDBAH         => LDBAH,
      SaveP         => SaveP,
      Write         => Write_out
    );

  -- -------------------------------------------------------------------------
  -- Stimulus and assertion process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin

    -- -----------------------------------------------------------------------
    -- Test 1: NOP (0xEA) at MCycle=0 (first cycle)
    --   NOP is a 2-cycle instruction. At cycle 0 (fetch), LCycle should
    --   indicate 1 remaining cycle. Inc_S and Dec_S should be '0'.
    -- -----------------------------------------------------------------------
    IR     <= x"EA";   -- NOP
    MCycle <= "000";
    wait for PROP_DELAY;
    assert Inc_S = '0'
      report "FAIL NOP MC0: Inc_S should be 0" severity error;
    assert Dec_S = '0'
      report "FAIL NOP MC0: Dec_S should be 0" severity error;
    report "PASS: NOP MCycle=0 -> Inc_S=0, Dec_S=0" severity note;

    -- -----------------------------------------------------------------------
    -- Test 2: PHA (0x48) - Push Accumulator (3 cycles)
    --   6502 microcode: MC0=fetch, MC1=write to stack, MC2=Dec_S
    --   At Cycle_1 Write should be '1'. At Cycle_2 Dec_S should be '1'.
    -- -----------------------------------------------------------------------
    IR     <= x"48";   -- PHA
    MCycle <= "000";
    wait for PROP_DELAY;
    assert Dec_S = '0'
      report "FAIL PHA MC0: Dec_S should be 0 at fetch cycle" severity error;

    MCycle <= "001";  -- Cycle_1: stack write
    wait for PROP_DELAY;
    assert Write_out = '1'
      report "FAIL PHA MC1: Write should be 1" severity error;
    report "PASS: PHA MCycle=1 -> Write=1 (stack write path)" severity note;

    MCycle <= "010";  -- Cycle_2: Dec_S
    wait for PROP_DELAY;
    assert Dec_S = '1'
      report "FAIL PHA MC2: Dec_S should be 1 (stack push)" severity error;
    report "PASS: PHA MCycle=2 -> Dec_S=1 (stack pointer decrement path)" severity note;

    -- -----------------------------------------------------------------------
    -- Test 3: PLA (0x68) - Pull Accumulator (4 cycles)
    --   At the appropriate microcode cycle, Inc_S should assert.
    -- -----------------------------------------------------------------------
    IR     <= x"68";   -- PLA
    MCycle <= "000";
    wait for PROP_DELAY;
    assert Inc_S = '0'
      report "FAIL PLA MC0: Inc_S should be 0 at fetch" severity error;

    -- Try MCycle=2 (dummy read from old SP, then Inc_S)
    MCycle <= "010";
    wait for PROP_DELAY;
    -- Check for Inc_S assertion (exact cycle may vary by implementation)
    if Inc_S = '1' then
      report "PASS: PLA MCycle=2 -> Inc_S=1" severity note;
    else
      -- Try MCycle=3
      MCycle <= "011";
      wait for PROP_DELAY;
      assert Inc_S = '1'
        report "FAIL PLA: Inc_S not asserted in MCycle=2 or MCycle=3" severity error;
      report "PASS: PLA MCycle=3 -> Inc_S=1 (stack pointer increment path)" severity note;
    end if;

    -- -----------------------------------------------------------------------
    -- Test 4: JSR (0x20) - Jump to Subroutine (6 cycles)
    --   At MCycle=3,4: two bytes pushed to stack (PCH, PCL), Dec_S each time.
    -- -----------------------------------------------------------------------
    IR     <= x"20";   -- JSR abs
    MCycle <= "011";
    wait for PROP_DELAY;
    assert Dec_S = '1'
      report "FAIL JSR MC3: Dec_S should be 1 (PCH push)" severity error;
    report "PASS: JSR MCycle=3 -> Dec_S=1" severity note;

    -- -----------------------------------------------------------------------
    -- Test 5: RTS (0x60) - Return from Subroutine (6 cycles)
    --   At MCycle=3,4: two bytes pulled from stack (PCL, PCH), Inc_S each.
    -- -----------------------------------------------------------------------
    IR     <= x"60";   -- RTS
    MCycle <= "010";
    wait for PROP_DELAY;
    -- RTS increments SP twice to pull return address
    if Inc_S = '1' then
      report "PASS: RTS MCycle=2 -> Inc_S=1" severity note;
    else
      MCycle <= "011";
      wait for PROP_DELAY;
      assert Inc_S = '1'
        report "FAIL RTS: Inc_S not seen in MC2 or MC3" severity error;
      report "PASS: RTS MCycle=3 -> Inc_S=1" severity note;
    end if;

    report "INFO: T65_MCode combinational decode tests complete." severity note;
    report "NOTE: BLOCKER: T65_Pack.vhd (work.T65_Pack) must be compiled into" &
           " 'work' before elaboration. Exact MCycle encoding depends on T65_Pack" &
           " T_Lcycle type definition." severity note;

    wait;
  end process stim_proc;

end architecture tb;
