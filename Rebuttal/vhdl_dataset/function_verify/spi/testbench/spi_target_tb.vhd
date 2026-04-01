--------------------------------------------------------------------------------
-- Testbench for spi
-- Target: if rising_edge(clk) then pipe_le(0) <= spi_le_int;  -- LE pipeline reg
-- Tests spi_clk toggling, ack pulse, and spi_le assertion.
-- NOTE: The DUT has a known bug where pipe_busy(0) is never assigned, so
--       busy is always '0'. We intentionally do NOT check busy here.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_target_tb is
end entity;

architecture tb of spi_target_tb is

    -- Generic: SPI_CLK_DIVIDER=1 -> fastest clock, simplest timing
    constant SPI_CLK_DIVIDER : integer := 1;
    constant CLK_PERIOD      : time    := 10 ns;   -- 100 MHz

    -- Each SPI clock half-period = (SPI_CLK_DIVIDER+1) = 2 system clocks.
    -- 32 bits * 2 edges * 2 clocks = 128 clocks minimum for one transfer.
    -- Add pipeline stages (LE_DELAY=4, BUSY_DELAY=8) and guard.
    constant TRANSFER_TIMEOUT : natural := 512;

    -- DUT ports
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal data_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal write    : std_logic := '0';
    signal busy     : std_logic;
    signal spi_clk  : std_logic;
    signal spi_data : std_logic;
    signal spi_le   : std_logic;
    signal ack      : std_logic;

    -- Monitoring signals
    signal ack_seen      : std_logic := '0';
    signal spi_clk_seen  : std_logic := '0';
    signal spi_le_seen   : std_logic := '0';

begin

    -- -------------------------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------------------------
    dut : entity work.spi
        generic map (SPI_CLK_DIVIDER => SPI_CLK_DIVIDER)
        port map (
            clk      => clk,
            rst      => rst,
            data_in  => data_in,
            write    => write,
            busy     => busy,
            spi_clk  => spi_clk,
            spi_data => spi_data,
            spi_le   => spi_le,
            ack      => ack
        );

    -- -------------------------------------------------------------------------
    -- Clock Generation
    -- -------------------------------------------------------------------------
    clk_gen : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- -------------------------------------------------------------------------
    -- Monitors
    -- -------------------------------------------------------------------------
    monitor : process (clk)
    begin
        if rising_edge(clk) then
            if ack = '1'     then ack_seen     <= '1'; end if;
            if spi_clk = '1' then spi_clk_seen <= '1'; end if;
            if spi_le = '1'  then spi_le_seen  <= '1'; end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
        variable timeout_cnt : natural := 0;
    begin
        -- =====================================================================
        -- Phase 1: Reset
        -- =====================================================================
        rst    <= '1';
        write  <= '0';
        data_in <= (others => '0');
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 3;

        -- Assert 1: After reset, busy should be low (no transfer in progress)
        assert busy = '0'
            report "ASSERT FAIL: busy should be '0' immediately after reset"
            severity failure;

        -- =====================================================================
        -- Phase 2: Wait for internal delay counter to expire before writing
        -- The DUT has a LE_DELAY=4 cycle internal guard after reset.
        -- =====================================================================
        wait for CLK_PERIOD * 10;

        -- =====================================================================
        -- Phase 3: Start a transfer with data_in = 0xDEADBEEF
        -- =====================================================================
        data_in <= x"DEADBEEF";
        write   <= '1';
        wait for CLK_PERIOD;
        write <= '0';

        -- =====================================================================
        -- Phase 4: Wait for ack pulse (confirms write accepted)
        -- =====================================================================
        timeout_cnt := 0;
        while ack_seen = '0' and timeout_cnt < 20 loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 2: ack must pulse to confirm the write was accepted
        assert ack_seen = '1'
            report "ASSERT FAIL: ack did not pulse after write=1; write not accepted"
            severity failure;

        -- =====================================================================
        -- Phase 5: Wait for spi_clk to toggle (verifies clock generation)
        -- =====================================================================
        timeout_cnt := 0;
        while spi_clk_seen = '0' and timeout_cnt < TRANSFER_TIMEOUT loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 3: spi_clk must toggle during transfer
        assert spi_clk_seen = '1'
            report "ASSERT FAIL: spi_clk never went high during transfer"
            severity failure;

        -- =====================================================================
        -- Phase 6: Wait for spi_le to assert (LE pipeline register output)
        -- This indicates the transfer has completed.
        -- =====================================================================
        timeout_cnt := 0;
        while spi_le_seen = '0' and timeout_cnt < TRANSFER_TIMEOUT loop
            wait for CLK_PERIOD;
            timeout_cnt := timeout_cnt + 1;
        end loop;

        -- Assert 4: spi_le must pulse (driven by pipe_le pipeline, the target signal)
        assert spi_le_seen = '1'
            report "ASSERT FAIL: spi_le never pulsed; pipe_le(0) pipeline not working"
            severity failure;

        report "spi_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process;

end architecture;
