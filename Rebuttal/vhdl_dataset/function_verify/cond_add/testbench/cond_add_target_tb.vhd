--------------------------------------------------------------------------------
-- Testbench: cond_add_target_tb.vhd
-- DUT: cond_adder (cond_add_original.vhd)
--
-- PACKAGE DEPENDENCY: The DUT uses `work.mypackage.all` which defines the
-- constant YBITS.  No package file was found in this folder or its parents.
-- ASSUMPTION: YBITS = 8 is used here.  If the real mypackage defines a
-- different value, recompile with the real package and remove the local
-- package declaration below.
--
-- SELF-CONTAINED: This testbench defines a local package `mypackage` that
-- reproduces the only symbol required by the DUT (YBITS).  Compile order:
--   1. This file (package body is in same compilation unit)
--   2. cond_add_original.vhd
--   3. This file (testbench entity)
-- With GHDL:
--   ghdl -a --std=93 cond_add_target_tb.vhd
--   ghdl -a --std=93 ../cond_add_original.vhd
--   ghdl -e --std=93 cond_add_target_tb
--   ghdl -r --std=93 cond_add_target_tb
--
-- FUNCTIONAL TESTS:
--   Test 1: sel='1', op_a=10, op_b=5  -> outp expected 15
--   Test 2: sel='0', op_a=10, op_b=5  -> outp expected 10
--   Test 3: sel='1', op_a=200, op_b=55 -> outp expected 255  (max)
--   Test 4: sel='1', op_a=255, op_b=1  -> outp expected 0   (wrap)
--   Test 5: sel='0', op_a=0,   op_b=99 -> outp expected 0   (op_b ignored)
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

entity cond_add_target_tb is
end entity cond_add_target_tb;

architecture tb of cond_add_target_tb is

    -- Component declaration (matches cond_adder entity)
    component cond_adder is
        port (
            op_a : in  STD_LOGIC_VECTOR(YBITS-1 downto 0);
            op_b : in  STD_LOGIC_VECTOR(YBITS-1 downto 0);
            sel  : in  STD_LOGIC;
            outp : out STD_LOGIC_VECTOR(YBITS-1 downto 0)
        );
    end component;

    -- Stimulus signals
    signal op_a_s : STD_LOGIC_VECTOR(YBITS-1 downto 0) := (others => '0');
    signal op_b_s : STD_LOGIC_VECTOR(YBITS-1 downto 0) := (others => '0');
    signal sel_s  : STD_LOGIC := '0';
    signal outp_s : STD_LOGIC_VECTOR(YBITS-1 downto 0);

    -- Small propagation delay constant (combinatorial DUT)
    constant T_PROP : time := 10 ns;

    -- Helper: convert integer to SLV of width YBITS
    function to_slv(val : integer) return STD_LOGIC_VECTOR is
    begin
        return CONV_STD_LOGIC_VECTOR(val, YBITS);
    end function;

begin

    -- Instantiate DUT
    DUT : cond_adder
        port map (
            op_a => op_a_s,
            op_b => op_b_s,
            sel  => sel_s,
            outp => outp_s
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- ---------------------------------------------------------------
        -- Test 1: sel='1', op_a=10, op_b=5 -> outp = 15
        -- ---------------------------------------------------------------
        op_a_s <= to_slv(10);
        op_b_s <= to_slv(5);
        sel_s  <= '1';
        wait for T_PROP;
        assert outp_s = to_slv(15)
            report "FAIL Test1: sel=1, op_a=10, op_b=5 => expected 15, got " &
                   integer'image(CONV_INTEGER(outp_s))
            severity error;
        assert outp_s = to_slv(15)
            report "PASS Test1: sel=1, op_a=10, op_b=5 => outp=15"
            severity note;

        -- ---------------------------------------------------------------
        -- Test 2: sel='0', op_a=10, op_b=5 -> outp = 10 (op_b ignored)
        -- ---------------------------------------------------------------
        op_a_s <= to_slv(10);
        op_b_s <= to_slv(5);
        sel_s  <= '0';
        wait for T_PROP;
        assert outp_s = to_slv(10)
            report "FAIL Test2: sel=0, op_a=10, op_b=5 => expected 10, got " &
                   integer'image(CONV_INTEGER(outp_s))
            severity error;
        assert outp_s = to_slv(10)
            report "PASS Test2: sel=0, op_a=10, op_b=5 => outp=10"
            severity note;

        -- ---------------------------------------------------------------
        -- Test 3: sel='1', op_a=200, op_b=55 -> outp = 255
        -- ---------------------------------------------------------------
        op_a_s <= to_slv(200);
        op_b_s <= to_slv(55);
        sel_s  <= '1';
        wait for T_PROP;
        assert outp_s = to_slv(255)
            report "FAIL Test3: sel=1, op_a=200, op_b=55 => expected 255, got " &
                   integer'image(CONV_INTEGER(outp_s))
            severity error;
        assert outp_s = to_slv(255)
            report "PASS Test3: sel=1, op_a=200, op_b=55 => outp=255"
            severity note;

        -- ---------------------------------------------------------------
        -- Test 4: sel='1', op_a=255, op_b=1 -> outp = 0 (8-bit wrap)
        -- ---------------------------------------------------------------
        op_a_s <= to_slv(255);
        op_b_s <= to_slv(1);
        sel_s  <= '1';
        wait for T_PROP;
        assert outp_s = to_slv(0)
            report "FAIL Test4: sel=1, op_a=255, op_b=1 => expected 0 (wrap), got " &
                   integer'image(CONV_INTEGER(outp_s))
            severity error;
        assert outp_s = to_slv(0)
            report "PASS Test4: sel=1, op_a=255, op_b=1 => outp=0 (wrap)"
            severity note;

        -- ---------------------------------------------------------------
        -- Test 5: sel='0', op_a=0, op_b=99 -> outp = 0 (op_b ignored)
        -- ---------------------------------------------------------------
        op_a_s <= to_slv(0);
        op_b_s <= to_slv(99);
        sel_s  <= '0';
        wait for T_PROP;
        assert outp_s = to_slv(0)
            report "FAIL Test5: sel=0, op_a=0, op_b=99 => expected 0, got " &
                   integer'image(CONV_INTEGER(outp_s))
            severity error;
        assert outp_s = to_slv(0)
            report "PASS Test5: sel=0, op_a=0, op_b=99 => outp=0"
            severity note;

        -- ---------------------------------------------------------------
        -- Simulation complete
        -- ---------------------------------------------------------------
        report "cond_add testbench complete." severity note;
        wait;
    end process stim_proc;

end architecture tb;
