`timescale 1ns/1ps
`include "../cic_comb_original.sv"

module cic_comb_target_tb;
  bit clk;
  bit rst;
  bit ena;
  bit [31:0] data_in;
  bit [31:0] data_out;

  always #5 clk = ~clk;

  cic_comb dut (
    .clk(clk),
    .rst(rst),
    .ena(ena),
    .data_in(data_in),
    .data_out(data_out)
  );

  integer pass_count, fail_count;

  task automatic check(input string test_name, input bit [31:0] exp_data_out);
    if (data_out !== exp_data_out) begin
      $display("FAIL %s: data_out=%0d (exp %0d)", test_name, data_out, exp_data_out);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  bit [31:0] r_data_model;

  initial begin
    clk = 0; rst = 0; ena = 0; data_in = 0;
    pass_count = 0; fail_count = 0;
    r_data_model = 0;

    // Test 1: Assert reset, data_out should be 0
    rst = 1; ena = 0; data_in = 32'hDEAD;
    @(posedge clk); #1;
    check("T1 reset clears data_out", 0);

    // Test 2: Reset also clears r_data (internal), check via subsequent enable
    rst = 0;
    @(posedge clk); #1;

    // Test 3: Enable with data_in=100, r_data was 0 after reset
    // data_out <= r_data(0) - data_in(100) = -100 (unsigned wrap)
    ena = 1; data_in = 32'd100;
    @(posedge clk); #1;
    check("T3 first sample after reset", 32'd0 - 32'd100);

    // Test 4: data_in=200, r_data was 100
    // data_out <= 100 - 200 = -100 (unsigned wrap)
    data_in = 32'd200;
    @(posedge clk); #1;
    check("T4 second sample", 32'd100 - 32'd200);

    // Test 5: data_in=200, r_data was 200
    // data_out <= 200 - 200 = 0
    data_in = 32'd200;
    @(posedge clk); #1;
    check("T5 same value", 32'd0);

    // Test 6: data_in=300, r_data was 200
    data_in = 32'd300;
    @(posedge clk); #1;
    check("T6 increasing", 32'd200 - 32'd300);

    // Test 7: Assert reset while enabled - should clear data_out
    rst = 1;
    @(posedge clk); #1;
    check("T7 reset while ena", 0);

    // Test 8: Still in reset, data_out stays 0
    data_in = 32'hFFFF;
    @(posedge clk); #1;
    check("T8 still reset", 0);

    // Test 9: Release reset, enable with new data
    // r_data was cleared by reset, so r_data=0
    rst = 0; ena = 1; data_in = 32'd50;
    @(posedge clk); #1;
    check("T9 after reset release", 32'd0 - 32'd50);

    // Test 10: data_in=50, r_data=50 => 50-50=0
    data_in = 32'd50;
    @(posedge clk); #1;
    check("T10 equal", 0);

    // Test 11: Disable ena, outputs should hold
    ena = 0; data_in = 32'd999;
    @(posedge clk); #1;
    check("T11 ena=0 hold", 0);

    // Test 12: Still disabled
    @(posedge clk); #1;
    check("T12 ena=0 hold2", 0);

    // Test 13: Re-enable, r_data should still be 50 (last stored)
    ena = 1; data_in = 32'd60;
    @(posedge clk); #1;
    check("T13 re-enable", 32'd50 - 32'd60);

    // Test 14: Reset has priority over enable
    rst = 1; ena = 1; data_in = 32'd100;
    @(posedge clk); #1;
    check("T14 rst priority over ena", 0);

    // Test 15: Release reset again
    rst = 0; ena = 1; data_in = 32'd10;
    @(posedge clk); #1;
    check("T15 post-reset2", 32'd0 - 32'd10);

    // Test 16: Large value
    data_in = 32'hFFFFFFFF;
    @(posedge clk); #1;
    check("T16 large value", 32'd10 - 32'hFFFFFFFF);

    // Test 17: data_in = 0
    data_in = 32'd0;
    @(posedge clk); #1;
    check("T17 data_in=0", 32'hFFFFFFFF - 32'd0);

    // Test 18: Reset clears after large values
    rst = 1;
    @(posedge clk); #1;
    check("T18 reset after large", 0);

    // Test 19-20: Multiple resets
    rst = 0;
    @(posedge clk);
    rst = 1;
    @(posedge clk); #1;
    check("T19 double reset", 0);

    rst = 0; ena = 1; data_in = 32'd5;
    @(posedge clk); #1;
    check("T20 after double reset", 32'd0 - 32'd5);

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] cic_comb all %0d / %0d tests PASSED", pass_count, pass_count);
    else
      $display("[TB_REAL] cic_comb FAILED %0d / %0d tests", fail_count, pass_count + fail_count);
    $finish;
  end
endmodule
