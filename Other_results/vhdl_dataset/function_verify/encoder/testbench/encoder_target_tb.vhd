--------------------------------------------------------------------------------
-- Testbench: encoder_target_tb.vhd
-- DUT: encoder (encoder_original.vhd)
--
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- BLOCKER 1 — Xilinx UNISIM library required
--   The DUT instantiates Xilinx LUT6 primitives from library UNISIM.
--   This testbench CANNOT be compiled or simulated without the Xilinx
--   simulation libraries (provided with Vivado / ISE).
--   To simulate: add the Xilinx UNISIM library to your simulator search path,
--   e.g. for GHDL:
--       ghdl -a --std=08 -P/path/to/unisim/UNISIM-obj08.cf ...
--   or use Vivado's built-in simulator (xsim).
--
-- BLOCKER 2 — work.MyPkg package required
--   The DUT uses `work.MyPkg.all` which must provide at minimum:
--     function bitSize(n : integer) return integer;
--     function log2(n : integer)    return integer;
--   Compile work.MyPkg before compiling the DUT.
--
-- DESIGN PARAMETERS USED IN THIS TESTBENCH
--   NTaps = 12  (smallest valid value, must be a multiple of 12)
--   OUT_WIDTH = bitSize(12) — depends on MyPkg; expected value = 4 (ceil log2 of 13)
--
-- COMPILE ORDER (once blockers are resolved):
--   1. MyPkg (from original source tree)
--   2. adderTreeLegacy (referenced by DUT via work.adderTreeLegacy)
--   3. risingEdgeDetector (not used by encoder but needed for delayLine)
--   4. encoder_original.vhd
--   5. encoder_target_tb.vhd
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- NOTE: work.MyPkg.all is NOT used in this testbench directly.
-- The DUT entity port `ones` has width bitSize(NTaps)-1 downto 0.
-- With NTaps=12 and the expected bitSize definition, that is 3 downto 0 (4 bits).
-- If bitSize returns a different value for 12, adjust ONES_WIDTH below.

entity encoder_target_tb is
end entity encoder_target_tb;

architecture tb of encoder_target_tb is

    -- -----------------------------------------------------------------------
    -- Parameters matching DUT generic
    -- -----------------------------------------------------------------------
    constant C_NTAPS      : integer := 12;
    -- bitSize(12) is expected to be 4 (number of bits to represent 0..12)
    -- Adjust if MyPkg.bitSize defines it differently.
    constant C_ONES_WIDTH : integer := 4;

    -- -----------------------------------------------------------------------
    -- Clock
    -- -----------------------------------------------------------------------
    constant C_CLK_PERIOD : time := 10 ns;
    signal clk_s : std_logic := '0';

    -- -----------------------------------------------------------------------
    -- DUT ports
    -- -----------------------------------------------------------------------
    signal thermo_s  : std_logic_vector(C_NTAPS-1 downto 0) := (others => '0');
    signal ones_s    : std_logic_vector(C_ONES_WIDTH-1 downto 0);
    signal validIn_s : std_logic := '0';
    signal validOut_s: std_logic;

    -- -----------------------------------------------------------------------
    -- Component declaration
    -- -----------------------------------------------------------------------
    -- NOTE: The `ones` port width depends on the MyPkg.bitSize function.
    -- The component declaration below assumes bitSize(12) = 4.
    component encoder is
        generic (
            NTaps : integer := 132
        );
        port (
            clk      : in  std_logic;
            thermo   : in  std_logic_vector(NTaps-1 downto 0);
            ones     : out std_logic_vector(C_ONES_WIDTH-1 downto 0);
            validIn  : in  std_logic;
            validOut : out std_logic
        );
    end component encoder;

begin

    -- -----------------------------------------------------------------------
    -- Clock generation
    -- -----------------------------------------------------------------------
    clk_gen : process
    begin
        clk_s <= '0';
        wait for C_CLK_PERIOD / 2;
        clk_s <= '1';
        wait for C_CLK_PERIOD / 2;
    end process clk_gen;

    -- -----------------------------------------------------------------------
    -- DUT instantiation
    -- NOTE: Will NOT compile without Xilinx UNISIM and work.MyPkg.
    -- -----------------------------------------------------------------------
    DUT : encoder
        generic map (
            NTaps => C_NTAPS
        )
        port map (
            clk      => clk_s,
            thermo   => thermo_s,
            ones     => ones_s,
            validIn  => validIn_s,
            validOut => validOut_s
        );

    -- -----------------------------------------------------------------------
    -- Stimulus
    -- The encoder converts thermometer code to a binary count of 1's.
    -- Pipeline depth = log2(NLUTs) + 1 clock cycles (adder tree + output reg).
    -- With NTaps=12, NLUTs=2, pipeline depth ~ log2(2)+1 = 2 cycles.
    -- -----------------------------------------------------------------------
    stim_proc : process
        -- Helper: count set bits in a slv (for reporting expected value)
        variable expected : integer;
    begin
        -- Reset / idle
        thermo_s  <= (others => '0');
        validIn_s <= '0';
        wait for 5 * C_CLK_PERIOD;

        -- Test 1: 0 ones -> expected ones = 0
        thermo_s  <= (others => '0');
        validIn_s <= '1';
        wait for C_CLK_PERIOD;

        -- Test 2: all ones (12 set bits) -> expected ones = 12 (0b1100)
        thermo_s  <= (others => '1');
        validIn_s <= '1';
        wait for C_CLK_PERIOD;

        -- Test 3: alternating 0101... (6 ones) -> expected ones = 6
        thermo_s  <= "010101010101";
        validIn_s <= '1';
        wait for C_CLK_PERIOD;

        -- Test 4: lower 3 bits set -> expected ones = 3
        thermo_s  <= "000000000111";
        validIn_s <= '1';
        wait for C_CLK_PERIOD;

        -- Allow pipeline to drain
        thermo_s  <= (others => '0');
        validIn_s <= '0';
        wait for 10 * C_CLK_PERIOD;

        -- -----------------------------------------------------------------------
        -- NOTE: Assertions are NOT included because the output register and
        -- pipeline depth depend on the MyPkg functions (log2, bitSize) which
        -- are unknown without the package source. When MyPkg is available,
        -- insert wait-for-pipeline-depth + assert statements here.
        -- -----------------------------------------------------------------------
        assert false
            report "FAIL: BLOCKER - encoder requires Xilinx UNISIM and work.MyPkg for functional verification."
            severity error;
        wait;
    end process stim_proc;

end architecture tb;
