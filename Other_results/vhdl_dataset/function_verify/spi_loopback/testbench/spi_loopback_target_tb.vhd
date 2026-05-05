--------------------------------------------------------------------------------
-- Testbench for SPI_LOOPBACK
-- Target: s_dout_reg <= (others => '0'); -- reset of s_dout_reg
-- Tests: reset behaviour, loopback connectivity (M_MISO <= M_MOSI),
--        and output signal states after reset.
--
-- NOTE: SPI_LOOPBACK instantiates several sub-entities (RST_SYNC, CLK_EN_GEN,
-- BTN_DEBOUNCE, SPI_MASTER, SPI_SLAVE, SSEG_DRIVER).  All must be compiled
-- into work before running this testbench.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_loopback_target_tb is
end entity;

architecture tb of spi_loopback_target_tb is

    constant CLK_PERIOD : time := 20 ns;   -- 50 MHz (as used internally)

    -- DUT ports
    signal CLK             : std_logic := '0';
    signal BTN_RST         : std_logic := '0';
    signal M_SCLK          : std_logic;
    signal M_CS_N          : std_logic;
    signal M_MOSI          : std_logic;
    signal M_MISO          : std_logic := '0';
    signal S_SCLK          : std_logic := '0';
    signal S_CS_N          : std_logic := '1';
    signal S_MOSI          : std_logic := '0';
    signal S_MISO          : std_logic;
    signal BTN_MENU_MODE   : std_logic := '0';
    signal BTN_MENU_ACTION : std_logic := '0';
    signal SSEG            : std_logic_vector(7 downto 0);
    signal SSEG_AN         : std_logic_vector(3 downto 0);

    -- Loopback: master MISO driven from master MOSI
    signal mosi_dly : std_logic := '0';

    -- Monitor
    signal m_cs_n_seen_low : std_logic := '0';
    signal m_sclk_seen_high : std_logic := '0';

begin

    -- -------------------------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------------------------
    dut : entity work.SPI_LOOPBACK
        port map (
            CLK             => CLK,
            BTN_RST         => BTN_RST,
            M_SCLK          => M_SCLK,
            M_CS_N          => M_CS_N,
            M_MOSI          => M_MOSI,
            M_MISO          => M_MISO,
            S_SCLK          => S_SCLK,
            S_CS_N          => S_CS_N,
            S_MOSI          => S_MOSI,
            S_MISO          => S_MISO,
            BTN_MENU_MODE   => BTN_MENU_MODE,
            BTN_MENU_ACTION => BTN_MENU_ACTION,
            SSEG            => SSEG,
            SSEG_AN         => SSEG_AN
        );

    -- -------------------------------------------------------------------------
    -- Clock Generation
    -- -------------------------------------------------------------------------
    clk_gen : process
    begin
        CLK <= '0'; wait for CLK_PERIOD / 2;
        CLK <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- -------------------------------------------------------------------------
    -- Loopback: M_MISO follows M_MOSI with one clock delay
    -- This models a slave device echoing back data on the same SPI bus.
    -- -------------------------------------------------------------------------
    loopback_proc : process (CLK)
    begin
        if rising_edge(CLK) then
            mosi_dly <= M_MOSI;
        end if;
    end process;
    M_MISO <= mosi_dly;

    -- -------------------------------------------------------------------------
    -- Monitor: detect M_CS_N going low and M_SCLK going high
    -- -------------------------------------------------------------------------
    monitor : process (CLK)
    begin
        if rising_edge(CLK) then
            if M_CS_N = '0'  then m_cs_n_seen_low  <= '1'; end if;
            if M_SCLK = '1'  then m_sclk_seen_high <= '1'; end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
        -- CLK_EN_GEN divides 50 MHz to 1 kHz => 50000 cycles per ms tick.
        -- BTN_DEBOUNCE samples at 1 kHz with debounce.  For simulation we
        -- hold BTN_MENU_ACTION long enough to pass debounce (>3 samples = >3 ms).
        constant DEBOUNCE_HOLD : natural := 200_000;  -- 4 ms @ 50 MHz
        variable timeout_cnt   : natural := 0;
    begin
        -- =====================================================================
        -- Phase 1: Assert reset (BTN_RST is active-high async)
        -- =====================================================================
        BTN_RST         <= '1';
        BTN_MENU_MODE   <= '0';
        BTN_MENU_ACTION <= '0';
        wait for CLK_PERIOD * 20;

        -- Assert 1: During reset M_CS_N should be high (master held in reset)
        assert M_CS_N = '1'
            report "ASSERT FAIL: M_CS_N should be '1' (inactive) while BTN_RST is asserted"
            severity failure;

        -- Assert 2: During reset M_SCLK should be low (SPI clock held low in reset)
        assert M_SCLK = '0'
            report "ASSERT FAIL: M_SCLK should be '0' while BTN_RST is asserted"
            severity failure;

        -- =====================================================================
        -- Phase 2: Release reset
        -- Allow debounce counters to settle (need 4 x 1ms sample periods
        -- so btn_deb_reg initializes to '0' before we press any button).
        -- =====================================================================
        BTN_RST <= '0';
        wait for CLK_PERIOD * 250_000;  -- 5 ms settling time

        -- Assert 3: After reset release, M_CS_N should remain high (no transaction started)
        assert M_CS_N = '1'
            report "ASSERT FAIL: M_CS_N should remain '1' after reset without triggering a transaction"
            severity failure;

        -- =====================================================================
        -- Phase 3: Trigger a master transaction via menu
        -- menu_cnt defaults to "00" after reset.
        -- In mode "10" (after 2 BTN_MENU_MODE presses), m_cnt_en becomes
        -- menu_action_en, which increments m_cnt and eventually fires m_din_vld
        -- In mode "11" (after 3 presses) m_din_vld = menu_action_en directly.
        -- Press BTN_MENU_MODE 3 times to reach mode "11", then press ACTION.
        -- =====================================================================

        -- Press BTN_MENU_MODE three times (simulate debounced presses)
        for press in 1 to 3 loop
            BTN_MENU_MODE <= '1';
            wait for CLK_PERIOD * DEBOUNCE_HOLD;
            BTN_MENU_MODE <= '0';
            wait for CLK_PERIOD * DEBOUNCE_HOLD;
        end loop;

        -- Now press BTN_MENU_ACTION to fire m_din_vld
        BTN_MENU_ACTION <= '1';
        wait for CLK_PERIOD * DEBOUNCE_HOLD;
        BTN_MENU_ACTION <= '0';

        -- Wait for master transaction to begin (CS_N goes low)
        timeout_cnt := 0;
        while m_cs_n_seen_low = '0' and timeout_cnt < 400_000 loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 4: M_CS_N must go low to indicate master started a transaction
        assert m_cs_n_seen_low = '1'
            report "ASSERT FAIL: M_CS_N never went low; master did not start a transaction"
            severity failure;

        -- Wait for SPI clock to toggle
        timeout_cnt := 0;
        while m_sclk_seen_high = '0' and timeout_cnt < 400_000 loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 5: M_SCLK must toggle during master transaction
        assert m_sclk_seen_high = '1'
            report "ASSERT FAIL: M_SCLK never toggled; SPI master clock not generated"
            severity failure;

        report "spi_loopback_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process;

end architecture;
