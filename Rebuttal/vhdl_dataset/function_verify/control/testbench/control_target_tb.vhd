-- Testbench for control
-- Target: The DUT has a bug where S_DATA transitions to S_START instead of
-- S_PROCESS_DATA, so the data processing logic (when others branch) is never
-- reached. All outputs remain at their initial/reset values.
--
-- Protocol (from DUT source):
--   DATA_START = 0xAA
--   Frame: DATA_START | length_byte | id_byte | data[0..length-1]
--
-- Tests:
--   1. Reset: pa_off='1', adf_ce='1' (initial values).
--   2. After reset release: ready='1'.
--   3. Send full packet, verify ready='1' returns (FSM consumed the packet).
--   4. Verify outputs remain at initial values (processing is unreachable).
--   5. Reset functionality: assert rst, release, verify ready='1' again.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_target_tb is
end control_target_tb;

architecture sim of control_target_tb is

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal ready      : std_logic;
    signal data_valid : std_logic := '0';
    signal led        : std_logic;
    signal pa_off     : std_logic;
    signal mix_enbl   : std_logic;
    signal adf_ce     : std_logic;
    signal adc_shdn   : std_logic_vector(1 downto 0);
    signal adc_oe     : std_logic_vector(1 downto 0);
    signal adf_writedata : std_logic_vector(31 downto 0);
    signal adf_write     : std_logic;
    signal spi_busy      : std_logic := '0';
    signal write_timer   : std_logic;
    signal write_delay   : std_logic;
    signal write_decimate : std_logic;
    signal write_pa_off  : std_logic;
    signal timer_data    : std_logic_vector(31 downto 0);
    signal enable_a      : std_logic;
    signal enable_b      : std_logic;
    signal enable_downsampler : std_logic;
    signal clear_buffer  : std_logic;

    constant CLK_PERIOD  : time := 10 ns;
    constant DATA_START  : std_logic_vector(7 downto 0) := x"AA";

    -- Send one byte via data_in / data_valid handshake
    procedure send_byte(
        signal clk_s       : in  std_logic;
        signal data_in_s   : out std_logic_vector(7 downto 0);
        signal dv_s        : out std_logic;
        constant byte_val  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        wait until rising_edge(clk_s);
        data_in_s <= byte_val;
        dv_s      <= '1';
        wait until rising_edge(clk_s);
        dv_s      <= '0';
    end procedure;

begin

    -- Clock: 10 ns period
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.control
        port map (
            clk               => clk,
            rst               => rst,
            data_in           => data_in,
            ready             => ready,
            data_valid        => data_valid,
            led               => led,
            pa_off            => pa_off,
            mix_enbl          => mix_enbl,
            adf_ce            => adf_ce,
            adc_shdn          => adc_shdn,
            adc_oe            => adc_oe,
            adf_writedata     => adf_writedata,
            adf_write         => adf_write,
            spi_busy          => spi_busy,
            write_timer       => write_timer,
            write_delay       => write_delay,
            write_decimate    => write_decimate,
            write_pa_off      => write_pa_off,
            timer_data        => timer_data,
            enable_a          => enable_a,
            enable_b          => enable_b,
            enable_downsampler => enable_downsampler,
            clear_buffer      => clear_buffer
        );

    stim : process
    begin
        -- ----------------------------------------------------------------
        -- Test 1: During reset, check initial output state.
        -- pa_off_int initialised to '1', adf_ce_int to '1'.
        -- ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD * 3;

        assert pa_off = '1'
            report "FAIL: pa_off initial value should be '1' (pa_off_int default)"
            severity error;

        assert adf_ce = '1'
            report "FAIL: adf_ce initial value should be '1' (adf_ce_int default)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: Release reset. After first rising edge with rst='0',
        -- ready should be '1' (set at top of rising_edge branch).
        -- ----------------------------------------------------------------
        rst <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert ready = '1'
            report "FAIL: ready should be '1' in S_START state"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Send a valid packet [0xAA, len=1, id=1, data=0x04].
        -- The FSM should consume all bytes (S_START -> S_LENGTH -> S_ID
        -- -> S_DATA -> S_START due to the bug). After the packet is
        -- consumed the FSM returns to S_START, so ready='1' again.
        -- ----------------------------------------------------------------
        send_byte(clk, data_in, data_valid, DATA_START);  -- START byte
        send_byte(clk, data_in, data_valid, x"01");       -- LENGTH = 1
        send_byte(clk, data_in, data_valid, x"01");       -- ID = 1
        send_byte(clk, data_in, data_valid, x"04");       -- DATA = 0x04

        -- Give the FSM one extra cycle to settle back in S_START
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Verify the FSM returned to S_START (ready='1' indicates this)
        assert ready = '1'
            report "FAIL: ready should be '1' after packet is consumed (FSM back in S_START)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: Verify outputs remain at initial values because the
        -- S_PROCESS_DATA state is never reached (bug: S_DATA goes to
        -- S_START instead of S_PROCESS_DATA).
        -- mix_enbl_int initial = '0', so mix_enbl stays '0'.
        -- pa_off_int initial = '1', adf_ce_int initial = '1'.
        -- led_int initial = '0'.
        -- ----------------------------------------------------------------
        assert mix_enbl = '0'
            report "FAIL: mix_enbl should remain '0' (processing logic is unreachable)"
            severity error;

        assert pa_off = '1'
            report "FAIL: pa_off should remain '1' (processing logic is unreachable)"
            severity error;

        assert adf_ce = '1'
            report "FAIL: adf_ce should remain '1' (processing logic is unreachable)"
            severity error;

        assert led = '0'
            report "FAIL: led should remain '0' (processing logic is unreachable)"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: Reset functionality. Assert rst, release, verify
        -- ready='1' returns on the first active clock edge.
        -- ----------------------------------------------------------------
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert ready = '1'
            report "FAIL: ready should be '1' immediately after second reset"
            severity error;

        -- Outputs should still be at initial values after reset
        assert mix_enbl = '0'
            report "FAIL: mix_enbl should be '0' after reset"
            severity error;

        assert pa_off = '1'
            report "FAIL: pa_off should be '1' after reset"
            severity error;

        report "All assertions passed.";
        wait;
    end process;

end sim;
