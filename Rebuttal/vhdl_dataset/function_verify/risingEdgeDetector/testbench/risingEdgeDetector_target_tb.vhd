--------------------------------------------------------------------------------
-- Testbench: risingEdgeDetector_target_tb
-- DUT: risingEdgeDetector
-- Tests the flip-flop-based rising edge detector.
-- sig_o = sig_i AND NOT q, where q is sig_i delayed by one clock.
--
-- Key insight: sig_o is combinational. The pulse sig_o='1' appears
-- between the moment sig_i goes high and the next rising clock edge
-- (which captures sig_i into q, killing the pulse). Therefore we must
-- check sig_o='1' BEFORE the clock edge and sig_o='0' AFTER it.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity risingEdgeDetector_target_tb is
end risingEdgeDetector_target_tb;

architecture sim of risingEdgeDetector_target_tb is

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals
    signal clk   : std_logic := '0';
    signal sig_i : std_logic := '0';
    signal sig_o : std_logic;

begin

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- DUT instantiation
    DUT : entity work.risingEdgeDetector
        port map (
            clk   => clk,
            sig_i => sig_i,
            sig_o => sig_o
        );

    -- Stimulus and checking
    stim_proc : process
    begin
        -- ----------------------------------------------------------------
        -- Test 1: Initial state, sig_i='0'
        -- q is uninitialised but sig_i=0 so sig_o = '0' AND NOT q = '0'
        -- ----------------------------------------------------------------
        sig_i <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test1: sig_o should be '0' when sig_i='0' (initial state)"
            severity error;

        -- Wait one more clock so q captures '0'
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test1b: sig_o should still be '0' (q=0, sig_i=0)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: Set sig_i='1' and check BEFORE the next clock edge.
        -- At this point q is still '0' (captured last cycle), so
        -- sig_o = '1' AND NOT '0' = '1' -- the rising-edge pulse.
        -- ----------------------------------------------------------------
        sig_i <= '1';
        wait for 1 ns;  -- let the combinational logic settle
        assert sig_o = '1'
            report "FAIL Test2: sig_o should be '1' after sig_i rises (before clock edge, q still 0)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Now wait for the rising clock edge.
        -- The flip-flop captures sig_i='1' into q.
        -- sig_o = '1' AND NOT '1' = '0' -- pulse ends.
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test3: sig_o should be '0' after clock edge captures sig_i into q"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: sig_i stays '1', another clock cycle.
        -- q='1', sig_o = '1' AND NOT '1' = '0'.
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test4: sig_o should be '0' when sig_i sustained high (no new edge)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: sig_i goes '0'. sig_o = '0' AND NOT '1' = '0'.
        -- After clock edge q captures '0', sig_o = '0' AND NOT '0' = '0'.
        -- ----------------------------------------------------------------
        sig_i <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test5: sig_o should be '0' after sig_i falls"
            severity error;

        -- One more cycle with sig_i='0' to ensure q='0'.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test5b: sig_o should remain '0' when sig_i stays low"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 6: Second rising edge of sig_i. Check BEFORE clock edge.
        -- q='0', sig_i='1' -> sig_o = '1' AND NOT '0' = '1'.
        -- ----------------------------------------------------------------
        sig_i <= '1';
        wait for 1 ns;  -- let combinational logic settle
        assert sig_o = '1'
            report "FAIL Test6: sig_o should be '1' after second sig_i rise (before clock edge)"
            severity error;

        -- After clock edge: q captures '1', sig_o = '1' AND NOT '1' = '0'.
        wait until rising_edge(clk);
        wait for 1 ns;
        assert sig_o = '0'
            report "FAIL Test6b: sig_o should be '0' after clock edge captures sig_i"
            severity error;

        report "All risingEdgeDetector tests passed." severity note;
        wait;
    end process;

end sim;
