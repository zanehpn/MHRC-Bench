--------------------------------------------------------------------------------
-- Testbench for UART_PARITY
-- Tests odd parity generation (TARGET behavior), mark parity, and space parity.
-- DUT: uart_parity_original.vhd (entity UART_PARITY)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_parity_target_tb is
end entity uart_parity_target_tb;

architecture tb of uart_parity_target_tb is

    ----------------------------------------------------------------------------
    -- DUT signals for ODD parity instance (DATA_WIDTH=8, PARITY_TYPE="odd")
    ----------------------------------------------------------------------------
    signal data_in_odd    : std_logic_vector(7 downto 0) := (others => '0');
    signal parity_out_odd : std_logic;

    ----------------------------------------------------------------------------
    -- DUT signals for MARK parity instance (DATA_WIDTH=8, PARITY_TYPE="mark")
    ----------------------------------------------------------------------------
    signal data_in_mark    : std_logic_vector(7 downto 0) := (others => '0');
    signal parity_out_mark : std_logic;

    ----------------------------------------------------------------------------
    -- DUT signals for SPACE parity instance (DATA_WIDTH=8, PARITY_TYPE="space")
    ----------------------------------------------------------------------------
    signal data_in_space    : std_logic_vector(7 downto 0) := (others => '0');
    signal parity_out_space : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Instantiate DUT: odd parity
    ----------------------------------------------------------------------------
    dut_odd : entity work.UART_PARITY
        generic map (
            DATA_WIDTH  => 8,
            PARITY_TYPE => "odd"
        )
        port map (
            DATA_IN    => data_in_odd,
            PARITY_OUT => parity_out_odd
        );

    ----------------------------------------------------------------------------
    -- Instantiate DUT: mark parity
    ----------------------------------------------------------------------------
    dut_mark : entity work.UART_PARITY
        generic map (
            DATA_WIDTH  => 8,
            PARITY_TYPE => "mark"
        )
        port map (
            DATA_IN    => data_in_mark,
            PARITY_OUT => parity_out_mark
        );

    ----------------------------------------------------------------------------
    -- Instantiate DUT: space parity
    ----------------------------------------------------------------------------
    dut_space : entity work.UART_PARITY
        generic map (
            DATA_WIDTH  => 8,
            PARITY_TYPE => "space"
        )
        port map (
            DATA_IN    => data_in_space,
            PARITY_OUT => parity_out_space
        );

    ----------------------------------------------------------------------------
    -- Stimulus and checking process
    ----------------------------------------------------------------------------
    stim_proc : process
    begin

        -----------------------------------------------------------------------
        -- Test 1 (ODD parity): DATA_IN = 0x00 (0 ones) -> odd parity = '1'
        -- Odd parity starts from '1' and XORs all bits.
        -- XOR(1, 0,0,0,0,0,0,0,0) = 1  => PARITY_OUT should be '1'
        -----------------------------------------------------------------------
        data_in_odd <= x"00";
        wait for 10 ns;
        assert parity_out_odd = '1'
            report "TEST FAILED: ODD parity for 0x00 should be '1', got '0'"
            severity FAILURE;
        report "TEST PASSED: ODD parity for 0x00 is '1'";

        -----------------------------------------------------------------------
        -- Test 2 (ODD parity): DATA_IN = 0xFF (8 ones) -> odd parity = '1'
        -- XOR(1, 1,1,1,1,1,1,1,1) = XOR of nine '1's = 1  => '1'
        -----------------------------------------------------------------------
        data_in_odd <= x"FF";
        wait for 10 ns;
        assert parity_out_odd = '1'
            report "TEST FAILED: ODD parity for 0xFF should be '1', got '0'"
            severity FAILURE;
        report "TEST PASSED: ODD parity for 0xFF is '1'";

        -----------------------------------------------------------------------
        -- Test 3 (ODD parity): DATA_IN = 0x01 (1 one) -> odd parity = '0'
        -- XOR(1, 0,0,0,0,0,0,0,1) = 0  => PARITY_OUT should be '0'
        -----------------------------------------------------------------------
        data_in_odd <= x"01";
        wait for 10 ns;
        assert parity_out_odd = '0'
            report "TEST FAILED: ODD parity for 0x01 should be '0', got '1'"
            severity FAILURE;
        report "TEST PASSED: ODD parity for 0x01 is '0'";

        -----------------------------------------------------------------------
        -- Test 4 (ODD parity): DATA_IN = 0xA5 = 1010_0101 (4 ones)
        -- XOR(1, 1,0,1,0,0,1,0,1) = 1  => PARITY_OUT should be '1'
        -----------------------------------------------------------------------
        data_in_odd <= x"A5";
        wait for 10 ns;
        assert parity_out_odd = '1'
            report "TEST FAILED: ODD parity for 0xA5 should be '1'"
            severity FAILURE;
        report "TEST PASSED: ODD parity for 0xA5 is '1'";

        -----------------------------------------------------------------------
        -- Test 5 (ODD parity): DATA_IN = 0x03 = 0000_0011 (2 ones)
        -- XOR(1, 0,0,0,0,0,0,1,1) = 1  => PARITY_OUT should be '1'
        -----------------------------------------------------------------------
        data_in_odd <= x"03";
        wait for 10 ns;
        assert parity_out_odd = '1'
            report "TEST FAILED: ODD parity for 0x03 should be '1'"
            severity FAILURE;
        report "TEST PASSED: ODD parity for 0x03 is '1'";

        -----------------------------------------------------------------------
        -- Test 6 (MARK parity): output must always be '1' regardless of input
        -----------------------------------------------------------------------
        data_in_mark <= x"00";
        wait for 10 ns;
        assert parity_out_mark = '1'
            report "TEST FAILED: MARK parity for 0x00 should be '1'"
            severity FAILURE;
        report "TEST PASSED: MARK parity for 0x00 is '1'";

        data_in_mark <= x"FF";
        wait for 10 ns;
        assert parity_out_mark = '1'
            report "TEST FAILED: MARK parity for 0xFF should be '1'"
            severity FAILURE;
        report "TEST PASSED: MARK parity for 0xFF is '1'";

        data_in_mark <= x"A5";
        wait for 10 ns;
        assert parity_out_mark = '1'
            report "TEST FAILED: MARK parity for 0xA5 should be '1'"
            severity FAILURE;
        report "TEST PASSED: MARK parity for 0xA5 is '1'";

        -----------------------------------------------------------------------
        -- Test 7 (SPACE parity): output must always be '0' regardless of input
        -----------------------------------------------------------------------
        data_in_space <= x"00";
        wait for 10 ns;
        assert parity_out_space = '0'
            report "TEST FAILED: SPACE parity for 0x00 should be '0'"
            severity FAILURE;
        report "TEST PASSED: SPACE parity for 0x00 is '0'";

        data_in_space <= x"FF";
        wait for 10 ns;
        assert parity_out_space = '0'
            report "TEST FAILED: SPACE parity for 0xFF should be '0'"
            severity FAILURE;
        report "TEST PASSED: SPACE parity for 0xFF is '0'";

        data_in_space <= x"A5";
        wait for 10 ns;
        assert parity_out_space = '0'
            report "TEST FAILED: SPACE parity for 0xA5 should be '0'"
            severity FAILURE;
        report "TEST PASSED: SPACE parity for 0xA5 is '0'";

        report "ALL UART_PARITY TESTS PASSED";
        wait;
    end process stim_proc;

end architecture tb;
