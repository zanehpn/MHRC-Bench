-------------------------------------------------------------------------------
-- Stub entities for apple2 design
-- Contains minimal implementations of all missing sub-entities needed by:
--   apple2_original.vhd  (timing_generator, cpu65xx, main_roms)
--   video_generator_original.vhd  (character_rom)
--   keyboard_original.vhd  (PS2_Ctrl)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- timing_generator stub
-- Instantiated in apple2_original.vhd as: entity work.timing_generator
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timing_generator is
  port (
    CLK_14M        : in  std_logic;
    CLK_7M         : out std_logic;
    CAS_N          : out std_logic;
    RAS_N          : out std_logic;
    Q3             : out std_logic;
    AX             : out std_logic;
    PHI0           : out std_logic;
    PRE_PHI0       : out std_logic;
    COLOR_REF      : out std_logic;
    TEXT_MODE      : in  std_logic;
    PAGE2          : in  std_logic;
    HIRES          : in  std_logic;
    VIDEO_ADDRESS  : out unsigned(15 downto 0);
    H0             : out std_logic;
    VA             : out std_logic;
    VB             : out std_logic;
    VC             : out std_logic;
    V2             : out std_logic;
    V4             : out std_logic;
    VBL            : out std_logic;
    HBL            : out std_logic;
    BLANK          : out std_logic;
    LDPS_N         : out std_logic;
    LD194          : out std_logic
  );
end timing_generator;

architecture stub of timing_generator is
  signal div : std_logic := '0';
begin
  -- Generate a toggling CLK_7M from CLK_14M (divide by 2)
  process (CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      div <= not div;
    end if;
  end process;

  CLK_7M        <= div;
  CAS_N         <= '1';
  RAS_N         <= '1';
  Q3            <= div;
  AX            <= '0';
  PHI0          <= '0';
  PRE_PHI0      <= '0';
  COLOR_REF     <= '0';
  VIDEO_ADDRESS <= (others => '0');
  H0            <= '0';
  VA            <= '0';
  VB            <= '0';
  VC            <= '0';
  V2            <= '0';
  V4            <= '0';
  VBL           <= '0';
  HBL           <= '0';
  BLANK         <= '1';  -- blanking active so video_generator outputs '0' (not 'U')
  LDPS_N        <= '1';
  LD194         <= '0';
end stub;

-------------------------------------------------------------------------------
-- cpu65xx stub
-- Instantiated in apple2_original.vhd as: entity work.cpu65xx
-- with generics pipelineOpcode, pipelineAluMux, pipelineAluOut (all boolean)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu65xx is
  generic (
    pipelineOpcode : boolean := false;
    pipelineAluMux : boolean := false;
    pipelineAluOut : boolean := false
  );
  port (
    clk            : in  std_logic;
    enable         : in  std_logic;
    reset          : in  std_logic;
    nmi_n          : in  std_logic;
    irq_n          : in  std_logic;
    di             : in  unsigned(7 downto 0);
    do             : out unsigned(7 downto 0);
    addr           : out unsigned(15 downto 0);
    we             : out std_logic;
    debugPc        : out unsigned(15 downto 0);
    debugOpcode    : out unsigned(7 downto 0)
  );
end cpu65xx;

architecture stub of cpu65xx is
begin
  do          <= (others => '0');
  addr        <= (others => '0');
  we          <= '0';
  debugPc     <= (others => '0');
  debugOpcode <= (others => '0');
end stub;

-------------------------------------------------------------------------------
-- main_roms stub
-- Instantiated in apple2_original.vhd as: entity work.main_roms
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main_roms is
  port (
    addr : in  unsigned(13 downto 0);
    clk  : in  std_logic;
    dout : out unsigned(7 downto 0)
  );
end main_roms;

architecture stub of main_roms is
begin
  dout <= (others => '0');
end stub;

-------------------------------------------------------------------------------
-- character_rom stub
-- Instantiated in video_generator_original.vhd as: entity work.character_rom
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity character_rom is
  port (
    addr : in  unsigned(8 downto 0);
    clk  : in  std_logic;
    dout : out unsigned(4 downto 0)
  );
end character_rom;

architecture stub of character_rom is
begin
  dout <= (others => '0');
end stub;

-------------------------------------------------------------------------------
-- PS2_Ctrl stub
-- Instantiated in keyboard_original.vhd as: entity work.PS2_Ctrl
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PS2_Ctrl is
  port (
    Clk       : in  std_logic;
    Reset     : in  std_logic;
    PS2_Clk   : in  std_logic;
    PS2_Data  : in  std_logic;
    DoRead    : in  std_logic;
    Scan_DAV  : out std_logic;
    Scan_Code : out unsigned(7 downto 0)
  );
end PS2_Ctrl;

architecture stub of PS2_Ctrl is
  signal bit_cnt   : integer range 0 to 10 := 0;
  signal shift_reg : unsigned(7 downto 0) := (others => '0');
  signal ps2_clk_r : std_logic_vector(2 downto 0) := (others => '1');
  signal frame_ok  : std_logic := '0';
  signal dav_int   : std_logic := '0';
begin

  Scan_DAV  <= dav_int;
  Scan_Code <= shift_reg;

  -- Detect falling edge of PS2_Clk and deserialise the 11-bit frame.
  -- Assert Scan_DAV for one clock after stop bit; clear when DoRead = '1'.
  process (Clk)
    variable falling : boolean;
  begin
    if rising_edge(Clk) then
      if Reset = '1' then
        ps2_clk_r <= (others => '1');
        bit_cnt   <= 0;
        shift_reg <= (others => '0');
        dav_int   <= '0';
        frame_ok  <= '0';
      else
        -- Synchronise PS2_Clk
        ps2_clk_r <= ps2_clk_r(1 downto 0) & PS2_Clk;
        falling := (ps2_clk_r(2) = '1' and ps2_clk_r(1) = '0');

        -- Clear DAV when the keyboard FSM acknowledges
        if DoRead = '1' and dav_int = '1' then
          dav_int <= '0';
        end if;

        if falling then
          if bit_cnt = 0 then
            -- Start bit (expect '0') – just skip it
            bit_cnt <= 1;
          elsif bit_cnt >= 1 and bit_cnt <= 8 then
            -- Data bits D0..D7 (LSB first): shift in from the top
            shift_reg <= PS2_Data & shift_reg(7 downto 1);
            bit_cnt   <= bit_cnt + 1;
          elsif bit_cnt = 9 then
            -- Parity bit – ignore for stub
            bit_cnt <= 10;
          elsif bit_cnt = 10 then
            -- Stop bit – frame complete
            dav_int <= '1';
            bit_cnt <= 0;
          end if;
        end if;
      end if;
    end if;
  end process;

end stub;
