library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package VComponents is

    component ODDR
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
    end component;

end package VComponents;
