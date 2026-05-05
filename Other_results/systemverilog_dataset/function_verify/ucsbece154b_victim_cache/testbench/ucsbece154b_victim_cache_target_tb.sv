`timescale 1ns/1ps

// Stub for unread module used inside the victim cache
module unread (
  input logic d_i
);
endmodule

`include "../ucsbece154b_victim_cache_original.sv"

module ucsbece154b_victim_cache_target_tb;

  // The DUT is a starter file with TODO placeholders.
  // NR_ENTRIES=2 uses the lru_bit section.
  // The TARGET code zeroes out MEM_d[lru_d].data, .tag, .valid on write.
  // We verify that all three fields of the LRU entry are zeroed after a write.

  localparam ADDR_WIDTH = 8;
  localparam LINE_WIDTH = 32;
  localparam NR_ENTRIES = 2;

  logic                   clk_i;
  logic                   rst_ni;
  logic                   flush_i;
  logic                   en_i;
  logic [ADDR_WIDTH-1:0]  raddr_i;
  logic [LINE_WIDTH-1:0]  rdata_o;
  logic                   hit_o;
  logic                   we_i;
  logic [ADDR_WIDTH-1:0]  waddr_i;
  logic [LINE_WIDTH-1:0]  wdata_i;

  ucsbece154b_victim_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .NR_ENTRIES(NR_ENTRIES)
  ) dut (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(flush_i), .en_i(en_i),
    .raddr_i(raddr_i), .rdata_o(rdata_o), .hit_o(hit_o),
    .we_i(we_i), .waddr_i(waddr_i), .wdata_i(wdata_i)
  );

  always #5 clk_i = ~clk_i;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task check;
    input integer test_id;
    input logic cond;
    input [255:0] msg; // description (unused in display but helps debug)
    total_tests = total_tests + 1;
    if (cond) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("FAIL: test %0d", test_id);
    end
  endtask

  initial begin
    clk_i = 0; rst_ni = 0; flush_i = 0; en_i = 0;
    raddr_i = '0; we_i = 0; waddr_i = '0; wdata_i = '0;

    // Release reset
    @(posedge clk_i); #1;
    rst_ni = 1;
    en_i = 1;
    @(posedge clk_i); #1;

    // ---------------------------------------------------------------
    // Test 1: Initially no hit (hit_o is hardcoded to 0 in the TODO stub)
    // ---------------------------------------------------------------
    raddr_i = 8'h10;
    #1;
    check(1, hit_o == 1'b0, "initial no hit");

    // ---------------------------------------------------------------
    // Test 2-5: Write entry A and verify LRU entry is ZEROED
    // The TARGET code does: MEM_d[lru_d].data = 0; .tag = 0; .valid = 0;
    // lru_q starts at 0 after reset, and lru_d = 0 (TODO), so MEM[0] is written.
    // ---------------------------------------------------------------
    we_i = 1;
    waddr_i = 8'hAB;
    wdata_i = 32'hDEADBEEF;
    @(posedge clk_i); #1;
    we_i = 0;

    // After the clock edge, MEM_q should have been updated.
    // The write should have zeroed data, tag, and valid of the LRU entry.
    @(posedge clk_i); #1;

    // Check MEM_q[0].data == 0 (the LRU entry's data was zeroed)
    check(2, dut.lru_bit.MEM_q[0].data == '0, "MEM[0].data zeroed after write");

    // Check MEM_q[0].tag == 0 (the LRU entry's tag was zeroed)
    check(3, dut.lru_bit.MEM_q[0].tag == '0, "MEM[0].tag zeroed after write");

    // Check MEM_q[0].valid == 0 (the LRU entry's valid was zeroed)
    check(4, dut.lru_bit.MEM_q[0].valid == 1'b0, "MEM[0].valid zeroed after write");

    // Test 5: A read to any address should MISS since valid=0 for the written entry
    raddr_i = 8'hAB;
    #1;
    check(5, hit_o == 1'b0, "read after write misses (valid=0)");

    // ---------------------------------------------------------------
    // Test 6-9: Write a second time and verify MEM[lru] is zeroed again
    // lru_d is always 0 per the TODO stub, so MEM[0] gets written again.
    // ---------------------------------------------------------------
    we_i = 1;
    waddr_i = 8'h55;
    wdata_i = 32'hCAFEBABE;
    @(posedge clk_i); #1;
    we_i = 0;
    @(posedge clk_i); #1;

    // Verify all three fields are zeroed for MEM[0]
    check(6, dut.lru_bit.MEM_q[0].data == '0, "MEM[0].data zeroed after 2nd write");
    check(7, dut.lru_bit.MEM_q[0].tag == '0, "MEM[0].tag zeroed after 2nd write");
    check(8, dut.lru_bit.MEM_q[0].valid == 1'b0, "MEM[0].valid zeroed after 2nd write");

    // Test 9: MEM[1] should still be in its reset/default state (valid=0)
    check(9, dut.lru_bit.MEM_q[1].valid == 1'b0, "MEM[1].valid is 0 (never written with valid)");

    // ---------------------------------------------------------------
    // Test 10-11: Flush and verify
    // ---------------------------------------------------------------
    flush_i = 1;
    @(posedge clk_i); #1;
    flush_i = 0;
    @(posedge clk_i); #1;

    check(10, dut.lru_bit.MEM_q[0].valid == 1'b0, "MEM[0].valid 0 after flush");
    check(11, dut.lru_bit.MEM_q[1].valid == 1'b0, "MEM[1].valid 0 after flush");

    // ---------------------------------------------------------------
    // Test 12-14: Write after flush, verify zeroing still works
    // ---------------------------------------------------------------
    we_i = 1;
    waddr_i = 8'h77;
    wdata_i = 32'hAAAABBBB;
    @(posedge clk_i); #1;
    we_i = 0;
    @(posedge clk_i); #1;

    check(12, dut.lru_bit.MEM_q[0].data == '0, "MEM[0].data zeroed after flush+write");
    check(13, dut.lru_bit.MEM_q[0].tag == '0, "MEM[0].tag zeroed after flush+write");
    check(14, dut.lru_bit.MEM_q[0].valid == 1'b0, "MEM[0].valid zeroed after flush+write");

    // ---------------------------------------------------------------
    // Test 15: Verify that the written entry does NOT contain the write data
    // This catches code that writes data CORRECTLY instead of zeroing.
    // If someone writes wdata_i to MEM, data would be non-zero.
    // ---------------------------------------------------------------
    we_i = 1;
    waddr_i = 8'h33;
    wdata_i = 32'h12345678;
    @(posedge clk_i); #1;
    we_i = 0;
    @(posedge clk_i); #1;

    check(15, dut.lru_bit.MEM_q[0].data != 32'h12345678,
          "MEM[0].data must NOT contain wdata (should be zero)");

    // ---------------------------------------------------------------
    // Test 16: Verify data is actually zero (not just != wdata)
    // ---------------------------------------------------------------
    check(16, dut.lru_bit.MEM_q[0].data == '0,
          "MEM[0].data must be exactly zero after write");

    if (fail_count == 0)
      $display("[TB_REAL] ucsbece154b_victim_cache all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] ucsbece154b_victim_cache FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #50000;
    $display("[TB_REAL] ucsbece154b_victim_cache FAILED - timeout");
    $finish;
  end
endmodule
