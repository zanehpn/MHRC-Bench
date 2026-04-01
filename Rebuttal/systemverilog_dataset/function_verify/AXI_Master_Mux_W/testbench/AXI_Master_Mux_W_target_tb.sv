`timescale 1ns/1ps
`include "../AXI_Master_Mux_W_original.sv"

module AXI_Master_Mux_W_target_tb;
  localparam DATA_WIDTH = 32;
  localparam ADDR_WIDTH = 32;
  localparam ID_WIDTH   = 4;
  localparam USER_WIDTH = 4;
  localparam STRB_WIDTH = DATA_WIDTH/8;

  logic ACLK, ARESETn;

  // Master 0
  logic [ID_WIDTH-1:0]   m0_AWID;
  logic [ADDR_WIDTH-1:0] m0_AWADDR;
  logic [7:0]            m0_AWLEN;
  logic [2:0]            m0_AWSIZE;
  logic [1:0]            m0_AWBURST;
  logic                  m0_AWLOCK;
  logic [3:0]            m0_AWCACHE;
  logic [2:0]            m0_AWPROT;
  logic [3:0]            m0_AWQOS;
  logic [3:0]            m0_AWREGION;
  logic [USER_WIDTH-1:0] m0_AWUSER;
  logic                  m0_AWVALID;
  logic                  m0_AWREADY;
  logic [ID_WIDTH-1:0]   m0_WID;
  logic [DATA_WIDTH-1:0] m0_WDATA;
  logic [STRB_WIDTH-1:0] m0_WSTRB;
  logic                  m0_WLAST;
  logic [USER_WIDTH-1:0] m0_WUSER;
  logic                  m0_WVALID;
  logic                  m0_WREADY;
  logic                  m0_BVALID;
  logic                  m0_BREADY;

  // Master 1
  logic [ID_WIDTH-1:0]   m1_AWID;
  logic [ADDR_WIDTH-1:0] m1_AWADDR;
  logic [7:0]            m1_AWLEN;
  logic [2:0]            m1_AWSIZE;
  logic [1:0]            m1_AWBURST;
  logic                  m1_AWLOCK;
  logic [3:0]            m1_AWCACHE;
  logic [2:0]            m1_AWPROT;
  logic [3:0]            m1_AWQOS;
  logic [3:0]            m1_AWREGION;
  logic [USER_WIDTH-1:0] m1_AWUSER;
  logic                  m1_AWVALID;
  logic                  m1_AWREADY;
  logic [ID_WIDTH-1:0]   m1_WID;
  logic [DATA_WIDTH-1:0] m1_WDATA;
  logic [STRB_WIDTH-1:0] m1_WSTRB;
  logic                  m1_WLAST;
  logic [USER_WIDTH-1:0] m1_WUSER;
  logic                  m1_WVALID;
  logic                  m1_WREADY;
  logic                  m1_BVALID;
  logic                  m1_BREADY;

  // Master 2
  logic [ID_WIDTH-1:0]   m2_AWID;
  logic [ADDR_WIDTH-1:0] m2_AWADDR;
  logic [7:0]            m2_AWLEN;
  logic [2:0]            m2_AWSIZE;
  logic [1:0]            m2_AWBURST;
  logic                  m2_AWLOCK;
  logic [3:0]            m2_AWCACHE;
  logic [2:0]            m2_AWPROT;
  logic [3:0]            m2_AWQOS;
  logic [3:0]            m2_AWREGION;
  logic [USER_WIDTH-1:0] m2_AWUSER;
  logic                  m2_AWVALID;
  logic                  m2_AWREADY;
  logic [ID_WIDTH-1:0]   m2_WID;
  logic [DATA_WIDTH-1:0] m2_WDATA;
  logic [STRB_WIDTH-1:0] m2_WSTRB;
  logic                  m2_WLAST;
  logic [USER_WIDTH-1:0] m2_WUSER;
  logic                  m2_WVALID;
  logic                  m2_WREADY;
  logic                  m2_BVALID;
  logic                  m2_BREADY;

  // Master 3
  logic [ID_WIDTH-1:0]   m3_AWID;
  logic [ADDR_WIDTH-1:0] m3_AWADDR;
  logic [7:0]            m3_AWLEN;
  logic [2:0]            m3_AWSIZE;
  logic [1:0]            m3_AWBURST;
  logic                  m3_AWLOCK;
  logic [3:0]            m3_AWCACHE;
  logic [2:0]            m3_AWPROT;
  logic [3:0]            m3_AWQOS;
  logic [3:0]            m3_AWREGION;
  logic [USER_WIDTH-1:0] m3_AWUSER;
  logic                  m3_AWVALID;
  logic                  m3_AWREADY;
  logic [ID_WIDTH-1:0]   m3_WID;
  logic [DATA_WIDTH-1:0] m3_WDATA;
  logic [STRB_WIDTH-1:0] m3_WSTRB;
  logic                  m3_WLAST;
  logic [USER_WIDTH-1:0] m3_WUSER;
  logic                  m3_WVALID;
  logic                  m3_WREADY;
  logic                  m3_BVALID;
  logic                  m3_BREADY;

  // Slave common outputs
  logic [ID_WIDTH-1:0]   s_AWID;
  logic [ADDR_WIDTH-1:0] s_AWADDR;
  logic [7:0]            s_AWLEN;
  logic [2:0]            s_AWSIZE;
  logic [1:0]            s_AWBURST;
  logic                  s_AWLOCK;
  logic [3:0]            s_AWCACHE;
  logic [2:0]            s_AWPROT;
  logic [3:0]            s_AWQOS;
  logic [3:0]            s_AWREGION;
  logic [USER_WIDTH-1:0] s_AWUSER;
  logic                  s_AWVALID;
  logic [ID_WIDTH-1:0]   s_WID;
  logic [DATA_WIDTH-1:0] s_WDATA;
  logic [STRB_WIDTH-1:0] s_WSTRB;
  logic                  s_WLAST;
  logic [USER_WIDTH-1:0] s_WUSER;
  logic                  s_WVALID;
  logic                  s_BREADY;

  // Master common inputs
  logic                  m_AWREADY;
  logic                  m_WREADY;
  logic                  m_BVALID;

  // Grant signals
  logic m0_wgrnt, m1_wgrnt, m2_wgrnt, m3_wgrnt;

  AXI_Master_Mux_W #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .ID_WIDTH   (ID_WIDTH),
    .USER_WIDTH (USER_WIDTH)
  ) dut (
    .ACLK(ACLK), .ARESETn(ARESETn),
    .m0_AWID(m0_AWID), .m0_AWADDR(m0_AWADDR), .m0_AWLEN(m0_AWLEN), .m0_AWSIZE(m0_AWSIZE),
    .m0_AWBURST(m0_AWBURST), .m0_AWLOCK(m0_AWLOCK), .m0_AWCACHE(m0_AWCACHE), .m0_AWPROT(m0_AWPROT),
    .m0_AWQOS(m0_AWQOS), .m0_AWREGION(m0_AWREGION), .m0_AWUSER(m0_AWUSER), .m0_AWVALID(m0_AWVALID),
    .m0_AWREADY(m0_AWREADY),
    .m0_WID(m0_WID), .m0_WDATA(m0_WDATA), .m0_WSTRB(m0_WSTRB), .m0_WLAST(m0_WLAST),
    .m0_WUSER(m0_WUSER), .m0_WVALID(m0_WVALID), .m0_WREADY(m0_WREADY),
    .m0_BVALID(m0_BVALID), .m0_BREADY(m0_BREADY),
    .m1_AWID(m1_AWID), .m1_AWADDR(m1_AWADDR), .m1_AWLEN(m1_AWLEN), .m1_AWSIZE(m1_AWSIZE),
    .m1_AWBURST(m1_AWBURST), .m1_AWLOCK(m1_AWLOCK), .m1_AWCACHE(m1_AWCACHE), .m1_AWPROT(m1_AWPROT),
    .m1_AWQOS(m1_AWQOS), .m1_AWREGION(m1_AWREGION), .m1_AWUSER(m1_AWUSER), .m1_AWVALID(m1_AWVALID),
    .m1_AWREADY(m1_AWREADY),
    .m1_WID(m1_WID), .m1_WDATA(m1_WDATA), .m1_WSTRB(m1_WSTRB), .m1_WLAST(m1_WLAST),
    .m1_WUSER(m1_WUSER), .m1_WVALID(m1_WVALID), .m1_WREADY(m1_WREADY),
    .m1_BVALID(m1_BVALID), .m1_BREADY(m1_BREADY),
    .m2_AWID(m2_AWID), .m2_AWADDR(m2_AWADDR), .m2_AWLEN(m2_AWLEN), .m2_AWSIZE(m2_AWSIZE),
    .m2_AWBURST(m2_AWBURST), .m2_AWLOCK(m2_AWLOCK), .m2_AWCACHE(m2_AWCACHE), .m2_AWPROT(m2_AWPROT),
    .m2_AWQOS(m2_AWQOS), .m2_AWREGION(m2_AWREGION), .m2_AWUSER(m2_AWUSER), .m2_AWVALID(m2_AWVALID),
    .m2_AWREADY(m2_AWREADY),
    .m2_WID(m2_WID), .m2_WDATA(m2_WDATA), .m2_WSTRB(m2_WSTRB), .m2_WLAST(m2_WLAST),
    .m2_WUSER(m2_WUSER), .m2_WVALID(m2_WVALID), .m2_WREADY(m2_WREADY),
    .m2_BVALID(m2_BVALID), .m2_BREADY(m2_BREADY),
    .m3_AWID(m3_AWID), .m3_AWADDR(m3_AWADDR), .m3_AWLEN(m3_AWLEN), .m3_AWSIZE(m3_AWSIZE),
    .m3_AWBURST(m3_AWBURST), .m3_AWLOCK(m3_AWLOCK), .m3_AWCACHE(m3_AWCACHE), .m3_AWPROT(m3_AWPROT),
    .m3_AWQOS(m3_AWQOS), .m3_AWREGION(m3_AWREGION), .m3_AWUSER(m3_AWUSER), .m3_AWVALID(m3_AWVALID),
    .m3_AWREADY(m3_AWREADY),
    .m3_WID(m3_WID), .m3_WDATA(m3_WDATA), .m3_WSTRB(m3_WSTRB), .m3_WLAST(m3_WLAST),
    .m3_WUSER(m3_WUSER), .m3_WVALID(m3_WVALID), .m3_WREADY(m3_WREADY),
    .m3_BVALID(m3_BVALID), .m3_BREADY(m3_BREADY),
    .s_AWID(s_AWID), .s_AWADDR(s_AWADDR), .s_AWLEN(s_AWLEN), .s_AWSIZE(s_AWSIZE),
    .s_AWBURST(s_AWBURST), .s_AWLOCK(s_AWLOCK), .s_AWCACHE(s_AWCACHE), .s_AWPROT(s_AWPROT),
    .s_AWQOS(s_AWQOS), .s_AWREGION(s_AWREGION), .s_AWUSER(s_AWUSER), .s_AWVALID(s_AWVALID),
    .s_WID(s_WID), .s_WDATA(s_WDATA), .s_WSTRB(s_WSTRB), .s_WLAST(s_WLAST),
    .s_WUSER(s_WUSER), .s_WVALID(s_WVALID),
    .s_BREADY(s_BREADY),
    .m_AWREADY(m_AWREADY), .m_WREADY(m_WREADY), .m_BVALID(m_BVALID),
    .m0_wgrnt(m0_wgrnt), .m1_wgrnt(m1_wgrnt), .m2_wgrnt(m2_wgrnt), .m3_wgrnt(m3_wgrnt)
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
    // Initialize all master inputs to distinct values
    m0_AWID = 4'hA; m0_AWADDR = 32'hAAAA_AAAA; m0_AWLEN = 8'h0A; m0_AWSIZE = 3'b010;
    m0_AWBURST = 2'b01; m0_AWLOCK = 1'b0; m0_AWCACHE = 4'h2; m0_AWPROT = 3'b001;
    m0_AWQOS = 4'h3; m0_AWREGION = 4'hF; m0_AWUSER = 4'hC; m0_AWVALID = 1;
    m0_WID = 4'hA; m0_WDATA = 32'h1111_1111; m0_WSTRB = 4'hF; m0_WLAST = 1;
    m0_WUSER = 4'hD; m0_WVALID = 1; m0_BREADY = 1;

    m1_AWID = 4'hB; m1_AWADDR = 32'hBBBB_BBBB; m1_AWLEN = 8'h0B; m1_AWSIZE = 3'b011;
    m1_AWBURST = 2'b10; m1_AWLOCK = 1'b1; m1_AWCACHE = 4'h3; m1_AWPROT = 3'b010;
    m1_AWQOS = 4'h4; m1_AWREGION = 4'hE; m1_AWUSER = 4'hB; m1_AWVALID = 0;
    m1_WID = 4'hB; m1_WDATA = 32'h2222_2222; m1_WSTRB = 4'hA; m1_WLAST = 0;
    m1_WUSER = 4'hE; m1_WVALID = 0; m1_BREADY = 0;

    m2_AWID = '0; m2_AWADDR = '0; m2_AWLEN = '0; m2_AWSIZE = '0;
    m2_AWBURST = '0; m2_AWLOCK = 0; m2_AWCACHE = '0; m2_AWPROT = '0;
    m2_AWQOS = '0; m2_AWREGION = '0; m2_AWUSER = '0; m2_AWVALID = 0;
    m2_WID = '0; m2_WDATA = '0; m2_WSTRB = '0; m2_WLAST = 0;
    m2_WUSER = '0; m2_WVALID = 0; m2_BREADY = 0;

    m3_AWID = '0; m3_AWADDR = '0; m3_AWLEN = '0; m3_AWSIZE = '0;
    m3_AWBURST = '0; m3_AWLOCK = 0; m3_AWCACHE = '0; m3_AWPROT = '0;
    m3_AWQOS = '0; m3_AWREGION = '0; m3_AWUSER = '0; m3_AWVALID = 0;
    m3_WID = '0; m3_WDATA = '0; m3_WSTRB = '0; m3_WLAST = 0;
    m3_WUSER = '0; m3_WVALID = 0; m3_BREADY = 0;

    m_AWREADY = 1; m_WREADY = 1; m_BVALID = 0;
    m0_wgrnt = 0; m1_wgrnt = 0; m2_wgrnt = 0; m3_wgrnt = 0;

    @(posedge ACLK); #1;
    ARESETn = 1;

    // === Test master 0 grant: TARGET signals (s_AWREGION, s_AWUSER, s_AWVALID, s_WID) ===
    m0_wgrnt = 1; m1_wgrnt = 0; m2_wgrnt = 0; m3_wgrnt = 0;
    #1;

    // Test 1: s_AWREGION should be m0_AWREGION
    check(s_AWREGION === 4'hF, "T1: s_AWREGION === m0_AWREGION (4'hF)");

    // Test 2: s_AWUSER should be m0_AWUSER
    check(s_AWUSER === 4'hC, "T2: s_AWUSER === m0_AWUSER (4'hC)");

    // Test 3: s_AWVALID should be m0_AWVALID
    check(s_AWVALID === 1'b1, "T3: s_AWVALID === m0_AWVALID (1)");

    // Test 4: s_WID should be m0_WID
    check(s_WID === 4'hA, "T4: s_WID === m0_WID (4'hA)");

    // Test 5: Also verify other signals in m0 case pass through
    check(s_AWID === 4'hA, "T5: s_AWID === m0_AWID");
    check(s_AWADDR === 32'hAAAA_AAAA, "T6: s_AWADDR === m0_AWADDR");
    check(s_AWQOS === 4'h3, "T7: s_AWQOS === m0_AWQOS");
    check(s_WDATA === 32'h1111_1111, "T8: s_WDATA === m0_WDATA");
    check(s_WSTRB === 4'hF, "T9: s_WSTRB === m0_WSTRB");
    check(s_WLAST === 1'b1, "T10: s_WLAST === m0_WLAST");
    check(s_WUSER === 4'hD, "T11: s_WUSER === m0_WUSER");
    check(s_WVALID === 1'b1, "T12: s_WVALID === m0_WVALID");
    check(s_BREADY === 1'b1, "T13: s_BREADY === m0_BREADY");

    // Test: change m0_AWREGION and verify it propagates
    m0_AWREGION = 4'h7;
    #1;
    check(s_AWREGION === 4'h7, "T14: s_AWREGION updated to 4'h7");

    // Test: change m0_AWUSER and verify
    m0_AWUSER = 4'h5;
    #1;
    check(s_AWUSER === 4'h5, "T15: s_AWUSER updated to 4'h5");

    // Test: change m0_AWVALID to 0
    m0_AWVALID = 0;
    #1;
    check(s_AWVALID === 1'b0, "T16: s_AWVALID follows m0_AWVALID=0");

    // Test: change m0_WID
    m0_WID = 4'h3;
    #1;
    check(s_WID === 4'h3, "T17: s_WID updated to m0_WID=3");

    // === Switch to master 1 and verify m0 signals are NOT on output ===
    m0_wgrnt = 0; m1_wgrnt = 1;
    #1;
    check(s_AWREGION === 4'hE, "T18: s_AWREGION === m1_AWREGION when m1 granted");
    check(s_AWUSER === 4'hB, "T19: s_AWUSER === m1_AWUSER when m1 granted");
    check(s_AWVALID === 1'b0, "T20: s_AWVALID === m1_AWVALID(0) when m1 granted");
    check(s_WID === 4'hB, "T21: s_WID === m1_WID when m1 granted");

    // === Switch back to master 0 ===
    m0_wgrnt = 1; m1_wgrnt = 0;
    m0_AWVALID = 1;
    m0_AWREGION = 4'hD;
    m0_AWUSER = 4'h9;
    m0_WID = 4'h6;
    #1;
    check(s_AWREGION === 4'hD, "T22: s_AWREGION back to m0 (4'hD)");
    check(s_AWUSER === 4'h9, "T23: s_AWUSER back to m0 (4'h9)");
    check(s_AWVALID === 1'b1, "T24: s_AWVALID back to m0 (1)");
    check(s_WID === 4'h6, "T25: s_WID back to m0 (4'h6)");

    // === Test default case (no grant) ===
    m0_wgrnt = 0; m1_wgrnt = 0; m2_wgrnt = 0; m3_wgrnt = 0;
    #1;
    check(s_AWREGION === 4'h0, "T26: default case s_AWREGION=0");
    check(s_AWUSER === 4'h0, "T27: default case s_AWUSER=0");
    check(s_AWVALID === 1'b0, "T28: default case s_AWVALID=0");
    check(s_WID === 4'h0, "T29: default case s_WID=0");

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] AXI_Master_Mux_W all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] AXI_Master_Mux_W FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
