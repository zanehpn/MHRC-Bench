--------------------------------------------------------------------------------
-- Testbench: delayLine_target_tb.vhd
-- DUT: delayLine (delayLine_original.vhd)
--
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- BLOCKER 1 — Xilinx UNISIM library required
--   The DUT instantiates Xilinx CARRY4 primitives from library UNISIM.
--   This testbench CANNOT be compiled or simulated without the Xilinx
--   simulation libraries (provided with Vivado / ISE).
--   To simulate: add the Xilinx UNISIM library to your simulator search path,
--   e.g. for GHDL:
--       ghdl -a --std=08 -P/path/to/unisim/UNISIM-obj08.cf ...
--   or use Vivado xsim.
--
-- BLOCKER 2 — work.risingEdgeDetector entity required
--   The DUT instantiates `work.risingEdgeDetector(rtl)` as a sub-entity.
--   That entity must be compiled before the DUT and this testbench.
--
-- NOTE: work.MyPkg is commented out in the DUT source; it is not needed here.
--
-- DESIGN PARAMETERS USED IN THIS TESTBENCH
--   NTaps = 48  (default value from the DUT; must be a multiple of 4 for
--                CARRY4 chains, and the original comment says multiple of 12)
--
-- COMPILE ORDER (once blockers are resolved):
--   1. risingEdgeDetector (sub-entity used by DUT)
--   2. delayLine_original.vhd
--   3. delayLine_target_tb.vhd
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity delayLine_target_tb is
end entity delayLine_target_tb;

architecture tb of delayLine_target_tb is

    -- -----------------------------------------------------------------------
    -- Parameters matching DUT generic
    -- -----------------------------------------------------------------------
    constant C_NTAPS      : integer := 48;
    constant C_CLK_PERIOD : time    := 10 ns;  -- system capture clock
    constant C_HIT_PERIOD : time    := 13 ns;  -- async hit signal (different domain)

    -- -----------------------------------------------------------------------
    -- DUT ports
    -- -----------------------------------------------------------------------
    signal clk_s    : std_logic := '0';
    signal hit_s    : std_logic := '0';
    signal enable_s : std_logic := '0';
    signal thermo_s : std_logic_vector(C_NTAPS-1 downto 0);
    signal valid_s  : std_logic;

    -- -----------------------------------------------------------------------
    -- Component declaration
    -- NOTE: Will NOT compile without Xilinx UNISIM and risingEdgeDetector.
    -- -----------------------------------------------------------------------
    component delayLine is
        generic (
            NTaps : integer := 48
        );
        port (
            clk    : in  std_logic;
            hit    : in  std_logic;
            enable : in  std_logic;
            thermo : out std_logic_vector(NTaps-1 downto 0);
            valid  : out std_logic
        );
    end component delayLine;

begin

    -- -----------------------------------------------------------------------
    -- System clock generation (capture clock domain)
    -- -----------------------------------------------------------------------
    clk_gen : process
    begin
        clk_s <= '0';
        wait for C_CLK_PERIOD / 2;
        clk_s <= '1';
        wait for C_CLK_PERIOD / 2;
    end process clk_gen;

    -- -----------------------------------------------------------------------
    -- DUT instantiation
    -- NOTE: Will NOT compile without Xilinx UNISIM and risingEdgeDetector.
    -- -----------------------------------------------------------------------
    DUT : delayLine
        generic map (
            NTaps => C_NTAPS
        )
        port map (
            clk    => clk_s,
            hit    => hit_s,
            enable => enable_s,
            thermo => thermo_s,
            valid  => valid_s
        );

    -- -----------------------------------------------------------------------
    -- Stimulus
    -- The delay line captures a propagating carry chain when a `hit` rising
    -- edge occurs while `enable` is asserted.
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        -- Initial state: disabled, no hit
        enable_s <= '0';
        hit_s    <= '0';
        wait for 5 * C_CLK_PERIOD;

        -- Enable the TDL
        enable_s <= '1';
        wait for 2 * C_CLK_PERIOD;

        -- Apply a hit pulse (rising edge propagates through CARRY4 chain)
        hit_s <= '1';
        wait for C_HIT_PERIOD;   -- hold for asymmetric time to create realistic delay
        hit_s <= '0';

        -- Wait for the thermometer code to be captured and synchronized
        -- (2 clock cycles for double-synchronizer in the DUT)
        wait for 5 * C_CLK_PERIOD;

        -- Apply a second hit pulse
        hit_s <= '1';
        wait for C_HIT_PERIOD;
        hit_s <= '0';
        wait for 5 * C_CLK_PERIOD;

        -- Disable TDL (hitQ should be forced to '0')
        enable_s <= '0';
        wait for 3 * C_CLK_PERIOD;

        -- -----------------------------------------------------------------------
        -- NOTE: Detailed assertions on thermo_s values are not included because
        -- the actual captured thermometer code depends on the Xilinx CARRY4
        -- timing models, which are only available via UNISIM.  When UNISIM is
        -- available, observe `thermo_s` and `valid_s` in a waveform viewer.
        -- -----------------------------------------------------------------------
        report "delayLine testbench stimulus complete. " &
               "NOTE: compilation requires Xilinx UNISIM and work.risingEdgeDetector." severity note;
        wait;
    end process stim_proc;

end architecture tb;
