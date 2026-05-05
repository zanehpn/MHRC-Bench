`timescale 1ns/1ps
`include "../axi_slave_original.sv"

// TARGET: line 50 in axi_slave.sv - RADDR state captures:
//   addr  <= s_axi.araddr;
//   len   <= s_axi.arlen;
//   size  <= s_axi.arsize;
//   burst <= s_axi.arburst;

module axi_slave_target_tb;
  logic aclk, areset_n;

  axi_if s_axi();

  axi_slave dut(
    .aclk(aclk),
    .areset_n(areset_n),
    .s_axi(s_axi)
  );

  always #5 aclk = ~aclk;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  task automatic check_raddr_capture(string name,
    logic [31:0] exp_addr, logic [7:0] exp_len, logic [2:0] exp_size, logic [1:0] exp_burst);
    total_tests++;
    if (dut.addr !== exp_addr || dut.len !== exp_len || dut.size !== exp_size || dut.burst !== exp_burst) begin
      $display("FAIL: %s addr=%h(exp %h) len=%h(exp %h) size=%h(exp %h) burst=%h(exp %h)",
        name, dut.addr, exp_addr, dut.len, exp_len, dut.size, exp_size, dut.burst, exp_burst);
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

  initial begin
    aclk = 0; areset_n = 0;
    s_axi.araddr  = 0; s_axi.arvalid = 0;
    s_axi.arlen   = 0; s_axi.arsize  = 0; s_axi.arburst = 0;
    s_axi.rready  = 0;
    s_axi.awaddr  = 0; s_axi.awvalid = 0;
    s_axi.awlen   = 0; s_axi.awsize  = 0; s_axi.awburst = 0;
    s_axi.wdata   = 0; s_axi.wstrb   = 0;
    s_axi.wvalid  = 0; s_axi.wlast   = 0;
    s_axi.bready  = 0;

    repeat(3) @(posedge aclk);
    #1;
    // T1: After reset, addr/len/size/burst are all 0
    check_raddr_capture("T1: reset values", 0, 0, 0, 0);

    areset_n = 1;
    @(posedge aclk); #1;

    // --- Test 1: Basic RADDR capture with specific values ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0000_0010;
    s_axi.arlen   = 8'h03;
    s_axi.arsize  = 3'b010;  // 4 bytes
    s_axi.arburst = 2'b01;   // INCR
    @(posedge aclk); // IDLE->RADDR
    @(posedge aclk); #1; // RADDR captures on this edge, moves to RDATA
    check_raddr_capture("T2: basic capture", 32'h10, 8'h03, 3'b010, 2'b01);
    s_axi.arvalid = 0;

    // Complete read to return to IDLE
    s_axi.rready = 1;
    repeat(4) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 2: Different address ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0000_0004;
    s_axi.arlen   = 8'h00;   // single beat
    s_axi.arsize  = 3'b010;
    s_axi.arburst = 2'b00;   // FIXED
    @(posedge aclk); // IDLE->RADDR
    @(posedge aclk); #1; // capture
    check_raddr_capture("T3: addr=4 len=0 burst=FIXED", 32'h4, 8'h00, 3'b010, 2'b00);
    s_axi.arvalid = 0;
    s_axi.rready = 1;
    repeat(2) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 3: Max length ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0000_0002;
    s_axi.arlen   = 8'h07;
    s_axi.arsize  = 3'b010;
    s_axi.arburst = 2'b01;
    @(posedge aclk); // IDLE->RADDR
    @(posedge aclk); #1;
    check_raddr_capture("T4: len=7", 32'h2, 8'h07, 3'b010, 2'b01);
    s_axi.arvalid = 0;
    s_axi.rready = 1;
    repeat(8) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 4: WRAP burst ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0000_0006;
    s_axi.arlen   = 8'h01;
    s_axi.arsize  = 3'b001;
    s_axi.arburst = 2'b10;   // WRAP
    @(posedge aclk);
    @(posedge aclk); #1;
    check_raddr_capture("T5: WRAP burst", 32'h6, 8'h01, 3'b001, 2'b10);
    s_axi.arvalid = 0;
    s_axi.rready = 1;
    repeat(3) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 5: SIZE_1_BYTE ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0000_0001;
    s_axi.arlen   = 8'h02;
    s_axi.arsize  = 3'b000;
    s_axi.arburst = 2'b01;
    @(posedge aclk);
    @(posedge aclk); #1;
    check_raddr_capture("T6: size=1byte", 32'h1, 8'h02, 3'b000, 2'b01);
    s_axi.arvalid = 0;
    s_axi.rready = 1;
    repeat(4) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 6: Address 0 ---
    s_axi.arvalid = 1;
    s_axi.araddr  = 32'h0;
    s_axi.arlen   = 8'h00;
    s_axi.arsize  = 3'b010;
    s_axi.arburst = 2'b01;
    @(posedge aclk);
    @(posedge aclk); #1;
    check_raddr_capture("T7: addr=0", 32'h0, 8'h00, 3'b010, 2'b01);
    s_axi.arvalid = 0;
    s_axi.rready = 1;
    repeat(2) @(posedge aclk);
    s_axi.rready = 0;
    @(posedge aclk); #1;

    // --- Test 7: Verify addr clears in default state ---
    // After RDATA completes, default case sets addr=0
    check_val("T8: addr clears in default", dut.addr == 0);

    // --- Test 8: Multiple successive reads with different params ---
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h3; s_axi.arlen = 8'h01; s_axi.arsize = 3'b010; s_axi.arburst = 2'b01;
    @(posedge aclk);
    @(posedge aclk); #1;
    check_raddr_capture("T9: successive read 1", 32'h3, 8'h01, 3'b010, 2'b01);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(3) @(posedge aclk);
    s_axi.rready = 0; @(posedge aclk);

    s_axi.arvalid = 1;
    s_axi.araddr = 32'h5; s_axi.arlen = 8'h03; s_axi.arsize = 3'b001; s_axi.arburst = 2'b00;
    @(posedge aclk);
    @(posedge aclk); #1;
    check_raddr_capture("T10: successive read 2", 32'h5, 8'h03, 3'b001, 2'b00);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(5) @(posedge aclk);
    s_axi.rready = 0; @(posedge aclk);

    // --- Test 9: All burst types ---
    // FIXED
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h1; s_axi.arlen = 8'h0; s_axi.arsize = 3'b010; s_axi.arburst = 2'b00;
    @(posedge aclk); @(posedge aclk); #1;
    check_raddr_capture("T11: FIXED burst", 32'h1, 8'h0, 3'b010, 2'b00);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(2) @(posedge aclk); s_axi.rready = 0; @(posedge aclk);

    // INCR
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h2; s_axi.arlen = 8'h0; s_axi.arsize = 3'b010; s_axi.arburst = 2'b01;
    @(posedge aclk); @(posedge aclk); #1;
    check_raddr_capture("T12: INCR burst", 32'h2, 8'h0, 3'b010, 2'b01);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(2) @(posedge aclk); s_axi.rready = 0; @(posedge aclk);

    // WRAP
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h3; s_axi.arlen = 8'h0; s_axi.arsize = 3'b010; s_axi.arburst = 2'b10;
    @(posedge aclk); @(posedge aclk); #1;
    check_raddr_capture("T13: WRAP burst", 32'h3, 8'h0, 3'b010, 2'b10);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(2) @(posedge aclk); s_axi.rready = 0; @(posedge aclk);

    // --- Test 10: All size values ---
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h0; s_axi.arlen = 8'h0; s_axi.arsize = 3'b011; s_axi.arburst = 2'b01;
    @(posedge aclk); @(posedge aclk); #1;
    check_raddr_capture("T14: size=8byte", 32'h0, 8'h0, 3'b011, 2'b01);
    s_axi.arvalid = 0; s_axi.rready = 1;
    repeat(2) @(posedge aclk); s_axi.rready = 0; @(posedge aclk);

    // --- Test 11: Reset clears captured values ---
    s_axi.arvalid = 1;
    s_axi.araddr = 32'h7; s_axi.arlen = 8'h05; s_axi.arsize = 3'b010; s_axi.arburst = 2'b01;
    @(posedge aclk); @(posedge aclk); #1;
    check_raddr_capture("T15: before reset capture", 32'h7, 8'h05, 3'b010, 2'b01);
    s_axi.arvalid = 0;
    areset_n = 0;
    @(posedge aclk); #1;
    check_raddr_capture("T16: reset clears all", 0, 0, 0, 0);
    areset_n = 1;
    @(posedge aclk); #1;

    repeat(3) @(posedge aclk);

    if (fail_count == 0)
      $display("[TB_REAL] axi_slave RADDR capture tests PASSED");
    else
      $display("[TB_REAL] axi_slave FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #20000;
    $display("[TB_REAL] axi_slave FAILED - TIMEOUT");
    $finish;
  end
endmodule
