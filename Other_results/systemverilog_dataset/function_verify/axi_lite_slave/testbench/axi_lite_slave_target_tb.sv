`timescale 1ns/1ps
`include "../axi_lite_slave_original.sv"

module axi_lite_slave_target_tb;
  logic aclk, areset_n;

  axi_lite_if s_axi_lite();

  axi_lite_slave dut(
    .aclk(aclk),
    .areset_n(areset_n),
    .s_axi_lite(s_axi_lite)
  );

  always #5 aclk = ~aclk;

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
    aclk = 0; areset_n = 0;
    s_axi_lite.araddr  = 0;
    s_axi_lite.arvalid = 0;
    s_axi_lite.rready  = 0;
    s_axi_lite.awaddr  = 0;
    s_axi_lite.awvalid = 0;
    s_axi_lite.wdata   = 0;
    s_axi_lite.wstrb   = 0;
    s_axi_lite.wvalid  = 0;
    s_axi_lite.bready  = 0;

    repeat(3) @(posedge aclk);
    #1; check_state("T1: reset->IDLE", IDLE);

    areset_n = 1;
    @(posedge aclk); #1;
    check_state("T2: stays IDLE", IDLE);

    // T3: IDLE->RADDR on arvalid
    s_axi_lite.arvalid = 1; s_axi_lite.araddr = 32'h5;
    @(posedge aclk); #1;
    check_state("T3: IDLE->RADDR", RADDR);

    // T4: RADDR->RDATA on handshake (arvalid=1, arready=1 since state==RADDR)
    @(posedge aclk); #1;
    check_state("T4: RADDR->RDATA", RDATA);
    s_axi_lite.arvalid = 0;

    // T5: RDATA->IDLE on rvalid&rready
    s_axi_lite.rready = 1;
    @(posedge aclk); #1;
    check_state("T5: RDATA->IDLE", IDLE);
    s_axi_lite.rready = 0;

    // T6: IDLE->WADDR on awvalid
    s_axi_lite.awvalid = 1; s_axi_lite.awaddr = 32'h3;
    @(posedge aclk); #1;
    check_state("T6: IDLE->WADDR", WADDR);

    // T7: WADDR->WDATA on handshake
    @(posedge aclk); #1;
    check_state("T7: WADDR->WDATA", WDATA);
    s_axi_lite.awvalid = 0;

    // T8: WDATA->WRESP on wvalid&wready
    s_axi_lite.wvalid = 1; s_axi_lite.wdata = 32'hABCD;
    @(posedge aclk); #1;
    check_state("T8: WDATA->WRESP", WRESP);
    s_axi_lite.wvalid = 0;

    // T9: WRESP->IDLE on bvalid&bready
    s_axi_lite.bready = 1;
    @(posedge aclk); #1;
    check_state("T9: WRESP->IDLE", IDLE);
    s_axi_lite.bready = 0;

    // T10: Read priority over write
    s_axi_lite.arvalid = 1; s_axi_lite.awvalid = 1;
    @(posedge aclk); #1;
    check_state("T10: read priority RADDR", RADDR);
    s_axi_lite.arvalid = 0; s_axi_lite.awvalid = 0;

    // Complete read to get back to IDLE
    s_axi_lite.arvalid = 1;
    @(posedge aclk); // RADDR->RDATA
    s_axi_lite.arvalid = 0; s_axi_lite.rready = 1;
    @(posedge aclk); // RDATA->IDLE
    #1; s_axi_lite.rready = 0;
    check_state("T11: back to IDLE", IDLE);

    // T12: IDLE stays IDLE with no valid
    @(posedge aclk); #1;
    check_state("T12: IDLE stays", IDLE);

    // T13: Write-only from IDLE (no arvalid)
    s_axi_lite.awvalid = 1; s_axi_lite.arvalid = 0;
    @(posedge aclk); #1;
    check_state("T13: IDLE->WADDR (write only)", WADDR);
    s_axi_lite.awvalid = 0;

    // Complete write
    @(posedge aclk); // WADDR->WDATA
    s_axi_lite.wvalid = 1;
    @(posedge aclk); // WDATA->WRESP
    s_axi_lite.wvalid = 0; s_axi_lite.bready = 1;
    @(posedge aclk); // WRESP->IDLE
    #1; s_axi_lite.bready = 0;
    check_state("T14: write complete IDLE", IDLE);

    // T15-T20: Multiple read transactions
    repeat(3) begin
      s_axi_lite.arvalid = 1;
      @(posedge aclk); // IDLE->RADDR
      @(posedge aclk); // RADDR->RDATA
      s_axi_lite.arvalid = 0; s_axi_lite.rready = 1;
      @(posedge aclk); // RDATA->IDLE
      s_axi_lite.rready = 0;
    end
    #1;
    check_state("T15: 3 reads done IDLE", IDLE);

    // T16-T21: Multiple write transactions
    repeat(3) begin
      s_axi_lite.awvalid = 1;
      @(posedge aclk); // IDLE->WADDR
      @(posedge aclk); // WADDR->WDATA
      s_axi_lite.awvalid = 0; s_axi_lite.wvalid = 1;
      @(posedge aclk); // WDATA->WRESP
      s_axi_lite.wvalid = 0; s_axi_lite.bready = 1;
      @(posedge aclk); // WRESP->IDLE
      s_axi_lite.bready = 0;
    end
    #1;
    check_state("T16: 3 writes done IDLE", IDLE);

    // T17: Write then read back - verify data integrity
    s_axi_lite.awvalid = 1; s_axi_lite.awaddr = 32'h2;
    @(posedge aclk); // IDLE->WADDR
    @(posedge aclk); // WADDR->WDATA
    s_axi_lite.awvalid = 0;
    s_axi_lite.wvalid = 1; s_axi_lite.wdata = 32'hDEADBEEF;
    @(posedge aclk); // WDATA->WRESP
    s_axi_lite.wvalid = 0; s_axi_lite.bready = 1;
    @(posedge aclk); // WRESP->IDLE
    s_axi_lite.bready = 0;
    #1; check_state("T17: write done IDLE", IDLE);

    // Read back
    s_axi_lite.arvalid = 1; s_axi_lite.araddr = 32'h2;
    @(posedge aclk); // IDLE->RADDR
    @(posedge aclk); // RADDR->RDATA
    s_axi_lite.arvalid = 0; s_axi_lite.rready = 1;
    #1;
    total_tests++;
    if (s_axi_lite.rdata !== 32'hDEADBEEF) begin
      $display("FAIL: T18 readback data=%h exp=DEADBEEF", s_axi_lite.rdata);
      fail_count++;
    end else pass_count++;
    @(posedge aclk); // RDATA->IDLE
    s_axi_lite.rready = 0;
    #1; check_state("T19: readback done IDLE", IDLE);

    // T20: RADDR->RDATA after handshake
    // When arvalid=1 causes IDLE->RADDR, handshake happens in RADDR
    // (arvalid=1 && arready=1 in RADDR), so RADDR->RDATA follows
    s_axi_lite.arvalid = 1;
    @(posedge aclk); // IDLE->RADDR
    #1; check_state("T20: in RADDR", RADDR);
    // Keep arvalid=1 so handshake completes in RADDR
    @(posedge aclk); #1;
    check_state("T21: RADDR->RDATA after handshake", RDATA);
    s_axi_lite.arvalid = 0;
    // Complete read to return to IDLE
    s_axi_lite.rready = 1;
    @(posedge aclk); // RDATA->IDLE
    s_axi_lite.rready = 0;
    #1; check_state("T22: back to IDLE after read", IDLE);

    // T23: WADDR->WDATA after handshake
    s_axi_lite.awvalid = 1;
    @(posedge aclk); // IDLE->WADDR
    #1; check_state("T23: in WADDR", WADDR);
    // Keep awvalid=1 so handshake completes in WADDR
    @(posedge aclk); #1;
    check_state("T24: WADDR->WDATA after handshake", WDATA);
    s_axi_lite.awvalid = 0;
    // Complete write to return to IDLE
    s_axi_lite.wvalid = 1; s_axi_lite.wdata = 32'h0;
    @(posedge aclk); // WDATA->WRESP
    s_axi_lite.wvalid = 0; s_axi_lite.bready = 1;
    @(posedge aclk); // WRESP->IDLE
    s_axi_lite.bready = 0;
    #1; check_state("T25: back to IDLE after write", IDLE);

    // T26-T27: Reset during transaction
    s_axi_lite.arvalid = 1;
    @(posedge aclk); // IDLE->RADDR
    #1; check_state("T26: in RADDR before reset", RADDR);
    areset_n = 0;
    @(posedge aclk); #1;
    check_state("T27: reset->IDLE mid-txn", IDLE);
    areset_n = 1;
    s_axi_lite.arvalid = 0;
    @(posedge aclk); #1;

    if (fail_count == 0)
      $display("[TB_REAL] axi_lite_slave FSM transition tests PASSED");
    else
      $display("[TB_REAL] axi_lite_slave FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #10000;
    $display("[TB_REAL] axi_lite_slave FAILED - TIMEOUT");
    $finish;
  end
endmodule
