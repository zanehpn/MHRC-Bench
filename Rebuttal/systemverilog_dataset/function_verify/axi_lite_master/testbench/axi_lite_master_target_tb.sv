`timescale 1ns/1ps
`include "../axi_lite_master_original.sv"

module axi_lite_master_target_tb;
  logic aclk, areset_n;
  logic start_read, start_write;

  axi_lite_if m_axi_lite();

  axi_lite_master dut(
    .aclk(aclk),
    .areset_n(areset_n),
    .m_axi_lite(m_axi_lite),
    .start_read(start_read),
    .start_write(start_write)
  );

  always #5 aclk = ~aclk;

  // Simple slave responses
  assign m_axi_lite.arready = 1'b1;
  assign m_axi_lite.rdata   = 32'hcafebabe;
  assign m_axi_lite.rresp   = 2'b00;
  assign m_axi_lite.rvalid  = 1'b1;
  assign m_axi_lite.awready = 1'b1;
  assign m_axi_lite.wready  = 1'b1;
  assign m_axi_lite.bresp   = 2'b00;
  assign m_axi_lite.bvalid  = 1'b1;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  task automatic check(string name, logic expected_rd, logic expected_wr);
    total_tests++;
    if (dut.start_read_delay !== expected_rd || dut.start_write_delay !== expected_wr) begin
      $display("FAIL: %s - start_read_delay=%0b (exp %0b), start_write_delay=%0b (exp %0b)",
               name, dut.start_read_delay, expected_rd, dut.start_write_delay, expected_wr);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    aclk = 0; areset_n = 0; start_read = 0; start_write = 0;

    // T1: Reset clears delay registers
    repeat (3) @(posedge aclk); #1;
    check("T1: reset clears delays", 1'b0, 1'b0);

    // Release reset
    areset_n = 1;

    // T2: Both inputs 0 => delays stay 0
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check("T2: both 0 after reset", 1'b0, 1'b0);

    // T3: start_read=1 => delay=1 next cycle
    start_read = 1; start_write = 0;
    @(posedge aclk); #1;
    check("T3: start_read=1 delayed", 1'b1, 1'b0);

    // T4: start_read back to 0
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check("T4: start_read=0 delayed", 1'b0, 1'b0);

    // T5: start_write=1
    start_read = 0; start_write = 1;
    @(posedge aclk); #1;
    check("T5: start_write=1 delayed", 1'b0, 1'b1);

    // T6: start_write back to 0
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check("T6: start_write=0 delayed", 1'b0, 1'b0);

    // T7: Both inputs 1
    start_read = 1; start_write = 1;
    @(posedge aclk); #1;
    check("T7: both=1", 1'b1, 1'b1);

    // T8: Both go to 0
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check("T8: both=0", 1'b0, 1'b0);

    // T9-T10: Rapid toggle read
    start_read = 1;
    @(posedge aclk); #1;
    check("T9: toggle rd=1", 1'b1, 1'b0);
    start_read = 0;
    @(posedge aclk); #1;
    check("T10: toggle rd=0", 1'b0, 1'b0);

    // T11-T12: Rapid toggle write
    start_write = 1;
    @(posedge aclk); #1;
    check("T11: toggle wr=1", 1'b0, 1'b1);
    start_write = 0;
    @(posedge aclk); #1;
    check("T12: toggle wr=0", 1'b0, 1'b0);

    // T13-T14: Alternating patterns
    start_read = 1; start_write = 0;
    @(posedge aclk); #1;
    check("T13: alt rd=1 wr=0", 1'b1, 1'b0);
    start_read = 0; start_write = 1;
    @(posedge aclk); #1;
    check("T14: alt rd=0 wr=1", 1'b0, 1'b1);

    // T15-T16: Reset mid-operation
    start_read = 1; start_write = 1;
    @(posedge aclk); #1;
    check("T15: both=1 before reset", 1'b1, 1'b1);
    areset_n = 0;
    @(posedge aclk); #1;
    check("T16: reset clears mid-op", 1'b0, 1'b0);

    // T17: Release reset with inputs high
    areset_n = 1;
    start_read = 1; start_write = 1;
    @(posedge aclk); #1;
    check("T17: after reset with inputs=1", 1'b1, 1'b1);

    // T18: Clear inputs
    start_read = 0; start_write = 0;
    @(posedge aclk); #1;
    check("T18: clear after reset release", 1'b0, 1'b0);

    // T19-T20: Read pulse (avoid race by not changing signal at posedge)
    start_read = 1;
    @(posedge aclk); #1;
    check("T19: rd pulse captured", 1'b1, 1'b0);
    start_read = 0;
    @(posedge aclk); #1;
    check("T20: rd pulse cleared", 1'b0, 1'b0);

    // T21-T22: Write pulse (avoid race by not changing signal at posedge)
    start_write = 1;
    @(posedge aclk); #1;
    check("T21: wr pulse captured", 1'b0, 1'b1);
    start_write = 0;
    @(posedge aclk); #1;
    check("T22: wr pulse cleared", 1'b0, 1'b0);

    // T23-T25: Extended hold on read
    start_read = 1;
    @(posedge aclk); #1;
    check("T23: hold rd cycle1", 1'b1, 1'b0);
    @(posedge aclk); #1;
    check("T24: hold rd cycle2", 1'b1, 1'b0);
    @(posedge aclk); #1;
    check("T25: hold rd cycle3", 1'b1, 1'b0);
    start_read = 0;

    repeat(5) @(posedge aclk);

    if (fail_count == 0)
      $display("[TB_REAL] axi_lite_master delay register tests PASSED");
    else
      $display("[TB_REAL] axi_lite_master FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #5000;
    $display("[TB_REAL] axi_lite_master FAILED - TIMEOUT");
    $finish;
  end
endmodule
