--------------------------------------------------------------------------------
-- Testbench for SPI_SLAVE
-- Target: bit_cnt_max <= '1' when (bit_cnt = WORD_SIZE-1) else '0';
-- Tests SPI mode 0 transaction, DOUT_VLD, DIN_RDY, and MISO data.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity spi_slave_target_tb is
end entity;

architecture tb of spi_slave_target_tb is

    constant WORD_SIZE   : natural := 8;
    constant CLK_PERIOD  : time    := 20 ns;   -- 50 MHz system clock
    constant SCLK_PERIOD : time    := 200 ns;  -- 5 MHz SPI clock

    -- DUT ports
    signal CLK      : std_logic := '0';
    signal RST      : std_logic := '0';
    signal SCLK     : std_logic := '0';
    signal CS_N     : std_logic := '1';
    signal MOSI     : std_logic := '0';
    signal MISO     : std_logic;
    signal DIN      : std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');
    signal DIN_VLD  : std_logic := '0';
    signal DIN_RDY  : std_logic;
    signal DOUT     : std_logic_vector(WORD_SIZE-1 downto 0);
    signal DOUT_VLD : std_logic;

    -- Test helpers
    signal dout_vld_seen : std_logic := '0';
    signal miso_captured : std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');

    -- Procedure: send one byte via SPI (mode 0) from master side
    -- Drives MOSI MSB-first, captures MISO MSB-first
    procedure spi_send_byte (
        signal sclk_s  : out std_logic;
        signal mosi_s  : out std_logic;
        signal miso_s  : in  std_logic;
        constant tx    : in  std_logic_vector(WORD_SIZE-1 downto 0);
        variable rx    : out std_logic_vector(WORD_SIZE-1 downto 0)
    ) is
    begin
        for i in WORD_SIZE-1 downto 0 loop
            mosi_s <= tx(i);
            wait for SCLK_PERIOD / 2;
            sclk_s <= '1';
            rx(i) := miso_s;           -- sample MISO on rising edge
            wait for SCLK_PERIOD / 2;
            sclk_s <= '0';
        end loop;
        mosi_s <= '0';
    end procedure;

begin

    -- -------------------------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------------------------
    dut : entity work.SPI_SLAVE
        generic map (WORD_SIZE => WORD_SIZE)
        port map (
            CLK      => CLK,
            RST      => RST,
            SCLK     => SCLK,
            CS_N     => CS_N,
            MOSI     => MOSI,
            MISO     => MISO,
            DIN      => DIN,
            DIN_VLD  => DIN_VLD,
            DIN_RDY  => DIN_RDY,
            DOUT     => DOUT,
            DOUT_VLD => DOUT_VLD
        );

    -- -------------------------------------------------------------------------
    -- System Clock Generation
    -- -------------------------------------------------------------------------
    clk_gen : process
    begin
        CLK <= '0'; wait for CLK_PERIOD / 2;
        CLK <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
        variable rx_byte : std_logic_vector(WORD_SIZE-1 downto 0);
        variable miso_bits : std_logic_vector(WORD_SIZE-1 downto 0);
        constant TX_DATA  : std_logic_vector(WORD_SIZE-1 downto 0) := x"A5";
        constant DIN_DATA : std_logic_vector(WORD_SIZE-1 downto 0) := x"3C";
    begin
        -- =====================================================================
        -- Phase 1: Reset
        -- =====================================================================
        RST     <= '1';
        CS_N    <= '1';
        SCLK    <= '0';
        MOSI    <= '0';
        DIN     <= (others => '0');
        DIN_VLD <= '0';
        wait for CLK_PERIOD * 5;
        RST <= '0';
        wait for CLK_PERIOD * 2;

        -- Assert 1: After reset, DIN_RDY should be high (slave ready when CS_N=1, shreg not busy)
        assert DIN_RDY = '1'
            report "ASSERT FAIL: DIN_RDY should be '1' after reset with CS_N high"
            severity failure;

        -- =====================================================================
        -- Phase 2: Load DIN data before the transaction so slave can transmit
        -- =====================================================================
        DIN     <= DIN_DATA;
        DIN_VLD <= '1';
        wait for CLK_PERIOD;
        DIN_VLD <= '0';
        wait for CLK_PERIOD * 2;

        -- =====================================================================
        -- Phase 3: SPI Mode 0 transaction - master sends TX_DATA (0xA5)
        -- =====================================================================
        CS_N <= '0';
        wait for SCLK_PERIOD;           -- setup time before first clock

        miso_bits := (others => '0');
        spi_send_byte(SCLK, MOSI, MISO, TX_DATA, miso_bits);
        miso_captured <= miso_bits;

        wait for SCLK_PERIOD / 2;

        -- Assert 2: DOUT_VLD must pulse after 8 SCLK cycles (last falling edge)
        -- Allow a few system clock cycles for synchronisation pipeline
        wait for CLK_PERIOD * 6;
        assert DOUT_VLD = '1' or dout_vld_seen = '1'
            report "ASSERT FAIL: DOUT_VLD did not pulse after 8-bit SPI transaction"
            severity failure;

        wait for CLK_PERIOD * 4;

        -- Assert 3: DOUT must equal the byte clocked in via MOSI (0xA5)
        assert DOUT = TX_DATA
            report "ASSERT FAIL: DOUT mismatch after SPI receive. Expected 0xA5, got 0x" &
                   to_hstring(DOUT)
            severity failure;

        CS_N <= '1';
        wait for SCLK_PERIOD * 2;

        -- =====================================================================
        -- Phase 4: Second transaction - verify DIN data appears on MISO
        -- Reload DIN, then run another transaction
        -- =====================================================================
        DIN     <= DIN_DATA;
        DIN_VLD <= '1';
        wait for CLK_PERIOD;
        DIN_VLD <= '0';
        wait for CLK_PERIOD * 2;

        CS_N <= '0';
        wait for SCLK_PERIOD;

        miso_bits := (others => '0');
        spi_send_byte(SCLK, MOSI, MISO, x"FF", miso_bits);

        -- Allow pipeline to settle
        wait for CLK_PERIOD * 6;

        -- Assert 4: MISO bits captured during second transaction should correspond
        -- to DIN_DATA (0x3C) shifted out by the slave
        assert miso_bits = DIN_DATA
            report "ASSERT FAIL: MISO data mismatch. Expected DIN_DATA=0x3C, got 0x" &
                   to_hstring(miso_bits)
            severity failure;

        CS_N <= '1';
        wait for SCLK_PERIOD;

        -- =====================================================================
        -- Phase 5: Assert DIN_RDY is available after transaction ends
        -- =====================================================================
        wait for CLK_PERIOD * 4;
        assert DIN_RDY = '1'
            report "ASSERT FAIL: DIN_RDY should be '1' after transaction with CS_N high"
            severity failure;

        report "spi_slave_target_tb: ALL ASSERTIONS PASSED" severity note;
        std.env.finish;
        wait;
    end process;

    -- -------------------------------------------------------------------------
    -- Monitor: track DOUT_VLD pulses
    -- -------------------------------------------------------------------------
    monitor : process (CLK)
    begin
        if rising_edge(CLK) then
            if DOUT_VLD = '1' then
                dout_vld_seen <= '1';
            end if;
        end if;
    end process;

end architecture;
