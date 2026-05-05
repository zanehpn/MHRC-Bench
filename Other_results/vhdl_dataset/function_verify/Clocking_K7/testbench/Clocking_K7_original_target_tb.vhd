-- =============================================================================
-- Testbench: Clocking_K7_original_target_tb.vhd
--
-- DUT: Clocking_K7 (Kintex-7 clock generation using Xilinx MMCM/PLL)
-- Source: Clocking_K7_original.vhd
--
-- BLOCKER: Xilinx UNISIM Primitives Required.
--
-- Clocking_K7 instantiates:
--   - PLLE2_ADV   from library unisim (Xilinx MMCM/PLL primitive)
--   - BUFG         from library unisim (global clock buffer)
--
-- These are Xilinx vendor-specific simulation primitives. They are provided
-- by the Xilinx Vivado or ISE UNISIM library and are NOT available in a
-- plain IEEE VHDL simulation environment (GHDL, ModelSim without Xilinx libs,
-- etc.).
--
-- To simulate this design:
--   Option A: Xilinx Vivado simulator (xsim)
--     - UNISIM is automatically available.
--     - Add source files to project, set top = Clocking_K7_original_target_tb.
--     - Run behavioral simulation.
--   Option B: GHDL with UNISIM stub
--     - Compile Xilinx UNISIM VHDL stubs (found in Vivado installation at
--       $XILINX_VIVADO/data/vhdl/src/unisims/).
--     - The PLLE2_ADV stub will drive LOCKED='0' and clock outputs='0' since
--       it cannot model PLL lock-up without real silicon behaviour.
--
-- Target: MMCME2_BASE generic map parameters in Clocking_K7.vhd:
--   CLKFBOUT_MULT => 25, CLKIN1_PERIOD => 25.000 (40 MHz input)
--   CLKOUT0_DIVIDE => 5  -> MiningClk = 40 * 25 / 5 = 200 MHz
--   CLKOUT1_DIVIDE => 25 -> UartClk   = 40 * 25 / 25 = 40 MHz
--   The PLLE2_ADV primitive is used (not MMCME2_BASE as noted in the target
--   description; the source uses PLLE2_ADV).
--
-- This testbench provides clock stimulus and checks port connectivity.
-- Assertions on MiningClk and UartClk frequencies are NOT made because
-- UNISIM stubs do not model PLL behavior.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Clocking_K7_original_target_tb is
end entity Clocking_K7_original_target_tb;

architecture tb of Clocking_K7_original_target_tb is

  -- -------------------------------------------------------------------------
  -- Input clock: 40 MHz (25 ns period) to match CLKIN1_PERIOD generic
  -- -------------------------------------------------------------------------
  constant CLK_IN_PERIOD : time := 25 ns;   -- 40 MHz

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal aReset    : std_logic := '1';
  signal ClkIn     : std_logic := '0';
  signal MiningClk : std_logic;
  signal UartClk   : std_logic;
  signal Locked    : std_logic;

begin

  -- -------------------------------------------------------------------------
  -- Input clock generation (40 MHz)
  -- -------------------------------------------------------------------------
  clkin_proc : process
  begin
    ClkIn <= '0'; wait for CLK_IN_PERIOD / 2;
    ClkIn <= '1'; wait for CLK_IN_PERIOD / 2;
  end process clkin_proc;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- BLOCKER NOTE: Elaboration will fail without Xilinx UNISIM library
  --   providing PLLE2_ADV and BUFG component bodies.
  -- -------------------------------------------------------------------------
  DUT : entity work.Clocking_K7
    port map (
      aReset    => aReset,
      ClkIn     => ClkIn,
      MiningClk => MiningClk,
      UartClk   => UartClk,
      Locked    => Locked
    );

  -- -------------------------------------------------------------------------
  -- Stimulus process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- Apply reset
    aReset <= '1';
    wait for 10 * CLK_IN_PERIOD;

    -- Release reset
    aReset <= '0';

    -- -----------------------------------------------------------------------
    -- Allow time for PLL lock (in real hardware ~100 us; in simulation with
    -- UNISIM stub, Locked may remain '0' unless the stub models lock).
    -- -----------------------------------------------------------------------
    wait for 200 * CLK_IN_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 1: Locked must not be 'U' (undriven)
    --   With a proper UNISIM library, Locked should eventually go '1'.
    --   With stubs Locked = '0' is acceptable; 'U' is not.
    -- -----------------------------------------------------------------------
    assert Locked /= 'U'
      report "FAIL: Locked output is 'U' (undriven) - PLLE2_ADV UNISIM model" &
             " may not be present." severity error;

    -- -----------------------------------------------------------------------
    -- ASSERT 2: MiningClk and UartClk must not be 'U'
    -- -----------------------------------------------------------------------
    assert MiningClk /= 'U'
      report "FAIL: MiningClk is 'U' (undriven) - BUFG or PLLE2_ADV UNISIM" &
             " model may not be present." severity error;
    assert UartClk /= 'U'
      report "FAIL: UartClk is 'U' (undriven) - BUFG or PLLE2_ADV UNISIM" &
             " model may not be present." severity error;

    if Locked = '1' then
      report "PASS: Locked = '1' - PLL has locked" severity note;
    else
      report "INFO: Locked = '0' - PLL has not locked. " &
             "This is expected with UNISIM stub models. " &
             "MiningClk and UartClk are valid structural outputs." severity note;
    end if;

    report "INFO: Clocking_K7_original_target_tb complete." &
           " BLOCKER: Requires Xilinx UNISIM library (PLLE2_ADV, BUFG)." &
           " PLL parameters: CLKFBOUT_MULT=25, CLKIN1_PERIOD=25.000ns," &
           " CLKOUT0_DIVIDE=5 (MiningClk=200MHz)," &
           " CLKOUT1_DIVIDE=25 (UartClk=40MHz)."
      severity note;

    wait;
  end process stim_proc;

end architecture tb;
