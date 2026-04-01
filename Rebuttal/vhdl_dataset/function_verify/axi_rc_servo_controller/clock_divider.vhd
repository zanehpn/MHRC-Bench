library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clock_divider is
    Generic (
        Slow_Clock_Period_PS : integer := 128000;
        ORIGINAL_CLK_PERIOD_PS : integer := 10000
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        slow_clk : out std_logic;
        slow_rst : out std_logic
    );
end entity clock_divider;

architecture rtl of clock_divider is
    constant DIV_RATIO : integer := Slow_Clock_Period_PS / ORIGINAL_CLK_PERIOD_PS / 2;
    signal count : integer range 0 to DIV_RATIO := 0;
    signal clk_reg : std_logic := '0';
    signal rst_sync : std_logic := '1';
    signal rst_sync2 : std_logic := '1';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count <= 0;
                clk_reg <= '0';
                rst_sync <= '1';
                rst_sync2 <= '1';
            else
                rst_sync2 <= rst_sync;
                rst_sync <= '0';
                if count = DIV_RATIO - 1 then
                    count <= 0;
                    clk_reg <= not clk_reg;
                else
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;
    slow_clk <= clk_reg;
    slow_rst <= rst_sync2;
end architecture;
