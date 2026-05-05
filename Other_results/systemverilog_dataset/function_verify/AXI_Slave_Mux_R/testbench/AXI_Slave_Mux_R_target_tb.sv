`timescale 1ns/1ps
`include "../AXI_Slave_Mux_R_original.sv"

module AXI_Slave_Mux_R_target_tb;
  localparam DATA_WIDTH = 32;
  localparam ADDR_WIDTH = 64;
  localparam ID_WIDTH   = 4;
  localparam USER_WIDTH = 4;

  logic ACLK, ARESETn;

  // Slave 0-7
  logic                  s0_ARVALID, s0_ARREADY;
  logic [ID_WIDTH-1:0]   s0_RID;
  logic [DATA_WIDTH-1:0] s0_RDATA;
  logic [1:0]            s0_RRESP;
  logic                  s0_RLAST;
  logic [USER_WIDTH-1:0] s0_RUSER;
  logic                  s0_RVALID, s0_RREADY;

  logic                  s1_ARVALID, s1_ARREADY;
  logic [ID_WIDTH-1:0]   s1_RID;
  logic [DATA_WIDTH-1:0] s1_RDATA;
  logic [1:0]            s1_RRESP;
  logic                  s1_RLAST;
  logic [USER_WIDTH-1:0] s1_RUSER;
  logic                  s1_RVALID, s1_RREADY;

  logic                  s2_ARVALID, s2_ARREADY;
  logic [ID_WIDTH-1:0]   s2_RID;
  logic [DATA_WIDTH-1:0] s2_RDATA;
  logic [1:0]            s2_RRESP;
  logic                  s2_RLAST;
  logic [USER_WIDTH-1:0] s2_RUSER;
  logic                  s2_RVALID, s2_RREADY;

  logic                  s3_ARVALID, s3_ARREADY;
  logic [ID_WIDTH-1:0]   s3_RID;
  logic [DATA_WIDTH-1:0] s3_RDATA;
  logic [1:0]            s3_RRESP;
  logic                  s3_RLAST;
  logic [USER_WIDTH-1:0] s3_RUSER;
  logic                  s3_RVALID, s3_RREADY;

  logic                  s4_ARVALID, s4_ARREADY;
  logic [ID_WIDTH-1:0]   s4_RID;
  logic [DATA_WIDTH-1:0] s4_RDATA;
  logic [1:0]            s4_RRESP;
  logic                  s4_RLAST;
  logic [USER_WIDTH-1:0] s4_RUSER;
  logic                  s4_RVALID, s4_RREADY;

  logic                  s5_ARVALID, s5_ARREADY;
  logic [ID_WIDTH-1:0]   s5_RID;
  logic [DATA_WIDTH-1:0] s5_RDATA;
  logic [1:0]            s5_RRESP;
  logic                  s5_RLAST;
  logic [USER_WIDTH-1:0] s5_RUSER;
  logic                  s5_RVALID, s5_RREADY;

  logic                  s6_ARVALID, s6_ARREADY;
  logic [ID_WIDTH-1:0]   s6_RID;
  logic [DATA_WIDTH-1:0] s6_RDATA;
  logic [1:0]            s6_RRESP;
  logic                  s6_RLAST;
  logic [USER_WIDTH-1:0] s6_RUSER;
  logic                  s6_RVALID, s6_RREADY;

  logic                  s7_ARVALID, s7_ARREADY;
  logic [ID_WIDTH-1:0]   s7_RID;
  logic [DATA_WIDTH-1:0] s7_RDATA;
  logic [1:0]            s7_RRESP;
  logic                  s7_RLAST;
  logic [USER_WIDTH-1:0] s7_RUSER;
  logic                  s7_RVALID, s7_RREADY;

  // Master common outputs
  logic                  m_ARREADY;
  logic [ID_WIDTH-1:0]   m_RID;
  logic [DATA_WIDTH-1:0] m_RDATA;
  logic [1:0]            m_RRESP;
  logic                  m_RLAST;
  logic [USER_WIDTH-1:0] m_RUSER;
  logic                  m_RVALID;

  // Slave common inputs
  logic [ADDR_WIDTH-1:0] s_ARADDR;
  logic                  s_ARVALID;
  logic                  s_RREADY;

  AXI_Slave_Mux_R #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH)
  ) dut (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .s0_ARVALID(s0_ARVALID), .s0_ARREADY(s0_ARREADY),
    .s0_RID(s0_RID), .s0_RDATA(s0_RDATA), .s0_RRESP(s0_RRESP),
    .s0_RLAST(s0_RLAST), .s0_RUSER(s0_RUSER), .s0_RVALID(s0_RVALID), .s0_RREADY(s0_RREADY),
    .s1_ARVALID(s1_ARVALID), .s1_ARREADY(s1_ARREADY),
    .s1_RID(s1_RID), .s1_RDATA(s1_RDATA), .s1_RRESP(s1_RRESP),
    .s1_RLAST(s1_RLAST), .s1_RUSER(s1_RUSER), .s1_RVALID(s1_RVALID), .s1_RREADY(s1_RREADY),
    .s2_ARVALID(s2_ARVALID), .s2_ARREADY(s2_ARREADY),
    .s2_RID(s2_RID), .s2_RDATA(s2_RDATA), .s2_RRESP(s2_RRESP),
    .s2_RLAST(s2_RLAST), .s2_RUSER(s2_RUSER), .s2_RVALID(s2_RVALID), .s2_RREADY(s2_RREADY),
    .s3_ARVALID(s3_ARVALID), .s3_ARREADY(s3_ARREADY),
    .s3_RID(s3_RID), .s3_RDATA(s3_RDATA), .s3_RRESP(s3_RRESP),
    .s3_RLAST(s3_RLAST), .s3_RUSER(s3_RUSER), .s3_RVALID(s3_RVALID), .s3_RREADY(s3_RREADY),
    .s4_ARVALID(s4_ARVALID), .s4_ARREADY(s4_ARREADY),
    .s4_RID(s4_RID), .s4_RDATA(s4_RDATA), .s4_RRESP(s4_RRESP),
    .s4_RLAST(s4_RLAST), .s4_RUSER(s4_RUSER), .s4_RVALID(s4_RVALID), .s4_RREADY(s4_RREADY),
    .s5_ARVALID(s5_ARVALID), .s5_ARREADY(s5_ARREADY),
    .s5_RID(s5_RID), .s5_RDATA(s5_RDATA), .s5_RRESP(s5_RRESP),
    .s5_RLAST(s5_RLAST), .s5_RUSER(s5_RUSER), .s5_RVALID(s5_RVALID), .s5_RREADY(s5_RREADY),
    .s6_ARVALID(s6_ARVALID), .s6_ARREADY(s6_ARREADY),
    .s6_RID(s6_RID), .s6_RDATA(s6_RDATA), .s6_RRESP(s6_RRESP),
    .s6_RLAST(s6_RLAST), .s6_RUSER(s6_RUSER), .s6_RVALID(s6_RVALID), .s6_RREADY(s6_RREADY),
    .s7_ARVALID(s7_ARVALID), .s7_ARREADY(s7_ARREADY),
    .s7_RID(s7_RID), .s7_RDATA(s7_RDATA), .s7_RRESP(s7_RRESP),
    .s7_RLAST(s7_RLAST), .s7_RUSER(s7_RUSER), .s7_RVALID(s7_RVALID), .s7_RREADY(s7_RREADY),
    .m_ARREADY(m_ARREADY), .m_RID(m_RID), .m_RDATA(m_RDATA), .m_RRESP(m_RRESP),
    .m_RLAST(m_RLAST), .m_RUSER(m_RUSER), .m_RVALID(m_RVALID),
    .s_ARADDR(s_ARADDR), .s_ARVALID(s_ARVALID), .s_RREADY(s_RREADY)
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
    s_ARADDR = '0; s_ARVALID = 0; s_RREADY = 0;

    // Initialize all slave inputs with distinct non-zero values
    s0_ARREADY = 1; s0_RID = 4'h0; s0_RDATA = 32'h0000_0000; s0_RRESP = 2'b00;
    s0_RLAST = 0; s0_RUSER = 4'h0; s0_RVALID = 1;
    s1_ARREADY = 1; s1_RID = 4'h1; s1_RDATA = 32'h1111_1111; s1_RRESP = 2'b01;
    s1_RLAST = 1; s1_RUSER = 4'h1; s1_RVALID = 1;
    s2_ARREADY = 0; s2_RID = 4'h2; s2_RDATA = 32'h2222_2222; s2_RRESP = 2'b10;
    s2_RLAST = 0; s2_RUSER = 4'h2; s2_RVALID = 0;
    s3_ARREADY = 0; s3_RID = 4'h3; s3_RDATA = 32'h3333_3333; s3_RRESP = 2'b11;
    s3_RLAST = 1; s3_RUSER = 4'h3; s3_RVALID = 0;
    s4_ARREADY = 1; s4_RID = 4'h4; s4_RDATA = 32'h4444_4444; s4_RRESP = 2'b00;
    s4_RLAST = 0; s4_RUSER = 4'h4; s4_RVALID = 1;
    s5_ARREADY = 1; s5_RID = 4'h5; s5_RDATA = 32'h5555_5555; s5_RRESP = 2'b01;
    s5_RLAST = 1; s5_RUSER = 4'h5; s5_RVALID = 1;
    s6_ARREADY = 0; s6_RID = 4'h6; s6_RDATA = 32'h6666_6666; s6_RRESP = 2'b10;
    s6_RLAST = 0; s6_RUSER = 4'h6; s6_RVALID = 0;
    s7_ARREADY = 0; s7_RID = 4'h7; s7_RDATA = 32'h7777_7777; s7_RRESP = 2'b11;
    s7_RLAST = 1; s7_RUSER = 4'h7; s7_RVALID = 0;

    // Release reset
    @(posedge ACLK); #1;
    ARESETn = 1;

    // After reset, araddr = 0 => top 3 bits = 000 => slave 0 selected
    // The araddr register starts at 0 after reset

    // === TARGET TEST: default RREADY case (s0_RREADY, s1_RREADY = 0) ===
    // The araddr is 0 after reset, so top 3 bits = 000 => NOT the default case.
    // We need to get araddr into a state with top bits not matching 000..111.
    // Since araddr is 64 bits and top 3 bits are used, all 3-bit values are valid
    // (000 through 111). The default case can't actually be hit with valid 3-bit values.
    // However, we should test specific slave selections and ensure RREADY routing.

    // First, test slave 0 selection (araddr top 3 = 000, which is reset default)
    s_RREADY = 1;
    #1;
    check(s0_RREADY === 1'b1, "T1: slave 0 selected, s0_RREADY = s_RREADY = 1");
    check(s1_RREADY === 1'b0, "T2: slave 0 selected, s1_RREADY = 0");
    check(s2_RREADY === 1'b0, "T3: slave 0 selected, s2_RREADY = 0");
    check(s3_RREADY === 1'b0, "T4: slave 0 selected, s3_RREADY = 0");
    check(s4_RREADY === 1'b0, "T5: slave 0 selected, s4_RREADY = 0");
    check(s5_RREADY === 1'b0, "T6: slave 0 selected, s5_RREADY = 0");
    check(s6_RREADY === 1'b0, "T7: slave 0 selected, s6_RREADY = 0");
    check(s7_RREADY === 1'b0, "T8: slave 0 selected, s7_RREADY = 0");

    // Test with s_RREADY = 0
    s_RREADY = 0;
    #1;
    check(s0_RREADY === 1'b0, "T9: slave 0 selected, s_RREADY=0 => s0_RREADY=0");

    // Switch to slave 1 (top 3 bits = 001)
    s_ARADDR = 64'h2000_0000_0000_0000;
    s_ARVALID = 1;
    @(posedge ACLK); #1;
    s_ARVALID = 0;
    s_RREADY = 1;
    #1;
    check(s0_RREADY === 1'b0, "T10: slave 1 selected, s0_RREADY = 0");
    check(s1_RREADY === 1'b1, "T11: slave 1 selected, s1_RREADY = s_RREADY = 1");

    // Also check read data mux for slave 1
    check(m_RDATA === 32'h1111_1111, "T12: slave 1 selected, m_RDATA from s1");
    check(m_RID === 4'h1, "T13: slave 1 selected, m_RID from s1");

    // Switch to slave 5 (top 3 bits = 101)
    s_ARADDR = 64'hA000_0000_0000_0000;
    s_ARVALID = 1;
    @(posedge ACLK); #1;
    s_ARVALID = 0;
    s_RREADY = 1;
    #1;
    check(s0_RREADY === 1'b0, "T14: slave 5 selected, s0_RREADY = 0");
    check(s1_RREADY === 1'b0, "T15: slave 5 selected, s1_RREADY = 0");
    check(s5_RREADY === 1'b1, "T16: slave 5 selected, s5_RREADY = s_RREADY = 1");
    check(m_RDATA === 32'h5555_5555, "T17: slave 5 selected, m_RDATA from s5");

    // Switch to slave 7 (top 3 bits = 111)
    s_ARADDR = 64'hE000_0000_0000_0000;
    s_ARVALID = 1;
    @(posedge ACLK); #1;
    s_ARVALID = 0;
    s_RREADY = 1;
    #1;
    check(s0_RREADY === 1'b0, "T18: slave 7 selected, s0_RREADY = 0");
    check(s1_RREADY === 1'b0, "T19: slave 7 selected, s1_RREADY = 0");
    check(s7_RREADY === 1'b1, "T20: slave 7 selected, s7_RREADY = s_RREADY = 1");
    check(m_RDATA === 32'h7777_7777, "T21: slave 7 selected, m_RDATA from s7");

    // Switch back to slave 0 and test toggling
    s_ARADDR = 64'h0000_0000_0000_0000;
    s_ARVALID = 1;
    @(posedge ACLK); #1;
    s_ARVALID = 0;
    s_RREADY = 1;
    #1;
    check(s0_RREADY === 1'b1, "T22: back to slave 0, s0_RREADY = 1");
    check(s1_RREADY === 1'b0, "T23: back to slave 0, s1_RREADY = 0");

    s_RREADY = 0;
    #1;
    check(s0_RREADY === 1'b0, "T24: slave 0, s_RREADY=0 => s0_RREADY=0");

    // Test ARVALID routing for slave 0
    s_ARVALID = 1;
    #1;
    check(s0_ARVALID === 1'b1, "T25: slave 0, s0_ARVALID = s_ARVALID = 1");
    check(s1_ARVALID === 1'b0, "T26: slave 0, s1_ARVALID = 0");

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] AXI_Slave_Mux_R all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] AXI_Slave_Mux_R FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
