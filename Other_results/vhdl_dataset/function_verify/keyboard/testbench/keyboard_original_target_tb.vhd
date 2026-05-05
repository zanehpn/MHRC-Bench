-- =============================================================================
-- Testbench: keyboard_original_target_tb.vhd
--
-- DUT: keyboard (Apple ][ PS/2 keyboard interface)
-- Source: keyboard_original.vhd
--
-- Target Logic:
--   if state = NORMAL_KEY then
--     latched_code <= code;
--     key_pressed  <= '1';
--   end if;
--   Observable via: K(7) = key_pressed bit (MSB of output K)
--
-- DEPENDENCY:
--   keyboard instantiates work.PS2_Ctrl (PS/2 protocol controller).
--   PS2_Ctrl.vhd must be compiled into 'work' before this testbench.
--
-- Test strategy:
--   The PS/2 protocol sends data LSB-first in an 11-bit frame:
--     [start=0] [D0..D7] [parity(odd)] [stop=1]
--   The host (keyboard) drives PS2_Clk low for each bit, with PS2_Data
--   set before the falling edge. PS2_Ctrl samples PS2_Data on falling
--   PS2_Clk edges.
--
--   PS/2 clock rate: typical 10-16 kHz. Using ~15 kHz here: ~67 us/bit.
--   CLK_14M: 70 ns period; PS2 clk cell = ~67 us >> CLK_14M.
--
--   Key pressed: scancode 0x1C ('A' key in Set 2 PS/2).
--   Scancode 0x1C is a normal key (not a modifier, not KEY_UP_CODE,
--   not EXTENDED_CODE). The FSM should reach NORMAL_KEY and set key_pressed.
--   Observable: K(7) goes high (key_pressed = '1' in the MSB of K output).
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keyboard_original_target_tb is
end entity keyboard_original_target_tb;

architecture tb of keyboard_original_target_tb is

  -- -------------------------------------------------------------------------
  -- Clock constants
  -- -------------------------------------------------------------------------
  constant CLK14M_PERIOD : time := 70 ns;   -- 14.31818 MHz

  -- PS/2 timing: ~15 kHz clock -> bit cell ~67 us; use 60 us for simulation
  constant PS2_HALF_PERIOD : time := 30 us;

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal PS2_Clk  : std_logic := '1';   -- idle high
  signal PS2_Data : std_logic := '1';   -- idle high
  signal CLK_14M  : std_logic := '0';
  signal read     : std_logic := '0';
  signal reset    : std_logic := '1';
  signal K        : unsigned(7 downto 0);

  -- Aliases for clarity
  alias key_pressed_out : std_logic is K(7);

  -- -------------------------------------------------------------------------
  -- PS/2 transmit procedure
  --   Sends one 11-bit PS/2 frame for the given 8-bit scancode.
  --   Frame: start(0), D0..D7, odd parity, stop(1).
  -- -------------------------------------------------------------------------
  procedure ps2_send_byte (
    constant scan_code : in std_logic_vector(7 downto 0);
    signal   ps2_clk   : out std_logic;
    signal   ps2_data  : out std_logic
  ) is
    variable parity_bit : std_logic;
    variable frame      : std_logic_vector(10 downto 0);
  begin
    -- Compute odd parity (number of '1' bits in data byte must be odd)
    parity_bit := scan_code(0) xor scan_code(1) xor scan_code(2) xor scan_code(3)
                  xor scan_code(4) xor scan_code(5) xor scan_code(6) xor scan_code(7);
    parity_bit := not parity_bit;  -- odd parity: invert even parity

    -- Build frame: [stop D7..D0 parity start] in transmission order (LSB first)
    -- Bit 0 = start bit (0)
    -- Bits 1..8 = data D0..D7
    -- Bit 9 = parity
    -- Bit 10 = stop (1)
    frame(0)          := '0';           -- start bit
    frame(8 downto 1) := scan_code;     -- data bits D0..D7
    frame(9)          := parity_bit;    -- odd parity
    frame(10)         := '1';           -- stop bit

    -- Transmit each bit: data set up, then clock toggled low then high
    for i in 0 to 10 loop
      ps2_data <= frame(i);
      wait for PS2_HALF_PERIOD;
      ps2_clk <= '0';                  -- falling edge: receiver samples here
      wait for PS2_HALF_PERIOD;
      ps2_clk <= '1';                  -- rising edge: prepare next bit
      wait for PS2_HALF_PERIOD;
    end loop;

    -- Leave bus idle (data and clk high)
    ps2_data <= '1';
    ps2_clk  <= '1';
    wait for PS2_HALF_PERIOD;
  end procedure ps2_send_byte;

begin

  -- -------------------------------------------------------------------------
  -- CLK_14M generation
  -- -------------------------------------------------------------------------
  clk14m_proc : process
  begin
    CLK_14M <= '0'; wait for CLK14M_PERIOD / 2;
    CLK_14M <= '1'; wait for CLK14M_PERIOD / 2;
  end process clk14m_proc;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.keyboard
    generic map (
      KEYMAP => "EN-us"
    )
    port map (
      PS2_Clk  => PS2_Clk,
      PS2_Data => PS2_Data,
      CLK_14M  => CLK_14M,
      read     => read,
      reset    => reset,
      K        => K
    );

  -- -------------------------------------------------------------------------
  -- Stimulus process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- Apply reset
    reset   <= '1';
    PS2_Clk  <= '1';
    PS2_Data <= '1';
    wait for 20 * CLK14M_PERIOD;

    -- De-assert reset
    reset <= '0';
    wait for 10 * CLK14M_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 1: After reset, key_pressed (K(7)) should be '0'
    -- -----------------------------------------------------------------------
    assert key_pressed_out = '0'
      report "FAIL: key_pressed (K[7]) is not '0' immediately after reset" severity error;
    report "PASS: key_pressed = '0' after reset" severity note;

    -- -----------------------------------------------------------------------
    -- Transmit PS/2 scancode 0x1C ('A' key, Set 2)
    --   Scancode 0x1C is not a modifier (not LEFT_SHIFT=0x12, RIGHT_SHIFT=0x59,
    --   LEFT_CTRL=0x14, ALT_GR=0x11), not KEY_UP_CODE (0xF0), not
    --   EXTENDED_CODE (0xE0). FSM path: IDLE -> HAVE_CODE -> DECODE ->
    --   NORMAL_KEY -> IDLE, setting key_pressed='1'.
    -- -----------------------------------------------------------------------
    report "INFO: Sending PS/2 scancode 0x1C (A key)" severity note;
    ps2_send_byte(x"1C", PS2_Clk, PS2_Data);

    -- Allow PS2_Ctrl and keyboard FSM to process the scancode
    -- PS2_Ctrl must de-serialise the 11-bit frame; at ~14 MHz CLK_14M that
    -- takes about 30 us / (70 ns) = ~430 CLK_14M cycles per PS/2 half-period.
    -- Total frame = 11 bits * 2 half-periods = 22 * 30 us = 660 us = ~9430 clocks.
    wait for 700 us;

    -- -----------------------------------------------------------------------
    -- ASSERT 2: key_pressed should be '1' after scancode received
    -- -----------------------------------------------------------------------
    assert key_pressed_out = '1'
      report "FAIL: key_pressed (K[7]) did not go high after PS/2 scancode 0x1C. " &
             "Check PS2_Ctrl dependency is compiled." severity error;

    if key_pressed_out = '1' then
      report "PASS: key_pressed = '1' after PS/2 scancode 0x1C (NORMAL_KEY path hit)" severity note;
    end if;

    -- -----------------------------------------------------------------------
    -- Step: Assert read strobe to clear key_pressed
    -- -----------------------------------------------------------------------
    read <= '1';
    wait for CLK14M_PERIOD;
    read <= '0';
    wait for 5 * CLK14M_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 3: key_pressed should be '0' after read strobe
    -- -----------------------------------------------------------------------
    assert key_pressed_out = '0'
      report "FAIL: key_pressed (K[7]) did not clear after read strobe" severity error;
    report "PASS: key_pressed cleared by read strobe" severity note;

    -- -----------------------------------------------------------------------
    -- Test: KEY_UP sequence (F0 then 1C) -> key_pressed should NOT go high
    -- -----------------------------------------------------------------------
    report "INFO: Sending KEY_UP sequence (0xF0, 0x1C)" severity note;
    ps2_send_byte(x"F0", PS2_Clk, PS2_Data);  -- KEY_UP_CODE
    wait for 200 us;
    ps2_send_byte(x"1C", PS2_Clk, PS2_Data);  -- key released
    wait for 700 us;

    assert key_pressed_out = '0'
      report "FAIL: key_pressed incorrectly asserted after KEY_UP sequence" severity error;
    report "PASS: KEY_UP sequence did not assert key_pressed" severity note;

    report "INFO: keyboard_original_target_tb complete." severity note;
    report "NOTE: PS2_Ctrl entity must be compiled into work for DUT elaboration." severity note;

    wait;
  end process stim_proc;

end architecture tb;
