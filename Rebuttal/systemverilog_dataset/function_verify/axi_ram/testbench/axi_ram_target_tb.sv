`timescale 1ns/1ps
`include "../axi_ram_original.v"

// TARGET: line 239 in axi_ram.v - WRITE_STATE_RESP:
//   s_axi_bvalid_next = 1'b1;
// This is the bvalid assertion in the WRITE_STATE_RESP state when
// s_axi_bready || !s_axi_bvalid. Without it, bvalid never gets set
// when the write response is deferred.

module axi_ram_target_tb;
  logic clk, rst;
  logic [0:0] s_axi_awid;
  logic [3:0] s_axi_awaddr;
  logic [7:0] s_axi_awlen;
  logic [2:0] s_axi_awsize;
  logic [1:0] s_axi_awburst;
  logic       s_axi_awlock;
  logic [3:0] s_axi_awcache;
  logic [2:0] s_axi_awprot;
  logic       s_axi_awvalid;
  wire        s_axi_awready;
  logic [7:0] s_axi_wdata;
  logic [0:0] s_axi_wstrb;
  logic       s_axi_wlast;
  logic       s_axi_wvalid;
  wire        s_axi_wready;
  wire  [0:0] s_axi_bid;
  wire  [1:0] s_axi_bresp;
  wire        s_axi_bvalid;
  logic       s_axi_bready;
  logic [0:0] s_axi_arid;
  logic [3:0] s_axi_araddr;
  logic [7:0] s_axi_arlen;
  logic [2:0] s_axi_arsize;
  logic [1:0] s_axi_arburst;
  logic       s_axi_arlock;
  logic [3:0] s_axi_arcache;
  logic [2:0] s_axi_arprot;
  logic       s_axi_arvalid;
  wire        s_axi_arready;
  wire  [0:0] s_axi_rid;
  wire  [7:0] s_axi_rdata;
  wire  [1:0] s_axi_rresp;
  wire        s_axi_rlast;
  wire        s_axi_rvalid;
  logic       s_axi_rready;

  axi_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(4), .STRB_WIDTH(1), .ID_WIDTH(1)) dut (
    .clk(clk), .rst(rst),
    .s_axi_awid(s_axi_awid), .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst), .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache), .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid), .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid), .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst), .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache), .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid), .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
  );

  always #5 clk = ~clk;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  task automatic check_val(string name, logic cond);
    total_tests++;
    if (!cond) begin
      $display("FAIL: %s", name);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  // Task: perform AW handshake only
  task automatic do_aw(input logic [3:0] addr, input logic [0:0] id, input logic [7:0] len);
    s_axi_awaddr  = addr;
    s_axi_awid    = id;
    s_axi_awlen   = len;
    s_axi_awsize  = 0;
    s_axi_awburst = 2'b01;
    s_axi_awvalid = 1;
    @(posedge clk);
    while (!s_axi_awready) @(posedge clk);
    s_axi_awvalid = 0;
  endtask

  // Task: perform a single W beat
  task automatic do_w_beat(input logic [7:0] data, input logic last);
    s_axi_wdata  = data;
    s_axi_wstrb  = 1'b1;
    s_axi_wlast  = last;
    s_axi_wvalid = 1;
    @(posedge clk);
    while (!s_axi_wready) @(posedge clk);
    s_axi_wvalid = 0;
    s_axi_wlast  = 0;
  endtask

  // Task: full single-beat write, control bready
  task automatic do_write_simple(input logic [3:0] addr, input logic [7:0] data, input logic [0:0] id);
    do_aw(addr, id, 8'd0);
    s_axi_bready = 1;
    do_w_beat(data, 1'b1);
    // Wait for bvalid and acknowledge
    while (!s_axi_bvalid) @(posedge clk);
    @(posedge clk);
    s_axi_bready = 0;
  endtask

  // Task: perform single-beat read
  task automatic do_read(input logic [3:0] addr, output logic [7:0] rdata_out);
    s_axi_araddr  = addr;
    s_axi_arid    = 0;
    s_axi_arlen   = 0;
    s_axi_arsize  = 0;
    s_axi_arburst = 2'b01;
    s_axi_arvalid = 1;
    s_axi_rready  = 1;
    @(posedge clk);
    while (!s_axi_arready) @(posedge clk);
    s_axi_arvalid = 0;
    while (!s_axi_rvalid) @(posedge clk);
    rdata_out = s_axi_rdata;
    @(posedge clk);
    s_axi_rready = 0;
  endtask

  logic [7:0] rd_data;

  initial begin
    clk = 0; rst = 1;
    s_axi_awid = 0; s_axi_awaddr = 0; s_axi_awlen = 0; s_axi_awsize = 0;
    s_axi_awburst = 0; s_axi_awlock = 0; s_axi_awcache = 0; s_axi_awprot = 0;
    s_axi_awvalid = 0;
    s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wlast = 0; s_axi_wvalid = 0;
    s_axi_bready = 0;
    s_axi_arid = 0; s_axi_araddr = 0; s_axi_arlen = 0; s_axi_arsize = 0;
    s_axi_arburst = 0; s_axi_arlock = 0; s_axi_arcache = 0; s_axi_arprot = 0;
    s_axi_arvalid = 0; s_axi_rready = 0;

    repeat(2) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // ========= Test 1: Normal write with bready=1 (fast path) =========
    // After reset, bvalid=0. With bready=1, the fast path in WRITE_STATE_BURST
    // is taken since (bready || !bvalid) = (1 || 1) = 1.
    do_write_simple(4'h3, 8'hA5, 1'b0);
    check_val("T1: fast path write completes", 1'b1);
    @(posedge clk);

    // ========= Test 2: Read back fast path write =========
    do_read(4'h3, rd_data);
    check_val("T2: read back fast write data=A5", rd_data === 8'hA5);

    // ========= Test 3: Write with bready=0 but bvalid=0 (still fast path) =========
    // bvalid=0 after acknowledged response. (!bvalid)=1, so fast path taken.
    // bready=0 means bvalid won't clear on its own.
    s_axi_bready = 0;
    do_aw(4'h5, 1'b0, 8'd0);
    do_w_beat(8'hBB, 1'b1);
    // Fast path: bvalid_next=1, state goes to IDLE
    // Wait a cycle for bvalid to register
    @(posedge clk); #1;
    check_val("T3: bvalid=1 fast path even with bready=0", s_axi_bvalid === 1'b1);
    check_val("T4: bresp=OKAY", s_axi_bresp === 2'b00);

    // Don't acknowledge yet - bvalid stays high
    @(posedge clk); #1;
    check_val("T5: bvalid stays 1 without bready", s_axi_bvalid === 1'b1);

    // Now acknowledge
    s_axi_bready = 1;
    @(posedge clk); #1;
    // bvalid_next = bvalid_reg && !bready = 1 && 0 = 0 (cleared by default logic)
    // But IDLE state doesn't override bvalid, so it stays at default
    check_val("T6: bvalid cleared after bready", s_axi_bvalid === 1'b0);
    s_axi_bready = 0;
    @(posedge clk);

    // ========= Test 4: Read back write from Test 3 =========
    do_read(4'h5, rd_data);
    check_val("T7: read back addr 5 = BB", rd_data === 8'hBB);

    // ========= Test 5: Force WRITE_STATE_RESP =========
    // To enter WRITE_STATE_RESP, we need bvalid=1 AND bready=0 when last
    // write beat completes. Strategy: do a write with bready=0 (fast path
    // since bvalid=0), DON'T acknowledge, then do another write with bready=0.
    // Now bvalid=1 from first write, so second write will enter WRITE_STATE_RESP.

    // First write: fast path, bready=0, don't acknowledge response
    s_axi_bready = 0;
    do_aw(4'h6, 1'b0, 8'd0);
    do_w_beat(8'hCC, 1'b1);
    // bvalid=1 from fast path, leave it unacknowledged
    @(posedge clk); #1;
    check_val("T8: first write bvalid=1", s_axi_bvalid === 1'b1);

    // Second write: now bvalid=1 and bready=0, so this will enter WRITE_STATE_RESP
    // But first we need awready to be 1 -- it should be since first write went to IDLE
    do_aw(4'h7, 1'b1, 8'd0);
    do_w_beat(8'hDD, 1'b1);
    // Now in WRITE_STATE_BURST, last beat, write_count==0:
    // bready=0, bvalid=1 -> !(bready || !bvalid) = !(0||0) = 1 -> WRITE_STATE_RESP
    // But wait: the default bvalid_next = bvalid_reg && !bready = 1 && 1 = 1
    // WRITE_STATE_RESP doesn't fire immediately because we need to see it
    repeat(2) @(posedge clk); #1;
    // In WRITE_STATE_RESP with bready=0 and bvalid=1:
    // Condition: bready || !bvalid = 0 || 0 = 0 -> stays in WRITE_STATE_RESP
    // bvalid_next = bvalid_reg && !bready = 1 && 1 = 1 (stays 1 from first write)
    // The first write's bvalid is still there
    check_val("T9: in RESP state, bvalid=1 from first write", s_axi_bvalid === 1'b1);

    // Assert bready to trigger the WRITE_STATE_RESP exit path
    // This is the TARGET code: sets bvalid_next=1
    s_axi_bready = 1;
    // On this cycle: bready=1, so bvalid_next default = bvalid_reg && !bready = 1 && 0 = 0
    // But WRITE_STATE_RESP overrides: bready || !bvalid = 1 || 0 = 1
    // So bvalid_next = 1 (from WRITE_STATE_RESP case), bid_next = write_id_reg
    @(posedge clk); #1;
    // Now bvalid_reg = 1 (the override), bid should be from second write (id=1)
    check_val("T10: bvalid=1 after RESP exit", s_axi_bvalid === 1'b1);
    check_val("T11: bid=1 from second write", s_axi_bid === 1'b1);
    check_val("T12: bresp=OKAY", s_axi_bresp === 2'b00);

    // Acknowledge it
    @(posedge clk); #1;
    // bvalid_next = bvalid_reg && !bready = 1 && 0 = 0
    check_val("T13: bvalid cleared", s_axi_bvalid === 1'b0);
    s_axi_bready = 0;
    @(posedge clk);

    // ========= Test 6: Verify both writes stored correctly =========
    do_read(4'h6, rd_data);
    check_val("T14: read back addr 6 = CC", rd_data === 8'hCC);
    do_read(4'h7, rd_data);
    check_val("T15: read back addr 7 = DD", rd_data === 8'hDD);

    // ========= Test 7: Burst write with deferred response =========
    // First do a write without acknowledging to get bvalid=1
    s_axi_bready = 0;
    do_aw(4'hA, 1'b0, 8'd0);
    do_w_beat(8'hEE, 1'b1);
    @(posedge clk); #1;
    check_val("T16: setup bvalid=1 for burst test", s_axi_bvalid === 1'b1);

    // Now burst write - should enter WRITE_STATE_RESP
    do_aw(4'h8, 1'b0, 8'd1); // awlen=1 -> 2 beats
    // Beat 1
    s_axi_wdata = 8'hAA; s_axi_wstrb = 1; s_axi_wlast = 0; s_axi_wvalid = 1;
    @(posedge clk);
    while (!s_axi_wready) @(posedge clk);
    // Beat 2
    s_axi_wdata = 8'hBB; s_axi_wlast = 1;
    @(posedge clk);
    while (!s_axi_wready) @(posedge clk);
    s_axi_wvalid = 0; s_axi_wlast = 0;

    // In WRITE_STATE_RESP now, bready=0
    repeat(2) @(posedge clk);
    s_axi_bready = 1;
    @(posedge clk); #1;
    check_val("T17: burst deferred bvalid=1", s_axi_bvalid === 1'b1);
    @(posedge clk); #1;
    check_val("T18: burst bvalid cleared", s_axi_bvalid === 1'b0);
    s_axi_bready = 0;
    @(posedge clk);

    // ========= Test 8: Reset behavior =========
    rst = 1;
    repeat(2) @(posedge clk);
    rst = 0;
    @(posedge clk); #1;
    check_val("T19: bvalid=0 after reset", s_axi_bvalid === 1'b0);

    // Write after reset should work normally
    do_write_simple(4'h2, 8'hCC, 1'b0);
    do_read(4'h2, rd_data);
    check_val("T20: readback post-reset write", rd_data === 8'hCC);

    repeat(3) @(posedge clk);

    if (fail_count == 0)
      $display("[TB_REAL] axi_ram WRITE_STATE_RESP bvalid tests PASSED");
    else
      $display("[TB_REAL] axi_ram FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #50000;
    $display("[TB_REAL] axi_ram FAILED - TIMEOUT");
    $finish;
  end
endmodule
