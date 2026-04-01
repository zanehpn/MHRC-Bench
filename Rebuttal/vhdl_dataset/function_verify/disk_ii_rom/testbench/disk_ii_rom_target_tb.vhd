--------------------------------------------------------------------------------
-- Testbench: disk_ii_rom_target_tb
-- DUT: disk_ii_rom
--
-- ROM contents (from source, first few entries):
--   addr=0x00 -> 0xA2  (162)
--   addr=0x01 -> 0x20  ( 32)
--   addr=0x02 -> 0xA0  (160)
--   addr=0xFF -> 0x00  (  0)  -- last entry is 0x00
--
-- dout is registered: it appears one clock after addr is applied.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity disk_ii_rom_target_tb is
end disk_ii_rom_target_tb;

architecture sim of disk_ii_rom_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk  : std_logic := '0';
    signal addr : unsigned(7 downto 0) := (others => '0');
    signal dout : unsigned(7 downto 0);

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
    DUT : entity work.disk_ii_rom
        port map (
            addr => addr,
            clk  => clk,
            dout => dout
        );

    -- Stimulus and checking
    stim_proc : process
        variable first_read : unsigned(7 downto 0);
    begin
        -- ----------------------------------------------------------------
        -- Test 1: Read address 0x00.
        -- ROM[0] = 0xA2. dout appears one clock after addr is applied.
        -- ----------------------------------------------------------------
        addr <= X"00";
        wait until rising_edge(clk);
        wait for 1 ns;  -- dout now holds ROM[0x00]

        assert dout = X"A2"
            report "FAIL Test1: ROM[0x00] should be 0xA2 (162), got "
                   & integer'image(to_integer(dout))
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: Read address 0x01.
        -- ROM[1] = 0x20.
        -- ----------------------------------------------------------------
        addr <= X"01";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dout = X"20"
            report "FAIL Test2: ROM[0x01] should be 0x20 (32), got "
                   & integer'image(to_integer(dout))
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: Read address 0x02.
        -- ROM[2] = 0xA0.
        -- ----------------------------------------------------------------
        addr <= X"02";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dout = X"A0"
            report "FAIL Test3: ROM[0x02] should be 0xA0 (160), got "
                   & integer'image(to_integer(dout))
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: Re-read address 0x00 to confirm determinism.
        -- ----------------------------------------------------------------
        addr <= X"00";
        wait until rising_edge(clk);
        wait for 1 ns;
        first_read := dout;

        -- Read a second time
        addr <= X"00";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dout = first_read
            report "FAIL Test4: ROM[0x00] should be deterministic; second read differs from first"
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: Read address 0xFF (last entry = 0x00).
        -- ----------------------------------------------------------------
        addr <= X"FF";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dout = X"00"
            report "FAIL Test5: ROM[0xFF] should be 0x00, got "
                   & integer'image(to_integer(dout))
            severity error;

        -- ----------------------------------------------------------------
        -- Test 6: ROM address 0x00 is non-zero (boot code sanity check).
        -- ----------------------------------------------------------------
        addr <= X"00";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert dout /= X"00"
            report "FAIL Test6: ROM[0x00] should be non-zero (Apple II boot code)"
            severity error;

        report "All disk_ii_rom tests passed." severity note;
        wait;
    end process;

end sim;
