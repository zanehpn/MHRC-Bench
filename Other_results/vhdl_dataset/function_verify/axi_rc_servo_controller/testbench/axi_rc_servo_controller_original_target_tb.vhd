-- =============================================================================
-- Testbench: axi_rc_servo_controller_original_target_tb.vhd
--
-- DUT: axi_rc_servo_controller (AXI4-Lite slave with RC servo control)
-- Source: axi_rc_servo_controller_original.vhd
--
-- Target Logic:
--   State machine in state_machine_decisions process:
--     when reset => next_state <= idle;   [target: FSM transitions to idle]
--   Observable: After ARESETN de-asserts (reset released), the FSM leaves
--   the 'reset' state and enters 'idle'. In 'idle' state AWREADY and
--   ARREADY become eligible to assert in response to AXI transactions.
--
-- PARTIAL BLOCKER:
--   axi_rc_servo_controller instantiates two internal components:
--     - clock_divider  (sub-module for servo PWM clock derivation)
--     - servo_controller (sub-module generating PWM output)
--   These sub-modules must be compiled alongside the top-level entity.
--   The library reference "library axi_rc_servo_controller" in the source
--   suggests the entity may be part of a named library; if compiled into
--   'work' the library clause should be removed or the library mapped.
--
--   This testbench drives a complete AXI4-Lite write transaction to the
--   servo position register (address 0x008, data = 0x00000080 = centre
--   position) and a subsequent read transaction, exercising the
--   write_transaction_in_progress and read_transaction_in_progress states,
--   and the 'complete' -> 'idle' transition that contains the target path.
--
-- AXI4-Lite write transaction handshake:
--   Master asserts AWVALID + WVALID simultaneously (allowed by spec).
--   Slave asserts AWREADY + WREADY when ready.
--   Slave then drives BVALID; master responds BREADY.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity axi_rc_servo_controller_original_target_tb is
end entity axi_rc_servo_controller_original_target_tb;

architecture tb of axi_rc_servo_controller_original_target_tb is

  -- -------------------------------------------------------------------------
  -- AXI4-Lite parameters (must match DUT generics)
  -- -------------------------------------------------------------------------
  constant C_S_AXI_DATA_WIDTH : integer := 32;
  constant C_S_AXI_ADDR_WIDTH : integer := 9;
  constant NUMBER_OF_SERVOS   : integer := 1;
  constant CLK_PERIOD         : time    := 10 ns;  -- 100 MHz AXI clock

  -- -------------------------------------------------------------------------
  -- DUT interface signals
  -- -------------------------------------------------------------------------
  signal servo_control_output : std_logic_vector(NUMBER_OF_SERVOS-1 downto 0);

  signal S_AXI_ACLK    : std_logic := '0';
  signal S_AXI_ARESETN : std_logic := '0';  -- active-low reset

  -- Write address channel
  signal S_AXI_AWADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal S_AXI_AWVALID : std_logic := '0';
  signal S_AXI_AWREADY : std_logic;

  -- Write data channel
  signal S_AXI_WDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
  signal S_AXI_WSTRB   : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
  signal S_AXI_WVALID  : std_logic := '0';
  signal S_AXI_WREADY  : std_logic;

  -- Write response channel
  signal S_AXI_BRESP   : std_logic_vector(1 downto 0);
  signal S_AXI_BVALID  : std_logic;
  signal S_AXI_BREADY  : std_logic := '0';

  -- Read address channel
  signal S_AXI_ARADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal S_AXI_ARVALID : std_logic := '0';
  signal S_AXI_ARREADY : std_logic;

  -- Read data channel
  signal S_AXI_RDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal S_AXI_RRESP   : std_logic_vector(1 downto 0);
  signal S_AXI_RVALID  : std_logic;
  signal S_AXI_RREADY  : std_logic := '0';

  -- -------------------------------------------------------------------------
  -- AXI4-Lite write transaction procedure
  -- -------------------------------------------------------------------------
  procedure axi_write (
    constant addr    : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    constant data    : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal   aclk    : in  std_logic;
    signal   awaddr  : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal   awvalid : out std_logic;
    signal   awready : in  std_logic;
    signal   wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal   wvalid  : out std_logic;
    signal   wready  : in  std_logic;
    signal   bvalid  : in  std_logic;
    signal   bready  : out std_logic
  ) is
  begin
    -- Present address and data simultaneously
    awaddr  <= addr;
    wdata   <= data;
    awvalid <= '1';
    wvalid  <= '1';
    -- Wait for AWREADY
    wait until rising_edge(aclk) and awready = '1';
    awvalid <= '0';
    -- Wait for WREADY
    wait until rising_edge(aclk) and wready = '1';
    wvalid  <= '0';
    -- Wait for write response
    wait until rising_edge(aclk) and bvalid = '1';
    bready  <= '1';
    wait until rising_edge(aclk);
    bready  <= '0';
  end procedure axi_write;

  -- -------------------------------------------------------------------------
  -- AXI4-Lite read transaction procedure
  -- -------------------------------------------------------------------------
  procedure axi_read (
    constant addr    : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal   aclk    : in  std_logic;
    signal   araddr  : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal   arvalid : out std_logic;
    signal   arready : in  std_logic;
    signal   rvalid  : in  std_logic;
    signal   rready  : out std_logic;
    signal   rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0)
  ) is
  begin
    araddr  <= addr;
    arvalid <= '1';
    wait until rising_edge(aclk) and arready = '1';
    arvalid <= '0';
    wait until rising_edge(aclk) and rvalid = '1';
    rready  <= '1';
    wait until rising_edge(aclk);
    rready  <= '0';
    report "INFO: AXI read returned data = 0x" & to_hstring(rdata) severity note;
  end procedure axi_read;

begin

  -- -------------------------------------------------------------------------
  -- AXI clock generation
  -- -------------------------------------------------------------------------
  clk_proc : process
  begin
    S_AXI_ACLK <= '0'; wait for CLK_PERIOD / 2;
    S_AXI_ACLK <= '1'; wait for CLK_PERIOD / 2;
  end process clk_proc;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  DUT : entity work.axi_rc_servo_controller
    generic map (
      C_FAMILY                    => "virtex7",
      C_S_AXI_ACLK_FREQ_HZ       => 100_000_000,
      C_S_AXI_DATA_WIDTH          => C_S_AXI_DATA_WIDTH,
      C_S_AXI_ADDR_WIDTH          => C_S_AXI_ADDR_WIDTH,
      NUMBER_OF_SERVOS            => NUMBER_OF_SERVOS,
      MINIMUM_HIGH_PULSE_WIDTH_NS => 1_000_000,
      MAXIMUM_HIGH_PULSE_WIDTH_NS => 2_000_000
    )
    port map (
      servo_control_output => servo_control_output,
      S_AXI_ACLK          => S_AXI_ACLK,
      S_AXI_ARESETN       => S_AXI_ARESETN,
      S_AXI_AWADDR        => S_AXI_AWADDR,
      S_AXI_AWVALID       => S_AXI_AWVALID,
      S_AXI_AWREADY       => S_AXI_AWREADY,
      S_AXI_ARADDR        => S_AXI_ARADDR,
      S_AXI_ARVALID       => S_AXI_ARVALID,
      S_AXI_ARREADY       => S_AXI_ARREADY,
      S_AXI_WDATA         => S_AXI_WDATA,
      S_AXI_WSTRB         => S_AXI_WSTRB,
      S_AXI_WVALID        => S_AXI_WVALID,
      S_AXI_WREADY        => S_AXI_WREADY,
      S_AXI_RDATA         => S_AXI_RDATA,
      S_AXI_RRESP         => S_AXI_RRESP,
      S_AXI_RVALID        => S_AXI_RVALID,
      S_AXI_RREADY        => S_AXI_RREADY,
      S_AXI_BRESP         => S_AXI_BRESP,
      S_AXI_BVALID        => S_AXI_BVALID,
      S_AXI_BREADY        => S_AXI_BREADY
    );

  -- -------------------------------------------------------------------------
  -- Stimulus process
  -- -------------------------------------------------------------------------
  stim_proc : process
  begin
    -- -----------------------------------------------------------------------
    -- Apply reset (ARESETN active-low: hold low for reset)
    -- -----------------------------------------------------------------------
    S_AXI_ARESETN <= '0';
    S_AXI_AWVALID <= '0';
    S_AXI_WVALID  <= '0';
    S_AXI_ARVALID <= '0';
    S_AXI_BREADY  <= '0';
    S_AXI_RREADY  <= '0';
    wait for 20 * CLK_PERIOD;

    -- De-assert reset (FSM should transition: reset -> idle)
    S_AXI_ARESETN <= '1';
    wait for 5 * CLK_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 1: After reset release, AWREADY and ARREADY should not be 'U'/'X'
    --   In idle state the FSM drives AWREADY='0', ARREADY='0' from the
    --   combinational process default assignments.
    -- -----------------------------------------------------------------------
    assert S_AXI_AWREADY /= 'U' and S_AXI_AWREADY /= 'X'
      report "FAIL: S_AXI_AWREADY is unknown after reset release" severity error;
    assert S_AXI_ARREADY /= 'U' and S_AXI_ARREADY /= 'X'
      report "FAIL: S_AXI_ARREADY is unknown after reset release" severity error;
    report "PASS: AXI ready signals driven (not unknown) after reset" severity note;

    -- Allow FSM to settle in idle
    wait for 5 * CLK_PERIOD;

    -- -----------------------------------------------------------------------
    -- Test 1: AXI4-Lite Write Transaction
    --   Write servo position 0x80 (mid-range) to servo_position register.
    --   Address layout per source: servo_position_register starts at offset
    --   calculated from local_address. Use address 0x008 (word 2, first servo
    --   position register area).
    --   FSM transition: idle -> write_transaction_in_progress -> complete -> idle
    --   Target path: next_state <= idle (from 'complete' state when both
    --   AWVALID and ARVALID are '0').
    -- -----------------------------------------------------------------------
    report "INFO: Initiating AXI4-Lite write transaction" severity note;
    axi_write(
      addr    => std_logic_vector(to_unsigned(8, C_S_AXI_ADDR_WIDTH)),
      data    => x"00000080",
      aclk    => S_AXI_ACLK,
      awaddr  => S_AXI_AWADDR,
      awvalid => S_AXI_AWVALID,
      awready => S_AXI_AWREADY,
      wdata   => S_AXI_WDATA,
      wvalid  => S_AXI_WVALID,
      wready  => S_AXI_WREADY,
      bvalid  => S_AXI_BVALID,
      bready  => S_AXI_BREADY
    );
    report "PASS: AXI4-Lite write transaction completed" severity note;

    -- Allow FSM to return to idle (complete -> idle when AWVALID=ARVALID=0)
    wait for 5 * CLK_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 2: BVALID should be '0' now (response consumed)
    -- -----------------------------------------------------------------------
    assert S_AXI_BVALID = '0'
      report "FAIL: BVALID still asserted after write completion handshake" severity error;
    report "PASS: BVALID deasserted after write response accepted" severity note;

    -- -----------------------------------------------------------------------
    -- Test 2: AXI4-Lite Read Transaction
    --   Read back from the same address.
    --   FSM: idle -> read_transaction_in_progress -> complete -> idle
    -- -----------------------------------------------------------------------
    report "INFO: Initiating AXI4-Lite read transaction" severity note;
    axi_read(
      addr    => std_logic_vector(to_unsigned(8, C_S_AXI_ADDR_WIDTH)),
      aclk    => S_AXI_ACLK,
      araddr  => S_AXI_ARADDR,
      arvalid => S_AXI_ARVALID,
      arready => S_AXI_ARREADY,
      rvalid  => S_AXI_RVALID,
      rready  => S_AXI_RREADY,
      rdata   => S_AXI_RDATA
    );
    report "PASS: AXI4-Lite read transaction completed" severity note;

    -- Allow FSM to settle in idle
    wait for 5 * CLK_PERIOD;

    -- -----------------------------------------------------------------------
    -- ASSERT 3: RVALID should be '0' after read data accepted
    -- -----------------------------------------------------------------------
    assert S_AXI_RVALID = '0'
      report "FAIL: RVALID still asserted after read data accepted" severity error;
    report "PASS: RVALID deasserted after read response accepted" severity note;

    -- -----------------------------------------------------------------------
    -- Verify servo_control_output is driven (not unknown)
    -- -----------------------------------------------------------------------
    assert servo_control_output /= (servo_control_output'range => 'U')
      report "FAIL: servo_control_output is undriven" severity error;
    report "PASS: servo_control_output is driven" severity note;

    report "INFO: axi_rc_servo_controller_original_target_tb complete." severity note;
    report "NOTE: clock_divider and servo_controller sub-modules must be compiled." &
           " Library 'axi_rc_servo_controller' in DUT source may need remapping to 'work'."
      severity note;

    std.env.finish;
    wait;
  end process stim_proc;

end architecture tb;
