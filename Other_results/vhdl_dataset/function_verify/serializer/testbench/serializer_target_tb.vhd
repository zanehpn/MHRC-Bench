-- Testbench for serializer
-- Target line: `fors6: if SERIES6 = true generate` - conditional generation for
-- Series 6 FPGA serializer.
--
-- ============================================================
-- BLOCKER: This design instantiates Xilinx UNISIM primitives
-- OBUFDS, OSERDESE2 (SERIES6=false) and OSERDESE1 (SERIES6=true).
-- These primitives are only available in the Xilinx UNISIM
-- simulation library.  This testbench CANNOT be simulated with
-- open-source tools (GHDL, ModelSim free, etc.) unless the
-- Xilinx simulation libraries are installed and linked.
-- The testbench structure is provided for completeness; it is
-- syntactically correct VHDL but will fail elaboration without
-- the UNISIM library.
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity serializer_target_tb is
end serializer_target_tb;

architecture sim of serializer_target_tb is

    -- DUT signals
    signal rst      : std_logic := '1';
    signal pixclk   : std_logic := '0';
    signal serclk   : std_logic := '0';
    signal endata_i : std_logic_vector(9 downto 0) := (others => '0');
    signal s_p      : std_logic;
    signal s_n      : std_logic;

    constant PIX_PERIOD : time := 10 ns;   -- pixel clock period (100 MHz)
    constant SER_PERIOD : time :=  2 ns;   -- serial clock 5x (500 MHz)

begin

    -- Pixel clock
    pixclk <= not pixclk after PIX_PERIOD / 2;

    -- Serial clock (5x pixel clock)
    serclk <= not serclk after SER_PERIOD / 2;

    -- DUT instantiation (Series-7 path, SERIES6=false default)
    dut : entity work.serializer
        generic map (
            SERIES6 => false
        )
        port map (
            rst      => rst,
            pixclk   => pixclk,
            serclk   => serclk,
            endata_i => endata_i,
            s_p      => s_p,
            s_n      => s_n
        );

    stim : process
    begin
        -- Release reset after a few pixel-clock cycles
        wait for PIX_PERIOD * 4;
        rst <= '0';

        -- Assert 1: after reset is released, s_p and s_n should be
        -- complementary (OBUFDS differential pair property).
        -- We wait several serial-clock periods for the serdes to stabilise.
        endata_i <= "1010101010";
        wait for PIX_PERIOD * 2;

        assert false
            report "FAIL: BLOCKER - serializer requires Xilinx UNISIM (OSERDESE2/OBUFDS) for functional verification."
            severity error;
        wait;
    end process;

end sim;
