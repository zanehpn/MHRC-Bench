library ieee;
use ieee.std_logic_1164.all;

entity debounce is
  generic (
    WAIT_CYCLES : integer := 4
  );
  port (
    clk        : in  std_logic;
    signal_in  : in  std_logic;
    signal_out : out std_logic
  );
end entity debounce;

architecture rtl of debounce is
  signal count : integer range 0 to WAIT_CYCLES := 0;
  signal sig_out_reg : std_logic := '0';
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if signal_in /= sig_out_reg then
        if count = WAIT_CYCLES then
          sig_out_reg <= signal_in;
          count <= 0;
        else
          count <= count + 1;
        end if;
      else
        count <= 0;
      end if;
    end if;
  end process;
  signal_out <= sig_out_reg;
end architecture;
