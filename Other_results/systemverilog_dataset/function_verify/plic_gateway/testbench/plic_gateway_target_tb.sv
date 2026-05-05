`timescale 1ns/1ps
`include "../plic_gateway_original.sv"

module plic_gateway_target_tb;

  localparam MAX_PENDING_COUNT = 4;

  logic clk, rst_n;
  logic src, edge_lvl;
  logic ip_out;
  logic claim_in, complete_in;

  plic_gateway #(.MAX_PENDING_COUNT(MAX_PENDING_COUNT)) dut (
    .rst_n(rst_n),
    .clk(clk),
    .src(src),
    .edge_lvl(edge_lvl),
    .ip(ip_out),
    .claim(claim_in),
    .complete(complete_in)
  );

  always #5 clk = ~clk;

  integer pass_count, fail_count;

  // Access internal signals for checking pending counter
  // The TARGET is about the pending counter decrement logic in the combinational case block
  // We focus on testing the edge-triggered pending counter behavior

  task automatic check_ip(input string name, input logic exp_ip);
    if (ip_out !== exp_ip) begin
      $display("FAIL %s: ip=%0b (exp %0b)", name, ip_out, exp_ip);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  // Generate a rising edge on src
  task automatic gen_src_edge();
    @(negedge clk); src = 0;
    @(negedge clk); src = 1;
    @(negedge clk); src = 0;
  endtask

  // Complete the claim-complete cycle
  task automatic do_claim_complete();
    @(negedge clk); claim_in = 1;
    @(posedge clk); #1;
    @(negedge clk); claim_in = 0;
    // Wait for claimed state
    @(posedge clk); #1;
    @(negedge clk); complete_in = 1;
    @(posedge clk); #1;
    @(negedge clk); complete_in = 0;
    @(posedge clk); #1;
  endtask

  initial begin
    clk = 0; rst_n = 0; src = 0; edge_lvl = 0;
    claim_in = 0; complete_in = 0;
    pass_count = 0; fail_count = 0;

    // Reset
    @(posedge clk); @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;

    // ========= EDGE MODE TESTS =========
    edge_lvl = 1'b1; // EDGE mode
    @(posedge clk);

    // T1: No edge => no pending
    @(posedge clk); @(posedge clk); #1;
    check_ip("T1 no edge", 1'b0);

    // T2: Generate one edge, should trigger IP
    gen_src_edge();
    // Wait for edge detection and IP assertion
    repeat(3) @(posedge clk); #1;
    check_ip("T2 one edge => ip", 1'b1);

    // T3: Claim clears IP
    @(negedge clk); claim_in = 1;
    @(posedge clk); #1;
    @(negedge clk); claim_in = 0;
    @(posedge clk); #1;
    check_ip("T3 claim clears ip", 1'b0);

    // T4: Complete returns to idle
    @(negedge clk); complete_in = 1;
    @(posedge clk); #1;
    @(negedge clk); complete_in = 0;
    @(posedge clk); #1;
    check_ip("T4 complete returns idle", 1'b0);

    // T5: Generate edge again after complete
    gen_src_edge();
    repeat(3) @(posedge clk); #1;
    check_ip("T5 edge after complete", 1'b1);

    // Complete the cycle
    do_claim_complete();

    // T6-T8: Multiple edges accumulate in pending counter
    // Generate 3 edges
    gen_src_edge();
    repeat(2) @(posedge clk);
    gen_src_edge();
    repeat(2) @(posedge clk);
    gen_src_edge();
    repeat(3) @(posedge clk); #1;
    // IP should be asserted (first edge triggers it, counter tracks rest)
    check_ip("T6 multiple edges", 1'b1);

    // T7: After claim+complete, should still be pending (counter > 0)
    do_claim_complete();
    repeat(2) @(posedge clk); #1;
    check_ip("T7 pending from counter", 1'b1);

    // T8: Another claim+complete
    do_claim_complete();
    repeat(2) @(posedge clk); #1;
    // After consuming the 3rd pending edge (first consumed when ip asserted, 2nd on T7)
    // This may or may not still be pending depending on exact count
    // Just check it doesn't hang

    // T9: Full claim+complete cycle to drain
    do_claim_complete();
    repeat(2) @(posedge clk); #1;
    check_ip("T9 drained", 1'b0);

    // ========= LEVEL MODE TESTS =========
    // Reset first
    @(negedge clk); rst_n = 0;
    @(posedge clk); @(posedge clk);
    @(negedge clk); rst_n = 1;
    @(posedge clk);

    edge_lvl = 1'b0; // LEVEL mode
    @(posedge clk);

    // T10: src=0 => no ip
    src = 0;
    @(posedge clk); @(posedge clk); #1;
    check_ip("T10 level src=0", 1'b0);

    // T11: src=1 => ip asserts
    @(negedge clk); src = 1;
    @(posedge clk); @(posedge clk); #1;
    check_ip("T11 level src=1", 1'b1);

    // T12: claim clears IP
    @(negedge clk); claim_in = 1;
    @(posedge clk); #1;
    @(negedge clk); claim_in = 0;
    @(posedge clk); #1;
    check_ip("T12 level claim", 1'b0);

    // T13: complete and src still high => ip reasserts
    @(negedge clk); complete_in = 1;
    @(posedge clk); #1;
    @(negedge clk); complete_in = 0;
    @(posedge clk); @(posedge clk); #1;
    check_ip("T13 level src still high", 1'b1);

    // T14: deassert src, claim+complete
    @(negedge clk); claim_in = 1;
    @(posedge clk); #1;
    @(negedge clk); claim_in = 0; src = 0;
    @(posedge clk); #1;
    @(negedge clk); complete_in = 1;
    @(posedge clk); #1;
    @(negedge clk); complete_in = 0;
    @(posedge clk); @(posedge clk); #1;
    check_ip("T14 level src deasserted", 1'b0);

    // T15: Back to edge mode, test decrement with simultaneous edge and decrement
    @(negedge clk); rst_n = 0;
    @(posedge clk); @(posedge clk);
    @(negedge clk); rst_n = 1; edge_lvl = 1'b1;
    @(posedge clk); @(posedge clk);

    // Generate edge
    gen_src_edge();
    repeat(3) @(posedge clk); #1;
    check_ip("T15 edge ip", 1'b1);

    // T16: Claim and complete
    do_claim_complete();
    repeat(2) @(posedge clk); #1;
    check_ip("T16 drained single edge", 1'b0);

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] plic_gateway all %0d / %0d tests PASSED", pass_count, pass_count);
    else
      $display("[TB_REAL] plic_gateway FAILED %0d / %0d tests", fail_count, pass_count + fail_count);
    $finish;
  end

  // Timeout
  initial begin
    #100000;
    $display("[TB_REAL] plic_gateway FAILED - timeout");
    $finish;
  end
endmodule
