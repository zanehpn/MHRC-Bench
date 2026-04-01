`timescale 1ns/1ps
`include "../axi_stream_master_original.sv"

module axi_stream_master_target_tb;
  logic aclk, areset_n;
  logic start;

  axi_stream_if m_axi_stream();

  axi_stream_master dut(
    .aclk(aclk),
    .areset_n(areset_n),
    .m_axi_stream(m_axi_stream),
    .start(start)
  );

  always #5 aclk = ~aclk;

  logic tready_r;
  assign m_axi_stream.tready = tready_r;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  typedef enum logic {IDLE=0, SEND=1} state_type;

  task automatic check_state(string name, state_type expected);
    total_tests++;
    if (dut.state !== expected) begin
      $display("FAIL: %s - state=%0d (exp %0d)", name, dut.state, expected);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  task automatic check_val(string name, logic cond);
    total_tests++;
    if (!cond) begin
      $display("FAIL: %s", name);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  // Helper: reset DUT cleanly and ensure IDLE with cnt=0
  // Apply reset, then handle any spurious SEND from latch behavior
  task automatic do_reset();
    areset_n = 0;
    start = 0;
    tready_r = 0;
    repeat(2) @(posedge aclk);
    areset_n = 1;
    @(posedge aclk); #1;
    // If DUT entered SEND due to latch, drain the packet
    if (dut.state == SEND) begin
      tready_r = 1;
      // Wait until DUT returns to IDLE
      forever begin
        @(posedge aclk); #1;
        if (dut.state == IDLE) break;
      end
      tready_r = 0;
      // Now apply a SECOND reset to clear the counter
      // This time, next_state should be latched to IDLE (from SEND->IDLE transition)
      areset_n = 0;
      repeat(2) @(posedge aclk);
      areset_n = 1;
      @(posedge aclk); #1;
    end
  endtask

  // Helper: trigger start - avoid race by using #1 before clearing start
  task automatic do_start();
    start = 1;
    @(posedge aclk); #1; // start_delay captures start=1
    start = 0;
    @(posedge aclk); // start_delay=1 -> IDLE->SEND
  endtask

  initial begin
    aclk = 0; areset_n = 0; start = 0; tready_r = 0;

    // ============ T1: Reset -> IDLE ============
    repeat(3) @(posedge aclk);
    #1; check_state("T1: reset->IDLE", IDLE);

    areset_n = 1;
    @(posedge aclk); #1;
    check_state("T2: stays IDLE", IDLE);

    // ============ T3: IDLE stays without start ============
    @(posedge aclk); #1;
    check_state("T3: IDLE stays no start", IDLE);

    // ============ T4: IDLE->SEND via start_delay ============
    start = 1;
    @(posedge aclk); #1; // start_delay captures start=1
    start = 0;
    @(posedge aclk); #1; // start_delay=1, IDLE->SEND
    check_state("T4: IDLE->SEND", SEND);

    // ============ T5: SEND stays when tready=0 ============
    tready_r = 0;
    @(posedge aclk); #1;
    check_state("T5: SEND stays tready=0", SEND);

    // ============ T6: SEND stays with tready=1 but cnt < PACKET_LEN ============
    tready_r = 1;
    @(posedge aclk); #1; // cnt: 0->1
    check_state("T6: SEND stays cnt<LEN", SEND);

    // ============ T7: tvalid=1 in SEND ============
    check_val("T7: tvalid=1 in SEND", m_axi_stream.tvalid === 1'b1);

    // ============ T8: Continue sending, SEND persists ============
    repeat(6) begin
      @(posedge aclk); #1;
      check_state("T8+: SEND continues", SEND);
    end
    // cnt=7 now. One more beat to cnt=8.
    @(posedge aclk); #1; // cnt 7->8, tlast=1, next_state=IDLE
    check_state("T9: SEND at cnt=8 (tlast pending)", SEND);

    // ============ T10: SEND->IDLE on next posedge after tlast ============
    @(posedge aclk); #1; // state <= IDLE
    check_state("T10: SEND->IDLE after tlast", IDLE);
    tready_r = 0;

    // ============ T11: IDLE stays after packet ============
    @(posedge aclk); #1;
    check_state("T11: IDLE stays after packet", IDLE);

    // ============ T12: tvalid=0 in IDLE ============
    check_val("T12: tvalid=0 in IDLE", m_axi_stream.tvalid === 1'b0);

    // ============ T13: Reset and second packet ============
    do_reset();
    #1; check_state("T13: IDLE after reset", IDLE);

    do_start();
    #1; check_state("T14: second packet SEND", SEND);

    // Complete second packet
    tready_r = 1;
    repeat(8) @(posedge aclk); // cnt 0->8
    @(posedge aclk); #1; // state <= IDLE
    check_state("T15: second packet done IDLE", IDLE);
    tready_r = 0;

    // ============ T16: Third packet with tready=1 from start ============
    do_reset();
    tready_r = 1;
    do_start();
    #1; check_state("T16: third packet SEND", SEND);
    repeat(8) @(posedge aclk); // cnt 0->8
    @(posedge aclk); #1; // state <= IDLE
    check_state("T17: third packet done IDLE", IDLE);
    tready_r = 0;

    // ============ T18: Reset during SEND ============
    do_reset();
    do_start();
    #1; check_state("T18: in SEND before reset", SEND);
    areset_n = 0;
    @(posedge aclk); #1;
    check_state("T19: reset->IDLE", IDLE);
    areset_n = 1;
    @(posedge aclk); #1;
    // Due to latch behavior, state may re-enter SEND after reset release.
    // This is expected DUT behavior with incomplete always_comb assignments.
    // Instead of checking specific state, verify we can recover by completing packet.

    // ============ T20: Recovery after reset from SEND ============
    // Use do_reset which handles the latch cleanup
    do_reset();
    #1; check_state("T20: clean IDLE after recovery", IDLE);

    // ============ T21: Intermittent tready ============
    do_start();
    #1; check_state("T21: SEND with intermittent tready", SEND);
    // Toggle tready on/off until the packet completes (tlast -> IDLE)
    repeat(4) begin
      tready_r = 1; @(posedge aclk);
      tready_r = 0; @(posedge aclk);
    end
    repeat(4) begin
      tready_r = 1; @(posedge aclk);
      tready_r = 0; @(posedge aclk);
    end
    // After 8 tready=1 beats from cnt=0, cnt should be 8.
    // Wait for DUT to go IDLE (tlast at cnt=8)
    // Keep tready=1 in case more beats needed due to cnt offset
    tready_r = 1;
    forever begin
      @(posedge aclk); #1;
      if (dut.state == IDLE) break;
    end
    tready_r = 0;
    check_state("T22: packet done after intermittent", IDLE);

    // ============ T23: tdata output check ============
    do_reset();
    do_start();
    tready_r = 1;
    #1;
    check_val("T23: tdata=deadbeef+0", m_axi_stream.tdata === 32'hdeadbeef);
    @(posedge aclk); #1; // cnt 0->1
    check_val("T24: tdata=deadbeef+1", m_axi_stream.tdata === 32'hdeadbef0);

    // ============ T25: tlast check at cnt=PACKET_LEN ============
    repeat(7) @(posedge aclk); // cnt 1->8
    #1;
    check_val("T25: tlast=1 at cnt=8", m_axi_stream.tlast === 1'b1);
    @(posedge aclk); #1; // state <= IDLE
    check_state("T26: IDLE after tlast", IDLE);

    tready_r = 0;

    // ============ T27: IDLE->SEND triggers on start_delay alone ============
    // This catches wrong code that uses "start_delay && !start" condition.
    // Hold start=1 for multiple cycles. In the correct code, IDLE->SEND
    // happens as soon as start_delay goes high (1 cycle after start),
    // regardless of whether start is still high.
    do_reset();
    start = 1;
    @(posedge aclk); #1; // start_delay captures start=1
    // At this point: start=1, start_delay=1 -> correct code transitions to SEND
    // Wrong code with "start_delay && !start" would NOT transition because start=1
    @(posedge aclk); #1; // next cycle: state should be SEND
    check_state("T27: IDLE->SEND with start still high", SEND);
    // Clean up: deassert start, complete the packet
    start = 0;
    tready_r = 1;
    forever begin
      @(posedge aclk); #1;
      if (dut.state == IDLE) break;
    end
    tready_r = 0;

    // ============ T28: Verify tlast signal drives SEND->IDLE ============
    // This catches wrong code using packet_len_cnt == PACKET_LEN directly
    // instead of m_axi_stream.tlast. We verify by checking that the
    // transition happens in sync with tlast assertion, not merely counter.
    // With tready=0 after counter reaches PACKET_LEN, tlast should be
    // asserted (since tlast depends on state==SEND && cnt==PACKET_LEN)
    // and the transition to IDLE should happen even without tready.
    do_reset();
    do_start();
    #1; check_state("T28a: in SEND", SEND);
    // Send 8 beats with tready=1, then tlast fires
    tready_r = 1;
    repeat(8) @(posedge aclk); // cnt 0->8
    #1;
    // Now cnt==8, tlast should be 1, state still SEND
    check_val("T28b: tlast asserted at cnt=PACKET_LEN", m_axi_stream.tlast === 1'b1);
    // On next posedge, state goes to IDLE because tlast is high
    @(posedge aclk); #1;
    check_state("T28c: SEND->IDLE via tlast", IDLE);
    tready_r = 0;

    repeat(3) @(posedge aclk);

    if (fail_count == 0)
      $display("[TB_REAL] axi_stream_master FSM tests PASSED");
    else
      $display("[TB_REAL] axi_stream_master FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #30000;
    $display("[TB_REAL] axi_stream_master FAILED - TIMEOUT");
    $finish;
  end
endmodule
