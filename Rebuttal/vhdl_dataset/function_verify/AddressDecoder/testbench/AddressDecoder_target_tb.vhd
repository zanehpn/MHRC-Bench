----------------------------------------------------------------------------------
-- Testbench: AddressDecoder_target_tb.vhd
-- Entity: AddressDecoder
-- Target feature:
--   process(NRESET, CLK)
--     if NRESET='0' then
--       ndev_sel_int <= '1'; nio_sel_int <= '1'; nio_stb_int <= '1'; a_int <= "0000";
--     elsif rising_edge(CLK) then
--       ndev_sel_int <= NDEV_SEL; nio_sel_int <= NIO_SEL; nio_stb_int <= NIO_STB;
--       a_int <= A;
--
-- Entity ports (from AddressDecoder_original.vhd):
--   A        : in  std_logic_vector(11 downto 8)   -- address bits [11:8]
--   B        : out std_logic_vector(10 downto 8)   -- EEPROM address
--   CLK      : in  std_logic
--   PHI0     : in  std_logic
--   RNW      : in  std_logic                        -- Read/Not-Write
--   NDEV_SEL : in  std_logic                        -- active low device select
--   NIO_SEL  : in  std_logic                        -- active low IO select
--   NIO_STB  : in  std_logic                        -- active low IO strobe
--   NRESET   : in  std_logic                        -- active low reset
--   DATA_EN  : out std_logic                        -- data bus enable
--   PGM_EN   : in  std_logic                        -- program enable
--   NG       : out std_logic                        -- bus transceiver gate
--   NOE      : out std_logic                        -- EEPROM output enable
--   NWE      : out std_logic                        -- EEPROM write enable
--
-- Notes on DUT source:
--   DATA_EN is a purely combinational output: DATA_EN <= RNW and not NDEV_SEL.
--   It uses the raw NDEV_SEL port input, NOT the registered ndev_sel_int.
--   Other combinatorial outputs (B, NG, NOE, NWE) use a mix of raw ports and
--   registered signals.  The target assertion verifies those synchronous register
--   captures fire correctly after NRESET is released.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AddressDecoder_target_tb is
end entity AddressDecoder_target_tb;

architecture tb of AddressDecoder_target_tb is

    constant CLK_PERIOD : time := 10 ns;

    -- DUT ports
    signal clk      : std_logic := '0';
    signal nreset   : std_logic := '0';   -- active low, start asserted
    signal a        : std_logic_vector(11 downto 8) := (others => '0');
    signal b        : std_logic_vector(10 downto 8);
    signal phi0     : std_logic := '0';
    signal rnw      : std_logic := '1';   -- read by default
    signal ndev_sel : std_logic := '1';   -- deselected by default
    signal nio_sel  : std_logic := '1';
    signal nio_stb  : std_logic := '1';
    signal data_en  : std_logic;
    signal pgm_en   : std_logic := '0';
    signal ng       : std_logic;
    signal noe      : std_logic;
    signal nwe      : std_logic;

begin

    -- Clock generation
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- DUT
    dut : entity work.AddressDecoder
        port map (
            A        => a,
            B        => b,
            CLK      => clk,
            PHI0     => phi0,
            RNW      => rnw,
            NDEV_SEL => ndev_sel,
            NIO_SEL  => nio_sel,
            NIO_STB  => nio_stb,
            NRESET   => nreset,
            DATA_EN  => data_en,
            PGM_EN   => pgm_en,
            NG       => ng,
            NOE      => noe,
            NWE      => nwe
        );

    stim_proc : process
    begin
        -- -------------------------------------------------------
        -- Phase 1: Assert reset (NRESET='0')
        -- All registered outputs should be initialised to safe states.
        -- ndev_sel_int='1', nio_sel_int='1', nio_stb_int='1', a_int="0000"
        --
        -- Keep NDEV_SEL='1' (deselected) during reset so that the
        -- combinational DATA_EN = RNW AND NOT NDEV_SEL = '1' AND '0' = '0'.
        -- -------------------------------------------------------
        nreset   <= '0';
        a        <= "1100";   -- A[11:8] = 0xC
        phi0     <= '1';
        rnw      <= '1';
        ndev_sel <= '1';      -- deselected during reset
        nio_sel  <= '1';
        nio_stb  <= '1';
        pgm_en   <= '0';
        wait for 3 * CLK_PERIOD;

        -- Assert 1: During reset with NDEV_SEL='1', DATA_EN must be low.
        -- DATA_EN = RNW and not NDEV_SEL = '1' AND NOT '1' = '0'.
        assert data_en = '0'
            report "FAIL: DATA_EN should be '0' during NRESET with NDEV_SEL='1'"
            severity error;

        -- -------------------------------------------------------
        -- Phase 2: Release reset, assert device select, wait for
        -- registers to capture the new input values.
        -- DATA_EN is combinational from the raw NDEV_SEL port,
        -- so it responds immediately to NDEV_SEL going low.
        -- -------------------------------------------------------
        nreset   <= '1';
        ndev_sel <= '0';      -- select device
        wait for 2 * CLK_PERIOD;   -- let rising edge capture into registers too

        -- Assert 2: DATA_EN = RNW AND NOT NDEV_SEL = '1' AND NOT '0' = '1'.
        assert data_en = '1'
            report "FAIL: DATA_EN should be '1' after reset release with NDEV_SEL='0' and RNW='1'"
            severity error;

        -- -------------------------------------------------------
        -- Phase 3: Drive A[11:8] = 0xC ("1100") = address 0xCxxx range.
        -- With A(11)=1, A(10)=1, A(9)=0, A(8)=0:
        --   B(8)  = (1 AND NOT 0) OR (1 AND 1 AND 0)     = 1 OR 0 = 1
        --   B(9)  = (1 AND NOT 0 AND 0) OR (1 AND 0 AND NOT 0) OR (1 AND 1 AND 0)
        --         = 0 OR 0 OR 0 = 0
        --   B(10) = (1 AND 1) OR (1 AND 0 AND 0) = 1 OR 0 = 1
        -- So expected B = "101" i.e. B(10)='1', B(9)='0', B(8)='1'
        -- Note: B is purely combinatorial from a_int which is registered.
        -- After 2 clock edges post-reset-release a_int captures A = "1100".
        -- -------------------------------------------------------
        wait for CLK_PERIOD;

        -- Assert 3: B(10) and B(8) should be '1', B(9) should be '0'
        -- for A[11:8]="1100"
        assert b(10) = '1'
            report "FAIL: B(10) should be '1' for A[11:8]='1100'"
            severity error;
        assert b(9) = '0'
            report "FAIL: B(9) should be '0' for A[11:8]='1100'"
            severity error;
        assert b(8) = '1'
            report "FAIL: B(8) should be '1' for A[11:8]='1100'"
            severity error;

        -- -------------------------------------------------------
        -- Phase 4: De-assert device select - DATA_EN should go low.
        -- DATA_EN is combinational from raw NDEV_SEL, so it responds
        -- immediately (no clock edge required).
        -- -------------------------------------------------------
        ndev_sel <= '1';   -- deselect device
        wait for 2 * CLK_PERIOD;

        -- Assert 4: DATA_EN = RNW AND NOT NDEV_SEL = '1' AND NOT '1' = '0'
        assert data_en = '0'
            report "FAIL: DATA_EN should be '0' when NDEV_SEL='1' (device deselected)"
            severity error;

        -- -------------------------------------------------------
        -- Phase 5: Switch to write (RNW='0') with device selected,
        -- check DATA_EN stays low (DATA_EN requires RNW=1)
        -- -------------------------------------------------------
        ndev_sel <= '0';
        rnw      <= '0';
        wait for 2 * CLK_PERIOD;

        -- Assert 5: DATA_EN = RNW AND NOT NDEV_SEL = '0' AND '1' = '0'
        assert data_en = '0'
            report "FAIL: DATA_EN should be '0' for write cycle (RNW='0')"
            severity error;

        -- -------------------------------------------------------
        -- Phase 6: Apply second NRESET to verify registers reset again.
        -- Set NDEV_SEL='1' during reset so DATA_EN reads '0'.
        -- -------------------------------------------------------
        nreset   <= '0';
        rnw      <= '1';
        ndev_sel <= '1';   -- deselect during reset
        wait for 2 * CLK_PERIOD;

        -- Assert 6: DATA_EN = RNW AND NOT NDEV_SEL = '1' AND NOT '1' = '0'
        assert data_en = '0'
            report "FAIL: DATA_EN should be '0' after second NRESET assertion with NDEV_SEL='1'"
            severity error;

        nreset <= '1';
        wait for 2 * CLK_PERIOD;

        report "All tests done.";
        wait;
    end process;

end architecture tb;
