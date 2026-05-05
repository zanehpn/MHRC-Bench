library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ODDR is
    generic (
        DDR_CLK_EDGE : string := "SAME_EDGE";
        INIT         : bit    := '0';
        SRTYPE       : string := "SYNC"
    );
    port (
        Q  : out std_logic;
        C  : in  std_logic;
        CE : in  std_logic;
        R  : in  std_logic;
        S  : in  std_logic;
        D1 : in  std_logic;
        D2 : in  std_logic
    );
end entity ODDR;

architecture behavioral of ODDR is
begin
    process (C)
    begin
        if rising_edge(C) then
            if R = '1' then
                Q <= '0';
            elsif S = '1' then
                Q <= '1';
            elsif CE = '1' then
                Q <= D1;
            end if;
        end if;
        if falling_edge(C) then
            if R = '1' then
                Q <= '0';
            elsif S = '1' then
                Q <= '1';
            elsif CE = '1' then
                Q <= D2;
            end if;
        end if;
    end process;
end architecture behavioral;
