`timescale 1ns/1ps
`include "../axi_master_original.sv"

// TARGET: line 78 in axi_master.sv - FSM case for IDLE, RADDR, RDATA transitions
// Original:
//   IDLE  : next_state = (start_read_delay) ? RADDR : ((start_write_delay) ? WADDR : IDLE);
//   RADDR : if (m_axi.arvalid && m_axi.arready) next_state = RDATA;
//   RDATA : if (m_axi.rvalid  && m_axi.rready && m_axi.rlast) next_state = IDLE;

module axi_master_target_tb;
  logic aclk, areset_n;
  logic start_read, start_write;

  axi_if m_axi();

  axi_master dut(
    .aclk(aclk),
    .areset_n(areset_n),
    .m_axi(m_axi),
    .start_read(start_read),
    .start_write(start_write)
  );

  always #5 aclk = ~aclk;

  // Controllable slave signals
  logic arready_r, rvalid_r, rlast_r;
  logic awready_r, wready_r, bvalid_r;

  assign m_axi.arready = arready_r;
  assign m_axi.rdata   = 32'hcafebabe;
  assign m_axi.rresp   = 2'b00;
  assign m_axi.rvalid  = rvalid_r;
  assign m_axi.rlast   = rlast_r;
  assign m_axi.awready = awready_r;
  assign m_axi.wready  = wready_r;
  assign m_axi.bresp   = 2'b00;
  assign m_axi.bvalid  = bvalid_r;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  typedef enum logic [2:0] {IDLE=0, RADDR=1, RDATA=2, WADDR=3, WDATA=4, WRESP=5} state_type;

  task automatic check_state(string name, state_type expected);
    total_tests++;
    if (dut.state !== expected) begin
      $display("FAIL: %s - state=%0d (exp %0d)", name, dut.state, expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    aclk = 0; areset_n = 0; start_read = 0; start_write = 0;
    arready_r = 0; rvalid_r = 0; rlast_r = 0;
    awready_r = 0; wready_r = 0; bvalid_r = 0;

    repeat(3) @(posedge aclk);
    #1; check_state("T1: reset->IDLE", IDLE);

    areset_n = 1;
    @(posedge aclk); #1;
    check_state("T2: stays IDLE", IDLE);

    // --- IDLE -> RADDR via start_read_delay ---
    // start_read held for one cycle, then cleared after #1 to avoid race
    start_read = 1;
    @(posedge aclk); #1; // start_read_delay captures start_read=1
    start_read = 0;
    @(posedge aclk); #1; // now start_read_delay=1, IDLE->RADDR
    check_state("T3: IDLE->RADDR on start_read", RADDR);

    // --- RADDR stays when arready=0 ---
    arready_r = 0;
    @(posedge aclk); #1;
    check_state("T4: RADDR stays no arready", RADDR);

    // --- RADDR -> RDATA on arvalid & arready ---
    arready_r = 1;
    @(posedge aclk); #1;
    check_state("T5: RADDR->RDATA", RDATA);
    arready_r = 0;

    // --- RDATA stays when rvalid=0 ---
    rvalid_r = 0; rlast_r = 0;
    @(posedge aclk); #1;
    check_state("T6: RDATA stays no rvalid", RDATA);

    // --- RDATA stays when rvalid=1 but rlast=0 ---
    rvalid_r = 1; rlast_r = 0;
    @(posedge aclk); #1;
    check_state("T7: RDATA stays no rlast", RDATA);

    // --- RDATA -> IDLE on rvalid & rready & rlast ---
    rvalid_r = 1; rlast_r = 1;
    @(posedge aclk); #1;
    check_state("T8: RDATA->IDLE on rlast", IDLE);
    rvalid_r = 0; rlast_r = 0;

    // --- IDLE -> WADDR via start_write_delay (no start_read) ---
    start_write = 1;
    @(posedge aclk); #1;
    start_write = 0;
    @(posedge aclk); #1;
    check_state("T9: IDLE->WADDR on start_write", WADDR);

    // Complete write to return to IDLE
    awready_r = 1;
    @(posedge aclk); #1; // WADDR->WDATA
    check_state("T10: WADDR->WDATA", WDATA);
    awready_r = 0;
    // Need wlast - the DUT generates wlast when len_cnt==LEN(4)
    // wready=1 to advance len_cnt
    wready_r = 1;
    repeat(4) @(posedge aclk); // len_cnt increments 0->1->2->3->4 (wlast at 4)
    // After 4th beat with wlast, should go to WRESP
    @(posedge aclk); #1;
    check_state("T11: WDATA->WRESP", WRESP);
    wready_r = 0;
    bvalid_r = 1;
    @(posedge aclk); #1;
    check_state("T12: WRESP->IDLE", IDLE);
    bvalid_r = 0;

    // --- Read priority over write from IDLE ---
    start_read = 1; start_write = 1;
    @(posedge aclk); #1;
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check_state("T13: read priority RADDR", RADDR);

    // Complete read
    arready_r = 1;
    @(posedge aclk); #1; // RADDR->RDATA
    arready_r = 0;
    rvalid_r = 1; rlast_r = 1;
    @(posedge aclk); #1;
    check_state("T14: read done IDLE", IDLE);
    rvalid_r = 0; rlast_r = 0;

    // --- IDLE stays without any start ---
    @(posedge aclk); #1;
    check_state("T15: IDLE stays", IDLE);
    @(posedge aclk); #1;
    check_state("T16: IDLE stays again", IDLE);

    // --- Multiple read transactions ---
    repeat(3) begin
      start_read = 1;
      @(posedge aclk); #1; start_read = 0;
      @(posedge aclk); // IDLE->RADDR
      arready_r = 1;
      @(posedge aclk); arready_r = 0; // RADDR->RDATA
      rvalid_r = 1; rlast_r = 1;
      @(posedge aclk); rvalid_r = 0; rlast_r = 0; // RDATA->IDLE
    end
    #1; check_state("T17: 3 reads done IDLE", IDLE);

    // --- Reset mid-read ---
    start_read = 1;
    @(posedge aclk); #1; start_read = 0;
    @(posedge aclk); // IDLE->RADDR
    #1; check_state("T18: RADDR before reset", RADDR);
    areset_n = 0;
    @(posedge aclk); #1;
    check_state("T19: reset->IDLE", IDLE);
    areset_n = 1;

    // --- RDATA with rvalid but no rlast - stays ---
    start_read = 1;
    @(posedge aclk); #1; start_read = 0;
    @(posedge aclk); // IDLE->RADDR
    arready_r = 1;
    @(posedge aclk); arready_r = 0; #1; // RADDR->RDATA
    check_state("T20: in RDATA", RDATA);
    rvalid_r = 1; rlast_r = 0;
    @(posedge aclk); #1;
    check_state("T21: RDATA stays no rlast", RDATA);
    @(posedge aclk); #1;
    check_state("T22: RDATA stays no rlast2", RDATA);
    rlast_r = 1;
    @(posedge aclk); #1;
    check_state("T23: RDATA->IDLE on rlast", IDLE);
    rvalid_r = 0; rlast_r = 0;

    // --- RADDR with no arready - stays ---
    start_read = 1;
    @(posedge aclk); #1; start_read = 0;
    @(posedge aclk); #1; // IDLE->RADDR
    check_state("T24: in RADDR", RADDR);
    arready_r = 0;
    @(posedge aclk); #1;
    check_state("T25: RADDR stays no arready", RADDR);
    @(posedge aclk); #1;
    check_state("T26: RADDR stays no arready2", RADDR);
    arready_r = 1;
    @(posedge aclk); #1;
    check_state("T27: RADDR->RDATA", RDATA);
    arready_r = 0;
    rvalid_r = 1; rlast_r = 1;
    @(posedge aclk); #1;
    check_state("T28: RDATA->IDLE", IDLE);
    rvalid_r = 0; rlast_r = 0;

    repeat(3) @(posedge aclk);

    if (fail_count == 0)
      $display("[TB_REAL] axi_master FSM transition tests PASSED");
    else
      $display("[TB_REAL] axi_master FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #10000;
    $display("[TB_REAL] axi_master FAILED - TIMEOUT");
    $finish;
  end
endmodule
