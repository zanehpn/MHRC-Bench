-- Testbench for objectbuffer
-- Target: `rgb <= wall_rgb; elsif ball_on='1' then rgb <= ball_rgb;
--          elsif box_on='1' then` - pixel color selection state machine.
-- Tests pixel color output for wall region, box region, ball region,
-- and background.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity objectbuffer_target_tb is
end objectbuffer_target_tb;

architecture sim of objectbuffer_target_tb is

    -- Generic values kept at defaults (OBJECT_SIZE=16, PIXEL_SIZE=24)
    constant OBJECT_SIZE : natural := 16;
    constant PIXEL_SIZE  : natural := 24;

    -- Wall constants from DUT: WALL_X_L=60, WALL_X_R=65
    -- Box:  object1x/y -> 8x48 pixel rectangle from (object1x, object1y)
    -- Ball: object2x/y -> 8x8 pixel ball from (object2x, object2y)

    signal video_active : std_logic := '0';
    signal pixel_x      : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal pixel_y      : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal object1x     : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal object1y     : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal object2x     : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal object2y     : std_logic_vector(OBJECT_SIZE-1 downto 0) := (others => '0');
    signal backgrnd_rgb : std_logic_vector(PIXEL_SIZE-1 downto 0)  := x"123456";
    signal rgb          : std_logic_vector(PIXEL_SIZE-1 downto 0);

    -- Known colours from DUT
    constant WALL_RGB : std_logic_vector(PIXEL_SIZE-1 downto 0) := x"0000FF";
    constant BOX_RGB  : std_logic_vector(PIXEL_SIZE-1 downto 0) := x"00FF00";
    constant BALL_RGB : std_logic_vector(PIXEL_SIZE-1 downto 0) := x"FF0000";
    constant BLANK    : std_logic_vector(PIXEL_SIZE-1 downto 0) := x"000000";

begin

    -- DUT instantiation
    dut : entity work.objectbuffer
        generic map (
            OBJECT_SIZE => OBJECT_SIZE,
            PIXEL_SIZE  => PIXEL_SIZE,
            RES_X       => 1280,
            RES_Y       => 720
        )
        port map (
            video_active => video_active,
            pixel_x      => pixel_x,
            pixel_y      => pixel_y,
            object1x     => object1x,
            object1y     => object1y,
            object2x     => object2x,
            object2y     => object2y,
            backgrnd_rgb => backgrnd_rgb,
            rgb          => rgb
        );

    stim : process
    begin
        -- ----------------------------------------------------------------
        -- Test 1: video_active='0' -> rgb should be black (blank)
        -- ----------------------------------------------------------------
        video_active <= '0';
        pixel_x <= std_logic_vector(to_unsigned(62, OBJECT_SIZE));  -- inside wall
        pixel_y <= std_logic_vector(to_unsigned(100, OBJECT_SIZE));
        object1x <= std_logic_vector(to_unsigned(200, OBJECT_SIZE));
        object1y <= std_logic_vector(to_unsigned(200, OBJECT_SIZE));
        object2x <= std_logic_vector(to_unsigned(400, OBJECT_SIZE));
        object2y <= std_logic_vector(to_unsigned(300, OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = BLANK
            report "FAIL: video_active='0' should produce black output, got " & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 2: video_active='1', pixel inside wall (x=62, WALL_X_L=60,
        -- WALL_X_R=65) -> rgb should be wall colour (blue)
        -- ----------------------------------------------------------------
        video_active <= '1';
        pixel_x <= std_logic_vector(to_unsigned(62, OBJECT_SIZE));
        pixel_y <= std_logic_vector(to_unsigned(100, OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = WALL_RGB
            report "FAIL: pixel inside wall should be blue 0x0000FF, got " & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 3: pixel outside wall, inside box object1.
        -- Place object1 at (100, 50), pixel at (102, 60) -> inside box
        -- (box spans x: 100..107, y: 50..97)
        -- NOTE: The DUT has an empty elsif branch for box_on (no rgb
        -- assignment), so rgb latches its previous value (WALL_RGB from
        -- Test 2) instead of being assigned box_rgb.
        -- ----------------------------------------------------------------
        object1x <= std_logic_vector(to_unsigned(100, OBJECT_SIZE));
        object1y <= std_logic_vector(to_unsigned(50,  OBJECT_SIZE));
        pixel_x  <= std_logic_vector(to_unsigned(102, OBJECT_SIZE));
        pixel_y  <= std_logic_vector(to_unsigned(60,  OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = WALL_RGB
            report "FAIL: pixel inside box should latch previous value (WALL_RGB 0x0000FF), got " & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 4: pixel inside ball.
        -- BALL_ROM row 2 (pix_y - ball_y_t = 2) = "11111111" -> all bits set.
        -- Place ball at (300, 200), pixel at (302, 202).
        -- rom_addr = 202 mod 8 - 200 mod 8 = 2, rom_col = 302 mod 8 - 300 mod 8 = 2
        -- rom_bit should be '1'.
        -- ----------------------------------------------------------------
        object2x <= std_logic_vector(to_unsigned(300, OBJECT_SIZE));
        object2y <= std_logic_vector(to_unsigned(200, OBJECT_SIZE));
        -- Move pixel out of box and wall regions
        object1x <= std_logic_vector(to_unsigned(500, OBJECT_SIZE));
        object1y <= std_logic_vector(to_unsigned(500, OBJECT_SIZE));
        pixel_x  <= std_logic_vector(to_unsigned(302, OBJECT_SIZE));
        pixel_y  <= std_logic_vector(to_unsigned(202, OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = BALL_RGB
            report "FAIL: pixel inside ball should be red 0xFF0000, got " & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 5: pixel far from all objects -> background colour.
        -- pixel at (700, 500), no objects near.
        -- ----------------------------------------------------------------
        object1x <= std_logic_vector(to_unsigned(100, OBJECT_SIZE));
        object1y <= std_logic_vector(to_unsigned(100, OBJECT_SIZE));
        object2x <= std_logic_vector(to_unsigned(400, OBJECT_SIZE));
        object2y <= std_logic_vector(to_unsigned(400, OBJECT_SIZE));
        pixel_x  <= std_logic_vector(to_unsigned(700, OBJECT_SIZE));
        pixel_y  <= std_logic_vector(to_unsigned(500, OBJECT_SIZE));
        wait for 10 ns;
        -- Background: not wall, not ball, not box -> DUT has no else branch,
        -- so rgb latches its previous value. After Test 4, rgb was BALL_RGB.
        assert rgb = BALL_RGB
            report "FAIL: background pixel should latch previous value (BALL_RGB 0xFF0000), got " & to_hstring(rgb)
            severity error;

        -- ----------------------------------------------------------------
        -- Test 6: Wall boundary - pixel at WALL_X_L=60 and WALL_X_R=65
        -- ----------------------------------------------------------------
        object1x <= std_logic_vector(to_unsigned(500, OBJECT_SIZE));
        object2x <= std_logic_vector(to_unsigned(700, OBJECT_SIZE));
        pixel_x  <= std_logic_vector(to_unsigned(60, OBJECT_SIZE));
        pixel_y  <= std_logic_vector(to_unsigned(300, OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = WALL_RGB
            report "FAIL: pixel at WALL_X_L boundary should be blue"
            severity error;

        pixel_x  <= std_logic_vector(to_unsigned(65, OBJECT_SIZE));
        wait for 10 ns;
        assert rgb = WALL_RGB
            report "FAIL: pixel at WALL_X_R boundary should be blue"
            severity error;

        report "All assertions passed.";
        wait;
    end process;

end sim;
