-------------------------------------------------------------------------------
-- Testbench: Mandelbrot_target_tb.vhd
-- DUT: Mandelbrot engine (Mandelbrot_original.vhd)
--
-- Target lines under test: reset clears output_offset/output_number to zero;
-- outputs are only updated on rising_edge(clk) (not combinationally).
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Mandelbrot_target_tb is
end entity Mandelbrot_target_tb;

architecture tb of Mandelbrot_target_tb is

    constant CLK_PERIOD      : time    := 10 ns;
    constant PIPELINE_DEPTH  : integer := 7;
    -- 240 iterations * 7 depth + margin
    constant MAX_WAIT_CYCLES : integer := 3000;

    -- Fixed-point coordinate values (sfixed(5 downto -26))
    constant COORD_POS2  : std_logic_vector(31 downto 0) := x"08000000"; -- 2.0
    constant COORD_ZERO  : std_logic_vector(31 downto 0) := x"00000000"; -- 0.0
    constant OFFSET_A    : unsigned(31 downto 0) := to_unsigned(16#AA#, 32);
    constant OFFSET_B    : unsigned(31 downto 0) := to_unsigned(16#BB#, 32);

    signal clk               : std_logic := '0';
    signal rst               : std_logic := '1';
    signal input_x           : std_logic_vector(31 downto 0) := (others => '0');
    signal input_y           : std_logic_vector(31 downto 0) := (others => '0');
    signal input_offset      : unsigned(31 downto 0)         := (others => '0');
    signal new_input_arrived : std_logic := '0';
    signal new_input_ack     : std_logic;
    signal output_number     : unsigned(7 downto 0);
    signal output_offset     : unsigned(31 downto 0);
    signal new_output_made   : std_logic;

    -- Monitor: capture last output_number for each expected offset
    signal captured_number_a : unsigned(7 downto 0) := (others => '0');
    signal captured_seen_a   : std_logic := '0';
    signal captured_number_b : unsigned(7 downto 0) := (others => '0');
    signal captured_seen_b   : std_logic := '0';

begin

    DUT : entity work.Mandelbrot
        port map (
            CLK               => clk,
            RST               => rst,
            input_x           => input_x,
            input_y           => input_y,
            input_offset      => input_offset,
            new_input_arrived => new_input_arrived,
            new_input_ack     => new_input_ack,
            output_number     => output_number,
            output_offset     => output_offset,
            new_output_made   => new_output_made
        );

    clk_gen : process
    begin
        loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
    end process clk_gen;

    -- Monitor: latch latest output_number for each offset tag
    monitor : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                captured_seen_a <= '0';
                captured_seen_b <= '0';
            else
                if new_output_made = '1' and output_offset = OFFSET_A then
                    captured_number_a <= output_number;
                    captured_seen_a   <= '1';
                end if;
                if new_output_made = '1' and output_offset = OFFSET_B then
                    captured_number_b <= output_number;
                    captured_seen_b   <= '1';
                end if;
            end if;
        end if;
    end process;

    stim : process
        variable cycles : integer := 0;

        procedure wait_clocks(n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure present_input(
            x      : std_logic_vector(31 downto 0);
            y      : std_logic_vector(31 downto 0);
            offset : unsigned(31 downto 0)
        ) is
        begin
            input_x           <= x;
            input_y           <= y;
            input_offset      <= offset;
            new_input_arrived <= '1';
            cycles := 0;
            loop
                wait until rising_edge(clk);
                cycles := cycles + 1;
                exit when new_input_ack = '1' or cycles >= 30;
            end loop;
            assert new_input_ack = '1'
                report "FAIL: new_input_ack not received within 30 cycles"
                severity failure;
            new_input_arrived <= '0';
            wait_clocks(1);
        end procedure;

    begin
        -----------------------------------------------------------------------
        -- Reset phase
        -----------------------------------------------------------------------
        rst <= '1';
        wait_clocks(10);

        -- Assert 1 (TARGET): outputs cleared during reset
        assert output_offset = x"00000000"
            report "FAIL Assert 1a: output_offset not 0 during reset"
            severity failure;
        assert output_number = x"00"
            report "FAIL Assert 1b: output_number not X00 during reset"
            severity failure;
        report "Assert 1 PASSED: outputs cleared under reset" severity note;

        -----------------------------------------------------------------------
        -- Release reset
        -----------------------------------------------------------------------
        rst <= '0';
        wait_clocks(5);

        -- Assert 2 (TARGET): outputs stable zero after reset
        assert output_offset = x"00000000"
            report "FAIL Assert 2: output_offset non-zero after reset release"
            severity failure;
        report "Assert 2 PASSED: outputs stable after reset" severity note;

        -----------------------------------------------------------------------
        -- Test A: outside-set point (2.0, 0.0) — diverges immediately
        -----------------------------------------------------------------------
        present_input(COORD_POS2, COORD_ZERO, OFFSET_A);

        -- Wait for pipeline to process (outside-set diverges in ~1 rotation)
        wait_clocks(PIPELINE_DEPTH * 4);

        assert captured_seen_a = '1'
            report "FAIL Assert 3: no output seen for outside-set point"
            severity failure;
        report "Test A PASSED: outside-set output received. output_number="
               & integer'image(to_integer(captured_number_a))
               severity note;

        -----------------------------------------------------------------------
        -- Test B: inside-set point (0.0, 0.0) — hits 239 iteration cap
        -- This takes ~240 pipeline rotations.
        -----------------------------------------------------------------------
        present_input(COORD_ZERO, COORD_ZERO, OFFSET_B);

        -- Wait for computation to complete
        wait_clocks(MAX_WAIT_CYCLES);

        assert captured_seen_b = '1'
            report "FAIL Assert 6: no output seen for inside-set point"
            severity failure;

        assert captured_number_b >= to_unsigned(239, 8)
            report "FAIL Assert 8: inside-set iter should be >=239. Got="
                   & integer'image(to_integer(captured_number_b))
            severity failure;

        report "Test B PASSED: inside-set hit cap. output_number="
               & integer'image(to_integer(captured_number_b))
               severity note;

        -----------------------------------------------------------------------
        -- Assert 9 (TARGET): re-apply reset, verify outputs cleared
        -----------------------------------------------------------------------
        wait_clocks(5);
        rst <= '1';
        wait_clocks(5);
        assert output_offset = x"00000000"
            report "FAIL Assert 9a: output_offset not cleared on second reset"
            severity failure;
        assert output_number = x"00"
            report "FAIL Assert 9b: output_number not cleared on second reset"
            severity failure;
        report "Assert 9 PASSED: outputs cleared on second reset" severity note;

        rst <= '0';
        wait_clocks(5);

        report "Mandelbrot_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process stim;

end architecture tb;
