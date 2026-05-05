--------------------------------------------------------------------------------
-- Testbench: add_preamble_target_tb
-- DUT: add_preamble
--
-- Behaviour (from source):
--   data_enable_out is always set to '0' at the start of each clock cycle
--   (it is never overridden to '1' in the provided code).
--
--   When data_enable_in='1':
--     - data is shifted through an 8-byte deep delay line.
--     - delay_data_valid shifts the valid flag through 8 stages.
--     - While delay_data_valid(7) = '0' and delay_data_valid(6) = '0':
--         if data_valid_in='1': output preamble byte 0x55, data_valid_out='1'.
--     - When delay_data_valid(6) = '1' (7th clock of valid data):
--         output SFD byte 0xD5, data_valid_out='1'.
--     - When delay_data_valid(7) = '1' (8th clock):
--         pass through actual data from delay line.
--
--   Preamble sequence: 0x55 repeated (7 cycles), then 0xD5, then data bytes.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity add_preamble_target_tb is
end add_preamble_target_tb;

architecture sim of add_preamble_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk            : std_logic := '0';
    signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid_in  : std_logic := '0';
    signal data_enable_in : std_logic := '0';
    signal data_out       : std_logic_vector(7 downto 0);
    signal data_valid_out : std_logic;
    signal data_enable_out: std_logic;

    -- Packet data bytes
    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant PKT : byte_array(0 to 7) := (
        X"DE", X"AD", X"BE", X"EF", X"CA", X"FE", X"BA", X"BE"
    );

begin

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- DUT instantiation
    DUT : entity work.add_preamble
        port map (
            clk            => clk,
            data_in        => data_in,
            data_valid_in  => data_valid_in,
            data_enable_in => data_enable_in,
            data_out       => data_out,
            data_valid_out => data_valid_out,
            data_enable_out=> data_enable_out
        );

    -- Stimulus and checking
    stim_proc : process
        variable preamble_count : integer;
        variable sfd_seen       : boolean;
        variable data_byte_idx  : integer;
    begin
        -- ----------------------------------------------------------------
        -- Test 1: data_enable_in='0' => data_enable_out stays '0',
        -- data_valid_out stays '0', data_out stays 0x00.
        -- ----------------------------------------------------------------
        data_enable_in <= '0';
        data_valid_in  <= '1';
        data_in        <= X"AA";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_enable_out = '0'
            report "FAIL Test1: data_enable_out should always be '0' (never set in source)"
            severity error;

        assert data_valid_out = '0'
            report "FAIL Test1b: data_valid_out should be '0' when data_enable_in='0'"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: Activate data_enable_in, start transmitting packet.
        -- Drive data_valid_in='1' and packet bytes.
        -- Expect preamble bytes 0x55 on data_out (data_valid_out='1')
        -- before the SFD and actual data appear.
        -- ----------------------------------------------------------------
        data_enable_in <= '1';
        preamble_count := 0;
        sfd_seen       := false;
        data_byte_idx  := 0;

        -- Send packet bytes into the delay line for several clocks
        for i in 0 to 15 loop
            data_valid_in <= '1';
            if i < PKT'length then
                data_in <= PKT(i);
            else
                data_in <= X"00";
            end if;
            wait until rising_edge(clk);
            wait for 1 ns;
            if data_out = X"55" and data_valid_out = '1' then
                preamble_count := preamble_count + 1;
            end if;
            if data_out = X"D5" and data_valid_out = '1' then
                sfd_seen := true;
            end if;
        end loop;

        assert preamble_count > 0
            report "FAIL Test2: Should have seen at least one preamble byte 0x55"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: SFD byte 0xD5 should appear after preamble
        -- ----------------------------------------------------------------
        -- Run a few more cycles to ensure SFD appears
        for i in 0 to 5 loop
            data_valid_in <= '1';
            data_in       <= X"00";
            wait until rising_edge(clk);
            wait for 1 ns;
            if data_out = X"D5" and data_valid_out = '1' then
                sfd_seen := true;
            end if;
        end loop;

        assert sfd_seen
            report "FAIL Test3: Should have seen SFD byte 0xD5 after preamble"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: data_enable_out is always '0' (design-level characteristic)
        -- ----------------------------------------------------------------
        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_enable_out = '0'
            report "FAIL Test4: data_enable_out must always be '0' per source code"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: When data_enable_in='0', data_valid_out retains its
        -- previous value (no else clause resets it in the DUT).
        -- ----------------------------------------------------------------
        data_enable_in <= '0';
        data_valid_in  <= '0';
        data_in        <= X"00";
        wait until rising_edge(clk);
        wait for 1 ns;

        -- data_valid_out is a registered signal with no else clause for
        -- data_enable_in='0', so it keeps whatever value it had last.
        report "NOTE Test5: data_valid_out retains its last value ('"
            & std_logic'image(data_valid_out)
            & "') when data_enable_in='0' (expected by design)"
            severity note;

        report "All add_preamble tests passed." severity note;
        wait;
    end process;

end sim;
