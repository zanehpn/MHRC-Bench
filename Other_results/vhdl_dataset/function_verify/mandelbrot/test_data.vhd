library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package test_data is
    function to_hex(i : std_logic_vector) return string;
    function to_hex(i : unsigned) return string;
end package test_data;

package body test_data is
    function to_hex(i : std_logic_vector) return string is
    begin
        return "0x" & to_hstring(i);
    end function;

    function to_hex(i : unsigned) return string is
    begin
        return "0x" & to_hstring(std_logic_vector(i));
    end function;
end package body test_data;
