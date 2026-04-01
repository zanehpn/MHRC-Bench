--------------------------------------------------------------------------------
-- Minimal ieee.fixed_pkg replacement for VCS 2016 (which lacks the package).
-- Provides only the subset of types and operations used by the Mandelbrot
-- designs: sfixed type, arithmetic (+,-,*), resize, scalb, to_sfixed, to_slv.
--
-- This is compiled into 'work' and referenced via 'use work.fixed_pkg.all;'
-- instead of 'use ieee.fixed_pkg.all;'
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package fixed_pkg is

    -- sfixed: array of std_logic indexed by integer (supports negative indices)
    type unresolved_sfixed is array (integer range <>) of std_logic;
    subtype sfixed is unresolved_sfixed;

    -- Arithmetic operators
    function "+" (l, r : unresolved_sfixed) return unresolved_sfixed;
    function "-" (l, r : unresolved_sfixed) return unresolved_sfixed;
    function "*" (l, r : unresolved_sfixed) return unresolved_sfixed;

    -- resize: truncate / extend to match size_res index range
    function resize (
        arg      : unresolved_sfixed;
        size_res : unresolved_sfixed
    ) return unresolved_sfixed;

    -- scalb: multiply by 2**N (shift left)
    function scalb (
        y : unresolved_sfixed;
        N : integer
    ) return unresolved_sfixed;

    -- to_sfixed from real
    function to_sfixed (
        arg         : real;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed;

    -- to_sfixed from integer
    function to_sfixed (
        arg         : integer;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed;

    -- to_sfixed from std_logic_vector (reinterpret bits)
    function to_sfixed (
        arg         : std_logic_vector;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed;

    -- to_slv: convert sfixed to std_logic_vector(N-1 downto 0)
    function to_slv (arg : unresolved_sfixed) return std_logic_vector;

end package fixed_pkg;


package body fixed_pkg is

    ---------------------------------------------------------------------------
    -- Internal helpers
    ---------------------------------------------------------------------------

    -- Convert sfixed to signed (preserving bit pattern)
    function sf_to_signed (arg : unresolved_sfixed) return signed is
        variable result : signed(arg'length - 1 downto 0);
    begin
        for i in result'range loop
            result(i) := arg(arg'right + i);
        end loop;
        return result;
    end function;

    -- Convert signed to sfixed with given index range
    function signed_to_sf (
        arg  : signed;
        left : integer;
        right: integer
    ) return unresolved_sfixed is
        constant LEN : integer := left - right + 1;
        variable result : unresolved_sfixed(left downto right);
        variable s : signed(LEN - 1 downto 0);
    begin
        -- Extend or truncate to target length
        if arg'length >= LEN then
            s := arg(LEN - 1 downto 0);
        else
            s := resize(arg, LEN);
        end if;
        for i in 0 to LEN - 1 loop
            result(right + i) := s(i);
        end loop;
        return result;
    end function;

    ---------------------------------------------------------------------------
    -- Arithmetic
    ---------------------------------------------------------------------------

    function "+" (l, r : unresolved_sfixed) return unresolved_sfixed is
        -- Result range: max(l'left, r'left)+1 downto min(l'right, r'right)
        constant res_left  : integer := maximum(l'left, r'left) + 1;
        constant res_right : integer := minimum(l'right, r'right);
        constant res_len   : integer := res_left - res_right + 1;
        variable ls, rs    : signed(res_len - 1 downto 0);
        variable ss        : signed(res_len - 1 downto 0);
    begin
        ls := resize(sf_to_signed(l), res_len);
        -- Align: if l'right /= res_right, shift
        if l'right > res_right then
            ls := shift_left(ls, l'right - res_right);
            ls := resize(sf_to_signed(l), res_len);
        end if;
        -- Full alignment: convert via intermediate
        ls := (others => '0');
        rs := (others => '0');
        for i in l'right to l'left loop
            ls(i - res_right) := l(i);
        end loop;
        -- Sign extend
        for i in l'left + 1 to res_left loop
            ls(i - res_right) := l(l'left); -- sign bit
        end loop;
        for i in r'right to r'left loop
            rs(i - res_right) := r(i);
        end loop;
        for i in r'left + 1 to res_left loop
            rs(i - res_right) := r(r'left); -- sign bit
        end loop;
        ss := ls + rs;
        return signed_to_sf(ss, res_left, res_right);
    end function;

    function "-" (l, r : unresolved_sfixed) return unresolved_sfixed is
        constant res_left  : integer := maximum(l'left, r'left) + 1;
        constant res_right : integer := minimum(l'right, r'right);
        constant res_len   : integer := res_left - res_right + 1;
        variable ls, rs    : signed(res_len - 1 downto 0);
        variable ss        : signed(res_len - 1 downto 0);
    begin
        ls := (others => '0');
        rs := (others => '0');
        for i in l'right to l'left loop
            ls(i - res_right) := l(i);
        end loop;
        for i in l'left + 1 to res_left loop
            ls(i - res_right) := l(l'left);
        end loop;
        for i in r'right to r'left loop
            rs(i - res_right) := r(i);
        end loop;
        for i in r'left + 1 to res_left loop
            rs(i - res_right) := r(r'left);
        end loop;
        ss := ls - rs;
        return signed_to_sf(ss, res_left, res_right);
    end function;

    function "*" (l, r : unresolved_sfixed) return unresolved_sfixed is
        -- Result range: l'left + r'left + 1 downto l'right + r'right
        constant res_left  : integer := l'left + r'left + 1;
        constant res_right : integer := l'right + r'right;
        variable ls : signed(l'length - 1 downto 0);
        variable rs : signed(r'length - 1 downto 0);
        variable ps : signed(l'length + r'length - 1 downto 0);
    begin
        ls := sf_to_signed(l);
        rs := sf_to_signed(r);
        ps := ls * rs;
        return signed_to_sf(ps, res_left, res_right);
    end function;

    ---------------------------------------------------------------------------
    -- resize
    ---------------------------------------------------------------------------
    function resize (
        arg      : unresolved_sfixed;
        size_res : unresolved_sfixed
    ) return unresolved_sfixed is
        constant res_left  : integer := size_res'left;
        constant res_right : integer := size_res'right;
        variable result    : unresolved_sfixed(res_left downto res_right);
    begin
        result := (others => '0');
        -- Copy overlapping bits
        for i in res_right to res_left loop
            if i >= arg'right and i <= arg'left then
                result(i) := arg(i);
            elsif i > arg'left then
                result(i) := arg(arg'left);  -- sign extend
            -- else: below arg range, leave as '0' (truncate fractional)
            end if;
        end loop;
        return result;
    end function;

    ---------------------------------------------------------------------------
    -- scalb: multiply by 2**N (effectively shift the index range)
    ---------------------------------------------------------------------------
    function scalb (
        y : unresolved_sfixed;
        N : integer
    ) return unresolved_sfixed is
        variable result : unresolved_sfixed(y'left + N downto y'right + N);
    begin
        for i in y'right to y'left loop
            result(i + N) := y(i);
        end loop;
        return result;
    end function;

    ---------------------------------------------------------------------------
    -- to_sfixed from real
    ---------------------------------------------------------------------------
    function to_sfixed (
        arg         : real;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed is
        constant LEN : integer := left_index - right_index + 1;
        variable scaled : real;
        variable ival   : integer;
        variable s      : signed(LEN - 1 downto 0);
    begin
        -- Scale: multiply by 2^(-right_index) to get integer representation
        scaled := arg * (2.0 ** (-right_index));
        if scaled >= 0.0 then
            ival := integer(floor(scaled + 0.5));
        else
            ival := integer(ceil(scaled - 0.5));
        end if;
        s := to_signed(ival, LEN);
        return signed_to_sf(s, left_index, right_index);
    end function;

    ---------------------------------------------------------------------------
    -- to_sfixed from integer
    ---------------------------------------------------------------------------
    function to_sfixed (
        arg         : integer;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed is
        constant LEN : integer := left_index - right_index + 1;
        variable s   : signed(LEN - 1 downto 0);
    begin
        -- Integer value: shift left by (-right_index) bits
        s := to_signed(arg * (2 ** (-right_index)), LEN);
        return signed_to_sf(s, left_index, right_index);
    end function;

    ---------------------------------------------------------------------------
    -- to_sfixed from std_logic_vector (reinterpret bits)
    ---------------------------------------------------------------------------
    function to_sfixed (
        arg         : std_logic_vector;
        left_index  : integer;
        right_index : integer
    ) return unresolved_sfixed is
        constant LEN : integer := left_index - right_index + 1;
        variable result : unresolved_sfixed(left_index downto right_index);
    begin
        for i in 0 to LEN - 1 loop
            result(right_index + i) := arg(i);
        end loop;
        return result;
    end function;

    ---------------------------------------------------------------------------
    -- to_slv
    ---------------------------------------------------------------------------
    function to_slv (arg : unresolved_sfixed) return std_logic_vector is
        variable result : std_logic_vector(arg'length - 1 downto 0);
    begin
        for i in 0 to arg'length - 1 loop
            result(i) := arg(arg'right + i);
        end loop;
        return result;
    end function;

end package body fixed_pkg;
