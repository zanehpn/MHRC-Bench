-- =============================================================================
-- Testbench: Boards_VUnit_original_target_tb.vhd
--
-- Candidate source: Boards_VUnit_original.vhdl
--
-- BLOCKER: THE CANDIDATE FILE IS ITSELF A TESTBENCH.
--
-- Boards_VUnit_original.vhdl contains entity 'tb_boards', which is a VUnit
-- simulation testbench, not a synthesisable design under test. It uses:
--
--   library vunit_lib;
--   context vunit_lib.vunit_context;
--   library JSON;
--   context JSON.json_ctx;
--
-- and the entity has generic 'runner_cfg : string' which is the VUnit runner
-- configuration parameter injected by the VUnit Python simulation framework.
-- The process body calls test_runner_setup(runner, runner_cfg) and iterates
-- test cases using the VUnit while test_suite / run() API.
--
-- This file CANNOT be re-wrapped in another testbench because:
--   1. It is not a DUT - it has no ports or observable output signals.
--   2. It depends on the VUnit simulation framework libraries (vunit_lib,
--      JSON context) which are not part of the IEEE standard.
--   3. The runner_cfg generic must be supplied by VUnit's test runner at
--      simulation invocation time; it cannot be set to a meaningful constant
--      without the VUnit infrastructure.
--   4. The entity exercises JSON parsing via OSVVM/VUnit JSON library
--      (jsonGetString, jsonGetBoolean, jsonLoad, etc.) which are VUnit-
--      specific simulation utilities.
--
-- TO RUN THIS TESTBENCH:
--   Install VUnit (https://vunit.github.io/).
--   Create a run.py script:
--     from vunit import VUnit
--     vu = VUnit.from_argv()
--     lib = vu.add_library("lib")
--     lib.add_source_files("Boards_VUnit_original.vhdl")
--     vu.main()
--   Execute: python run.py
--
-- No re-wrapping testbench is possible. This file is provided as a
-- documentation placeholder per the BLOCKER specification.
-- =============================================================================

-- This entity is intentionally minimal. It serves only as a placeholder to
-- document the BLOCKER described above.

library ieee;
use ieee.std_logic_1164.all;

entity Boards_VUnit_original_target_tb is
  -- No ports: this is a placeholder only.
end entity Boards_VUnit_original_target_tb;

architecture blocker_placeholder of Boards_VUnit_original_target_tb is
begin

  blocker_report : process
  begin
    report "FAIL: BLOCKER - Boards_VUnit is a VUnit testbench, cannot be verified without VUnit framework."
      severity failure;
    wait;
  end process blocker_report;

end architecture blocker_placeholder;
