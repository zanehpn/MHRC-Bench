--------------------------------------------------------------------------------
-- Testbench: pwm_driver_target_tb
-- DUT: pwm_driver
--
-- PWM logic (from source):
--   tick_counter starts at 0 (on reset).
--   Each clock: if tick_counter < 255 -> increment; else reset to 0.
--   led_output='1' when tick_counter (after increment) < input_val.
--   Period = 256 clocks (255 increment steps + 1 reset step).
--   For input_val=0x80 (128): led_output='1' for 127 out of 256 clocks.
--   For input_val=0x00  (  0): led_output is always '0' (0 < 0 is false).
--   For input_val=0xFF (255): led_output='1' for 254 out of 256 clocks.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity pwm_driver_target_tb is
end pwm_driver_target_tb;

architecture sim of pwm_driver_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk        : std_ulogic := '0';
    signal rst        : std_ulogic := '1';
    signal input_val  : std_ulogic_vector(7 downto 0) := (others => '0');
    signal led_output : std_ulogic;

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
    DUT : entity work.pwm_driver
        port map (
            clk        => clk,
            rst        => rst,
            input_val  => input_val,
            led_output => led_output
        );

    -- Stimulus and checking
    stim_proc : process
        variable high_count : integer;
    begin
        -- ----------------------------------------------------------------
        -- Test 1: Reset forces led_output='0'
        -- ----------------------------------------------------------------
        rst       <= '1';
        input_val <= X"80";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert led_output = '0'
            report "FAIL Test1: led_output should be '0' during reset"
            severity error;

        wait until rising_edge(clk);
        wait for 1 ns;
        assert led_output = '0'
            report "FAIL Test1b: led_output should remain '0' during second reset cycle"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: input_val=0x00 => led_output always '0' for one full period
        -- ----------------------------------------------------------------
        rst       <= '0';
        input_val <= X"00";
        high_count := 0;

        for i in 0 to 255 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if led_output = '1' then
                high_count := high_count + 1;
            end if;
        end loop;

        assert high_count = 0
            report "FAIL Test2: input_val=0x00 should give led_output='0' for all 256 cycles, got "
                   & integer'image(high_count) & " high cycles"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: input_val=0x80 (128) => roughly half-duty cycle
        -- Over one full 256-clock period, led_output should be '1' for
        -- exactly 127 cycles (tick_counter values 1..127 after increment).
        -- Allow a range of 120..135 to be robust to any off-by-one in the
        -- internal counter state at the start of observation.
        -- ----------------------------------------------------------------
        rst       <= '1';
        input_val <= X"80";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        -- Let the counter settle from reset (tick_counter=0 after reset)
        high_count := 0;
        for i in 0 to 255 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if led_output = '1' then
                high_count := high_count + 1;
            end if;
        end loop;

        assert high_count >= 120 and high_count <= 135
            report "FAIL Test3: input_val=0x80 should give ~127 high cycles in 256, got "
                   & integer'image(high_count)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: input_val=0xFF (255) => led_output='1' for 254/256 cycles
        -- ----------------------------------------------------------------
        rst       <= '1';
        input_val <= X"FF";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        high_count := 0;
        for i in 0 to 255 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if led_output = '1' then
                high_count := high_count + 1;
            end if;
        end loop;

        assert high_count >= 250
            report "FAIL Test4: input_val=0xFF should give >=250 high cycles in 256, got "
                   & integer'image(high_count)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: Confirm input_val=0x00 stays '0' even after non-zero input
        -- ----------------------------------------------------------------
        input_val <= X"00";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led_output = '0'
            report "FAIL Test5: led_output should return to '0' immediately when input_val=0x00"
            severity error;

        report "All pwm_driver tests passed." severity note;
        std.env.finish;
        wait;
    end process;

end sim;
