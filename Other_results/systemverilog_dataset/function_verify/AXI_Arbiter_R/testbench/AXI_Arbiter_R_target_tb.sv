`timescale 1ns/1ps
`include "../AXI_Arbiter_R_original.sv"

module AXI_Arbiter_R_target_tb;
  logic ACLK, ARESETn;
  logic m0_ARVALID, m0_RREADY;
  logic m1_ARVALID, m1_RREADY;
  logic m2_ARVALID, m2_RREADY;
  logic m3_ARVALID, m3_RREADY;
  logic m_RVALID, m_RLAST;
  logic m0_rgrnt, m1_rgrnt, m2_rgrnt, m3_rgrnt;

  AXI_Arbiter_R dut(
    .ACLK(ACLK),
    .ARESETn(ARESETn),
    .m0_ARVALID(m0_ARVALID),
    .m0_RREADY(m0_RREADY),
    .m1_ARVALID(m1_ARVALID),
    .m1_RREADY(m1_RREADY),
    .m2_ARVALID(m2_ARVALID),
    .m2_RREADY(m2_RREADY),
    .m3_ARVALID(m3_ARVALID),
    .m3_RREADY(m3_RREADY),
    .m_RVALID(m_RVALID),
    .m_RLAST(m_RLAST),
    .m0_rgrnt(m0_rgrnt),
    .m1_rgrnt(m1_rgrnt),
    .m2_rgrnt(m2_rgrnt),
    .m3_rgrnt(m3_rgrnt)
  );

  initial ACLK = 0;
  always #5 ACLK = ~ACLK;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task clear_inputs;
    m0_ARVALID = 0; m0_RREADY = 0;
    m1_ARVALID = 0; m1_RREADY = 0;
    m2_ARVALID = 0; m2_RREADY = 0;
    m3_ARVALID = 0; m3_RREADY = 0;
    m_RVALID = 0; m_RLAST = 0;
  endtask

  task check_grant(input logic exp0, exp1, exp2, exp3, input string msg);
    total_tests++;
    if (m0_rgrnt !== exp0 || m1_rgrnt !== exp1 || m2_rgrnt !== exp2 || m3_rgrnt !== exp3) begin
      $display("FAIL: %s - expected %b%b%b%b got %b%b%b%b",
               msg, exp0, exp1, exp2, exp3, m0_rgrnt, m1_rgrnt, m2_rgrnt, m3_rgrnt);
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

    // Navigate to state MASTER_1 by having m1 request from MASTER_0
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;

    // Test 2: Now in MASTER_1
    check_grant(0, 1, 0, 0, "T2: transition to MASTER_1");

    // === TARGET TESTS: behavior in AXI_MASTER_1 state ===

    // Test 3: In MASTER_1, m1_ARVALID=1 => stay in MASTER_1
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 1, 0, 0, "T3: MASTER_1 + m1_ARVALID => stay MASTER_1");

    // Test 4: In MASTER_1, m_RVALID=1 (ongoing read) => stay in MASTER_1
    clear_inputs();
    m_RVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 1, 0, 0, "T4: MASTER_1 + m_RVALID => stay MASTER_1");

    // Test 5: In MASTER_1, m1_RREADY=1 (ongoing read) => stay in MASTER_1
    clear_inputs();
    m1_RREADY = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 1, 0, 0, "T5: MASTER_1 + m1_RREADY => stay MASTER_1");

    // Test 6: In MASTER_1, m2_ARVALID=1 => go to MASTER_2
    clear_inputs();
    m2_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T6: MASTER_1 + m2_ARVALID => MASTER_2");

    // Go back to MASTER_1: from MASTER_2, request m1
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;
    check_grant(0, 1, 0, 0, "T6b: back to MASTER_1");

    // Test 7: In MASTER_1, m3_ARVALID=1 => go to MASTER_3
    clear_inputs();
    m3_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T7: MASTER_1 + m3_ARVALID => MASTER_3");

    // Go back to MASTER_1
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;
    check_grant(0, 1, 0, 0, "T7b: back to MASTER_1");

    // Test 8: In MASTER_1, m0_ARVALID=1 => go to MASTER_0
    clear_inputs();
    m0_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T8: MASTER_1 + m0_ARVALID => MASTER_0");

    // Go back to MASTER_1
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;
    check_grant(0, 1, 0, 0, "T8b: back to MASTER_1");

    // Test 9 (KEY TARGET TEST): In MASTER_1, NO requests at all => should go to MASTER_0
    // This is the else branch: next_state = AXI_MASTER_0 (not MASTER_1)
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T9: MASTER_1 + no requests => MASTER_0 (default)");

    // Test 10: Verify from MASTER_0, no requests => stays MASTER_0
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T10: MASTER_0 + no requests => stay MASTER_0");

    // === TARGET TESTS: MASTER_2 state behavior ===
    // Navigate: MASTER_0 -> MASTER_2
    clear_inputs();
    m2_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_ARVALID = 0;
    check_grant(0, 0, 1, 0, "T11: transition to MASTER_2");

    // Test 12: In MASTER_2, m2_ARVALID => stay
    clear_inputs();
    m2_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T12: MASTER_2 + m2_ARVALID => stay MASTER_2");

    // Test 13: In MASTER_2, m2_RREADY => stay (ongoing read)
    clear_inputs();
    m2_RREADY = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T13: MASTER_2 + m2_RREADY => stay MASTER_2");

    // Test 14: In MASTER_2, m3_ARVALID => MASTER_3
    clear_inputs();
    m3_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T14: MASTER_2 + m3_ARVALID => MASTER_3");

    // Go back to MASTER_2
    clear_inputs();
    m2_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m2_ARVALID = 0;

    // Test 15: In MASTER_2, no requests => stay MASTER_2
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T15: MASTER_2 + no requests => stay MASTER_2");

    // Test 16: In MASTER_2, m0_ARVALID => MASTER_0
    clear_inputs();
    m0_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T16: MASTER_2 + m0_ARVALID => MASTER_0");

    // Navigate to MASTER_1, then test default again
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;

    // Test 17: Repeat - MASTER_1 idle => MASTER_0
    clear_inputs();
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(1, 0, 0, 0, "T17: MASTER_1 + no activity => MASTER_0 (repeat)");

    // Test 18: priority check in MASTER_1: m2 and m3 both valid, m2 wins
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;
    // Now in MASTER_1
    clear_inputs();
    m2_ARVALID = 1;
    m3_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 1, 0, "T18: MASTER_1 + m2&m3 valid => MASTER_2 (priority)");

    // Test 19: priority in MASTER_1: m0 and m3 valid, m3 wins (higher priority in MASTER_1)
    // In MASTER_1: priority is 1>2>3>0, so m3 should win over m0
    clear_inputs();
    m1_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    m1_ARVALID = 0;
    // Now in MASTER_1
    clear_inputs();
    m3_ARVALID = 1;
    m0_ARVALID = 1;
    @(posedge ACLK);
    @(negedge ACLK);
    check_grant(0, 0, 0, 1, "T19: MASTER_1 + m3&m0 valid => MASTER_3 (m3 higher priority)");

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] AXI_Arbiter_R all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] AXI_Arbiter_R FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
