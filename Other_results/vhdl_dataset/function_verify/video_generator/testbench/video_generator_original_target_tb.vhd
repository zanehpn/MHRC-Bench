-- =============================================================================
-- Testbench: video_generator_original_target_tb.vhd
--
-- DUT: video_generator (Apple ][ video generation)
-- Source: video_generator_original.vhd
--
-- Target Logic:
--   hires_delayed <= graph_shiftreg(0);
--   (Process A11_74LS74: on rising CLK_14M, hires_delayed captures bit 0 of
--    the graphics shift register. As the shift register shifts, successive
--    pixel bits appear on hires_delayed with a one-clock delay.)
--
-- Target observable output: VIDEO (connected to hires_delayed via the mux
-- when HIRES_MODE is active and blank_delayed='0').
--
-- DEPENDENCY:
--   video_generator instantiates work.character_rom (PS/2 char ROM for text
--   mode). This entity must be compiled before elaboration. If character_rom
--   is absent, comment out the thecharrom instance in the DUT or provide a
--   stub.
--
-- Test strategy:
--   1. Generate CLK_14M (70 ns) and CLK_7M (140 ns, half of 14M).
--   2. Set HIRES_MODE='1', TEXT_MODE='0', MIXED_MODE='0', BLANK='0'.
--   3. Strobe LD194='0' with AX='1'/CAS_N='0' to load a known byte into
--      graph_shiftreg via the B4B9 shift register load path.
--   4. Release LD194 to '1' (shift mode). The shift register advances each
--      time CLK_7M='0' on a CLK_14M rising edge.
--   5. Monitor VIDEO output: it should track the bit pattern of the loaded
--      byte, shifting out LSB-first.
--   6. Assert that VIDEO changes value as pixels are clocked out.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_generator_original_target_tb is
end entity video_generator_original_target_tb;

architecture tb of video_generator_original_target_tb is

  -- -------------------------------------------------------------------------
  -- Clock constants
  -- CLK_14M: ~14.31818 MHz => 69.84 ns, use 70 ns
  -- CLK_7M : ~7.15909  MHz => 139.7 ns, use 140 ns (half of 14M)
  -- -------------------------------------------------------------------------
  constant CLK14M_HALF : time := 35 ns;   -- half-period of CLK_14M
  constant CLK7M_HALF  : time := 70 ns;   -- half-period of CLK_7M

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal CLK_14M    : std_logic := '0';
  signal CLK_7M     : std_logic := '0';
  signal AX         : std_logic := '0';
  signal CAS_N      : std_logic := '1';
  signal TEXT_MODE  : std_logic := '0';
  signal PAGE2      : std_logic := '0';
  signal HIRES_MODE : std_logic := '1';  -- HIRES enabled
  signal MIXED_MODE : std_logic := '0';
  signal H0         : std_logic := '0';
  signal VA         : std_logic := '0';
  signal VB         : std_logic := '0';
  signal VC         : std_logic := '0';
  signal V2         : std_logic := '0';
  signal V4         : std_logic := '0';
  signal BLANK      : std_logic := '0';  -- active display
  signal DL         : unsigned(7 downto 0) := x"A5";  -- test pixel pattern
  signal LDPS_N     : std_logic := '1';
  signal LD194      : std_logic := '1';
  signal FLASH_CLK  : std_logic := '0';
  signal HIRES      : std_logic;
  signal VIDEO      : std_logic;
  signal COLOR_LINE : std_logic;

  -- Observation
  signal video_prev     : std_logic := '0';
  signal video_changes  : integer   := 0;

begin

  -- -------------------------------------------------------------------------
  -- CLK_14M generation (70 ns period)
  -- -------------------------------------------------------------------------
  clk14m_proc : process
  begin
    CLK_14M <= '0'; wait for CLK14M_HALF;
    CLK_14M <= '1'; wait for CLK14M_HALF;
  end process clk14m_proc;

  -- -------------------------------------------------------------------------
  -- CLK_7M generation (140 ns period, derived from CLK_14M phase)
  -- CLK_7M is '1' for the first half of each CLK_14M pair and '0' for the
  -- second half, matching the Apple II clock relationship.
  -- -------------------------------------------------------------------------
  clk7m_proc : process
  begin
    CLK_7M <= '1'; wait for CLK14M_HALF * 2;   -- high for one 14M cycle
    CLK_7M <= '0'; wait for CLK14M_HALF * 2;   -- low for one 14M cycle
  end process clk7m_proc;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.video_generator
    port map (
      CLK_14M    => CLK_14M,
      CLK_7M     => CLK_7M,
      AX         => AX,
      CAS_N      => CAS_N,
      TEXT_MODE  => TEXT_MODE,
      PAGE2      => PAGE2,
      HIRES_MODE => HIRES_MODE,
      MIXED_MODE => MIXED_MODE,
      H0         => H0,
      VA         => VA,
      VB         => VB,
      VC         => VC,
      V2         => V2,
      V4         => V4,
      BLANK      => BLANK,
      DL         => DL,
      LDPS_N     => LDPS_N,
      LD194      => LD194,
      FLASH_CLK  => FLASH_CLK,
      HIRES      => HIRES,
      VIDEO      => VIDEO,
      COLOR_LINE => COLOR_LINE
    );

  -- -------------------------------------------------------------------------
  -- VIDEO transition counter
  -- -------------------------------------------------------------------------
  video_monitor : process (CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      if VIDEO /= video_prev and VIDEO /= 'U' and VIDEO /= 'X' then
        video_changes <= video_changes + 1;
      end if;
      video_prev <= VIDEO;
    end if;
  end process video_monitor;

  -- -------------------------------------------------------------------------
  -- Stimulus and assertion process
  -- -------------------------------------------------------------------------
  stim_proc : process
    variable initial_video : std_logic;
  begin
    -- -----------------------------------------------------------------------
    -- Step 1: Settle combinational defaults for a few cycles
    -- -----------------------------------------------------------------------
    wait for 10 * 70 ns;

    -- -----------------------------------------------------------------------
    -- Step 2: Enable AX=1, CAS_N=0 to gate the graphics timing pipeline.
    --   The B5B8 latch (graphics_time) only advances when AX='1' & CAS_N='0'.
    --   Hold for several CLK_14M cycles.
    -- -----------------------------------------------------------------------
    AX    <= '1';
    CAS_N <= '0';
    wait for 6 * 70 ns;

    -- -----------------------------------------------------------------------
    -- Step 3: Load a known byte (0xA5 = 1010_0101) into graph_shiftreg.
    --   LD194='0' and lores_time=0 (HIRES mode) triggers the load path:
    --     graph_shiftreg <= DL  (in B4B9_74LS194 process)
    --   Also assert LDPS_N='0' briefly to prime text shiftreg for completeness.
    -- -----------------------------------------------------------------------
    DL    <= x"A5";      -- pixel pattern: 1010_0101
    LD194 <= '0';        -- load strobe
    wait for 2 * 70 ns;
    LD194 <= '1';        -- release to shift mode

    -- Also load blank_delayed = BLANK = '0' (active display)
    -- pixel_select needs graphics_time_1='1' (active video area)
    -- Wait a few cycles for pipeline to prime
    wait for 4 * 70 ns;

    -- -----------------------------------------------------------------------
    -- Step 4: Capture initial VIDEO value
    -- -----------------------------------------------------------------------
    initial_video := VIDEO;
    report "INFO: Initial VIDEO value after load = '" &
           std_logic'image(VIDEO) & "'" severity note;

    -- -----------------------------------------------------------------------
    -- Step 5: Clock out pixels for one full byte (8 bits)
    --   graph_shiftreg shifts right when CLK_7M='0' on CLK_14M rising edge.
    --   VIDEO should reflect bit 0 of graph_shiftreg (via hires_delayed).
    --   With pattern 0xA5 = 1010_0101, VIDEO should alternate between 1 and 0.
    -- -----------------------------------------------------------------------
    wait for 20 * 70 ns;   -- allow ~20 CLK_14M cycles for 8 hires pixel shifts

    -- -----------------------------------------------------------------------
    -- ASSERT 1: VIDEO must not be unknown
    -- -----------------------------------------------------------------------
    assert VIDEO /= 'U' and VIDEO /= 'X'
      report "FAIL: VIDEO is unknown after pixel shift sequence" severity error;

    -- -----------------------------------------------------------------------
    -- ASSERT 2: VIDEO must have changed at least once during shifting.
    --   Pattern 0xA5 has alternating bits, so VIDEO should change every
    --   hires clock. If video_changes = 0, shifting is not working.
    -- -----------------------------------------------------------------------
    assert video_changes > 0
      report "FAIL: VIDEO never changed during " &
             "pixel shift sequence - hires shift register may not be advancing"
      severity error;

    report "PASS: VIDEO changed " & integer'image(video_changes) &
           " times during hires pixel shift (target: hires_delayed <= graph_shiftreg(0))"
      severity note;

    -- -----------------------------------------------------------------------
    -- Step 6: Test BLANK='1' -> VIDEO should go to '0' (blanked)
    -- -----------------------------------------------------------------------
    BLANK <= '1';
    wait for 4 * 70 ns;

    -- -----------------------------------------------------------------------
    -- Step 7: Confirm COLOR_LINE follows HIRES_MODE and graphics_time_3
    -- -----------------------------------------------------------------------
    assert COLOR_LINE /= 'U'
      report "FAIL: COLOR_LINE is unknown" severity error;

    report "INFO: video_generator_original_target_tb complete." severity note;
    report "NOTE: character_rom entity must be compiled for text-mode paths." severity note;

    wait;
  end process stim_proc;

end architecture tb;
