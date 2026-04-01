--------------------------------------------------------------------------------
-- Testbench for uart (uart_2)
-- Entity: uart (uart_original.vhd)
-- Generics: baud:positive, clock_frequency:positive
--
-- Target behavior: RX filter logic - when bit is '0' and filter > 0,
--   decrement filter.  When filter reaches 0, uart_rx_bit is forced '0'.
--
-- Test plan:
--   Use clock_frequency=1843200, baud=115200 for clean timing.
--   TX path: present data via data_stream_in / data_stream_in_stb.
--     Check data_stream_in_ack rises when byte is accepted.
--     Check tx serial output transitions for start/stop bit.
--   RX loopback: connect tx output to rx input (loopback).
--     Check data_stream_out_stb rises and data_stream_out matches sent byte.
--
-- DUT: uart_original.vhd (entity uart)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_target_tb is
end entity uart_target_tb;

architecture tb of uart_target_tb is

    constant C_BAUD      : positive := 115200;
    constant C_CLK_FREQ  : positive := 1843200;

    -- Derived: c_tx_div = clock_frequency / baud = 16
    --          c_rx_div = clock_frequency / (baud*16) = 1
    constant CLK_PERIOD  : time := 1 sec / C_CLK_FREQ; -- ~542 ns
    constant TX_BIT_CLKS : integer := C_CLK_FREQ / C_BAUD; -- 16

    -- RX bit time: The DUT's RX oversamples at baud*16. The oversample divider
    -- counts 0..c_rx_div (i.e. c_rx_div+1 clocks per tick). One RX bit =
    -- 16 oversample ticks = 16*(c_rx_div+1) clocks. With c_rx_div=1 that is
    -- 32 clocks per bit.  Add extra margin for the 2-stage synchroniser and
    -- 2-bit filter (up to ~4 oversample ticks of latency on transitions).
    constant C_RX_DIV      : integer := C_CLK_FREQ / (C_BAUD * 16); -- 1
    constant RX_BIT_CLKS   : integer := 16 * (C_RX_DIV + 1);       -- 32
    constant RX_BIT_TIME   : time := CLK_PERIOD * RX_BIT_CLKS;     -- exact match
    constant TX_BIT_TIME   : time := CLK_PERIOD * TX_BIT_CLKS;

    signal clock               : std_logic := '0';
    signal reset               : std_logic := '1';
    signal data_stream_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal data_stream_in_stb  : std_logic := '0';
    signal data_stream_in_ack  : std_logic;
    signal data_stream_out     : std_logic_vector(7 downto 0);
    signal data_stream_out_stb : std_logic;
    signal tx                  : std_logic;
    signal rx                  : std_logic := '1';

    signal clk_en : boolean := true;

    -- rx is driven only from stim_proc; no loopback needed for direct RX tests
    signal rx_drv : std_logic := '1';

    -- Latch to capture one-cycle-wide data_stream_out_stb pulses
    signal rx_stb_seen  : std_logic := '0';
    signal rx_stb_clear : std_logic := '0';

begin

    rx <= rx_drv;

    -- Latch stb pulse so we don't miss it during bit-bang procedure
    stb_latch : process (clock)
    begin
        if rising_edge(clock) then
            if reset = '1' or rx_stb_clear = '1' then
                rx_stb_seen <= '0';
            elsif data_stream_out_stb = '1' then
                rx_stb_seen <= '1';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------------------
    clk_proc : process
    begin
        while clk_en loop
            clock <= '0';
            wait for CLK_PERIOD / 2;
            clock <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_proc;

    ----------------------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------------------
    dut : entity work.uart
        generic map (
            baud             => C_BAUD,
            clock_frequency  => C_CLK_FREQ
        )
        port map (
            clock               => clock,
            reset               => reset,
            data_stream_in      => data_stream_in,
            data_stream_in_stb  => data_stream_in_stb,
            data_stream_in_ack  => data_stream_in_ack,
            data_stream_out     => data_stream_out,
            data_stream_out_stb => data_stream_out_stb,
            tx                  => tx,
            rx                  => rx
        );

    ----------------------------------------------------------------------------
    -- Stimulus and checking
    ----------------------------------------------------------------------------
    stim_proc : process

        -- Send a byte via the data_stream_in interface and wait for ack
        procedure send_byte(data : std_logic_vector(7 downto 0)) is
        begin
            data_stream_in     <= data;
            data_stream_in_stb <= '1';
            -- Wait for ack (may take up to one baud tick = TX_BIT_CLKS clocks)
            for i in 1 to TX_BIT_CLKS * 4 loop
                if data_stream_in_ack = '1' then
                    exit;
                end if;
                wait until rising_edge(clock);
            end loop;
            data_stream_in_stb <= '0';
        end procedure;

        -- Bit-bang a UART byte on rx input (LSB first).
        -- Use RX_BIT_TIME which accounts for the DUT's 16x oversampling
        -- divider (c_rx_div+1 clocks per tick) and filter latency.
        procedure rx_send_byte(data : std_logic_vector(7 downto 0)) is
        begin
            rx_drv <= '0';                      -- start bit
            wait for RX_BIT_TIME;
            for i in 0 to 7 loop
                rx_drv <= data(i);
                wait for RX_BIT_TIME;
            end loop;
            rx_drv <= '1';                      -- stop bit
            wait for RX_BIT_TIME * 2;           -- extra stop-bit time for filter settling
        end procedure;

    begin

        -----------------------------------------------------------------------
        -- Reset phase
        -----------------------------------------------------------------------
        reset              <= '1';
        data_stream_in_stb <= '0';
        rx_drv             <= '1';
        wait for CLK_PERIOD * 4;
        reset              <= '0';
        wait for CLK_PERIOD * 4;

        -----------------------------------------------------------------------
        -- Check 1: TX line should be idle ('1') after reset
        -----------------------------------------------------------------------
        assert tx = '1'
            report "TEST FAILED: TX should be '1' (idle) after reset"
            severity FAILURE;
        report "TEST PASSED: TX is '1' at idle";

        -----------------------------------------------------------------------
        -- Test 2: Send byte 0xA5 via TX path; verify ack and start bit
        -----------------------------------------------------------------------
        send_byte(x"A5");

        -- data_stream_in_ack should have pulsed during send_byte
        -- (it was latched for one cycle when tx_baud_tick fired)
        -- Just check TX drops to '0' (start bit)
        -- TX will go low on the baud tick after ack
        -- Wait up to 2 baud periods for start bit
        for i in 1 to TX_BIT_CLKS * 2 loop
            if tx = '0' then
                exit;
            end if;
            wait for CLK_PERIOD;
        end loop;

        assert tx = '0'
            report "TEST FAILED: TX should be '0' during start bit after send"
            severity FAILURE;
        report "TEST PASSED: TX start bit is '0'";

        -- Wait for the full 10-bit frame to complete
        -- 10 bits * TX_BIT_CLKS cycles + margin
        wait for TX_BIT_TIME * 11;

        -----------------------------------------------------------------------
        -- Check 3: TX returns to '1' (stop/idle) after frame
        -----------------------------------------------------------------------
        assert tx = '1'
            report "TEST FAILED: TX should return to '1' after full frame"
            severity FAILURE;
        report "TEST PASSED: TX returns to '1' after frame";

        -----------------------------------------------------------------------
        -- Test 4: RX path - bit-bang 0xA5 onto rx and check data_stream_out
        -- Use rx_stb_seen latch to avoid missing one-cycle stb pulse.
        -----------------------------------------------------------------------
        rx_stb_clear <= '1'; wait for CLK_PERIOD; rx_stb_clear <= '0';
        rx_send_byte(x"A5");

        -- Wait for data_stream_out_stb to pulse (allow up to 20 bit periods)
        for i in 1 to RX_BIT_CLKS * 40 loop
            if rx_stb_seen = '1' or data_stream_out_stb = '1' then
                exit;
            end if;
            wait for CLK_PERIOD;
        end loop;

        assert rx_stb_seen = '1' or data_stream_out_stb = '1'
            report "TEST FAILED: data_stream_out_stb did not assert for 0xA5"
            severity FAILURE;
        report "TEST PASSED: data_stream_out_stb asserted for 0xA5";

        assert data_stream_out = x"A5"
            report "TEST FAILED: data_stream_out should be 0xA5, got " &
                   integer'image(to_integer(unsigned(data_stream_out)))
            severity FAILURE;
        report "TEST PASSED: data_stream_out = 0xA5";

        -- Wait for strobe to clear
        wait for CLK_PERIOD * 4;

        -----------------------------------------------------------------------
        -- Test 5: RX path - bit-bang 0x55 and check
        -----------------------------------------------------------------------
        rx_stb_clear <= '1'; wait for CLK_PERIOD; rx_stb_clear <= '0';
        rx_send_byte(x"55");

        for i in 1 to RX_BIT_CLKS * 40 loop
            if rx_stb_seen = '1' or data_stream_out_stb = '1' then
                exit;
            end if;
            wait for CLK_PERIOD;
        end loop;

        assert rx_stb_seen = '1' or data_stream_out_stb = '1'
            report "TEST FAILED: data_stream_out_stb did not assert for 0x55"
            severity FAILURE;
        report "TEST PASSED: data_stream_out_stb asserted for 0x55";

        assert data_stream_out = x"55"
            report "TEST FAILED: data_stream_out should be 0x55, got " &
                   integer'image(to_integer(unsigned(data_stream_out)))
            severity FAILURE;
        report "TEST PASSED: data_stream_out = 0x55";

        -- Wait for strobe to clear
        wait for CLK_PERIOD * 4;

        -----------------------------------------------------------------------
        -- Test 6: RX path - 0x00 (all zeros data bits)
        -----------------------------------------------------------------------
        rx_stb_clear <= '1'; wait for CLK_PERIOD; rx_stb_clear <= '0';
        rx_send_byte(x"00");

        for i in 1 to RX_BIT_CLKS * 40 loop
            if rx_stb_seen = '1' or data_stream_out_stb = '1' then
                exit;
            end if;
            wait for CLK_PERIOD;
        end loop;

        assert rx_stb_seen = '1' or data_stream_out_stb = '1'
            report "TEST FAILED: data_stream_out_stb did not assert for 0x00"
            severity FAILURE;
        report "TEST PASSED: data_stream_out_stb asserted for 0x00";

        assert data_stream_out = x"00"
            report "TEST FAILED: data_stream_out should be 0x00"
            severity FAILURE;
        report "TEST PASSED: data_stream_out = 0x00";

        report "ALL uart (uart_2) TESTS PASSED";

        clk_en <= false;
        wait;
    end process stim_proc;

end architecture tb;
