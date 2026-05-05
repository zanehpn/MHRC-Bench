-------------------------------------------------------------------------------
-- Testbench: spi2axi_target_tb.vhd
--
-- Target line under test:
--   elsif spi_tx_byte_idx=9 then spi_tx_byte := axi_rdata(7 downto 0);
--
-- This exercises the SPI-to-AXI4-Lite bridge by simulating an SPI master
-- performing a read transaction and verifying that the four data bytes
-- returned on MISO match the 32-bit word supplied on axi_rdata (0xDEADBEEF).
--
-- Protocol (CPOL=0, CPHA=0, 11-byte frame):
--   Byte  0     : command  (0x01 = READ)
--   Bytes 1-4   : address  (MSB first; spi_rx_valid pulses after byte 4)
--   Bytes 5-10  : dummy RX / response TX
--     TX byte 6 : axi_rdata[31:24]   (MSByte)
--     TX byte 7 : axi_rdata[23:16]
--     TX byte 8 : axi_rdata[15: 8]
--     TX byte 9 : axi_rdata[ 7: 0]   <-- TARGET
--     TX byte 10: status byte
--
-- NOTE: The DUT's SPI TX pipeline loads spi_tx_byte based on
-- spi_tx_byte_idx AFTER incrementing, and the loaded byte is
-- transmitted during the NEXT SPI byte slot. The AXI slave model
-- must hold rvalid until rready handshake completes (proper AXI
-- protocol) so that the DUT can latch axi_rdata.
--
-- Compile order (GHDL example):
--   ghdl -a --std=08 spi2axi_original.vhd
--   ghdl -a --std=08 spi2axi_target_tb.vhd
--   ghdl -e --std=08 spi2axi_target_tb
--   ghdl -r --std=08 spi2axi_target_tb --vcd=spi2axi_target_tb.vcd
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi2axi_target_tb is
end entity spi2axi_target_tb;

architecture tb of spi2axi_target_tb is

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant CLK_PERIOD   : time    := 10 ns;   -- 100 MHz AXI clock
    constant SPI_HALF     : time    := 200 ns;  -- SPI SCK half-period (~2.5 MHz)
    constant CMD_READ     : std_logic_vector(7 downto 0) := x"01";
    constant AXI_RD_DATA  : std_logic_vector(31 downto 0) := x"DEADBEEF";
    constant SPI_ADDR     : std_logic_vector(31 downto 0) := x"00000004";
    -- Number of synchroniser stages in the DUT (2 flip-flops per synchroniser)
    -- We wait this many AXI clock cycles after every SPI edge so the
    -- synchronised versions are stable before the SPI FSM samples them.
    constant SYNC_LATENCY : integer := 3;

    ---------------------------------------------------------------------------
    -- DUT signals
    ---------------------------------------------------------------------------
    signal axi_aclk      : std_logic := '0';
    signal axi_aresetn   : std_logic := '0';

    -- SPI master-side signals (driven by testbench)
    signal spi_sck       : std_logic := '0';
    signal spi_ss_n      : std_logic := '1';  -- deasserted (idle)
    signal spi_mosi      : std_logic := '0';
    signal spi_miso      : std_logic;         -- driven by DUT

    -- AXI4-Lite slave signals (driven by the AXI slave model below)
    signal s_axi_awaddr  : std_logic_vector(31 downto 0);
    signal s_axi_awprot  : std_logic_vector(2 downto 0);
    signal s_axi_awvalid : std_logic;
    signal s_axi_awready : std_logic := '0';

    signal s_axi_wdata   : std_logic_vector(31 downto 0);
    signal s_axi_wstrb   : std_logic_vector(3 downto 0);
    signal s_axi_wvalid  : std_logic;
    signal s_axi_wready  : std_logic := '0';

    signal s_axi_araddr  : std_logic_vector(31 downto 0);
    signal s_axi_arprot  : std_logic_vector(2 downto 0);
    signal s_axi_arvalid : std_logic;
    signal s_axi_arready : std_logic := '0';

    signal s_axi_rdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axi_rresp   : std_logic_vector(1 downto 0)  := "00";
    signal s_axi_rvalid  : std_logic := '0';
    signal s_axi_rready  : std_logic;

    signal s_axi_bresp   : std_logic_vector(1 downto 0)  := "00";
    signal s_axi_bvalid  : std_logic := '0';
    signal s_axi_bready  : std_logic;

    ---------------------------------------------------------------------------
    -- Shared verification storage
    ---------------------------------------------------------------------------
    -- Bytes captured from MISO during the 11 SPI TX byte slots
    type byte_array_t is array (0 to 10) of std_logic_vector(7 downto 0);
    signal miso_capture : byte_array_t := (others => (others => '0'));

begin

    ---------------------------------------------------------------------------
    -- DUT instantiation
    ---------------------------------------------------------------------------
    uut : entity work.spi2axi
        generic map (
            SPI_CPOL       => 0,
            SPI_CPHA       => 0,
            AXI_ADDR_WIDTH => 32
        )
        port map (
            spi_sck       => spi_sck,
            spi_ss_n      => spi_ss_n,
            spi_mosi      => spi_mosi,
            spi_miso      => spi_miso,
            axi_aclk      => axi_aclk,
            axi_aresetn   => axi_aresetn,
            s_axi_awaddr  => s_axi_awaddr,
            s_axi_awprot  => s_axi_awprot,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata   => s_axi_wdata,
            s_axi_wstrb   => s_axi_wstrb,
            s_axi_wvalid  => s_axi_wvalid,
            s_axi_wready  => s_axi_wready,
            s_axi_araddr  => s_axi_araddr,
            s_axi_arprot  => s_axi_arprot,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata   => s_axi_rdata,
            s_axi_rresp   => s_axi_rresp,
            s_axi_rvalid  => s_axi_rvalid,
            s_axi_rready  => s_axi_rready,
            s_axi_bresp   => s_axi_bresp,
            s_axi_bvalid  => s_axi_bvalid,
            s_axi_bready  => s_axi_bready
        );

    ---------------------------------------------------------------------------
    -- AXI clock generation
    ---------------------------------------------------------------------------
    clk_gen : process
    begin
        loop
            axi_aclk <= '0';
            wait for CLK_PERIOD / 2;
            axi_aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process clk_gen;

    ---------------------------------------------------------------------------
    -- Simple AXI4-Lite slave model
    --   * Accepts read-address transactions and returns AXI_RD_DATA
    --   * Accepts write-address+data and responds with OKAY
    --   * Operates purely in the AXI clock domain
    --   * Follows proper AXI handshake: xVALID stays high until xREADY
    ---------------------------------------------------------------------------
    axi_slave : process (axi_aclk)
        variable rd_pending : boolean := false;
    begin
        if rising_edge(axi_aclk) then
            -- Read address channel: accept when arvalid is asserted
            if s_axi_arvalid = '1' and s_axi_arready = '0' and not rd_pending then
                s_axi_arready <= '1';
                -- Prepare read data, but hold rvalid until handshake
                s_axi_rdata   <= AXI_RD_DATA;
                s_axi_rresp   <= "00";   -- OKAY
                s_axi_rvalid  <= '1';
                rd_pending    := true;
            else
                s_axi_arready <= '0';
            end if;

            -- Read data channel: hold rvalid until rready completes handshake
            if rd_pending and s_axi_rvalid = '1' and s_axi_rready = '1' then
                s_axi_rvalid <= '0';
                rd_pending   := false;
            end if;

            -- Write address + data (accept simultaneously)
            if s_axi_awvalid = '1' and s_axi_awready = '0' then
                s_axi_awready <= '1';
            else
                s_axi_awready <= '0';
            end if;
            if s_axi_wvalid = '1' and s_axi_wready = '0' then
                s_axi_wready <= '1';
            else
                s_axi_wready <= '0';
            end if;
            -- Write response: hold bvalid until bready
            if s_axi_bready = '1' and s_axi_bvalid = '0' then
                s_axi_bvalid <= '1';
                s_axi_bresp  <= "00";
            elsif s_axi_bvalid = '1' and s_axi_bready = '1' then
                s_axi_bvalid <= '0';
            end if;
        end if;
    end process axi_slave;

    ---------------------------------------------------------------------------
    -- Procedure: send one byte MSB-first over SPI (CPOL=0, CPHA=0)
    --   Also captures the simultaneous MISO byte into miso_byte.
    --   For CPOL=0/CPHA=0:
    --     - MOSI is set up while SCK is low
    --     - SCK rising edge: slave samples MOSI
    --     - SCK falling edge: slave drives next MISO bit
    ---------------------------------------------------------------------------
    -- Procedures cannot reference signals in 2008 without port maps;
    -- we implement the SPI master as a single stimulus process instead.
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- Stimulus process: SPI master + assertions
    ---------------------------------------------------------------------------
    stim : process
        -- Shift one byte out on MOSI (MSB first) while capturing MISO.
        -- spi_tx_byte_slot: which TX byte slot (0-10) this byte corresponds to
        -- (used to index miso_capture).
        variable miso_byte : std_logic_vector(7 downto 0);
        variable slot      : integer;

        procedure wait_axi_clocks(n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(axi_aclk);
            end loop;
        end procedure;

        -- Send/receive one 8-bit SPI byte, store received byte in miso_capture(slot).
        procedure spi_transfer_byte(
            tx_byte  : in  std_logic_vector(7 downto 0);
            tx_slot  : in  integer
        ) is
        begin
            for bit_idx in 7 downto 0 loop
                -- Set up MOSI before rising SCK
                spi_mosi <= tx_byte(bit_idx);
                wait for SPI_HALF;
                -- Rising SCK: DUT samples MOSI
                spi_sck  <= '1';
                -- Capture MISO on rising edge (it holds the MSB of the TX shreg)
                miso_byte(bit_idx) := spi_miso;
                wait for SPI_HALF;
                -- Falling SCK: DUT shifts TX shreg
                spi_sck  <= '0';
                -- Allow synchroniser + FSM to see the edge
                wait_axi_clocks(SYNC_LATENCY);
            end loop;
            miso_capture(tx_slot) <= miso_byte;
        end procedure;

    begin
        -----------------------------------------------------------------------
        -- Reset
        -----------------------------------------------------------------------
        axi_aresetn <= '0';
        spi_ss_n    <= '1';
        spi_sck     <= '0';
        spi_mosi    <= '0';
        wait_axi_clocks(10);
        axi_aresetn <= '1';
        wait_axi_clocks(5);

        -----------------------------------------------------------------------
        -- Assert 1: After reset, AXI master-side valid signals must be low
        -----------------------------------------------------------------------
        assert s_axi_arvalid = '0'
            report "FAIL Assert 1a: s_axi_arvalid should be 0 after reset"
            severity failure;
        assert s_axi_awvalid = '0'
            report "FAIL Assert 1b: s_axi_awvalid should be 0 after reset"
            severity failure;

        -----------------------------------------------------------------------
        -- Begin SPI frame: assert chip-select
        -----------------------------------------------------------------------
        spi_ss_n <= '0';
        wait_axi_clocks(SYNC_LATENCY);

        -----------------------------------------------------------------------
        -- Send 11-byte SPI read frame
        --   Byte 0 : CMD_READ (0x01)
        --   Bytes 1-4 : address 0x00000004 (MSB first)
        --   Bytes 5-10: dummy TX bytes (0x00), DUT replies with read data
        -----------------------------------------------------------------------
        -- Byte 0: command
        spi_transfer_byte(CMD_READ,      0);
        -- Bytes 1-4: address MSB first
        spi_transfer_byte(SPI_ADDR(31 downto 24), 1);
        spi_transfer_byte(SPI_ADDR(23 downto 16), 2);
        spi_transfer_byte(SPI_ADDR(15 downto  8), 3);
        spi_transfer_byte(SPI_ADDR( 7 downto  0), 4);
        -- After byte 4 the DUT fires spi_rx_valid and begins an AXI read.
        -- Give the AXI FSM time to complete the read (arvalid->arready->rvalid).
        wait_axi_clocks(20);

        -----------------------------------------------------------------------
        -- Assert 2: DUT must have driven s_axi_arvalid at some point.
        -- By now the AXI slave model has accepted the transaction and returned
        -- rvalid, so arvalid will be back to 0.  We check the address that was
        -- captured by the AXI slave model through s_axi_araddr.
        -----------------------------------------------------------------------
        assert s_axi_araddr = SPI_ADDR
            report "FAIL Assert 2: AXI read address mismatch (expected 0x00000004)"
            severity failure;

        -- Bytes 5-10: dummy, DUT is now sending back read data
        spi_transfer_byte(x"00", 5);
        spi_transfer_byte(x"00", 6);   -- will contain rdata[31:24] on MISO
        spi_transfer_byte(x"00", 7);   -- will contain rdata[23:16] on MISO
        spi_transfer_byte(x"00", 8);   -- will contain rdata[15: 8] on MISO
        spi_transfer_byte(x"00", 9);   -- TARGET: will contain rdata[ 7: 0] on MISO
        spi_transfer_byte(x"00", 10);  -- status byte

        -- Wait for last byte to propagate through synchroniser
        wait_axi_clocks(SYNC_LATENCY + 2);

        -----------------------------------------------------------------------
        -- De-assert chip-select to end the frame
        -----------------------------------------------------------------------
        spi_ss_n <= '1';
        wait_axi_clocks(SYNC_LATENCY + 5);

        -----------------------------------------------------------------------
        -- Assert 3: MISO byte captured at TX slot 6 must equal rdata[31:24]
        -----------------------------------------------------------------------
        assert miso_capture(6) = AXI_RD_DATA(31 downto 24)
            report "FAIL Assert 3: MISO byte 6 (rdata[31:24]) mismatch. Got "
                   & integer'image(to_integer(unsigned(miso_capture(6))))
                   & " expected "
                   & integer'image(to_integer(unsigned(AXI_RD_DATA(31 downto 24))))
            severity failure;

        -----------------------------------------------------------------------
        -- Assert 4 (TARGET): MISO byte captured at TX slot 9 must equal
        --   axi_rdata(7 downto 0) i.e. the least-significant byte of DEADBEEF
        --   = 0xEF = 239
        -----------------------------------------------------------------------
        assert miso_capture(9) = AXI_RD_DATA(7 downto 0)
            report "FAIL Assert 4 (TARGET): MISO byte 9 (rdata[7:0]) mismatch. Got "
                   & integer'image(to_integer(unsigned(miso_capture(9))))
                   & " expected "
                   & integer'image(to_integer(unsigned(AXI_RD_DATA(7 downto 0))))
            severity failure;

        -----------------------------------------------------------------------
        -- Assert 5: After chip-select deasserts, AXI valid lines must be idle
        -----------------------------------------------------------------------
        assert s_axi_arvalid = '0'
            report "FAIL Assert 5: s_axi_arvalid should be 0 after transaction ends"
            severity failure;

        -----------------------------------------------------------------------
        -- Report and finish
        -----------------------------------------------------------------------
        report "spi2axi_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process stim;

end architecture tb;
