library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity servo_controller is
    Generic (
        clock_period_ns : integer := 1024
    );
    Port (
        minimum_high_pulse_width_ns : in std_logic_vector(31 downto 0);
        maximum_high_pulse_width_ns : in std_logic_vector(31 downto 0);
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        servo_position_input : in std_logic_vector(7 downto 0);
        servo_control_out : out std_logic
    );
end entity servo_controller;

architecture rtl of servo_controller is
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                servo_control_out <= '0';
            else
                servo_control_out <= '0';
            end if;
        end if;
    end process;
end architecture;
