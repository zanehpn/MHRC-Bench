-------------------------------------------------------------------------------
-- Stub entities for miner_top design
-- Contains minimal implementations of missing sub-entities needed by:
--   miner_top_original.vhd  (soc_wrapper, clk_wiz_0)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- soc_wrapper stub
-- Declared as component in miner_top_original.vhd
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity soc_wrapper is
  port (
    ARST_AVL_N             : out std_logic_vector(0 to 0);
    CLK_AVL                : out std_logic;
    M_AVALON_ADDRESS       : out std_logic_vector(31 downto 0);
    M_AVALON_BYTEENABLE    : out std_logic_vector(3 downto 0);
    M_AVALON_READ          : out std_logic;
    M_AVALON_READDATA      : in  std_logic_vector(31 downto 0);
    M_AVALON_READDATAVALID : in  std_logic;
    M_AVALON_WAITREQUEST   : in  std_logic;
    M_AVALON_WRITE         : out std_logic;
    M_AVALON_WRITEDATA     : out std_logic_vector(31 downto 0)
  );
end soc_wrapper;

architecture stub of soc_wrapper is
begin
  ARST_AVL_N          <= (others => '1');   -- de-asserted reset
  CLK_AVL             <= '0';
  M_AVALON_ADDRESS    <= (others => '0');
  M_AVALON_BYTEENABLE <= (others => '0');
  M_AVALON_READ       <= '0';
  M_AVALON_WRITE      <= '0';
  M_AVALON_WRITEDATA  <= (others => '0');
end stub;

-------------------------------------------------------------------------------
-- clk_wiz_0 stub
-- Declared as component in miner_top_original.vhd
-- Xilinx clock wizard IP - generates an output clock from an input clock
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity clk_wiz_0 is
  port (
    clk_out1 : out std_logic;
    resetn   : in  std_logic;
    locked   : out std_logic;
    clk_in1  : in  std_logic
  );
end clk_wiz_0;

architecture stub of clk_wiz_0 is
begin
  -- Pass through input clock as output clock
  clk_out1 <= clk_in1;
  locked   <= '1';
end stub;
