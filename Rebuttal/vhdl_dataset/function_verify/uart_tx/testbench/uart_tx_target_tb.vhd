--------------------------------------------------------------------------------
-- Testbench for UART_TX
-- Target behavior (databits state): tx_ready='0', data output selected from
-- shift register (tx_data_out_sel="10"), bit_count enabled,
-- clk_div NOT cleared.
--
-- Test plan:
--   1. Assert RST, release.
--   2. Check DIN_RDY='1' at idle.
--   3. Present DIN=0xA5, DIN_VLD='1'.
--   4. UART_CLK_EN is held permanently high so that the internal UART_CLK_DIV
--      (DIV_MAX_VAL = CLK_DIV_VAL = 16) counts every system clock cycle and
--      produces tx_clk_en once every 16 system clocks (one baud period).
--   5. Check DIN_RDY goes '0' when transmission starts (txsync / startbit).
--   6. Wait for a complete 10-bit frame (start + 8 data + stop, no parity).
--      With parity="none" the FSM still traverses the paritybit state for one
--      baud period, so the frame is effectively 11 baud periods long (txsync +
--      start + 8 data + parity + stop).
--   7. Check DIN_RDY returns '1'.
--
-- Note: UART_TX internally instantiates UART_CLK_DIV and UART_PARITY which
--       must be compiled in the same simulation library (work).
--
-- DUT: uart_tx_original.vhd  (entity UART_TX)
--      CLK_DIV_VAL=16, PARITY_BIT="none"
--
-- Key insight: UART_CLK_EN is an *oversampling* clock enable that feeds the
-- internal UART_CLK_DIV.  The internal divider further divides by CLK_DIV_VAL
-- to produce the actual baud-rate tick (tx_clk_en).  Therefore the testbench
-- must drive UART_CLK_EN='1' on every clock cycle so that the internal
-- divider counts at the system clock rate.  One baud period then equals
-- CLK_DIV_VAL (16) system clock cycles.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_target_tb is
end entity uart_tx_target_tb;

architecture tb of uart_tx_target_tb is

    constant CLK_PERIOD   : time    := 10 ns;
    constant CLK_DIV_VAL  : integer := 16;

    -- One baud period in system clock cycles = CLK_DIV_VAL
    -- (because UART_CLK_EN='1' every cycle and internal divider divides by
    -- CLK_DIV_VAL).
    constant BAUD_PERIOD  : integer := CLK_DIV_VAL;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal uart_clk_en : std_logic := '1';  -- held high permanently
    signal uart_txd    : std_logic;
    signal din         : std_logic_vector(7 downto 0) := (others => '0');
    signal din_vld     : std_logic := '0';
    signal din_rdy     : std_logic;

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
    -- UART_CLK_EN: held permanently at '1'.
    -- The internal UART_CLK_DIV inside UART_TX counts UART_CLK_EN='1' events
    -- (i.e. every rising_edge of CLK) and produces the baud-rate tick
    -- (tx_clk_en) once every CLK_DIV_VAL system clocks.
    ----------------------------------------------------------------------------
    uart_clk_en <= '1';

    ----------------------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------------------
    dut : entity work.UART_TX
        generic map (
            CLK_DIV_VAL => CLK_DIV_VAL,
            PARITY_BIT  => "none"
        )
        port map (
            CLK         => clk,
            RST         => rst,
            UART_CLK_EN => uart_clk_en,
            UART_TXD    => uart_txd,
            DIN         => din,
            DIN_VLD     => din_vld,
            DIN_RDY     => din_rdy
        );

    ----------------------------------------------------------------------------
    -- Stimulus and checking
    ----------------------------------------------------------------------------
    stim_proc : process

        -- procedure: wait for rising edge of CLK
        procedure clk_wait(n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- procedure: wait for DIN_RDY to reach expected value, timeout after
        -- max_cycles system clocks
        procedure wait_din_rdy(expected : std_logic; max_cycles : integer) is
        begin
            for i in 1 to max_cycles loop
                if din_rdy = expected then
                    return;
                end if;
                wait until rising_edge(clk);
            end loop;
        end procedure;

        variable tx_bits : std_logic_vector(9 downto 0); -- start+data+stop
        variable received_data : std_logic_vector(7 downto 0);

    begin

        -----------------------------------------------------------------------
        -- Reset phase
        -----------------------------------------------------------------------
        rst     <= '1';
        din_vld <= '0';
        din     <= x"00";
        clk_wait(4);
        rst     <= '0';

        -- Allow a few clock cycles for DIN_RDY to settle
        clk_wait(4);

        -----------------------------------------------------------------------
        -- Check 1: DIN_RDY should be '1' (idle) after reset
        -----------------------------------------------------------------------
        assert din_rdy = '1'
            report "TEST FAILED: DIN_RDY should be '1' at idle after reset"
            severity FAILURE;
        report "TEST PASSED: DIN_RDY is '1' at idle";

        -----------------------------------------------------------------------
        -- Present data to transmit: DIN = 0xA5 = 1010_0101
        -----------------------------------------------------------------------
        din     <= x"A5";
        din_vld <= '1';

        -- Wait for the DUT to accept and start transmission
        -- (DIN_RDY should go '0')
        wait_din_rdy('0', BAUD_PERIOD * 4);

        din_vld <= '0';

        -----------------------------------------------------------------------
        -- Check 2: DIN_RDY goes '0' when transmission begins
        -----------------------------------------------------------------------
        assert din_rdy = '0'
            report "TEST FAILED: DIN_RDY should be '0' once transmission starts"
            severity FAILURE;
        report "TEST PASSED: DIN_RDY is '0' during transmission";

        -----------------------------------------------------------------------
        -- Check 3: UART_TXD should output start bit '0' at start of frame.
        -- After txsync (a few cycles) + pipeline delay, TXD will be '0'.
        -- Wait for TXD to drop to '0' (start bit begins).
        -----------------------------------------------------------------------
        for i in 1 to BAUD_PERIOD * 2 loop
            wait until rising_edge(clk);
            exit when uart_txd = '0';
        end loop;

        assert uart_txd = '0'
            report "TEST FAILED: UART_TXD should be '0' during start bit"
            severity FAILURE;
        report "TEST PASSED: UART_TXD is '0' during start bit";

        -----------------------------------------------------------------------
        -- Wait for full UART frame to complete.
        -- Frame with parity="none": txsync(1) + start(1) + 8 data +
        --   stop(1) = 11 baud periods total.  Wait generously.
        -----------------------------------------------------------------------
        clk_wait(BAUD_PERIOD * 16);

        -----------------------------------------------------------------------
        -- Check 4: DIN_RDY should return '1' after transmission completes
        -----------------------------------------------------------------------
        wait_din_rdy('1', BAUD_PERIOD * 4);

        assert din_rdy = '1'
            report "TEST FAILED: DIN_RDY should return '1' after transmission"
            severity FAILURE;
        report "TEST PASSED: DIN_RDY returns '1' after full transmission";

        -----------------------------------------------------------------------
        -- Check 5: UART_TXD should be '1' (stop/idle) after transmission
        -----------------------------------------------------------------------
        assert uart_txd = '1'
            report "TEST FAILED: UART_TXD should be '1' (stop/idle) after frame"
            severity FAILURE;
        report "TEST PASSED: UART_TXD is '1' at idle after frame";

        -----------------------------------------------------------------------
        -- Second transmission: DIN = 0x00
        -- Verify DIN_RDY cycle repeats correctly
        -----------------------------------------------------------------------
        din     <= x"00";
        din_vld <= '1';
        wait_din_rdy('0', BAUD_PERIOD * 4);
        din_vld <= '0';

        assert din_rdy = '0'
            report "TEST FAILED: DIN_RDY should be '0' for second transmission"
            severity FAILURE;
        report "TEST PASSED: DIN_RDY is '0' for second transmission";

        clk_wait(BAUD_PERIOD * 14);
        wait_din_rdy('1', BAUD_PERIOD * 4);

        assert din_rdy = '1'
            report "TEST FAILED: DIN_RDY should return '1' after second transmission"
            severity FAILURE;
        report "TEST PASSED: DIN_RDY returns '1' after second transmission";

        report "ALL UART_TX TESTS PASSED";

        clk_en <= false;
        wait;
    end process stim_proc;

end architecture tb;
