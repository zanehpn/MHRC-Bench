-- Testbench for tmds_encoder
-- Target line: `if din(i)='1' then c := c + 1;` - counting ones in input data
-- Tests TMDS encoding for various input values and control tokens.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tmds_encoder_target_tb is
end tmds_encoder_target_tb;

architecture sim of tmds_encoder_target_tb is

    signal clk  : std_logic := '0';
    signal en   : std_logic := '0';
    signal ctrl : std_logic_vector(1 downto 0) := "00";
    signal din  : std_logic_vector(7 downto 0) := (others => '0');
    signal dout : std_logic_vector(9 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Clock generation: 10 ns period
    clk <= not clk after CLK_PERIOD / 2;

    -- Instantiate DUT
    dut : entity work.tmds_encoder
        port map (
            clk  => clk,
            en   => en,
            ctrl => ctrl,
            din  => din,
            dout => dout
        );

    -- Stimulus process
    stim : process
        variable dout_00 : std_logic_vector(9 downto 0);
        variable dout_ff : std_logic_vector(9 downto 0);
        variable dout_aa : std_logic_vector(9 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Test 1: en='0', ctrl="00" -> control token "1101010100"
        -- ----------------------------------------------------------------
        en   <= '0';
        ctrl <= "00";
        din  <= x"00";
        wait until rising_edge(clk);
        wait for 1 ns;  -- let outputs settle after clock edge
        assert dout = "1101010100"
            report "FAIL: ctrl=00 token expected 1101010100, got " & to_string(dout)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: en='0', ctrl="01" -> control token "0010101011"
        -- ----------------------------------------------------------------
        ctrl <= "01";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert dout = "0010101011"
            report "FAIL: ctrl=01 token expected 0010101011, got " & to_string(dout)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: en='0', ctrl="10" -> control token "0101010100"
        -- ----------------------------------------------------------------
        ctrl <= "10";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert dout = "0101010100"
            report "FAIL: ctrl=10 token expected 0101010100, got " & to_string(dout)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: en='0', ctrl="11" -> control token "1010101011"
        -- ----------------------------------------------------------------
        ctrl <= "11";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert dout = "1010101011"
            report "FAIL: ctrl=11 token expected 1010101011, got " & to_string(dout)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: en='1', ctrl="00", din=0x00 (all zeros, 0 ones)
        -- Capture output and check it is a 10-bit value (non-trivial check:
        -- the encoded output must not equal any of the 4 control tokens).
        -- ----------------------------------------------------------------
        en   <= '1';
        ctrl <= "00";
        din  <= x"00";
        wait until rising_edge(clk);
        wait for 1 ns;
        dout_00 := dout;
        assert dout /= "1101010100" and dout /= "0010101011" and
               dout /= "0101010100" and dout /= "1010101011"
            report "FAIL: data token for din=0x00 matches a control token"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 6: en='1', ctrl="00", din=0xFF (all ones, 8 ones)
        -- Output should differ from the all-zeros encoding.
        -- ----------------------------------------------------------------
        din  <= x"FF";
        wait until rising_edge(clk);
        wait for 1 ns;
        dout_ff := dout;
        assert dout_ff /= dout_00
            report "FAIL: dout for din=0xFF should differ from din=0x00"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 7: en='1', ctrl="00", din=0xAA (alternating bits, 4 ones)
        -- Output should differ from both previous outputs.
        -- ----------------------------------------------------------------
        din  <= x"AA";
        wait until rising_edge(clk);
        wait for 1 ns;
        dout_aa := dout;
        assert dout_aa /= dout_00
            report "FAIL: dout for din=0xAA should differ from din=0x00"
            severity error;
        assert dout_aa /= dout_ff
            report "FAIL: dout for din=0xAA should differ from din=0xFF"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 8: Switching back to en='0' resets disparity and gives
        -- known control token.
        -- ----------------------------------------------------------------
        en   <= '0';
        ctrl <= "00";
        din  <= x"55";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert dout = "1101010100"
            report "FAIL: after switching en='0' ctrl=00 token expected 1101010100"
            severity error;

        report "All assertions passed.";
        wait;
    end process;

end sim;
