`timescale 1ns/1ps
`include "../plic_cell_original.sv"

module plic_cell_target_tb;
  // Parameters
  localparam ID         = 3;
  localparam SOURCES    = 8;
  localparam PRIORITIES = 7;
  localparam SOURCES_BITS  = $clog2(SOURCES + 1);
  localparam PRIORITY_BITS = $clog2(PRIORITIES);

  logic                          rst_ni;
  logic                          clk_i;
  logic                          ip_i;
  logic                          ie_i;
  logic [PRIORITY_BITS-1:0]      priority_i;
  logic [SOURCES_BITS-1:0]       id_o;
  logic [PRIORITY_BITS-1:0]      priority_o;

  plic_cell #(
    .ID       (ID),
    .SOURCES  (SOURCES),
    .PRIORITIES(PRIORITIES)
  ) dut (
    .rst_ni     (rst_ni),
    .clk_i      (clk_i),
    .ip_i       (ip_i),
    .ie_i       (ie_i),
    .priority_i (priority_i),
    .id_o       (id_o),
    .priority_o (priority_o)
  );

  always #5 clk_i = ~clk_i;

  integer pass_count, fail_count;

  task automatic check(input string test_name,
                       input [PRIORITY_BITS-1:0] exp_priority,
                       input [SOURCES_BITS-1:0] exp_id);
    if (priority_o !== exp_priority || id_o !== exp_id) begin
      $display("FAIL %s: priority_o=%0d (exp %0d), id_o=%0d (exp %0d)",
               test_name, priority_o, exp_priority, id_o, exp_id);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    clk_i = 0; rst_ni = 0; ip_i = 0; ie_i = 0; priority_i = '0;
    pass_count = 0; fail_count = 0;

    // Test 1: Reset clears outputs
    @(posedge clk_i); #1;
    check("T1 reset priority_o=0", 0, 0);

    // Release reset
    @(negedge clk_i); rst_ni = 1;

    // Test 2: ip=0, ie=0 => priority_o=0
    @(negedge clk_i); ip_i = 0; ie_i = 0; priority_i = 3;
    @(posedge clk_i); #1;
    check("T2 ip=0,ie=0", 0, 0);

    // Test 3: ip=1, ie=0 => priority_o=0 (not enabled)
    @(negedge clk_i); ip_i = 1; ie_i = 0; priority_i = 3;
    @(posedge clk_i); #1;
    check("T3 ip=1,ie=0", 0, 0);

    // Test 4: ip=0, ie=1 => priority_o=0 (not pending)
    @(negedge clk_i); ip_i = 0; ie_i = 1; priority_i = 3;
    @(posedge clk_i); #1;
    check("T4 ip=0,ie=1", 0, 0);

    // Test 5: ip=1, ie=1 => priority_o = priority_i, id_o = ID
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = 3;
    @(posedge clk_i); #1;
    check("T5 ip=1,ie=1,p=3", 3, ID);

    // Test 6: Change priority while active
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = 5;
    @(posedge clk_i); #1;
    check("T6 ip=1,ie=1,p=5", 5, ID);

    // Test 7: Max priority value
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = {PRIORITY_BITS{1'b1}};
    @(posedge clk_i); #1;
    check("T7 max priority", {PRIORITY_BITS{1'b1}}, ID);

    // Test 8: Min priority = 0
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = 0;
    @(posedge clk_i); #1;
    check("T8 priority=0", 0, ID);

    // Test 9: priority=1
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = 1;
    @(posedge clk_i); #1;
    check("T9 priority=1", 1, ID);

    // Test 10: Deassert ip, priority goes to 0
    @(negedge clk_i); ip_i = 0; ie_i = 1; priority_i = 5;
    @(posedge clk_i); #1;
    check("T10 deassert ip", 0, 0);

    // Test 11: Deassert ie, priority goes to 0
    @(negedge clk_i); ip_i = 1; ie_i = 0; priority_i = 5;
    @(posedge clk_i); #1;
    check("T11 deassert ie", 0, 0);

    // Test 12: Re-assert both
    @(negedge clk_i); ip_i = 1; ie_i = 1; priority_i = 2;
    @(posedge clk_i); #1;
    check("T12 reassert", 2, ID);

    // Test 13: Assert reset while active
    @(negedge clk_i); rst_ni = 0;
    @(posedge clk_i); #1;
    check("T13 reset while active", 0, 0);

    // Test 14: Release reset, ip/ie still high
    @(negedge clk_i); rst_ni = 1;
    @(posedge clk_i); #1;
    check("T14 after reset release", 2, ID);

    // Test 15: Toggle ip rapidly
    @(negedge clk_i); ip_i = 0; ie_i = 1; priority_i = 4;
    @(posedge clk_i); #1;
    check("T15 ip=0", 0, 0);
    @(negedge clk_i); ip_i = 1;
    @(posedge clk_i); #1;
    check("T16 ip=1 again", 4, ID);

    // Test 17: priority_i = 6
    @(negedge clk_i); priority_i = 6;
    @(posedge clk_i); #1;
    check("T17 p=6", 6, ID);

    // Test 18-20: Both deasserted for multiple cycles
    @(negedge clk_i); ip_i = 0; ie_i = 0;
    @(posedge clk_i); #1;
    check("T18 both 0 cyc1", 0, 0);
    @(posedge clk_i); #1;
    check("T19 both 0 cyc2", 0, 0);
    @(posedge clk_i); #1;
    check("T20 both 0 cyc3", 0, 0);

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] plic_cell all %0d / %0d tests PASSED", pass_count, pass_count);
    else
      $display("[TB_REAL] plic_cell FAILED %0d / %0d tests", fail_count, pass_count + fail_count);
    $finish;
  end
endmodule
