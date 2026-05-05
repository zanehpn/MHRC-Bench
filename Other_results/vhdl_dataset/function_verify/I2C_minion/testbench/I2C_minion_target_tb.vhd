----------------------------------------------------------------------------------
-- Testbench: I2C_minion_target_tb.vhd
-- Entity: I2C_minion
-- Target feature: scl_prev_reg <= scl_internal; sda_prev_reg <= sda_internal;
--   These delayed copies are used for I2C edge detection (rising/falling SCL)
--   and START/STOP condition detection.
--
-- Generics: MINION_ADDR = "1010000" (0x50), USE_INPUT_DEBOUNCING = false
-- Ports:
--   scl              : inout std_logic
--   sda              : inout std_logic
--   clk              : in    std_logic
--   rst              : in    std_logic
--   read_req         : out   std_logic
--   data_to_master   : in    std_logic_vector(7 downto 0)
--   data_valid       : out   std_logic
--   data_from_master : out   std_logic_vector(7 downto 0)
--
-- I2C Timing Notes:
--   System clock: 10 ns period (100 MHz).
--   I2C SCL period: 100 clock cycles (1 us, ~1 MHz I2C for easy testing).
--   For correct edge detection the DUT must sample SCL/SDA at least 2
--   system-clock cycles before each SCL edge so that scl_prev_reg is updated.
--
-- Test sequence:
--   1. Reset, idle bus (SCL=SDA='1').
--   2. Assert reset releases state_reg to idle.
--   3. Generate I2C START (SDA falls while SCL high).
--   4. Clock out 7-bit address 0x50 = "1010000", then write bit '0'.
--   5. Check data_valid pulses after 8 data bits (write transaction byte).
--   6. Generate STOP condition (SDA rises while SCL high).
--   7. Verify state machine returns to idle after stop.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity I2C_minion_target_tb is
end entity I2C_minion_target_tb;

architecture tb of I2C_minion_target_tb is

    constant CLK_PERIOD  : time := 10 ns;   -- 100 MHz system clock
    -- I2C half-bit time in system clocks (50 clocks = 500 ns half-period)
    constant I2C_HALF    : integer := 50;
    constant I2C_QUARTER : integer := 25;

    -- DUT ports
    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal scl              : std_logic;    -- inout - driven via tristate
    signal sda              : std_logic;    -- inout - driven via tristate
    signal read_req         : std_logic;
    signal data_to_master   : std_logic_vector(7 downto 0) := X"A5";
    signal data_valid       : std_logic;
    signal data_from_master : std_logic_vector(7 downto 0);

    -- Master-side drivers (open-drain model: '0' drives low, 'H' releases
    -- to weak pull-up so that std_logic resolution correctly models the
    -- wired-AND bus without a feedback latch).
    signal scl_master : std_logic := 'H';
    signal sda_master : std_logic := 'H';

    -- Observed latch
    signal data_valid_seen : std_logic := '0';

    -- Helpers
    signal read_req_seen : std_logic := '0';

begin

    -- Clock
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Open-drain bus model using std_logic resolution.
    -- The master drives 'H' (weak pull-up) when releasing and '0' when
    -- pulling low.  The DUT drives '0' (ACK) or 'Z' (release) on its
    -- inout ports.  std_logic resolution correctly combines these:
    --   resolved('H', 'Z') = 'H'  (idle / released)
    --   resolved('0', 'Z') = '0'  (master pulls low)
    --   resolved('H', '0') = '0'  (slave pulls low for ACK)
    -- The DUT internally maps any non-'0' value to '1' via:
    --   scl_internal <= '0' when scl_pre_internal = '0' else '1';
    scl <= scl_master;
    sda <= sda_master;

    -- DUT
    dut : entity work.I2C_minion
        generic map (
            MINION_ADDR            => "1010000",  -- 0x50
            USE_INPUT_DEBOUNCING   => false,
            DEBOUNCING_WAIT_CYCLES => 4
        )
        port map (
            scl              => scl,
            sda              => sda,
            clk              => clk,
            rst              => rst,
            read_req         => read_req,
            data_to_master   => data_to_master,
            data_valid       => data_valid,
            data_from_master => data_from_master
        );

    -- Monitor: latch pulses
    mon_proc : process(clk)
    begin
        if rising_edge(clk) then
            if data_valid = '1' then
                data_valid_seen <= '1';
            end if;
            if read_req = '1' then
                read_req_seen <= '1';
            end if;
        end if;
    end process;

    -- Helper procedure: wait N system clock cycles
    -- (implemented inline in stim_proc via wait for N*CLK_PERIOD)

    stim_proc : process

        -- Drive SCL master half-period
        procedure scl_high(cycles : integer := I2C_HALF) is
        begin
            scl_master <= 'H';  -- release = high (pull-up)
            wait for cycles * CLK_PERIOD;
        end procedure;

        procedure scl_low(cycles : integer := I2C_HALF) is
        begin
            scl_master <= '0';
            wait for cycles * CLK_PERIOD;
        end procedure;

        -- Clock one bit onto SDA during SCL cycle
        procedure send_bit(b : std_logic) is
        begin
            if b = '0' then
                sda_master <= '0';
            else
                sda_master <= 'H';
            end if;
            wait for I2C_QUARTER * CLK_PERIOD;  -- setup before SCL rise
            scl_master <= 'H';                   -- SCL high
            wait for I2C_HALF   * CLK_PERIOD;
            scl_master <= '0';                   -- SCL low
            wait for I2C_QUARTER * CLK_PERIOD;
        end procedure;

        variable addr_byte  : std_logic_vector(7 downto 0);
        variable data_byte  : std_logic_vector(7 downto 0);
    begin
        -- -------------------------------------------------------
        -- Initialise: idle bus, hold reset
        -- -------------------------------------------------------
        scl_master <= 'H';   -- SCL high (idle)
        sda_master <= 'H';   -- SDA high (idle)
        rst        <= '1';
        wait for 5 * CLK_PERIOD;

        -- Assert 1: During reset, data_valid must be low
        assert data_valid = '0'
            report "FAIL: data_valid should be '0' during reset"
            severity error;

        -- Release reset
        rst <= '0';
        wait for 5 * CLK_PERIOD;

        -- Assert 2: After reset release, read_req must be low (idle)
        assert read_req = '0'
            report "FAIL: read_req should be '0' after reset release"
            severity error;

        -- -------------------------------------------------------
        -- Phase 1: Generate I2C START condition
        --   SCL=1, SDA transitions 1->0
        -- -------------------------------------------------------
        scl_master <= 'H';   -- SCL high
        sda_master <= 'H';   -- SDA high
        wait for I2C_HALF * CLK_PERIOD;

        sda_master <= '0';   -- SDA falls while SCL high -> START
        wait for I2C_HALF * CLK_PERIOD;

        scl_master <= '0';   -- SCL goes low (end of start)
        wait for I2C_QUARTER * CLK_PERIOD;

        -- Assert 3: After START, data_valid still low (no data transferred yet)
        -- and DUT should have moved to get_address_and_cmd state (not verifiable
        -- from outside, but we confirm no spurious data_valid pulse occurred)
        assert data_valid = '0'
            report "FAIL: data_valid should be '0' immediately after START"
            severity error;

        -- -------------------------------------------------------
        -- Phase 2: Send address byte = 0x50 = "1010000" + write bit '0'
        --   MSB first: 1, 0, 1, 0, 0, 0, 0, then R/W='0'
        -- -------------------------------------------------------
        addr_byte := "10100000";  -- 0x50 address + write

        for i in 7 downto 0 loop
            send_bit(addr_byte(i));
        end loop;

        -- DUT ACK: release SDA so DUT can pull it low for ACK
        sda_master <= 'H';
        wait for I2C_QUARTER * CLK_PERIOD;
        scl_master <= 'H';    -- SCL high for ACK clock
        wait for I2C_HALF   * CLK_PERIOD;
        scl_master <= '0';    -- SCL low
        wait for I2C_QUARTER * CLK_PERIOD;

        -- -------------------------------------------------------
        -- Phase 3: Write one data byte = 0xAB to DUT
        -- -------------------------------------------------------
        data_byte := X"AB";
        for i in 7 downto 0 loop
            send_bit(data_byte(i));
        end loop;

        -- Slave ACK clock: release SDA so DUT can pull low for ACK
        sda_master <= 'H';
        wait for I2C_QUARTER * CLK_PERIOD;
        scl_master <= 'H';
        wait for I2C_HALF   * CLK_PERIOD;
        scl_master <= '0';
        wait for I2C_QUARTER * CLK_PERIOD;

        -- Assert 4: data_valid should have pulsed after the 8th data bit SCL rise
        assert data_valid_seen = '1'
            report "FAIL: data_valid never pulsed after complete write byte"
            severity error;

        -- Assert 5: data_from_master should capture the byte we sent
        assert data_from_master = data_byte
            report "FAIL: data_from_master=" & to_hstring(data_from_master) &
                   " expected=" & to_hstring(data_byte)
            severity error;

        -- -------------------------------------------------------
        -- Phase 4: Generate STOP condition
        --   SCL=1, SDA transitions 0->1
        -- -------------------------------------------------------
        sda_master <= '0';   -- SDA low
        wait for I2C_QUARTER * CLK_PERIOD;
        scl_master <= 'H';   -- SCL rises
        wait for I2C_HALF   * CLK_PERIOD;
        sda_master <= 'H';   -- SDA rises while SCL high -> STOP
        wait for I2C_HALF   * CLK_PERIOD;

        -- Give the DUT a few clocks to process STOP
        wait for 5 * CLK_PERIOD;

        -- Assert 6: After STOP, data_valid should be low again (pulse cleared)
        assert data_valid = '0'
            report "FAIL: data_valid should be '0' after STOP condition"
            severity error;

        -- Assert 7: read_req should remain '0' (this was a write transaction)
        assert read_req = '0'
            report "FAIL: read_req should be '0' for a write transaction"
            severity error;

        report "All tests done.";
        wait;
    end process;

end architecture tb;
