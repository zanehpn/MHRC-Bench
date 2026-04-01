--------------------------------------------------------------------------------
-- Testbench: Blake2bMinerCore_target_tb.vhd
-- DUT: Blake2bMinerCore (Blake2bMinerCore_original.vhd)
--
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- BLOCKER — work.PkgBlake2b package required
--   The DUT uses `work.PkgBlake2b.all` which must provide at minimum:
--     type U64Array_t  is array (integer range <>) of unsigned(63 downto 0);
--     constant kU64Zeros : unsigned(63 downto 0);
--     constant kHin   : U64Array_t(7 downto 0);  -- Blake2b hash init values
--     constant kIV    : U64Array_t(7 downto 0);  -- Blake2b IV
--     constant kMsgLen: unsigned(7 downto 0);     -- message length constant
--     constant kSigma : integer array (0..9, 0..15); -- message schedule
--     sub-entity work.QuadG (the G-function mixer)
--   No PkgBlake2b file was found in this folder.
--   All of the above must be compiled before compiling the DUT.
--
-- COMPILE ORDER (once blocker is resolved):
--   1. work.PkgBlake2b (provides types, constants, and QuadG entity)
--   2. work.QuadG  (instantiated by the DUT via entity work.QuadG)
--   3. Blake2bMinerCore_original.vhd
--   4. Blake2bMinerCore_target_tb.vhd
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--
-- DUT ENTITY PORTS (from Blake2bMinerCore_original.vhd):
--   Clk        : in  std_logic
--   Enable     : in  std_logic
--   BlockHeader: in  U64Array_t(9 downto 0)  -- 10 x 64-bit = 80-byte block header
--   NonceOut   : out unsigned(63 downto 0)
--   Success    : out std_logic
--
-- DESIGN NOTES:
--   - The DUT is a fully pipelined Blake2b miner core.  Pipeline depth is
--     4 * 2 * 12 = 96 clock cycles.  After 96 cycles the first valid hash
--     result emerges.
--   - When Enable='0', the nonce counters reset to kNonceSeed.
--   - When Enable='1', the nonce counters increment by 1 each cycle.
--   - Target is taken from BlockHeader(4).  A Success pulse appears when
--     Hash0_be < Target.
--   - The kNonceSeed generic defaults to x"FFFFFFFFFFFF" so the first
--     active nonce is 0x000000000000 after the first increment.
--
-- STRUCTURAL TESTBENCH:
--   Provides clock, enable, and a fixed BlockHeader stimulus.
--   Monitors NonceOut and Success.  No assertions on Success value because
--   the actual hash output depends on PkgBlake2b constants (kHin, kIV, kSigma).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.PkgBlake2b.all;

entity Blake2bMinerCore_target_tb is
end entity Blake2bMinerCore_target_tb;

architecture tb of Blake2bMinerCore_target_tb is

    constant C_CLK_PERIOD  : time := 2.5 ns;  -- 400 MHz (target clock rate)
    constant C_PIPE_LENGTH : integer := 96;    -- 4 * 2 * 12

    -- Clock and control
    signal clk_s    : std_logic := '0';
    signal enable_s : std_logic := '0';

    -- Block header (80-byte Sia block header, 10 x 64-bit words)
    signal block_header_s : U64Array_t(9 downto 0) := (others => (others => '0'));

    -- Outputs
    signal nonce_out_s : unsigned(63 downto 0);
    signal success_s   : std_logic;

    -- Component declaration
    -- NOTE: Will NOT compile without work.PkgBlake2b.
    component Blake2bMinerCore is
        generic (
            kNonceSeed : unsigned(47 downto 0) := (others => '1')
        );
        port (
            Clk         : in  std_logic;
            Enable      : in  std_logic;
            BlockHeader : in  U64Array_t(9 downto 0);
            NonceOut    : out unsigned(63 downto 0);
            Success     : out std_logic
        );
    end component Blake2bMinerCore;

begin

    -- -----------------------------------------------------------------------
    -- Clock generation (400 MHz)
    -- -----------------------------------------------------------------------
    clk_gen : process
    begin
        clk_s <= '0';
        wait for C_CLK_PERIOD / 2;
        clk_s <= '1';
        wait for C_CLK_PERIOD / 2;
    end process clk_gen;

    -- -----------------------------------------------------------------------
    -- DUT instantiation
    -- NOTE: Will NOT compile without work.PkgBlake2b and work.QuadG.
    -- -----------------------------------------------------------------------
    DUT : Blake2bMinerCore
        generic map (
            kNonceSeed => (others => '1')  -- starts counting from 0
        )
        port map (
            Clk         => clk_s,
            Enable      => enable_s,
            BlockHeader => block_header_s,
            NonceOut    => nonce_out_s,
            Success     => success_s
        );

    -- -----------------------------------------------------------------------
    -- Stimulus
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        -- Keep disabled (nonce resets to seed value)
        enable_s <= '0';
        wait for 5 * C_CLK_PERIOD;

        -- Set a test block header.
        -- Word 4 (index 4) is used as the target by the DUT.
        -- Set it to the maximum value so that almost any hash will succeed
        -- (useful for a smoke test; replace with a realistic Siacoin target
        -- when testing correctness).
        block_header_s(0) <= x"0000000000000000";
        block_header_s(1) <= x"0000000000000001";
        block_header_s(2) <= x"0000000000000002";
        block_header_s(3) <= x"0000000000000003";
        block_header_s(4) <= x"FFFFFFFFFFFFFFFF";  -- very easy target (all ones)
        block_header_s(5) <= x"0000000000000005";
        block_header_s(6) <= x"0000000000000006";
        block_header_s(7) <= x"0000000000000007";
        block_header_s(8) <= x"0000000000000008";
        block_header_s(9) <= x"0000000000000009";

        -- Start mining
        enable_s <= '1';

        -- Allow the pipeline to fill (C_PIPE_LENGTH cycles) plus some margin
        wait for (C_PIPE_LENGTH + 20) * C_CLK_PERIOD;

        -- Monitor for a success event (with easy target, may fire immediately)
        if success_s = '1' then
            report "PASS: Success asserted! NonceOut=" &
                   integer'image(to_integer(nonce_out_s)) severity note;
        else
            report "NOTE: No success in first " &
                   integer'image(C_PIPE_LENGTH + 20) &
                   " cycles. This is expected if hash > target." severity note;
        end if;

        -- Continue running for a while and look for a success pulse
        wait until success_s = '1' for 10000 * C_CLK_PERIOD;
        if success_s = '1' then
            report "PASS: Success asserted during extended run. NonceOut=" &
                   integer'image(to_integer(nonce_out_s)) severity note;
        else
            report "NOTE: No success event detected after 10000 cycles. " &
                   "The DUT requires PkgBlake2b constants to produce a valid hash." severity note;
        end if;

        -- Stop mining
        enable_s <= '0';
        wait for 5 * C_CLK_PERIOD;

        report "FAIL: BLOCKER - Blake2bMinerCore requires work.PkgBlake2b and work.QuadG for functional verification."
               severity failure;
        wait;
    end process stim_proc;

end architecture tb;
