--------------------------------------------------------------------------------
-- Testbench for SpiController
-- Target: data_out(0) <= slavesel; data_out(3 downto 1) <= (others => '0');
--         data_out(4) <= sdhc;   -- status register readback (addr="11")
-- Tests: reset, register read at addr="11", status bit values after write.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SpiController_target_tb is
end entity;

architecture tb of SpiController_target_tb is

    constant CLK_PERIOD  : time := 20 ns;   -- 50 MHz
    constant PHI0_PERIOD : time := 1000 ns; -- 1 MHz phi0 (6502 style)

    -- DUT ports
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);
    signal is_read  : std_logic := '1';
    signal nreset   : std_logic := '0';
    signal addr     : std_logic_vector(1 downto 0) := "00";
    signal phi0     : std_logic := '0';
    signal ndev_sel : std_logic := '1';
    signal clk      : std_logic := '0';
    signal miso     : std_logic := '0';
    signal mosi     : std_logic;
    signal sclk     : std_logic;
    signal nsel     : std_logic;
    signal wp       : std_logic := '0';
    signal card     : std_logic := '0';
    signal pgm_en   : std_logic;
    signal led      : std_logic;

    -- Helper: issue a CPU bus write cycle on ndev_sel
    -- addr_v, data_v are driven before ndev_sel falls; is_read='0'
    procedure cpu_write (
        signal addr_s    : out std_logic_vector(1 downto 0);
        signal data_s    : out std_logic_vector(7 downto 0);
        signal is_read_s : out std_logic;
        signal ndev_sel_s: out std_logic;
        constant addr_v  : in  std_logic_vector(1 downto 0);
        constant data_v  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        addr_s     <= addr_v;
        data_s     <= data_v;
        is_read_s  <= '0';
        ndev_sel_s <= '0';
        wait for PHI0_PERIOD / 2;
        ndev_sel_s <= '1';   -- rising edge of ndev_sel latches the write
        wait for PHI0_PERIOD / 4;
        is_read_s  <= '1';
        wait for PHI0_PERIOD / 4;
    end procedure;

    -- Helper: issue a CPU bus read cycle
    procedure cpu_read (
        signal addr_s    : out std_logic_vector(1 downto 0);
        signal is_read_s : out std_logic;
        signal ndev_sel_s: out std_logic;
        constant addr_v  : in  std_logic_vector(1 downto 0)
    ) is
    begin
        addr_s     <= addr_v;
        is_read_s  <= '1';
        ndev_sel_s <= '0';
        wait for PHI0_PERIOD / 2;
        ndev_sel_s <= '1';
        wait for PHI0_PERIOD / 2;
    end procedure;

begin

    -- -------------------------------------------------------------------------
    -- DUT Instantiation
    -- -------------------------------------------------------------------------
    dut : entity work.SpiController
        port map (
            data_in  => data_in,
            data_out => data_out,
            is_read  => is_read,
            nreset   => nreset,
            addr     => addr,
            phi0     => phi0,
            ndev_sel => ndev_sel,
            clk      => clk,
            miso     => miso,
            mosi     => mosi,
            sclk     => sclk,
            nsel     => nsel,
            wp       => wp,
            card     => card,
            pgm_en   => pgm_en,
            led      => led
        );

    -- -------------------------------------------------------------------------
    -- Clock and phi0 Generation
    -- -------------------------------------------------------------------------
    clk_gen : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    phi0_gen : process
    begin
        phi0 <= '0'; wait for PHI0_PERIOD / 2;
        phi0 <= '1'; wait for PHI0_PERIOD / 2;
    end process;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
    begin
        -- =====================================================================
        -- Phase 1: Assert reset (nreset active-low)
        -- =====================================================================
        nreset  <= '0';
        ndev_sel <= '1';
        is_read  <= '1';
        addr     <= "00";
        data_in  <= (others => '0');
        card     <= '0';
        wait for PHI0_PERIOD * 3;

        -- Assert 1: During reset, nsel (slavesel) should be high (inactive)
        -- After reset: slavesel initialised to '1' in cpu_write process
        assert nsel = '1'
            report "ASSERT FAIL: nsel should be '1' (slave deselected) after reset"
            severity failure;

        -- =====================================================================
        -- Phase 2: Deassert reset
        -- =====================================================================
        nreset <= '1';
        wait for PHI0_PERIOD * 2;

        -- =====================================================================
        -- Phase 3: Read slave-select / SDHC status register (addr="11")
        -- After reset: slavesel='1', sdhc='0', inited='0'
        -- Expected data_out: bit0=slavesel='1', bits3..1='0', bit4=sdhc='0',
        --                    bit7=inited='0'  => 0x01
        -- =====================================================================
        cpu_read(addr, is_read, ndev_sel, "11");
        wait for 10 ns;   -- combinational read; settle

        -- Assert 2: data_out(0) must equal slavesel='1' after reset
        assert data_out(0) = '1'
            report "ASSERT FAIL: data_out(0) should be '1' (slavesel='1') after reset read of addr=11"
            severity failure;

        -- Assert 3: data_out(3 downto 1) must be '0' (reserved zeros per spec)
        assert data_out(3 downto 1) = "000"
            report "ASSERT FAIL: data_out(3 downto 1) should be ""000"" in slave-select register"
            severity failure;

        -- Assert 4: data_out(4) must equal sdhc='0' after reset
        assert data_out(4) = '0'
            report "ASSERT FAIL: data_out(4) should be '0' (sdhc='0') after reset"
            severity failure;

        -- =====================================================================
        -- Phase 4: Write to slave-select register to deselect slave and set sdhc
        -- Write addr="11", data bit0=0 (select slave), bit4=1 (sdhc=1)
        -- =====================================================================
        cpu_write(addr, data_in, is_read, ndev_sel, "11", x"11");
        -- x"11" = 0001_0001: bit0=1 (slavesel stays '1'), bit4=1 (sdhc='1')
        wait for 10 ns;

        -- Read back
        cpu_read(addr, is_read, ndev_sel, "11");
        wait for 10 ns;

        -- Assert 5: data_out(4) should now reflect sdhc='1'
        assert data_out(4) = '1'
            report "ASSERT FAIL: data_out(4) should be '1' after writing sdhc=1"
            severity failure;

        -- Assert 6: data_out(0) should reflect slavesel='1' (written bit0=1)
        assert data_out(0) = '1'
            report "ASSERT FAIL: data_out(0) should be '1' after writing slavesel=1"
            severity failure;

        -- =====================================================================
        -- Phase 5: Write slavesel=0 (select the slave) and verify nsel goes low
        -- =====================================================================
        cpu_write(addr, data_in, is_read, ndev_sel, "11", x"10");
        -- x"10" = 0001_0000: bit0=0 (slavesel='0'), bit4=1 (sdhc='1')
        wait for 10 ns;

        -- Assert 7: nsel must go low after writing slavesel=0
        assert nsel = '0'
            report "ASSERT FAIL: nsel should be '0' after writing slavesel=0"
            severity failure;

        -- Read back slave-select register and verify data_out(0) = 0
        cpu_read(addr, is_read, ndev_sel, "11");
        wait for 10 ns;

        assert data_out(0) = '0'
            report "ASSERT FAIL: data_out(0) should be '0' after writing slavesel=0"
            severity failure;

        report "SpiController_target_tb: ALL ASSERTIONS PASSED" severity note;
        wait;
    end process;

end architecture;
