--------------------------------------------------------------------------------
-- Testbench: mandelbrot_target_tb.vhd
-- DUT: Mandelbrot (mandelbrot_original.vhdl — lowercase variant)
--
-- The DUT is identical in functionality to the uppercase Mandelbrot variant.
-- Target lines: reset clears output_offset/output_number; outputs are clocked.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mandelbrot_target_tb is
end entity mandelbrot_target_tb;

architecture tb of mandelbrot_target_tb is

    constant C_CLK_PERIOD     : time    := 10 ns;
    constant PIPELINE_DEPTH   : integer := 7;
    constant MAX_WAIT_CYCLES  : integer := 3000;

    -- Fixed-point coordinates: sfixed(5 downto -26)
    -- Value = signed_integer / 2^26
    constant COORD_POS2  : std_logic_vector(31 downto 0) := x"08000000"; -- 2.0
    constant COORD_ZERO  : std_logic_vector(31 downto 0) := x"00000000"; -- 0.0
    constant OFFSET_A    : unsigned(31 downto 0) := to_unsigned(16#AA#, 32);
    constant OFFSET_B    : unsigned(31 downto 0) := to_unsigned(16#BB#, 32);

    signal clk_s               : std_logic := '0';
    signal rst_s               : std_logic := '1';
    signal input_x_s           : std_logic_vector(31 downto 0) := (others => '0');
    signal input_y_s           : std_logic_vector(31 downto 0) := (others => '0');
    signal input_offset_s      : unsigned(31 downto 0)         := (others => '0');
    signal new_input_arrived_s : std_logic := '0';
    signal new_input_ack_s     : std_logic;
    signal output_number_s     : unsigned(7 downto 0);
    signal output_offset_s     : unsigned(31 downto 0);
    signal new_output_made_s   : std_logic;

    -- Monitor: capture latest iteration count per offset
    signal cap_num_a  : unsigned(7 downto 0) := (others => '0');
    signal cap_seen_a : std_logic := '0';
    signal cap_num_b  : unsigned(7 downto 0) := (others => '0');
    signal cap_seen_b : std_logic := '0';

begin

    clk_gen : process
    begin
        loop
            clk_s <= '0'; wait for C_CLK_PERIOD / 2;
            clk_s <= '1'; wait for C_CLK_PERIOD / 2;
        end loop;
    end process;

    DUT : entity work.Mandelbrot
        port map (
            CLK               => clk_s,
            RST               => rst_s,
            input_x           => input_x_s,
            input_y           => input_y_s,
            input_offset      => input_offset_s,
            new_input_arrived => new_input_arrived_s,
            new_input_ack     => new_input_ack_s,
            output_number     => output_number_s,
            output_offset     => output_offset_s,
            new_output_made   => new_output_made_s
        );

    -- Monitor process: latch latest output_number for each offset
    monitor : process (clk_s)
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' then
                cap_seen_a <= '0';
                cap_seen_b <= '0';
            else
                if new_output_made_s = '1' and output_offset_s = OFFSET_A then
                    cap_num_a  <= output_number_s;
                    cap_seen_a <= '1';
                end if;
                if new_output_made_s = '1' and output_offset_s = OFFSET_B then
                    cap_num_b  <= output_number_s;
                    cap_seen_b <= '1';
                end if;
            end if;
        end if;
    end process;

    stim_proc : process
        variable cycles : integer := 0;

        procedure wait_clocks(n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk_s);
            end loop;
        end procedure;

        procedure present_input(
            x      : std_logic_vector(31 downto 0);
            y      : std_logic_vector(31 downto 0);
            offset : unsigned(31 downto 0)
        ) is
        begin
            input_x_s           <= x;
            input_y_s           <= y;
            input_offset_s      <= offset;
            new_input_arrived_s <= '1';
            cycles := 0;
            loop
                wait until rising_edge(clk_s);
                cycles := cycles + 1;
                exit when new_input_ack_s = '1' or cycles >= 30;
            end loop;
            assert new_input_ack_s = '1'
                report "FAIL: new_input_ack not received within 30 cycles"
                severity failure;
            new_input_arrived_s <= '0';
            wait_clocks(1);
        end procedure;

    begin
        -- Reset
        rst_s <= '1';
        wait_clocks(10);

        -- Assert 1: outputs cleared during reset
        assert output_offset_s = x"00000000"
            report "FAIL Assert 1a: output_offset not 0 during reset"
            severity failure;
        assert output_number_s = x"00"
            report "FAIL Assert 1b: output_number not X00 during reset"
            severity failure;
        report "Assert 1 PASSED: outputs cleared under reset" severity note;

        -- Release reset
        rst_s <= '0';
        wait_clocks(5);

        -- Test A: outside-set point (2.0, 0.0)
        present_input(COORD_POS2, COORD_ZERO, OFFSET_A);
        wait_clocks(PIPELINE_DEPTH * 4);

        assert cap_seen_a = '1'
            report "FAIL Assert 3: no output for outside-set point"
            severity failure;
        report "Test A PASSED: outside-set output received. output_number="
               & integer'image(to_integer(cap_num_a))
               severity note;

        -- Test B: inside-set point (0.0, 0.0) — hits 239 iteration cap
        present_input(COORD_ZERO, COORD_ZERO, OFFSET_B);
        wait_clocks(MAX_WAIT_CYCLES);

        assert cap_seen_b = '1'
            report "FAIL Assert 6: no output for inside-set point"
            severity failure;
        assert cap_num_b >= to_unsigned(239, 8)
            report "FAIL Assert 8: inside-set iter should be >=239. Got="
                   & integer'image(to_integer(cap_num_b))
            severity failure;
        report "Test B PASSED: inside-set hit cap. output_number="
               & integer'image(to_integer(cap_num_b))
               severity note;

        -- Assert 9: re-apply reset, verify outputs cleared
        wait_clocks(5);
        rst_s <= '1';
        wait_clocks(5);
        assert output_offset_s = x"00000000"
            report "FAIL Assert 9a: output_offset not cleared on second reset"
            severity failure;
        assert output_number_s = x"00"
            report "FAIL Assert 9b: output_number not cleared on second reset"
            severity failure;
        report "Assert 9 PASSED: outputs cleared on second reset" severity note;

        rst_s <= '0';
        wait_clocks(5);

        report "mandelbrot_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process stim_proc;

end architecture tb;
