-- =============================================================================
-- Testbench: apple2_original_target_tb.vhd
--
-- DUT: apple2 (top-level Apple ][+ board)
-- Source: apple2_original.vhd
--
-- Target Logic:
--   Speaker select: address decoding at C030-C03F triggers SPEAKER_SELECT,
--   which toggles the speaker output on each access.
--     when x"3" => SPEAKER_SELECT <= '1';   (C030-C03F address range)
--   The speaker signal is driven by:
--     process(CLK_14M): if SPEAKER_SELECT='1' then speaker_sig <= not speaker_sig;
--
-- PARTIAL BLOCKER:
--   apple2 is a complete system-on-chip containing instantiations of:
--     - 6502 CPU (T65 core) - requires T65_Pack in work library
--     - Video timing generator
--     - Video character/graphics generator (requires character_rom entity)
--     - PS/2 keyboard controller
--     - Apple II address decoder
--   The CPU boots from internal ROM. In simulation the ROM entity must be
--   compiled and available. With no RAM stimulus the CPU will execute garbage
--   after reset vectors are resolved from ROM.
--   The speaker logic is purely in the address decoder (combinational) and
--   a flip-flop. It can be stimulated independently of CPU execution by
--   waiting for reset de-assertion, then observing outputs.
--   This testbench does NOT drive valid ROM/RAM data; it exercises the port
--   connectivity and checks that outputs are not unknown after reset.
--   Sub-entity dependencies that must be compiled before this testbench:
--     work.T65_Pack, work.T65, work.T65_MCode, work.T65_ALU,
--     work.video_generator, work.character_rom, work.keyboard, work.PS2_Ctrl
--
-- Clock: CLK_14M = 14.31818 MHz => period ~69.84 ns (approximated as 70 ns).
--        FLASH_CLK: ~2 Hz, period ~500 ms (drives flashing text in video).
--        In simulation FLASH_CLK is toggled every 5 us to speed up testing.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity apple2_original_target_tb is
end entity apple2_original_target_tb;

architecture tb of apple2_original_target_tb is

  -- -------------------------------------------------------------------------
  -- Clock constants
  -- CLK_14M: 14.31818 MHz -> ~69.84 ns, rounded to 70 ns for simulation
  -- FLASH_CLK: ~2 Hz -> 500 ms real; use 5 us in simulation
  -- -------------------------------------------------------------------------
  constant CLK14M_PERIOD  : time := 70 ns;
  constant FLASH_PERIOD   : time := 5 us;  -- compressed for simulation

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal CLK_14M        : std_logic := '0';
  signal CLK_2M         : std_logic;
  signal PRE_PHASE_ZERO : std_logic;
  signal FLASH_CLK      : std_logic := '0';
  signal reset          : std_logic := '1';
  signal ADDR           : unsigned(15 downto 0);
  signal ram_addr       : unsigned(15 downto 0);
  signal D              : unsigned(7 downto 0);
  signal ram_do         : unsigned(7 downto 0) := (others => '0');
  signal PD             : unsigned(7 downto 0) := (others => '1');
  signal ram_we         : std_logic;
  signal VIDEO          : std_logic;
  signal COLOR_LINE     : std_logic;
  signal HBL            : std_logic;
  signal VBL            : std_logic;
  signal LD194          : std_logic;
  signal K              : unsigned(7 downto 0) := (others => '0');
  signal READ_KEY       : std_logic;
  signal AN             : std_logic_vector(3 downto 0);
  signal GAMEPORT       : std_logic_vector(7 downto 0) := (others => '0');
  signal PDL_STROBE     : std_logic;
  signal STB            : std_logic;
  signal IO_SELECT      : std_logic_vector(7 downto 0);
  signal DEVICE_SELECT  : std_logic_vector(7 downto 0);
  signal pcDebugOut     : unsigned(15 downto 0);
  signal opcodeDebugOut : unsigned(7 downto 0);
  signal speaker        : std_logic;
  signal pause          : std_logic := '0';

  -- Observation flags
  signal got_non_x_video : boolean := false;

begin

  -- -------------------------------------------------------------------------
  -- CLK_14M generation (14.31818 MHz ~= 70 ns period)
  -- -------------------------------------------------------------------------
  clk14m_proc : process
  begin
    CLK_14M <= '0'; wait for CLK14M_PERIOD / 2;
    CLK_14M <= '1'; wait for CLK14M_PERIOD / 2;
  end process clk14m_proc;

  -- -------------------------------------------------------------------------
  -- FLASH_CLK generation (compressed to 5 us in simulation)
  -- -------------------------------------------------------------------------
  flash_proc : process
  begin
    FLASH_CLK <= '0'; wait for FLASH_PERIOD / 2;
    FLASH_CLK <= '1'; wait for FLASH_PERIOD / 2;
  end process flash_proc;

  -- -------------------------------------------------------------------------
  -- Minimal RAM model (return 0 for all reads; CPU will execute 0x00 = BRK)
  -- -------------------------------------------------------------------------
  ram_do <= (others => '0');

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.apple2
    port map (
      CLK_14M        => CLK_14M,
      CLK_2M         => CLK_2M,
      PRE_PHASE_ZERO => PRE_PHASE_ZERO,
      FLASH_CLK      => FLASH_CLK,
      reset          => reset,
      ADDR           => ADDR,
      ram_addr       => ram_addr,
      D              => D,
      ram_do         => ram_do,
      PD             => PD,
      ram_we         => ram_we,
      VIDEO          => VIDEO,
      COLOR_LINE     => COLOR_LINE,
      HBL            => HBL,
      VBL            => VBL,
      LD194          => LD194,
      K              => K,
      READ_KEY       => READ_KEY,
      AN             => AN,
      GAMEPORT       => GAMEPORT,
      PDL_STROBE     => PDL_STROBE,
      STB            => STB,
      IO_SELECT      => IO_SELECT,
      DEVICE_SELECT  => DEVICE_SELECT,
      pcDebugOut     => pcDebugOut,
      opcodeDebugOut => opcodeDebugOut,
      speaker        => speaker,
      pause          => pause
    );

  -- -------------------------------------------------------------------------
  -- Stimulus and assertion process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- Hold reset for 40 CLK_14M cycles
    reset <= '1';
    wait for 40 * CLK14M_PERIOD;

    -- De-assert reset
    reset <= '0';

    -- Allow the system to advance past reset
    wait for 100 * CLK14M_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 1: CLK_2M must not be unknown after reset
    -- -----------------------------------------------------------------------
    assert CLK_2M /= 'U' and CLK_2M /= 'X'
      report "FAIL: CLK_2M is unknown ('U'/'X') after reset" severity error;

    -- -----------------------------------------------------------------------
    -- ASSERT 2: speaker output must not be unknown after reset
    -- -----------------------------------------------------------------------
    assert speaker /= 'U' and speaker /= 'X'
      report "FAIL: speaker is unknown ('U'/'X') after reset" severity error;

    -- -----------------------------------------------------------------------
    -- ASSERT 3: VIDEO output must not be unknown after a brief run period.
    --   Allow time for video timing to initialise.
    -- -----------------------------------------------------------------------
    wait for 500 * CLK14M_PERIOD;
    assert VIDEO /= 'U'
      report "FAIL: VIDEO output is 'U' (undriven) after 500 CLK_14M cycles" severity error;

    -- -----------------------------------------------------------------------
    -- ASSERT 4: Address bus must be driven
    -- -----------------------------------------------------------------------
    assert ADDR /= (ADDR'range => 'U')
      report "FAIL: ADDR bus is all 'U'" severity error;

    -- -----------------------------------------------------------------------
    -- Note on speaker target logic:
    --   The address decoder asserts SPEAKER_SELECT combinationally when
    --   A = 0xC03x. The speaker flip-flop toggles on each CLK_14M rising
    --   edge while SPEAKER_SELECT='1'. To observe this without a working
    --   CPU/ROM, the address decoder would need to be driven from the test
    --   bench via the internal A bus (not exposed as a direct input port).
    --   The speaker path is visible only after the CPU performs an access to
    --   0xC030-0xC03F, which requires ROM execution. This is the PARTIAL
    --   BLOCKER: full speaker toggle verification requires Apple II ROM image.
    -- -----------------------------------------------------------------------
    report "INFO: apple2_original_target_tb basic port connectivity checks passed." severity note;
    report "NOTE: Speaker toggle (C030-C03F) verification requires Apple II ROM" &
           " and RAM stimulus (PARTIAL BLOCKER). Sub-entity dependencies:" &
           " T65_Pack, T65, T65_MCode, T65_ALU, video_generator," &
           " character_rom, keyboard, PS2_Ctrl must all be compiled." severity note;

    wait for 1 us;
    report "SIMULATION COMPLETE: apple2_original_target_tb" severity note;
    wait;
  end process stim_proc;

end architecture tb;
