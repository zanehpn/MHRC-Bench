--------------------------------------------------------------------------------
-- Testbench for UART_DEBOUNCER
-- Target behavior: output_reg_rst goes low (i.e. DEB_OUT can go high) when
-- ANY bit in the shift register OR DEB_IN is '1' (OR of all bits).
-- Tests:
--   1. Apply DEB_IN='1' for LATENCY cycles -> DEB_OUT goes high
--   2. Apply DEB_IN='0' for LATENCY cycles -> DEB_OUT goes low
--   3. Glitch test: brief '1' pulse does not immediately set DEB_OUT
-- DUT: uart_debouncer_original.vhd (entity UART_DEBOUNCER)
-- LATENCY=4 used (SHREG_DEPTH = LATENCY-1 = 3 bits in shift register)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_debouncer_target_tb is
end entity uart_debouncer_target_tb;

architecture tb of uart_debouncer_target_tb is

    constant LATENCY   : natural := 4;
    constant CLK_PERIOD : time   := 10 ns;

    signal clk     : std_logic := '0';
    signal deb_in  : std_logic := '0';
    signal deb_out : std_logic;

    -- helper to generate clock
    signal clk_en : boolean := true;

begin

    ----------------------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------------------
    clk_proc : process
    begin
        while clk_en loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_proc;

    ----------------------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------------------
    dut : entity work.UART_DEBOUNCER
        generic map (
            LATENCY => LATENCY
        )
        port map (
            CLK     => clk,
            DEB_IN  => deb_in,
            DEB_OUT => deb_out
        );

    ----------------------------------------------------------------------------
    -- Stimulus and checking
    ----------------------------------------------------------------------------
    stim_proc : process
    begin

        -----------------------------------------------------------------------
        -- Initial state: DEB_IN='0' -> DEB_OUT should remain '0'
        -----------------------------------------------------------------------
        deb_in <= '0';
        -- Let the device settle for a few cycles
        wait for CLK_PERIOD * 5;

        assert deb_out = '0'
            report "TEST FAILED: DEB_OUT should be '0' at startup with DEB_IN='0'"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT is '0' at startup";

        -----------------------------------------------------------------------
        -- Test 1: Drive DEB_IN='1' continuously.
        -- After LATENCY clock cycles the shift register is fully '1' so
        -- output_reg_set='1' fires on a rising edge -> DEB_OUT goes to '1'.
        -- LATENCY=4: SHREG_DEPTH=3, so 4 '1' samples (DEB_IN + 3 shreg bits)
        -- are needed for AND to be '1'.  Allow LATENCY+2 cycles to be safe.
        -----------------------------------------------------------------------
        deb_in <= '1';
        wait for CLK_PERIOD * (LATENCY + 2);

        assert deb_out = '1'
            report "TEST FAILED: DEB_OUT should be '1' after LATENCY cycles of DEB_IN='1'"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT is '1' after sustained DEB_IN='1'";

        -----------------------------------------------------------------------
        -- Test 2: Drive DEB_IN='0' continuously.
        -- After LATENCY clock cycles the shift register is fully '0' and
        -- DEB_IN='0', so output_reg_rst='1' -> DEB_OUT goes to '0'.
        -- Allow LATENCY+2 cycles.
        -----------------------------------------------------------------------
        deb_in <= '0';
        wait for CLK_PERIOD * (LATENCY + 2);

        assert deb_out = '0'
            report "TEST FAILED: DEB_OUT should be '0' after LATENCY cycles of DEB_IN='0'"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT returns to '0' after sustained DEB_IN='0'";

        -----------------------------------------------------------------------
        -- Test 3: OR logic - a single '1' pulse (shorter than LATENCY) must
        -- keep output_reg_rst low (NOT reset the output) while the '1' is
        -- anywhere in the shift register.
        -- Bring DEB_IN high for 1 cycle then low; DEB_OUT should NOT go high
        -- (because AND set never fires), but reset should also be suppressed
        -- for SHREG_DEPTH cycles (OR keeps output_reg_rst = '0').
        -----------------------------------------------------------------------

        -- Start fresh: make sure DEB_OUT is '0'
        deb_in <= '0';
        wait for CLK_PERIOD * (LATENCY + 2);

        assert deb_out = '0'
            report "TEST FAILED: DEB_OUT should be '0' before glitch test"
            severity FAILURE;

        -- Apply 1-cycle glitch
        deb_in <= '1';
        wait for CLK_PERIOD;          -- one high cycle
        deb_in <= '0';

        -- Immediately after the glitch, the '1' sample is in the shift
        -- register, so output_reg_rst must be '0' (OR is '1').
        -- DEB_OUT should still be '0' (AND never fired).
        wait for CLK_PERIOD / 2;      -- settle combinatorial output_reg_rst

        -- Check that DEB_OUT did not spuriously go to '1'
        assert deb_out = '0'
            report "TEST FAILED: DEB_OUT should stay '0' for a single-cycle glitch"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT stays '0' for a single-cycle glitch";

        -----------------------------------------------------------------------
        -- Test 4: Full toggle - set high then back low, confirm both transitions
        -----------------------------------------------------------------------
        deb_in <= '1';
        wait for CLK_PERIOD * (LATENCY + 2);
        assert deb_out = '1'
            report "TEST FAILED: DEB_OUT should be '1' in toggle test (set phase)"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT set to '1' in toggle test";

        deb_in <= '0';
        wait for CLK_PERIOD * (LATENCY + 2);
        assert deb_out = '0'
            report "TEST FAILED: DEB_OUT should be '0' in toggle test (reset phase)"
            severity FAILURE;
        report "TEST PASSED: DEB_OUT reset to '0' in toggle test";

        report "ALL UART_DEBOUNCER TESTS PASSED";

        clk_en <= false;
        wait;
    end process stim_proc;

end architecture tb;
