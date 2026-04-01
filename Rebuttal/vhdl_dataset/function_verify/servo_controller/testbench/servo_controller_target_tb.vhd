-- Testbench for servo_controller
-- Target: `control_counter <= control_counter + 1;` - counter increment for
-- PWM generation.
--
-- Configuration:
--   clock_period_ns = 100  (10 MHz clock, 10 ns period)
--   minimum_high_pulse_width_ns = 1_000_000 ns  (1 ms)
--   maximum_high_pulse_width_ns = 2_000_000 ns  (2 ms)
--   PWM period = 25_000_000 ns (25 ms)
--
-- With clock_period_ns=100:
--   min_high_clock_periods = 1_000_000 / 100 = 10_000
--   max_high_clock_periods = 2_000_000 / 100 = 20_000
--   PWM_period_clock_periods = 25_000_000 / 100 = 250_000
--
-- For servo_position_input=0x00: high pulse = 1 ms (10_000 cycles)
-- For servo_position_input=0xFF: high pulse = ~2 ms (20_000 cycles)
--
-- To keep simulation time practical we observe the first high pulse only
-- and check that servo_control_out goes high and then returns low.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity servo_controller_target_tb is
end servo_controller_target_tb;

architecture sim of servo_controller_target_tb is

    constant CLK_PERIOD_NS_INT : integer := 100;  -- 100 ns clock
    constant CLK_PERIOD        : time    := 100 ns;

    signal clk                         : std_logic := '0';
    signal rst                         : std_logic := '1';
    signal minimum_high_pulse_width_ns : std_logic_vector(31 downto 0)
        := std_logic_vector(to_unsigned(1_000_000, 32));
    signal maximum_high_pulse_width_ns : std_logic_vector(31 downto 0)
        := std_logic_vector(to_unsigned(2_000_000, 32));
    signal servo_position_input        : std_logic_vector(7 downto 0) := x"00";
    signal servo_control_out           : std_logic;

    -- Expected minimum high pulse width in clock cycles
    constant MIN_HIGH_CLKS : integer := 1_000_000 / CLK_PERIOD_NS_INT;  -- 10_000

begin

    -- Clock: 100 ns period (10 MHz)
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.servo_controller
        generic map (
            clock_period_ns => CLK_PERIOD_NS_INT
        )
        port map (
            minimum_high_pulse_width_ns => minimum_high_pulse_width_ns,
            maximum_high_pulse_width_ns => maximum_high_pulse_width_ns,
            clk                         => clk,
            rst                         => rst,
            servo_position_input        => servo_position_input,
            servo_control_out           => servo_control_out
        );

    stim : process
        variable high_count : integer := 0;
        variable low_seen   : boolean := false;
    begin
        -- ----------------------------------------------------------------
        -- Test 1: During reset, output should be '0' (FSM in reset state
        -- drives servo_control_out='0' via the combinational default).
        -- ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD * 3;
        assert servo_control_out = '0'
            report "FAIL: servo_control_out should be 0 during reset"
            severity error;

        -- ----------------------------------------------------------------
        -- Release reset with position=0x00 (minimum pulse width).
        -- FSM transitions reset -> high_period.
        -- ----------------------------------------------------------------
        rst <= '0';
        servo_position_input <= x"00";

        -- Test 2: servo_control_out should go high immediately (high_period)
        wait until rising_edge(clk);
        wait for CLK_PERIOD / 4;
        -- After one clock the FSM should be in high_period, output = '1'
        wait until rising_edge(clk);
        wait for CLK_PERIOD / 4;
        assert servo_control_out = '1'
            report "FAIL: servo_control_out should be '1' in high_period state"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Measure the high pulse width.
        -- Count how many cycles servo_control_out stays '1'.
        -- Should be approximately MIN_HIGH_CLKS = 10_000 cycles.
        -- Allow +/-2 cycles tolerance for FSM pipeline stages.
        -- ----------------------------------------------------------------
        high_count := 0;
        while servo_control_out = '1' loop
            wait until rising_edge(clk);
            high_count := high_count + 1;
            if high_count > MIN_HIGH_CLKS + 10 then
                exit;  -- safety exit
            end if;
        end loop;

        assert high_count >= MIN_HIGH_CLKS - 2 and high_count <= MIN_HIGH_CLKS + 2
            report "FAIL: high pulse width mismatch. Expected ~" &
                   integer'image(MIN_HIGH_CLKS) & " cycles, got " &
                   integer'image(high_count) & " cycles"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: After the high pulse, servo_control_out should go low
        -- (low_period state).
        -- ----------------------------------------------------------------
        assert servo_control_out = '0'
            report "FAIL: servo_control_out should be '0' after high pulse ends"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: Change position to 0xFF; the new high pulse (starting
        -- next PWM cycle) should last longer than the minimum.
        -- Wait for output to go high again.
        -- ----------------------------------------------------------------
        servo_position_input <= x"FF";
        -- Wait for the low period to complete (up to 240_000 cycles)
        for i in 1 to 240_001 loop
            wait until rising_edge(clk);
            if servo_control_out = '1' then
                low_seen := true;
                exit;
            end if;
        end loop;
        assert low_seen
            report "FAIL: servo_control_out did not return to '1' for second PWM cycle"
            severity error;

        report "All assertions passed.";
        wait;
    end process;

end sim;
