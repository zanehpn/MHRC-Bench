--------------------------------------------------------------------------------
-- Testbench for SPI_MASTER
-- Target: second_edge_en <= '0'; rx_data_vld <= '0'; -- signal clears in reset/idle
-- Tests reset behaviour, loopback (MISO = MOSI), and DOUT_VLD + DOUT correctness.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master_target_tb is
end entity;

architecture tb of spi_master_target_tb is

    -- Generics matching the test scenario
    constant CLK_FREQ    : natural := 50_000_000;
    constant SCLK_FREQ   : natural := 5_000_000;
    constant WORD_SIZE   : natural := 8;
    constant SLAVE_COUNT : natural := 1;

    constant CLK_PERIOD  : time := 20 ns;   -- 50 MHz

    -- Derived: DIVIDER_VALUE = (50e6/5e6)/2 = 5; each half-SCLK period = 5 system clocks
    -- Full SPI transaction = 8 bits * 2 edges * 5 clocks + end/gap states
    -- Conservatively wait 200 system clock cycles for completion
    constant TRANSACTION_TIMEOUT : natural := 300;

    -- DUT ports
    signal CLK      : std_logic := '0';
    signal RST      : std_logic := '0';
    signal SCLK     : std_logic;
    signal CS_N     : std_logic_vector(SLAVE_COUNT-1 downto 0);
    signal MOSI     : std_logic;
    signal MISO     : std_logic := '0';
    signal DIN      : std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');
    -- DIN_ADDR: when SLAVE_COUNT=1, width is log2(1)=0 bits (null range); omit from port map
    -- signal DIN_ADDR : std_logic_vector(-1 downto 0); -- null range, cannot declare
    signal DIN_LAST : std_logic := '1';
    signal DIN_VLD  : std_logic := '0';
    signal DIN_RDY  : std_logic;
    signal DOUT     : std_logic_vector(WORD_SIZE-1 downto 0);
    signal DOUT_VLD : std_logic;

    -- Loopback: MISO follows MOSI with one-clock delay to model a real SPI slave
    signal mosi_dly : std_logic := '0';

    signal dout_vld_seen : std_logic := '0';
    signal dout_captured : std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');

begin

    -- -------------------------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------------------------
    dut : entity work.SPI_MASTER
        generic map (
            CLK_FREQ    => CLK_FREQ,
            SCLK_FREQ   => SCLK_FREQ,
            WORD_SIZE   => WORD_SIZE,
            SLAVE_COUNT => SLAVE_COUNT
        )
        port map (
            CLK      => CLK,
            RST      => RST,
            SCLK     => SCLK,
            CS_N     => CS_N,
            MOSI     => MOSI,
            MISO     => MISO,
            DIN      => DIN,
            DIN_ADDR => (others => '0'),  -- SLAVE_COUNT=1: null-range, open not allowed; use empty literal
            DIN_LAST => DIN_LAST,
            DIN_VLD  => DIN_VLD,
            DIN_RDY  => DIN_RDY,
            DOUT     => DOUT,
            DOUT_VLD => DOUT_VLD
        );

    -- -------------------------------------------------------------------------
    -- System Clock
    -- -------------------------------------------------------------------------
    clk_gen : process
    begin
        CLK <= '0'; wait for CLK_PERIOD / 2;
        CLK <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- -------------------------------------------------------------------------
    -- MISO Loopback: delayed MOSI -> MISO (model simple slave echo)
    -- One CLK delay to ensure proper setup/hold with respect to SCLK
    -- -------------------------------------------------------------------------
    loopback : process (CLK)
    begin
        if rising_edge(CLK) then
            mosi_dly <= MOSI;
        end if;
    end process;
    MISO <= mosi_dly;

    -- -------------------------------------------------------------------------
    -- Monitor: capture DOUT when DOUT_VLD pulses
    -- -------------------------------------------------------------------------
    monitor : process (CLK)
    begin
        if rising_edge(CLK) then
            if DOUT_VLD = '1' then
                dout_vld_seen <= '1';
                dout_captured <= DOUT;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
        constant TEST_DATA : std_logic_vector(WORD_SIZE-1 downto 0) := x"AB";
        variable timeout_cnt : natural := 0;
    begin
        -- =====================================================================
        -- Phase 1: Apply reset
        -- =====================================================================
        RST     <= '1';
        DIN_VLD <= '0';
        DIN     <= (others => '0');
        wait for CLK_PERIOD * 10;
        RST <= '0';
        wait for CLK_PERIOD * 5;

        -- Assert 1: After reset, DIN_RDY must be '1' (master in idle state)
        assert DIN_RDY = '1'
            report "ASSERT FAIL: DIN_RDY should be '1' after reset (master not ready)"
            severity failure;

        -- Assert 2: After reset, CS_N should be deasserted (high)
        assert CS_N(0) = '1'
            report "ASSERT FAIL: CS_N(0) should be '1' (inactive) after reset"
            severity failure;

        -- =====================================================================
        -- Phase 2: Present input data and start transaction
        -- =====================================================================
        DIN     <= TEST_DATA;
        DIN_LAST <= '1';     -- deassert CS after this word
        DIN_VLD <= '1';
        wait for CLK_PERIOD;
        DIN_VLD <= '0';

        -- =====================================================================
        -- Phase 3: Wait for DOUT_VLD to pulse (transaction complete)
        -- =====================================================================
        timeout_cnt := 0;
        while dout_vld_seen = '0' and timeout_cnt < TRANSACTION_TIMEOUT loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 3: DOUT_VLD must have pulsed within the timeout
        assert dout_vld_seen = '1'
            report "ASSERT FAIL: DOUT_VLD did not pulse within " &
                   integer'image(TRANSACTION_TIMEOUT) & " clock cycles"
            severity failure;

        -- Assert 4: DOUT must equal the looped-back test data (0xAB)
        -- In loopback mode (MISO = delayed MOSI), the master samples its own
        -- transmitted bits, so DOUT == DIN.
        assert dout_captured = TEST_DATA
            report "ASSERT FAIL: DOUT mismatch in loopback. Expected 0xAB, got 0x" &
                   to_hstring(dout_captured)
            severity failure;

        -- =====================================================================
        -- Phase 4: After transaction, master should return to idle
        -- =====================================================================
        wait for CLK_PERIOD * 20;
        assert DIN_RDY = '1'
            report "ASSERT FAIL: DIN_RDY should be '1' after transaction completes"
            severity failure;

        report "spi_master_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process;

end architecture;
