-- Testbench for sample_packer
-- Target: buffer pointer reset logic (`clear_buffer` resets write_pointer and
-- read_pointer to zero).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sample_packer_target_tb is
end sample_packer_target_tb;

architecture sim of sample_packer_target_tb is

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal data_a       : std_logic_vector(15 downto 0) := (others => '0');
    signal data_b       : std_logic_vector(15 downto 0) := (others => '0');
    signal adc_valid    : std_logic := '0';
    signal sample_valid : std_logic := '0';
    signal usb_write    : std_logic;
    signal usb_writedata : std_logic_vector(7 downto 0);
    signal enable_a     : std_logic := '1';
    signal enable_b     : std_logic := '1';
    signal tx_full      : std_logic := '0';
    signal clear_buffer : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;
    constant PACKET_START_BYTE : std_logic_vector(7 downto 0) := x"7F";

    -- Shared capture signals between monitor and stimulus
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    signal captured_bytes  : byte_array_t(0 to 7) := (others => (others => '0'));
    signal capture_count   : integer := 0;
    signal capture_enable  : boolean := false;
    signal capture_reset   : boolean := false;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.sample_packer
        port map (
            clk          => clk,
            rst          => rst,
            data_a       => data_a,
            data_b       => data_b,
            adc_valid    => adc_valid,
            sample_valid => sample_valid,
            usb_write    => usb_write,
            usb_writedata => usb_writedata,
            enable_a     => enable_a,
            enable_b     => enable_b,
            tx_full      => tx_full,
            clear_buffer => clear_buffer
        );

    -- Concurrent monitor: captures usb_writedata whenever usb_write='1'
    monitor_proc : process(clk)
    begin
        if rising_edge(clk) then
            if capture_reset then
                capture_count <= 0;
            elsif capture_enable and usb_write = '1' and capture_count < 8 then
                captured_bytes(capture_count) <= usb_writedata;
                capture_count <= capture_count + 1;
            end if;
        end if;
    end process;

    stim : process
        variable write_seen_after_clear : boolean := false;
    begin
        -- Test 1: Hold reset, then release
        rst         <= '1';
        adc_valid   <= '0';
        sample_valid <= '0';
        clear_buffer <= '0';
        tx_full     <= '0';
        enable_a    <= '1';
        enable_b    <= '1';
        wait for CLK_PERIOD * 3;

        rst <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert usb_write = '0'
            report "FAIL: usb_write should be 0 after reset is released"
            severity error;

        wait for CLK_PERIOD;

        -- Test 2: Trigger a sweep start and supply one sample.
        -- Enable capture BEFORE triggering so we don't miss early bytes.
        capture_reset  <= true;
        wait until rising_edge(clk);
        capture_reset  <= false;
        capture_enable <= true;

        data_a <= x"1234";
        data_b <= x"5678";

        -- Raise sample_valid WITHOUT adc_valid to trigger header writes
        sample_valid <= '1';
        adc_valid    <= '0';

        wait until rising_edge(clk);  -- detects rising edge of sample_valid
        wait until rising_edge(clk);  -- writes PACKET_START
        wait until rising_edge(clk);  -- writes sweep_count

        -- Now provide ADC sample data
        adc_valid <= '1';
        wait until rising_edge(clk);  -- latches data, data_int_valid='1'
        wait until rising_edge(clk);  -- writes A_low
        sample_valid <= '0';
        adc_valid    <= '0';

        -- Wait for all 6 bytes to be output via USB
        wait for CLK_PERIOD * 30;

        capture_enable <= false;

        -- Verify we got at least 6 bytes
        assert capture_count >= 6
            report "FAIL: expected at least 6 USB bytes, got " &
                   integer'image(capture_count)
            severity error;

        -- Byte 0: PACKET_START (0x7F)
        assert captured_bytes(0) = PACKET_START_BYTE
            report "FAIL: first byte should be PACKET_START (0x7F), got 0x" &
                   to_hstring(captured_bytes(0))
            severity error;

        -- Byte 1: sweep_count = 0x00
        assert captured_bytes(1) = x"00"
            report "FAIL: second byte should be sweep_count=0x00, got 0x" &
                   to_hstring(captured_bytes(1))
            severity error;

        -- Byte 2: data_a(7:0) = 0x34
        assert captured_bytes(2) = x"34"
            report "FAIL: third byte should be A_low=0x34, got 0x" &
                   to_hstring(captured_bytes(2))
            severity error;

        -- Byte 3: data_a(15:8) = 0x12
        assert captured_bytes(3) = x"12"
            report "FAIL: fourth byte should be A_high=0x12, got 0x" &
                   to_hstring(captured_bytes(3))
            severity error;

        -- Byte 4: data_b(7:0) = 0x78
        assert captured_bytes(4) = x"78"
            report "FAIL: fifth byte should be B_low=0x78, got 0x" &
                   to_hstring(captured_bytes(4))
            severity error;

        -- Byte 5: data_b(15:8) = 0x56
        assert captured_bytes(5) = x"56"
            report "FAIL: sixth byte should be B_high=0x56, got 0x" &
                   to_hstring(captured_bytes(5))
            severity error;

        -- Test 3: tx_full='1' should suppress usb_write
        tx_full <= '1';
        sample_valid <= '1';
        adc_valid    <= '0';
        data_a <= x"ABCD";
        data_b <= x"EF01";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        adc_valid <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        sample_valid <= '0';
        adc_valid    <= '0';
        for i in 1 to 10 loop
            wait until rising_edge(clk);
            assert usb_write = '0'
                report "FAIL: usb_write should be '0' when tx_full='1'"
                severity error;
        end loop;
        tx_full <= '0';

        -- Test 4: clear_buffer resets pointers
        wait for CLK_PERIOD * 20;

        sample_valid <= '1';
        adc_valid    <= '0';
        data_a <= x"1111";
        data_b <= x"2222";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        adc_valid <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        sample_valid <= '0';
        adc_valid    <= '0';
        wait for CLK_PERIOD * 5;

        clear_buffer <= '1';
        wait until rising_edge(clk);
        clear_buffer <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert usb_write = '0'
            report "FAIL: usb_write should be '0' immediately after clear_buffer"
            severity error;

        write_seen_after_clear := false;
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            if usb_write = '1' then
                write_seen_after_clear := true;
            end if;
        end loop;

        assert not write_seen_after_clear
            report "FAIL: usb_write asserted after clear_buffer with no new data"
            severity error;

        report "All assertions passed.";
        wait;
    end process;

end sim;
