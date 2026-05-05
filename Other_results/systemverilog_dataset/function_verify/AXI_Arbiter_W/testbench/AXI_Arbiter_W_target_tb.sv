`timescale 1ns/1ps
`include "../AXI_Arbiter_W_original.sv"

module AXI_Arbiter_W_target_tb;
  logic ACLK, ARESETn;
  logic m0_AWVALID, m0_WVALID, m0_BREADY;
  logic m1_AWVALID, m1_WVALID, m1_BREADY;
  logic m2_AWVALID, m2_WVALID, m2_BREADY;
  logic m3_AWVALID, m3_WVALID, m3_BREADY;
  logic m_AWREADY, m_WREADY, m_BVALID;
  logic m0_wgrnt, m1_wgrnt, m2_wgrnt, m3_wgrnt;

  AXI_Arbiter_W dut (
    .ACLK(ACLK),
    .ARESETn(ARESETn),
    .m0_AWVALID(m0_AWVALID), .m0_WVALID(m0_WVALID), .m0_BREADY(m0_BREADY),
    .m1_AWVALID(m1_AWVALID), .m1_WVALID(m1_WVALID), .m1_BREADY(m1_BREADY),
    .m2_AWVALID(m2_AWVALID), .m2_WVALID(m2_WVALID), .m2_BREADY(m2_BREADY),
    .m3_AWVALID(m3_AWVALID), .m3_WVALID(m3_WVALID), .m3_BREADY(m3_BREADY),
    .m_AWREADY(m_AWREADY), .m_WREADY(m_WREADY), .m_BVALID(m_BVALID),
    .m0_wgrnt(m0_wgrnt), .m1_wgrnt(m1_wgrnt), .m2_wgrnt(m2_wgrnt), .m3_wgrnt(m3_wgrnt)
  );

  initial ACLK = 0;
  always #5 ACLK = ~ACLK;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task clear_inputs;
    m0_AWVALID = 0; m0_WVALID = 0; m0_BREADY = 0;
    m1_AWVALID = 0; m1_WVALID = 0; m1_BREADY = 0;
    m2_AWVALID = 0; m2_WVALID = 0; m2_BREADY = 0;
    m3_AWVALID = 0; m3_WVALID = 0; m3_BREADY = 0;
    m_AWREADY = 0; m_WREADY = 0; m_BVALID = 0;
  endtask

  task check_grant(input logic exp0, exp1, exp2, exp3, input string msg);
    total_tests++;
    if (m0_wgrnt !== exp0 || m1_wgrnt !== exp1 || m2_wgrnt !== exp2 || m3_wgrnt !== exp3) begin
      $display("FAIL: %s - expected %b%b%b%b got %b%b%b%b",
               msg, exp0, exp1, exp2, exp3, m0_wgrnt, m1_wgrnt, m2_wgrnt, m3_wgrnt);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    // Reset
    ARESETn = 0;
    clear_inputs();
    @(posedge ACLK);
    @(posedge ACLK);
    ARESETn = 1;
    @(posedge ACLK);
    @(negedge ACLK);

    // Test 1: After reset, state = MASTER_0
    check_grant(1, 0, 0, 0, "T1: reset state is MASTER_0");

    // Navigate to MASTER_2: MASTER_0 -> m2 request
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 2: Now in MASTER_2
    check_grant(0, 0, 1, 0, "T2: transition to MASTER_2");

    // === TARGET TESTS: default branch in AXI_MASTER_2 state ===

    // Test 3: In MASTER_2, m2_AWVALID=1 => stay MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T3: MASTER_2 + m2_AWVALID => stay MASTER_2");

    // Test 4: In MASTER_2, m2_WVALID=1 (ongoing write) => stay MASTER_2
    clear_inputs();
    m2_WVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T4: MASTER_2 + m2_WVALID => stay MASTER_2");

    // Test 5: In MASTER_2, m_WREADY=1 (ongoing write) => stay MASTER_2
    clear_inputs();
    m_WREADY = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T5: MASTER_2 + m_WREADY => stay MASTER_2");

    // Test 6: In MASTER_2, m3_AWVALID=1 => go to MASTER_3
    clear_inputs();
    m3_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T6: MASTER_2 + m3_AWVALID => MASTER_3");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 7: In MASTER_2, m0_AWVALID=1 => go to MASTER_0
    clear_inputs();
    m0_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T7: MASTER_2 + m0_AWVALID => MASTER_0");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 8: In MASTER_2, m1_AWVALID=1 => go to MASTER_1
    clear_inputs();
    m1_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 1, 0, 0, "T8: MASTER_2 + m1_AWVALID => MASTER_1");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 9 (KEY TARGET TEST): In MASTER_2, no requests => stay MASTER_2
    // This is the else branch: next_state = AXI_MASTER_2
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T9: MASTER_2 + no requests => stay MASTER_2 (default)");

    // Test 10: Repeat - still no requests, still MASTER_2
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T10: MASTER_2 + no requests => stay MASTER_2 (repeat)");

    // Test 11: Again from MASTER_2 idle
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T11: MASTER_2 + no requests => still MASTER_2 (3rd)");

    // Test 12: m_BVALID && m2_BREADY => go to MASTER_3
    clear_inputs();
    m_BVALID = 1;
    m2_BREADY = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T12: MASTER_2 + BVALID&BREADY => MASTER_3");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 13: priority in MASTER_2: m3 and m0 both valid, m3 should win
    clear_inputs();
    m3_AWVALID = 1;
    m0_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T13: MASTER_2 + m3&m0 valid => MASTER_3 (priority)");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 14: priority in MASTER_2: m0 and m1 both valid, m0 should win
    clear_inputs();
    m0_AWVALID = 1;
    m1_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T14: MASTER_2 + m0&m1 valid => MASTER_0 (priority)");

    // Go back to MASTER_2
    clear_inputs();
    m2_AWVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_AWVALID = 0;

    // Test 15: no activity again
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T15: MASTER_2 + idle => stay MASTER_2");

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] AXI_Arbiter_W all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] AXI_Arbiter_W FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
