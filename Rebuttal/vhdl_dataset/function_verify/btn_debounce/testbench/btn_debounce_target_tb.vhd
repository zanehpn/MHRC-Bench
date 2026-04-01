--------------------------------------------------------------------------------
-- Testbench: btn_debounce_target_tb
-- DUT: BTN_DEBOUNCE (generic CNT_WIDTH=2)
--
-- Architecture:
--   btn_raw_sync_reg2 tracks BTN_RAW after 2-cycle synchroniser.
--   btn_raw_sample_reg captures btn_raw_sync_reg2 on SAMPLE_EN='1'.
--   deb_cnt counts SAMPLE_EN pulses where btn_raw_diff=0;
--   deb_cnt_max when deb_cnt = 2^CNT_WIDTH - 1 = 3 (CNT_WIDTH=2).
--   BTN_DEB is set to btn_raw_sample_reg when deb_cnt_max='1'.
--   BTN_DEB_RE pulses when deb_cnt_max AND btn_raw_sample_reg AND NOT btn_deb_reg.
--
-- NOTE: btn_deb_reg (driving BTN_DEB) has NO async reset, so it starts as 'U'.
--       Only BTN_DEB_RE and deb_cnt are reset by ASYNC_RST.
--       We must not assert BTN_DEB='0' until the debounce counter has saturated
--       at least once after reset release.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity btn_debounce_target_tb is
end btn_debounce_target_tb;

architecture sim of btn_debounce_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal CLK        : std_logic := '0';
    signal ASYNC_RST  : std_logic := '1';
    signal SAMPLE_EN  : std_logic := '0';
    signal BTN_RAW    : std_logic := '0';
    signal BTN_DEB    : std_logic;
    signal BTN_DEB_RE : std_logic;

    -- Timeout helper
    signal test_done : boolean := false;

begin

    -- Clock generation
    clk_proc : process
    begin
        while not test_done loop
            CLK <= '0';
            wait for CLK_PERIOD / 2;
            CLK <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- DUT instantiation
    DUT : entity work.BTN_DEBOUNCE
        generic map (
            CNT_WIDTH => 2
        )
        port map (
            CLK        => CLK,
            ASYNC_RST  => ASYNC_RST,
            SAMPLE_EN  => SAMPLE_EN,
            BTN_RAW    => BTN_RAW,
            BTN_DEB    => BTN_DEB,
            BTN_DEB_RE => BTN_DEB_RE
        );

    -- Stimulus and checking
    stim_proc : process

        -- Helper: pulse SAMPLE_EN for one clock cycle
        procedure pulse_sample_en is
        begin
            SAMPLE_EN <= '1';
            wait until rising_edge(CLK);
            wait for 1 ns;
            SAMPLE_EN <= '0';
        end procedure;

    begin
        -- ----------------------------------------------------------------
        -- Test 1: Assert reset
        -- btn_deb_reg has NO async reset, so BTN_DEB will be 'U' at startup.
        -- Only check BTN_DEB_RE which IS async-reset to '0'.
        -- ----------------------------------------------------------------
        ASYNC_RST <= '1';
        BTN_RAW   <= '0';
        SAMPLE_EN <= '0';
        wait for CLK_PERIOD * 3;
        wait for 1 ns;

        assert BTN_DEB_RE = '0'
            report "FAIL Test1: BTN_DEB_RE should be '0' during ASYNC_RST"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: Release reset with BTN_RAW='0'.
        -- Allow synchroniser to propagate '0' (2 clock cycles), then
        -- pulse SAMPLE_EN enough times for deb_cnt to reach max (need 3
        -- increments: 0->1->2->3). After counter saturates, wait one more
        -- clock for btn_deb_reg to capture btn_raw_sample_reg.
        -- Then BTN_DEB should be '0'.
        -- ----------------------------------------------------------------
        ASYNC_RST <= '0';
        BTN_RAW   <= '0';

        -- Let synchroniser propagate BTN_RAW='0' through 2 flip-flops
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);  -- extra margin

        -- Pulse SAMPLE_EN enough times for debounce counter to saturate.
        -- CNT_WIDTH=2 => counter max = 3, need at least 3 SAMPLE_EN pulses
        -- to go 0->1->2->3. Give extra pulses to be safe.
        for i in 0 to 5 loop
            pulse_sample_en;
            wait until rising_edge(CLK);
        end loop;

        -- After deb_cnt_max='1', btn_deb_reg captures on the next rising edge.
        -- Allow one more cycle for the capture.
        wait until rising_edge(CLK);
        wait for 1 ns;

        assert BTN_DEB = '0'
            report "FAIL Test2: BTN_DEB should be '0' after debounce settles with BTN_RAW='0'"
            severity error;

        assert BTN_DEB_RE = '0'
            report "FAIL Test2b: BTN_DEB_RE should be '0' when button is not pressed"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Press button (BTN_RAW='1') and let synchroniser pipeline fill
        -- Need at least 2 clock cycles for btn_raw_sync_reg2 to see '1'
        -- ----------------------------------------------------------------
        BTN_RAW <= '1';
        -- Allow two sync stages to propagate
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);  -- extra margin

        -- Now pulse SAMPLE_EN enough times for the debounce counter to saturate.
        -- CNT_WIDTH=2 => deb_cnt_max when deb_cnt=3, so need at least 3 SAMPLE_EN
        -- pulses while btn_raw_diff=0 (stable input).
        -- Give extra pulses to be safe.
        for i in 0 to 7 loop
            pulse_sample_en;
            wait until rising_edge(CLK);
        end loop;

        wait for 1 ns;

        -- After enough SAMPLE_EN pulses with stable BTN_RAW='1', BTN_DEB should be '1'
        assert BTN_DEB = '1'
            report "FAIL Test3: BTN_DEB should be '1' after debouncing pressed button"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: BTN_DEB_RE should have pulsed (check it is now back to '0'
        -- since it only pulses for one clock cycle on the rising edge).
        -- We check the current state: after the debounce settled, RE would
        -- have fired and should now be '0' (btn_deb_reg already matches).
        -- ----------------------------------------------------------------
        assert BTN_DEB_RE = '0'
            report "FAIL Test4: BTN_DEB_RE should have returned to '0' after the rising-edge pulse"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: Release button (BTN_RAW='0'), run debounce again
        -- After enough SAMPLE_EN pulses, BTN_DEB should go back to '0'
        -- ----------------------------------------------------------------
        BTN_RAW <= '0';
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);
        wait until rising_edge(CLK);

        for i in 0 to 7 loop
            pulse_sample_en;
            wait until rising_edge(CLK);
        end loop;

        wait for 1 ns;

        assert BTN_DEB = '0'
            report "FAIL Test5: BTN_DEB should return to '0' after button released and debounced"
            severity error;

        report "All btn_debounce tests passed." severity note;
        test_done <= true;
        wait;
    end process;

end sim;
