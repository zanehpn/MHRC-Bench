--------------------------------------------------------------------------------
-- Testbench: pattern_generator_target_tb
-- DUT: pattern_generator
--
-- State machine (s0..s5) cycles through a color spectrum.
-- Initial register values: r=0xFF, g=0x00, b=0x00 => rgb=0xFF0000.
-- In s0: state immediately -> s1 (first clock, no g-increment guard).
-- In s1: r decrements each clock until r=0, then -> s2.
-- rgb = r & g & b (combinational from signals).
--
-- Tests:
--   1. video_active='0': r,g,b reset to initial values (r=FF,g=0,b=0).
--   2. video_active='1': rgb is non-zero in the early s1 phase (r decrementing).
--   3. After many cycles different color phases appear (g or b becomes non-zero).
--   4. After video_active='0' then '1', rgb returns to non-zero pattern.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pattern_generator_target_tb is
end pattern_generator_target_tb;

architecture sim of pattern_generator_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk          : std_logic := '0';
    signal video_active : std_logic := '0';
    signal rgb          : std_logic_vector(23 downto 0);

    -- Helper functions to extract color channels
    signal r_chan : std_logic_vector(7 downto 0);
    signal g_chan : std_logic_vector(7 downto 0);
    signal b_chan : std_logic_vector(7 downto 0);

begin

    r_chan <= rgb(23 downto 16);
    g_chan <= rgb(15 downto  8);
    b_chan <= rgb( 7 downto  0);

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- DUT instantiation
    DUT : entity work.pattern_generator
        port map (
            clk          => clk,
            video_active => video_active,
            rgb          => rgb
        );

    -- Stimulus and checking
    stim_proc : process
        variable saw_non_zero   : boolean;
        variable saw_g_nonzero  : boolean;
        variable saw_b_nonzero  : boolean;
    begin
        -- ----------------------------------------------------------------
        -- Test 1: video_active='0' resets rgb to initial state (FF0000).
        -- r,g,b initialise to FF/00/00 in the source; one clock with
        -- video_active='0' will re-apply the reset branch.
        -- ----------------------------------------------------------------
        video_active <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        -- After first clock with video_active='0': r<=FF, g<=00, b<=00
        assert rgb = X"FF0000"
            report "FAIL Test1: rgb should be 0xFF0000 when video_active='0', got 0x"
                   & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: video_active='1' - rgb is non-zero in the s1 phase.
        -- First clock with video_active='1': state goes s0->s1 (r stays FF).
        -- Second clock: r decrements to FE; rgb = FE0000 (non-zero).
        -- ----------------------------------------------------------------
        video_active <= '1';
        wait until rising_edge(clk);  -- s0 -> s1, r stays FF
        wait for 1 ns;

        assert rgb /= X"000000"
            report "FAIL Test2: rgb should be non-zero when video_active='1' in state s1"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Run for 300 more clocks and confirm rgb is non-zero
        -- at least once during the active phase (s1 = r decrementing).
        -- ----------------------------------------------------------------
        saw_non_zero := false;
        for i in 0 to 299 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if rgb /= X"000000" then
                saw_non_zero := true;
            end if;
        end loop;

        assert saw_non_zero
            report "FAIL Test3: rgb was never non-zero during 300 active clocks"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: After 256 clocks in s1 (r goes from 0xFF down to 0),
        -- state moves to s2 where b increments. Run for many more cycles
        -- and check that g or b eventually becomes non-zero.
        -- ----------------------------------------------------------------
        saw_g_nonzero := false;
        saw_b_nonzero := false;

        -- s1 runs for up to 255 extra clocks (r=0xFE..0x00), then s2 runs.
        -- We already spent ~300 clocks above, so s2 has started.
        -- Run 300 more clocks looking for b non-zero.
        for i in 0 to 299 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if unsigned(g_chan) /= 0 then
                saw_g_nonzero := true;
            end if;
            if unsigned(b_chan) /= 0 then
                saw_b_nonzero := true;
            end if;
        end loop;

        assert saw_b_nonzero or saw_g_nonzero
            report "FAIL Test4: Expected g or b to become non-zero after color cycling (s2/s3 phase)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: video_active='0' resets back to FF0000
        -- ----------------------------------------------------------------
        video_active <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert rgb = X"FF0000"
            report "FAIL Test5: rgb should reset to 0xFF0000 when video_active='0', got 0x"
                   & to_hstring(rgb)
            severity error;

        report "All pattern_generator tests passed." severity note;
        wait;
    end process;

end sim;
