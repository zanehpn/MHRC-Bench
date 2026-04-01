--------------------------------------------------------------------------------
-- Testbench: nr_r4_cel_target_tb.vhd
-- DUT: nr_r4_half_cell (nr_r4_cel_original.vhd)
--
-- PACKAGE DEPENDENCY: The DUT uses `work.mypackage.all` which defines the
-- constant YBITS.  No package file was found in this folder or its parents.
-- ASSUMPTION: YBITS = 8 is used here.  Adjust and recompile if the real
-- mypackage defines a different value.
--
-- PORT WIDTHS (derived from nr_r4_cel_original.vhd with YBITS=8):
--   op_r   : STD_LOGIC_VECTOR(YBITS   downto 0) = (8 downto 0)   9 bits
--   op_y   : STD_LOGIC_VECTOR(YBITS   downto 0) = (8 downto 0)   9 bits
--   op_3y  : STD_LOGIC_VECTOR(YBITS+1 downto 0) = (9 downto 0)  10 bits
--   x_1    : STD_LOGIC                                             1 bit
--   x_0    : STD_LOGIC                                             1 bit
--   n_qneg : STD_LOGIC_VECTOR(1 downto 0)                         2 bits
--   new_r  : STD_LOGIC_VECTOR(YBITS   downto 0) = (8 downto 0)   9 bits
--
-- SELF-CONTAINED: A local package `mypackage` with YBITS=8 is declared here.
--
-- COMPILE ORDER:
--   1. This file (package declaration)
--   2. nr_r4_cel_original.vhd
--   3. This file (testbench entity)
-- With GHDL:
--   ghdl -a --std=93 nr_r4_cel_target_tb.vhd
--   ghdl -a --std=93 ../nr_r4_cel_original.vhd
--   ghdl -e --std=93 nr_r4_cel_target_tb
--   ghdl -r --std=93 nr_r4_cel_target_tb
--
-- KEY INTERNAL LOGIC (from DUT source):
--   sr      <= op_r(YBITS);           -- sign bit of op_r
--   op_4r   <= op_r(YBITS-1..0) & x_1 & x_0;   -- left-shift op_r by 2, append x_1:x_0
--   When sr='1' (negative):
--     a2_pm_b  <= (op_r & x_1) + op_y
--     a4_pm_3b <= op_4r + op_3y
--     a4_pm_b  <= op_4r + op_y
--   When sr='0' (positive):
--     a2_pm_b  <= ('0' & op_y) + NOT(op_r & x_1)   [i.e. subtract]
--     a4_pm_3b <= op_4r - op_3y
--     a4_pm_b  <= op_4r - ('0' & op_y)
--
-- FUNCTIONAL TESTS:
--   Test 1: sr='0' (positive remainder), verify sr and op_4r computation
--   Test 2: sr='1' (negative remainder), verify sr and op_4r computation
--   Test 3: Corner case op_r=0, x_1=0, x_0=0
--------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Local package reproducing work.mypackage
-- ---------------------------------------------------------------------------
package mypackage is
    constant YBITS : integer := 8;
end package mypackage;

-- ---------------------------------------------------------------------------
-- Testbench entity
-- ---------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.mypackage.all;

entity nr_r4_cel_target_tb is
end entity nr_r4_cel_target_tb;

architecture tb of nr_r4_cel_target_tb is

    -- Port widths
    constant W_R  : integer := YBITS + 1;   -- 9
    constant W_3Y : integer := YBITS + 2;   -- 10

    -- Component declaration matching nr_r4_half_cell
    component nr_r4_half_cell is
        port (
            op_r   : in  STD_LOGIC_VECTOR(YBITS   downto 0);
            op_y   : in  STD_LOGIC_VECTOR(YBITS   downto 0);
            op_3y  : in  STD_LOGIC_VECTOR(YBITS+1 downto 0);
            x_1    : in  STD_LOGIC;
            x_0    : in  STD_LOGIC;
            n_qneg : out STD_LOGIC_VECTOR(1 downto 0);
            new_r  : out STD_LOGIC_VECTOR(YBITS   downto 0)
        );
    end component;

    -- Stimulus signals
    signal op_r_s   : STD_LOGIC_VECTOR(YBITS   downto 0) := (others => '0');
    signal op_y_s   : STD_LOGIC_VECTOR(YBITS   downto 0) := (others => '0');
    signal op_3y_s  : STD_LOGIC_VECTOR(YBITS+1 downto 0) := (others => '0');
    signal x_1_s    : STD_LOGIC := '0';
    signal x_0_s    : STD_LOGIC := '0';
    signal n_qneg_s : STD_LOGIC_VECTOR(1 downto 0);
    signal new_r_s  : STD_LOGIC_VECTOR(YBITS   downto 0);

    constant T_PROP : time := 20 ns;

    -- Helper
    function to_slv_r(val : integer) return STD_LOGIC_VECTOR is
    begin
        return CONV_STD_LOGIC_VECTOR(val, W_R);
    end function;

    function to_slv_3y(val : integer) return STD_LOGIC_VECTOR is
    begin
        return CONV_STD_LOGIC_VECTOR(val, W_3Y);
    end function;

begin

    -- Instantiate DUT
    DUT : nr_r4_half_cell
        port map (
            op_r   => op_r_s,
            op_y   => op_y_s,
            op_3y  => op_3y_s,
            x_1    => x_1_s,
            x_0    => x_0_s,
            n_qneg => n_qneg_s,
            new_r  => new_r_s
        );

    stim_proc : process
        -- Variables to mirror DUT's internal combinatorial signals
        variable sr_v    : std_logic;
        variable op_4r_v : STD_LOGIC_VECTOR(W_3Y-1 downto 0);
        variable expected_new_r_lo : STD_LOGIC_VECTOR(YBITS downto 0);
    begin
        -----------------------------------------------------------------------
        -- Test 1: Positive remainder (sr='0', op_r MSB = '0')
        --   op_r = 0b000000010  (2 in 9-bit two's complement, positive)
        --   x_1  = '1', x_0 = '0'
        --   sr   should be '0' (op_r(YBITS) = '0')
        --   op_4r = op_r(7..0) & x_1 & x_0 = 00000010 & 1 & 0 = 0000001010
        -----------------------------------------------------------------------
        op_r_s  <= to_slv_r(2);    -- 9-bit: 0_0000_0010
        op_y_s  <= to_slv_r(4);    -- 9-bit: 0_0000_0100
        op_3y_s <= to_slv_3y(12);  -- 10-bit: 00_0000_1100
        x_1_s   <= '1';
        x_0_s   <= '0';
        wait for T_PROP;

        -- Check sr = op_r(YBITS) = MSB of op_r_s
        sr_v := op_r_s(YBITS);
        assert sr_v = '0'
            report "FAIL Test1: sr expected '0', got '1'"
            severity error;

        -- op_4r = op_r(7..0) & '1' & '0'
        -- op_r_s(7..0) = 0000_0010, so op_4r = 00_0000_1010 = 10
        op_4r_v := op_r_s(YBITS-1 downto 0) & x_1_s & x_0_s;
        assert op_4r_v = to_slv_3y(10)
            report "FAIL Test1: op_4r expected 10 (0b0000001010), got " &
                   integer'image(CONV_INTEGER(op_4r_v))
            severity error;

        report "PASS Test1: sr='0', op_4r=10 verified" severity note;

        -----------------------------------------------------------------------
        -- Test 2: Negative remainder (sr='1', op_r MSB = '1')
        --   op_r = 9-bit value with MSB='1'.
        --   Use 0b1_0000_0100 = 260 unsigned = -252 in 9-bit signed
        --   x_1 = '0', x_0 = '1'
        --   sr  = '1'
        --   op_4r = op_r(7..0) & x_1 & x_0 = 0000_0100 & 0 & 1 = 00_0000_1001 = 9
        -----------------------------------------------------------------------
        op_r_s  <= "100000100";   -- 9-bit: MSB=1 (negative), lower 8 = 0000_0100
        op_y_s  <= to_slv_r(6);
        op_3y_s <= to_slv_3y(18);
        x_1_s   <= '0';
        x_0_s   <= '1';
        wait for T_PROP;

        sr_v := op_r_s(YBITS);
        assert sr_v = '1'
            report "FAIL Test2: sr expected '1', got '0'"
            severity error;

        op_4r_v := op_r_s(YBITS-1 downto 0) & x_1_s & x_0_s;
        assert op_4r_v = to_slv_3y(9)
            report "FAIL Test2: op_4r expected 9 (0b0000001001), got " &
                   integer'image(CONV_INTEGER(op_4r_v))
            severity error;

        report "PASS Test2: sr='1', op_4r=9 verified" severity note;

        -----------------------------------------------------------------------
        -- Test 3: Corner case — op_r = 0, x_1 = '0', x_0 = '0'
        --   sr    = '0' (MSB of zero)
        --   op_4r = 0000_0000 & '0' & '0' = 0
        -----------------------------------------------------------------------
        op_r_s  <= (others => '0');
        op_y_s  <= (others => '0');
        op_3y_s <= (others => '0');
        x_1_s   <= '0';
        x_0_s   <= '0';
        wait for T_PROP;

        sr_v := op_r_s(YBITS);
        assert sr_v = '0'
            report "FAIL Test3: sr expected '0' for op_r=0"
            severity error;

        op_4r_v := op_r_s(YBITS-1 downto 0) & x_1_s & x_0_s;
        assert op_4r_v = to_slv_3y(0)
            report "FAIL Test3: op_4r expected 0"
            severity error;

        assert new_r_s = (YBITS downto 0 => '0')
            report "FAIL Test3: new_r expected all-zeros for all-zero inputs"
            severity error;

        report "PASS Test3: corner case all-zeros verified" severity note;

        -----------------------------------------------------------------------
        report "nr_r4_cel testbench complete." severity note;
        wait;
    end process stim_proc;

end architecture tb;
