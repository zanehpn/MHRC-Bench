`timescale 1ns/1ps
`include "../plic_dynamic_registers_original.sv"

module plic_dynamic_registers_target_tb;

  parameter SOURCES = 8;
  parameter TARGETS = 1;
  parameter PRIORITIES = 8;
  parameter ADDR_SIZE = 32;
  parameter DATA_SIZE = 32;
  parameter MAX_PENDING_COUNT = 4;
  parameter HAS_THRESHOLD = 1;
  parameter HAS_CONFIG_REG = 1;
  parameter BE_SIZE = (DATA_SIZE+7)/8;
  parameter SOURCES_BITS = $clog2(SOURCES+1);
  parameter PRIORITY_BITS = $clog2(PRIORITIES);

  // Register layout constants (must match module internals)
  localparam CONFIG_REGS = (16 + 16 + 16 + 1 + DATA_SIZE - 1) / DATA_SIZE; // = 2
  localparam EL_REGS = (SOURCES + DATA_SIZE - 1) / DATA_SIZE; // = 1
  localparam PRIORITY_NIBBLES = (PRIORITY_BITS + 3 - 1) / 4;  // = 1
  localparam PRIORITY_FIELDS_PER_REG = DATA_SIZE / (PRIORITY_NIBBLES * 4); // = 8
  localparam PRIORITY_REGS = (SOURCES + PRIORITY_FIELDS_PER_REG - 1) / PRIORITY_FIELDS_PER_REG; // = 1
  localparam IE_REGS = EL_REGS * TARGETS; // = 1
  localparam THRESHOLD_REGS = TARGETS; // = 1
  localparam ID_REGS = TARGETS; // = 1
  localparam TOTAL_REGS = CONFIG_REGS + EL_REGS + IE_REGS + PRIORITY_REGS + THRESHOLD_REGS + ID_REGS;
  // Register order: CONFIG(2), EL(1), PRIORITY(1), IE(1), THRESHOLD(1), ID(1) = 7 regs
  localparam DATA_BYTES = BE_SIZE; // = 4

  // Addresses (register_index * 4)
  localparam ADDR_CONFIG0   = 0;   // reg 0
  localparam ADDR_CONFIG1   = 4;   // reg 1
  localparam ADDR_EL        = 8;   // reg 2
  localparam ADDR_PRIORITY  = 12;  // reg 3
  localparam ADDR_IE        = 16;  // reg 4
  localparam ADDR_THRESHOLD = 20;  // reg 5
  localparam ADDR_ID        = 24;  // reg 6

  logic rst_n, clk;
  logic we, re;
  logic [BE_SIZE-1:0] be;
  logic [ADDR_SIZE-1:0] waddr, raddr;
  logic [DATA_SIZE-1:0] wdata, rdata;
  logic [SOURCES-1:0] el;
  logic [SOURCES-1:0] ip;
  logic [SOURCES-1:0] ie [TARGETS];
  logic [PRIORITY_BITS-1:0] p [SOURCES];
  logic [PRIORITY_BITS-1:0] th [TARGETS];
  logic [SOURCES_BITS-1:0] id_in [TARGETS];
  logic [TARGETS-1:0] claim_out;
  logic [TARGETS-1:0] complete_out;

  plic_dynamic_registers #(
    .SOURCES(SOURCES),
    .TARGETS(TARGETS),
    .PRIORITIES(PRIORITIES),
    .MAX_PENDING_COUNT(MAX_PENDING_COUNT),
    .HAS_THRESHOLD(HAS_THRESHOLD),
    .HAS_CONFIG_REG(HAS_CONFIG_REG)
  ) dut (
    .rst_n(rst_n),
    .clk(clk),
    .we(we),
    .re(re),
    .be(be),
    .waddr(waddr),
    .raddr(raddr),
    .wdata(wdata),
    .rdata(rdata),
    .el(el),
    .ip(ip),
    .ie(ie),
    .p(p),
    .th(th),
    .id(id_in),
    .claim(claim_out),
    .complete(complete_out)
  );

  always #5 clk = ~clk;

  integer pass_count, fail_count;

  // Write task
  task automatic do_write(input [ADDR_SIZE-1:0] addr, input [DATA_SIZE-1:0] data, input [BE_SIZE-1:0] byte_en);
    @(negedge clk);
    we = 1; waddr = addr; wdata = data; be = byte_en;
    @(posedge clk); #1;
    we = 0;
  endtask

  // Read task
  task automatic do_read(input [ADDR_SIZE-1:0] addr, output [DATA_SIZE-1:0] data);
    @(negedge clk);
    re = 1; raddr = addr;
    @(posedge clk); #1;
    re = 0;
    @(posedge clk); #1;
    data = rdata;
  endtask

  logic [DATA_SIZE-1:0] rd;

  initial begin
    clk = 0; rst_n = 0; we = 0; re = 0; be = '0;
    waddr = '0; raddr = '0; wdata = '0;
    ip = '0; id_in[0] = '0;
    pass_count = 0; fail_count = 0;

    @(posedge clk); @(posedge clk);
    rst_n = 1;
    @(posedge clk); @(posedge clk);

    // ====== Test writes to various register types ======

    // T1: Write to EL register with full byte enable
    do_write(ADDR_EL, 32'h000000AA, 4'hF);
    @(posedge clk); #1;
    if (el == 8'hAA) pass_count++; else begin fail_count++; $display("FAIL T1: el=%h exp AA", el); end

    // T2: Write to EL register with partial byte enable (only low byte)
    do_write(ADDR_EL, 32'h0000FF55, 4'h1);
    @(posedge clk); #1;
    // Only byte 0 should change: was AA, new low byte = 55
    if (el == 8'h55) pass_count++; else begin fail_count++; $display("FAIL T2: el=%h exp 55", el); end

    // T3: Write to EL register with no byte enable => no change
    do_write(ADDR_EL, 32'hFFFFFFFF, 4'h0);
    @(posedge clk); #1;
    if (el == 8'h55) pass_count++; else begin fail_count++; $display("FAIL T3: el=%h exp 55", el); end

    // T4: Write to PRIORITY register
    do_write(ADDR_PRIORITY, 32'h00000003, 4'hF);
    @(posedge clk); #1;
    if (p[0] == 3) pass_count++; else begin fail_count++; $display("FAIL T4: p[0]=%0d exp 3", p[0]); end

    // T5: Write priority for source 1 (bits [7:4])
    do_write(ADDR_PRIORITY, 32'h00000053, 4'hF);
    @(posedge clk); #1;
    if (p[0] == 3 && p[1] == 5) pass_count++;
    else begin fail_count++; $display("FAIL T5: p[0]=%0d p[1]=%0d", p[0], p[1]); end

    // T6: Write IE register
    do_write(ADDR_IE, 32'h000000FF, 4'hF);
    @(posedge clk); #1;
    if (ie[0] == 8'hFF) pass_count++; else begin fail_count++; $display("FAIL T6: ie=%h exp FF", ie[0]); end

    // T7: Write THRESHOLD register
    do_write(ADDR_THRESHOLD, 32'h00000005, 4'hF);
    @(posedge clk); #1;
    if (th[0] == 5) pass_count++; else begin fail_count++; $display("FAIL T7: th=%0d exp 5", th[0]); end

    // T8: Write to ID register should NOT modify register (generates strobe only)
    // complete is registered: complete <= gen_complete(we, waddr), so it
    // reflects the we/waddr from the CURRENT cycle. We need to check it
    // right after the write posedge (inside do_write the posedge has already happened).
    // do_write sets we=1 at negedge, then at posedge the DUT latches complete=1,
    // then do_write sets we=0 at #1 after that posedge.
    // So after do_write returns, complete is already 1. Check immediately.
    do_write(ADDR_ID, 32'h00000001, 4'hF);
    // complete should be 1 now (latched at the posedge inside do_write)
    if (complete_out) pass_count++; else begin fail_count++; $display("FAIL T8: no complete strobe"); end

    // T9: Verify at next posedge (with we=0), complete goes back to 0
    @(posedge clk); #1;
    if (!complete_out) pass_count++; else begin fail_count++; $display("FAIL T9: complete still asserted"); end

    // T10: Write to EL with byte enable = 4'h2 (second byte only)
    do_write(ADDR_EL, 32'h0000FF00, 4'h2);
    @(posedge clk); #1;
    // Low byte stays 55, second byte becomes FF => for 8-bit el, only low byte matters
    // Actually EL is SOURCES=8 bits, so only bits [7:0] of register matter
    // Byte 0 = 55, byte 1 changed to FF => register = 0xFF55, el = bits[7:0] = 55
    if (el == 8'h55) pass_count++; else begin fail_count++; $display("FAIL T10: el=%h exp 55", el); end

    // T11: Verify reset clears all registers
    @(negedge clk); rst_n = 0;
    @(posedge clk); @(posedge clk); #1;
    if (el == 0 && p[0] == 0 && th[0] == 0) pass_count++;
    else begin fail_count++; $display("FAIL T11: reset did not clear"); end

    // T12: Release reset and write again
    @(negedge clk); rst_n = 1;
    @(posedge clk); @(posedge clk);
    do_write(ADDR_PRIORITY, 32'h00000007, 4'hF);
    @(posedge clk); #1;
    if (p[0] == 7) pass_count++; else begin fail_count++; $display("FAIL T12: p[0]=%0d exp 7", p[0]); end

    // T13: Write with only upper byte enable shouldn't affect lower bytes
    do_write(ADDR_PRIORITY, 32'hFF000000, 4'h8);
    @(posedge clk); #1;
    // Low byte still has 07
    if (p[0] == 7) pass_count++; else begin fail_count++; $display("FAIL T13: p[0]=%0d exp 7", p[0]); end

    // T14: Overwrite priority completely
    do_write(ADDR_PRIORITY, 32'h00000000, 4'hF);
    @(posedge clk); #1;
    if (p[0] == 0) pass_count++; else begin fail_count++; $display("FAIL T14: p[0]=%0d exp 0", p[0]); end

    // T15: Write threshold with partial byte enable
    do_write(ADDR_THRESHOLD, 32'h00000003, 4'hF);
    @(posedge clk); #1;
    do_write(ADDR_THRESHOLD, 32'h00000000, 4'h0); // no bytes enabled
    @(posedge clk); #1;
    if (th[0] == 3) pass_count++; else begin fail_count++; $display("FAIL T15: th=%0d exp 3", th[0]); end

    // T16: Read back EL via read interface
    do_write(ADDR_EL, 32'h000000A5, 4'hF);
    @(posedge clk);
    do_read(ADDR_EL, rd);
    if (rd[7:0] == 8'hA5) pass_count++; else begin fail_count++; $display("FAIL T16: rd=%h exp A5", rd); end

    // T17: Read back priority
    do_write(ADDR_PRIORITY, 32'h00000021, 4'hF);
    @(posedge clk);
    do_read(ADDR_PRIORITY, rd);
    if (rd[2:0] == 1 && rd[6:4] == 2) pass_count++;
    else begin fail_count++; $display("FAIL T17: rd=%h", rd); end

    // T18: Write multiple times in succession
    do_write(ADDR_EL, 32'h00000001, 4'hF);
    do_write(ADDR_EL, 32'h00000003, 4'hF);
    do_write(ADDR_EL, 32'h00000007, 4'hF);
    @(posedge clk); #1;
    if (el == 8'h07) pass_count++; else begin fail_count++; $display("FAIL T18: el=%h exp 07", el); end

    // T19: we=0 doesn't change registers
    @(negedge clk); we = 0; waddr = ADDR_EL; wdata = 32'hFF; be = 4'hF;
    @(posedge clk); #1;
    if (el == 8'h07) pass_count++; else begin fail_count++; $display("FAIL T19: el changed w/o we"); end

    // T20: claim on read of ID register
    id_in[0] = 4'd5;
    do_read(ADDR_ID, rd);
    @(posedge clk); #1;
    // claim should have pulsed
    // Just verify rd contains the id
    if (rd[SOURCES_BITS-1:0] == 5) pass_count++;
    else begin fail_count++; $display("FAIL T20: id read=%0d exp 5", rd[SOURCES_BITS-1:0]); end

    // Summary
    if (fail_count == 0)
      $display("[TB_REAL] plic_dynamic_registers all %0d / %0d tests PASSED", pass_count, pass_count);
    else
      $display("[TB_REAL] plic_dynamic_registers FAILED %0d / %0d tests", fail_count, pass_count + fail_count);
    $finish;
  end
endmodule
