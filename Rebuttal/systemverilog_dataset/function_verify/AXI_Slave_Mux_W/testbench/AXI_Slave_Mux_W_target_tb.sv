`timescale 1ns/1ps
`include "../AXI_Slave_Mux_W_original.sv"

module AXI_Slave_Mux_W_target_tb;
  localparam DATA_WIDTH = 32;
  localparam ADDR_WIDTH = 64;
  localparam ID_WIDTH   = 4;
  localparam USER_WIDTH = 4;

  logic ACLK, ARESETn;

  // Slave 0
  logic                  s0_AWVALID, s0_AWREADY;
  logic                  s0_WVALID,  s0_WREADY;
  logic [ID_WIDTH-1:0]   s0_BID;
  logic [1:0]            s0_BRESP;
  logic [USER_WIDTH-1:0] s0_BUSER;
  logic                  s0_BVALID,  s0_BREADY;

  // Slave 1
  logic                  s1_AWVALID, s1_AWREADY;
  logic                  s1_WVALID,  s1_WREADY;
  logic [ID_WIDTH-1:0]   s1_BID;
  logic [1:0]            s1_BRESP;
  logic [USER_WIDTH-1:0] s1_BUSER;
  logic                  s1_BVALID,  s1_BREADY;

  // Slave 2
  logic                  s2_AWVALID, s2_AWREADY;
  logic                  s2_WVALID,  s2_WREADY;
  logic [ID_WIDTH-1:0]   s2_BID;
  logic [1:0]            s2_BRESP;
  logic [USER_WIDTH-1:0] s2_BUSER;
  logic                  s2_BVALID,  s2_BREADY;

  // Slave 3
  logic                  s3_AWVALID, s3_AWREADY;
  logic                  s3_WVALID,  s3_WREADY;
  logic [ID_WIDTH-1:0]   s3_BID;
  logic [1:0]            s3_BRESP;
  logic [USER_WIDTH-1:0] s3_BUSER;
  logic                  s3_BVALID,  s3_BREADY;

  // Slave 4
  logic                  s4_AWVALID, s4_AWREADY;
  logic                  s4_WVALID,  s4_WREADY;
  logic [ID_WIDTH-1:0]   s4_BID;
  logic [1:0]            s4_BRESP;
  logic [USER_WIDTH-1:0] s4_BUSER;
  logic                  s4_BVALID,  s4_BREADY;

  // Slave 5
  logic                  s5_AWVALID, s5_AWREADY;
  logic                  s5_WVALID,  s5_WREADY;
  logic [ID_WIDTH-1:0]   s5_BID;
  logic [1:0]            s5_BRESP;
  logic [USER_WIDTH-1:0] s5_BUSER;
  logic                  s5_BVALID,  s5_BREADY;

  // Slave 6
  logic                  s6_AWVALID, s6_AWREADY;
  logic                  s6_WVALID,  s6_WREADY;
  logic [ID_WIDTH-1:0]   s6_BID;
  logic [1:0]            s6_BRESP;
  logic [USER_WIDTH-1:0] s6_BUSER;
  logic                  s6_BVALID,  s6_BREADY;

  // Slave 7
  logic                  s7_AWVALID, s7_AWREADY;
  logic                  s7_WVALID,  s7_WREADY;
  logic [ID_WIDTH-1:0]   s7_BID;
  logic [1:0]            s7_BRESP;
  logic [USER_WIDTH-1:0] s7_BUSER;
  logic                  s7_BVALID,  s7_BREADY;

  // Master common outputs
  logic                  m_AWREADY;
  logic                  m_WREADY;
  logic [ID_WIDTH-1:0]   m_BID;
  logic [1:0]            m_BRESP;
  logic [USER_WIDTH-1:0] m_BUSER;
  logic                  m_BVALID;

  // Slave common inputs
  logic [ADDR_WIDTH-1:0] s_AWADDR;
  logic                  s_AWVALID;
  logic                  s_WVALID;
  logic                  s_BREADY;

  AXI_Slave_Mux_W #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH)
  ) dut (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .s0_AWVALID(s0_AWVALID), .s0_AWREADY(s0_AWREADY),
    .s0_WVALID(s0_WVALID), .s0_WREADY(s0_WREADY),
    .s0_BID(s0_BID), .s0_BRESP(s0_BRESP), .s0_BUSER(s0_BUSER), .s0_BVALID(s0_BVALID), .s0_BREADY(s0_BREADY),
    .s1_AWVALID(s1_AWVALID), .s1_AWREADY(s1_AWREADY),
    .s1_WVALID(s1_WVALID), .s1_WREADY(s1_WREADY),
    .s1_BID(s1_BID), .s1_BRESP(s1_BRESP), .s1_BUSER(s1_BUSER), .s1_BVALID(s1_BVALID), .s1_BREADY(s1_BREADY),
    .s2_AWVALID(s2_AWVALID), .s2_AWREADY(s2_AWREADY),
    .s2_WVALID(s2_WVALID), .s2_WREADY(s2_WREADY),
    .s2_BID(s2_BID), .s2_BRESP(s2_BRESP), .s2_BUSER(s2_BUSER), .s2_BVALID(s2_BVALID), .s2_BREADY(s2_BREADY),
    .s3_AWVALID(s3_AWVALID), .s3_AWREADY(s3_AWREADY),
    .s3_WVALID(s3_WVALID), .s3_WREADY(s3_WREADY),
    .s3_BID(s3_BID), .s3_BRESP(s3_BRESP), .s3_BUSER(s3_BUSER), .s3_BVALID(s3_BVALID), .s3_BREADY(s3_BREADY),
    .s4_AWVALID(s4_AWVALID), .s4_AWREADY(s4_AWREADY),
    .s4_WVALID(s4_WVALID), .s4_WREADY(s4_WREADY),
    .s4_BID(s4_BID), .s4_BRESP(s4_BRESP), .s4_BUSER(s4_BUSER), .s4_BVALID(s4_BVALID), .s4_BREADY(s4_BREADY),
    .s5_AWVALID(s5_AWVALID), .s5_AWREADY(s5_AWREADY),
    .s5_WVALID(s5_WVALID), .s5_WREADY(s5_WREADY),
    .s5_BID(s5_BID), .s5_BRESP(s5_BRESP), .s5_BUSER(s5_BUSER), .s5_BVALID(s5_BVALID), .s5_BREADY(s5_BREADY),
    .s6_AWVALID(s6_AWVALID), .s6_AWREADY(s6_AWREADY),
    .s6_WVALID(s6_WVALID), .s6_WREADY(s6_WREADY),
    .s6_BID(s6_BID), .s6_BRESP(s6_BRESP), .s6_BUSER(s6_BUSER), .s6_BVALID(s6_BVALID), .s6_BREADY(s6_BREADY),
    .s7_AWVALID(s7_AWVALID), .s7_AWREADY(s7_AWREADY),
    .s7_WVALID(s7_WVALID), .s7_WREADY(s7_WREADY),
    .s7_BID(s7_BID), .s7_BRESP(s7_BRESP), .s7_BUSER(s7_BUSER), .s7_BVALID(s7_BVALID), .s7_BREADY(s7_BREADY),
    .m_AWREADY(m_AWREADY), .m_WREADY(m_WREADY),
    .m_BID(m_BID), .m_BRESP(m_BRESP), .m_BUSER(m_BUSER), .m_BVALID(m_BVALID),
    .s_AWADDR(s_AWADDR), .s_AWVALID(s_AWVALID), .s_WVALID(s_WVALID), .s_BREADY(s_BREADY)
  );

  always #5 ACLK = ~ACLK;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task check(input logic ok, input string msg);
    total_tests++;
    if (!ok) begin
      $display("FAIL: %s", msg);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    ACLK = 0; ARESETn = 0;
    s_AWADDR = '0; s_AWVALID = 0; s_WVALID = 0; s_BREADY = 0;

    // Init all slave inputs with distinct values
    s0_AWREADY = 1; s0_WREADY = 1; s0_BID = 4'h0; s0_BRESP = 2'b00; s0_BUSER = 4'h0; s0_BVALID = 0;
    s1_AWREADY = 0; s1_WREADY = 0; s1_BID = 4'h1; s1_BRESP = 2'b01; s1_BUSER = 4'h1; s1_BVALID = 0;
    s2_AWREADY = 1; s2_WREADY = 0; s2_BID = 4'h2; s2_BRESP = 2'b10; s2_BUSER = 4'h2; s2_BVALID = 0;
    s3_AWREADY = 0; s3_WREADY = 1; s3_BID = 4'h3; s3_BRESP = 2'b11; s3_BUSER = 4'h3; s3_BVALID = 0;
    s4_AWREADY = 1; s4_WREADY = 1; s4_BID = 4'h4; s4_BRESP = 2'b00; s4_BUSER = 4'h4; s4_BVALID = 1;
    s5_AWREADY = 1; s5_WREADY = 1; s5_BID = 4'h5; s5_BRESP = 2'b01; s5_BUSER = 4'h5; s5_BVALID = 1;
    s6_AWREADY = 0; s6_WREADY = 0; s6_BID = 4'h6; s6_BRESP = 2'b10; s6_BUSER = 4'h6; s6_BVALID = 0;
    s7_AWREADY = 0; s7_WREADY = 0; s7_BID = 4'h7; s7_BRESP = 2'b11; s7_BUSER = 4'h7; s7_BVALID = 0;

    // Release reset
    @(posedge ACLK); #1;
    ARESETn = 1;

    // === TARGET TEST: 3'b101 case => slave 5, specifically m_AWREADY = s5_AWREADY ===
    // Set address to slave 5 (top 3 bits = 101)
    s_AWADDR = 64'hA000_0000_0000_0000;
    s_AWVALID = 1;
    @(posedge ACLK); #1;
    s_AWVALID = 0;
    #1;

    // Test 1: m_AWREADY should be s5_AWREADY = 1
    check(m_AWREADY === 1'b1, "T1: slave 5 selected, m_AWREADY = s5_AWREADY = 1");

    // Test 2: m_WREADY should be s5_WREADY = 1
    check(m_WREADY === 1'b1, "T2: slave 5 selected, m_WREADY = s5_WREADY = 1");

    // Test 3: m_BID should be s5_BID = 5
    check(m_BID === 4'h5, "T3: slave 5 selected, m_BID = s5_BID = 5");

    // Test 4: m_BRESP should be s5_BRESP
    check(m_BRESP === 2'b01, "T4: slave 5 selected, m_BRESP = s5_BRESP = 01");

    // Test 5: m_BUSER should be s5_BUSER
    check(m_BUSER === 4'h5, "T5: slave 5 selected, m_BUSER = s5_BUSER = 5");

    // Test 6: m_BVALID should be s5_BVALID = 1
    check(m_BVALID === 1'b1, "T6: slave 5 selected, m_BVALID = s5_BVALID = 1");

    // Test 7: Toggle s5_AWREADY to 0
    s5_AWREADY = 0;
    #1;
    check(m_AWREADY === 1'b0, "T7: slave 5, s5_AWREADY=0 => m_AWREADY=0");

    // Test 8: Toggle s5_AWREADY back to 1
    s5_AWREADY = 1;
    #1;
    check(m_AWREADY === 1'b1, "T8: slave 5, s5_AWREADY=1 => m_AWREADY=1");

    // Test 9: Change s5_BID
    s5_BID = 4'hF;
    #1;
    check(m_BID === 4'hF, "T9: slave 5, s5_BID=F => m_BID=F");

    // Test 10: Change s5_BRESP
    s5_BRESP = 2'b11;
    #1;
    check(m_BRESP === 2'b11, "T10: slave 5, s5_BRESP=11 => m_BRESP=11");

    // Test 11: Check AWVALID routing to slave 5
    s_AWVALID = 1;
    #1;
    check(s5_AWVALID === 1'b1, "T11: slave 5, s5_AWVALID = s_AWVALID = 1");
    check(s0_AWVALID === 1'b0, "T12: slave 5, s0_AWVALID = 0");
    check(s4_AWVALID === 1'b0, "T13: slave 5, s4_AWVALID = 0");
    s_AWVALID = 0;

    // Test: Check BREADY routing to slave 5
    s_BREADY = 1;
    #1;
    check(s5_BREADY === 1'b1, "T14: slave 5, s5_BREADY = s_BREADY = 1");
    check(s0_BREADY === 1'b0, "T15: slave 5, s0_BREADY = 0");
    check(s4_BREADY === 1'b0, "T16: slave 5, s4_BREADY = 0");

    // Test: Check WVALID routing to slave 5
    s_WVALID = 1;
    #1;
    check(s5_WVALID === 1'b1, "T17: slave 5, s5_WVALID = s_WVALID = 1");
    check(s0_WVALID === 1'b0, "T18: slave 5, s0_WVALID = 0");

    // === Switch to slave 4 (top 3 = 100) to ensure s5 signals are no longer routed ===
    s_AWADDR = 64'h8000_0000_0000_0000;
    s_AWVALID = 1;
    @(posedge ACLK); #1;
    s_AWVALID = 0;
    #1;
    check(m_AWREADY === 1'b1, "T19: slave 4 selected, m_AWREADY = s4_AWREADY = 1");
    check(m_BID === 4'h4, "T20: slave 4 selected, m_BID = s4_BID = 4");

    // === Switch back to slave 5 ===
    s_AWADDR = 64'hA000_0000_0000_0000;
    s_AWVALID = 1;
    @(posedge ACLK); #1;
    s_AWVALID = 0;
    #1;
    check(m_AWREADY === 1'b1, "T21: back to slave 5, m_AWREADY = s5_AWREADY = 1");
    check(m_BID === 4'hF, "T22: back to slave 5, m_BID = s5_BID = F");

    // === Test slave 6 (top 3 = 110) ===
    s_AWADDR = 64'hC000_0000_0000_0000;
    s_AWVALID = 1;
    @(posedge ACLK); #1;
    s_AWVALID = 0;
    #1;
    check(m_AWREADY === 1'b0, "T23: slave 6 selected, m_AWREADY = s6_AWREADY = 0");
    check(m_BID === 4'h6, "T24: slave 6 selected, m_BID = s6_BID = 6");

    // === Test slave 0 (top 3 = 000) ===
    s_AWADDR = 64'h0000_0000_0000_1000;
    s_AWVALID = 1;
    @(posedge ACLK); #1;
    s_AWVALID = 0;
    #1;
    check(m_AWREADY === 1'b1, "T25: slave 0 selected, m_AWREADY = s0_AWREADY = 1");
    check(m_BID === 4'h0, "T26: slave 0 selected, m_BID = s0_BID = 0");

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] AXI_Slave_Mux_W all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] AXI_Slave_Mux_W FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
