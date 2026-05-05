--------------------------------------------------------------------------------
-- Testbench: counter_target_tb
-- DUT: counter (generic BITS)
-- Tests free-running counter: starts at 0, increments each clock, wraps at 2^BITS.
-- Uses BITS=8 for fast simulation.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_target_tb is
end counter_target_tb;

architecture sim of counter_target_tb is

    constant CLK_PERIOD : time    := 10 ns;
    constant TB_BITS    : integer := 8;

    signal clk    : std_logic := '0';
    signal coarse : std_logic_vector(TB_BITS - 1 downto 0);

begin

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- DUT instantiation with reduced bit width
    DUT : entity work.counter
        generic map (
            BITS => TB_BITS
        )
        port map (
            clk    => clk,
            coarse => coarse
        );

    -- Stimulus and checking
    stim_proc : process
        variable prev_count : unsigned(TB_BITS - 1 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Test 1: Initial output is 0 before first clock edge
        -- (count is initialised to (others => '0'))
        -- ----------------------------------------------------------------
        wait for 1 ns;  -- before first rising edge
        assert unsigned(coarse) = 0
            report "FAIL Test1: coarse should be 0 at reset/init"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: After first rising clock edge, coarse = 1
        -- (coarse is driven combinationally from count; count increments
        --  on rising_edge, coarse follows count)
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert unsigned(coarse) = 1
            report "FAIL Test2: coarse should be 1 after first clock edge"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: After second rising clock edge, coarse = 2
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert unsigned(coarse) = 2
            report "FAIL Test3: coarse should be 2 after second clock edge"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: Counter increments monotonically for 10 cycles
        -- ----------------------------------------------------------------
        for i in 3 to 12 loop
            prev_count := unsigned(coarse);
            wait until rising_edge(clk);
            wait for 1 ns;
            assert unsigned(coarse) = prev_count + 1
                report "FAIL Test4: counter did not increment by 1 at cycle " & integer'image(i)
                severity error;
        end loop;

        -- ----------------------------------------------------------------
        -- Test 5: Counter wraps from 255 back to 0 (for BITS=8)
        -- Run until coarse = 254, then check next cycle is 255, then 0.
        -- ----------------------------------------------------------------
        -- Wind forward until coarse = 254
        while unsigned(coarse) /= 254 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        assert unsigned(coarse) = 254
            report "FAIL Test5a: coarse should be 254 before wrap"
            severity error;

        -- Next clock: 255
        wait until rising_edge(clk);
        wait for 1 ns;
        assert unsigned(coarse) = 255
            report "FAIL Test5b: coarse should be 255 one before wrap"
            severity error;

        -- Next clock: wraps to 0
        wait until rising_edge(clk);
        wait for 1 ns;
        assert unsigned(coarse) = 0
            report "FAIL Test5c: coarse should wrap to 0 after 255"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 6: Continues counting upward after wrap
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;
        assert unsigned(coarse) = 1
            report "FAIL Test6: coarse should be 1 after wrap to 0"
            severity error;

        report "All counter tests passed." severity note;
        wait;
    end process;

end sim;
