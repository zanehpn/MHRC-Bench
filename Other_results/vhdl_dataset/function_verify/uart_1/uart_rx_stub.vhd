--------------------------------------------------------------------------------
-- UART RX STUB
-- Minimal safe-output stub for UART_RX used by the top-level UART entity.
-- Does NOT decode UART data; simply drives all outputs to safe defaults.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_RX is
    Generic (
        CLK_DIV_VAL : integer := 16;    -- clock divider value for UART bit rate
        PARITY_BIT  : string  := "none" -- type of parity: "none", "even", "odd", "mark", "space"
    );
    Port (
        -- CLOCK AND RESET
        CLK          : in  std_logic;
        RST          : in  std_logic;
        -- UART INTERFACE
        UART_CLK_EN  : in  std_logic;
        UART_RXD     : in  std_logic;
        -- USER DATA OUTPUT INTERFACE
        DOUT         : out std_logic_vector(7 downto 0);
        DOUT_VLD     : out std_logic;
        FRAME_ERROR  : out std_logic;
        PARITY_ERROR : out std_logic
    );
end entity;

architecture STUB of UART_RX is
begin

    DOUT         <= (others => '0');
    DOUT_VLD     <= '0';
    FRAME_ERROR  <= '0';
    PARITY_ERROR <= '0';

end architecture;
