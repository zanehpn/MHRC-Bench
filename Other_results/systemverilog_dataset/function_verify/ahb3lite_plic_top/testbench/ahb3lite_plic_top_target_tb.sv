`timescale 1ns/1ps

// AHB3-Lite package stub with required constants
package ahb3lite_pkg;
  // Transfer type
  localparam [1:0] HTRANS_IDLE   = 2'b00;
  localparam [1:0] HTRANS_BUSY   = 2'b01;
  localparam [1:0] HTRANS_NONSEQ = 2'b10;
  localparam [1:0] HTRANS_SEQ    = 2'b11;

  // Transfer size
  localparam [2:0] HSIZE_BYTE   = 3'b000;
  localparam [2:0] HSIZE_HWORD  = 3'b001;
  localparam [2:0] HSIZE_WORD   = 3'b010;
  localparam [2:0] HSIZE_DWORD  = 3'b011;
  localparam [2:0] HSIZE_B128   = 3'b100;
  localparam [2:0] HSIZE_B256   = 3'b101;
  localparam [2:0] HSIZE_B512   = 3'b110;
  localparam [2:0] HSIZE_B1024  = 3'b111;

  // Burst type
  localparam [2:0] HBURST_SINGLE = 3'b000;
  localparam [2:0] HBURST_INCR   = 3'b001;
  localparam [2:0] HBURST_WRAP4  = 3'b010;
  localparam [2:0] HBURST_INCR4  = 3'b011;
  localparam [2:0] HBURST_WRAP8  = 3'b100;
  localparam [2:0] HBURST_INCR8  = 3'b101;
  localparam [2:0] HBURST_WRAP16 = 3'b110;
  localparam [2:0] HBURST_INCR16 = 3'b111;

  // Response
  localparam       HRESP_OKAY  = 1'b0;
  localparam       HRESP_ERROR = 1'b1;
endpackage

// Stub for plic_dynamic_registers
module plic_dynamic_registers #(
  parameter ADDR_SIZE         = 32,
  parameter DATA_SIZE         = 32,
  parameter SOURCES           = 64,
  parameter TARGETS           = 4,
  parameter PRIORITIES        = 8,
  parameter MAX_PENDING_COUNT = 8,
  parameter HAS_THRESHOLD     = 1,
  parameter HAS_CONFIG_REG    = 1
)(
  input                                            rst_n,
  input                                            clk,
  input                                            we,
  input                                            re,
  input  [(DATA_SIZE+7)/8-1:0]                     be,
  input  [ADDR_SIZE-1:0]                           waddr,
  input  [ADDR_SIZE-1:0]                           raddr,
  input  [DATA_SIZE-1:0]                           wdata,
  output reg [DATA_SIZE-1:0]                       rdata,
  output [SOURCES-1:0]                             el,
  input  [SOURCES-1:0]                             ip,
  output [SOURCES-1:0]                             ie [TARGETS],
  output [$clog2(PRIORITIES)-1:0]                  p  [SOURCES],
  output [$clog2(PRIORITIES)-1:0]                  th [TARGETS],
  input  [$clog2(SOURCES+1)-1:0]                   id [TARGETS],
  output [TARGETS-1:0]                             claim,
  output [TARGETS-1:0]                             complete
);
  assign el = '0;
  assign rdata = '0;
  assign claim = '0;
  assign complete = '0;
  genvar gi, gj;
  generate
    for (gi = 0; gi < TARGETS; gi++) begin : gen_ie
      assign ie[gi] = '1;
    end
    for (gi = 0; gi < TARGETS; gi++) begin : gen_th
      assign th[gi] = '0;
    end
    for (gj = 0; gj < SOURCES; gj++) begin : gen_p
      assign p[gj] = '1;
    end
  endgenerate
endmodule

// Stub for plic_core
module plic_core #(
  parameter SOURCES           = 64,
  parameter TARGETS           = 4,
  parameter PRIORITIES        = 8,
  parameter MAX_PENDING_COUNT = 8
)(
  input                                            rst_n,
  input                                            clk,
  input  [SOURCES-1:0]                             src,
  input  [SOURCES-1:0]                             el,
  output [SOURCES-1:0]                             ip,
  input  [SOURCES-1:0]                             ie [TARGETS],
  input  [$clog2(PRIORITIES)-1:0]                  ipriority [SOURCES],
  input  [$clog2(PRIORITIES)-1:0]                  threshold [TARGETS],
  output [TARGETS-1:0]                             ireq,
  output [$clog2(SOURCES+1)-1:0]                   id [TARGETS],
  input  [TARGETS-1:0]                             claim,
  input  [TARGETS-1:0]                             complete
);
  assign ip = src;
  assign ireq = |src ? { TARGETS{1'b1} } : '0;
  genvar gi;
  generate
    for (gi = 0; gi < TARGETS; gi++) begin : gen_id
      assign id[gi] = '0;
    end
  endgenerate
endmodule

`include "../ahb3lite_plic_top_original.sv"

// ---------------------------------------------------------------------------
//  Testbench:  verify address_offset / gen_be byte-enable generation
//
//  The <TARGET> fills in address_offset values for HDATA_SIZE = 512..32.
//  We instantiate the DUT with HDATA_SIZE = 32 and 64 and check that
//  ahb_be (which is gen_be's registered output) matches the expected
//  byte-enable pattern for various (HSIZE, HADDR) combinations.
// ---------------------------------------------------------------------------
module ahb3lite_plic_top_target_tb;
  import ahb3lite_pkg::*;

  localparam HADDR_SIZE = 32;
  localparam SOURCES    = 4;
  localparam TARGETS    = 1;

  int err_count = 0;
  int test_count = 0;
  logic dut64_done = 0;

  // -------------------------------------------------------
  //  DUT #1 : HDATA_SIZE = 32   (BE_SIZE = 4)
  //  Expected address_offset = 7'b000_0011
  // -------------------------------------------------------
  localparam HDATA32 = 32;
  localparam BE32    = (HDATA32 + 7) / 8;  // 4

  logic                     clk32, rst32_n;
  logic                     hsel32, hwrite32, hready32;
  logic [HADDR_SIZE-1:0]    haddr32;
  logic [HDATA32-1:0]       hwdata32, hrdata32;
  logic [2:0]               hsize32, hburst32;
  logic [3:0]               hprot32;
  logic [1:0]               htrans32;
  logic                     hreadyout32, hresp32;
  logic [SOURCES-1:0]       src32;
  logic [TARGETS-1:0]       irq32;

  ahb3lite_plic_top #(
    .HADDR_SIZE (HADDR_SIZE),
    .HDATA_SIZE (HDATA32),
    .SOURCES    (SOURCES),
    .TARGETS    (TARGETS),
    .PRIORITIES (8),
    .MAX_PENDING_COUNT (8),
    .HAS_THRESHOLD  (1),
    .HAS_CONFIG_REG (1)
  ) dut32 (
    .HRESETn   (rst32_n),
    .HCLK      (clk32),
    .HSEL      (hsel32),
    .HADDR     (haddr32),
    .HWDATA    (hwdata32),
    .HRDATA    (hrdata32),
    .HWRITE    (hwrite32),
    .HSIZE     (hsize32),
    .HBURST    (hburst32),
    .HPROT     (hprot32),
    .HTRANS    (htrans32),
    .HREADYOUT (hreadyout32),
    .HREADY    (hready32),
    .HRESP     (hresp32),
    .src       (src32),
    .irq       (irq32)
  );

  always #5 clk32 = ~clk32;

  // -------------------------------------------------------
  //  DUT #2 : HDATA_SIZE = 64   (BE_SIZE = 8)
  //  Expected address_offset = 7'b000_0111
  // -------------------------------------------------------
  localparam HDATA64 = 64;
  localparam BE64    = (HDATA64 + 7) / 8;  // 8

  logic                     clk64, rst64_n;
  logic                     hsel64, hwrite64, hready64;
  logic [HADDR_SIZE-1:0]    haddr64;
  logic [HDATA64-1:0]       hwdata64, hrdata64;
  logic [2:0]               hsize64, hburst64;
  logic [3:0]               hprot64;
  logic [1:0]               htrans64;
  logic                     hreadyout64, hresp64;
  logic [SOURCES-1:0]       src64;
  logic [TARGETS-1:0]       irq64;

  ahb3lite_plic_top #(
    .HADDR_SIZE (HADDR_SIZE),
    .HDATA_SIZE (HDATA64),
    .SOURCES    (SOURCES),
    .TARGETS    (TARGETS),
    .PRIORITIES (8),
    .MAX_PENDING_COUNT (8),
    .HAS_THRESHOLD  (1),
    .HAS_CONFIG_REG (1)
  ) dut64 (
    .HRESETn   (rst64_n),
    .HCLK      (clk64),
    .HSEL      (hsel64),
    .HADDR     (haddr64),
    .HWDATA    (hwdata64),
    .HRDATA    (hrdata64),
    .HWRITE    (hwrite64),
    .HSIZE     (hsize64),
    .HBURST    (hburst64),
    .HPROT     (hprot64),
    .HTRANS    (htrans64),
    .HREADYOUT (hreadyout64),
    .HREADY    (hready64),
    .HRESP     (hresp64),
    .src       (src64),
    .irq       (irq64)
  );

  always #5 clk64 = ~clk64;

  // -------------------------------------------------------
  //  Helper: check a byte-enable value
  // -------------------------------------------------------
  task automatic check_be_32(
    input [BE32-1:0] expected,
    input string     msg
  );
    test_count++;
    if (dut32.ahb_be !== expected) begin
      $display("[FAIL] DUT32 %s : ahb_be=%04b  expected=%04b", msg, dut32.ahb_be, expected);
      err_count++;
    end else begin
      $display("[PASS] DUT32 %s : ahb_be=%04b", msg, dut32.ahb_be);
    end
  endtask

  task automatic check_be_64(
    input [BE64-1:0] expected,
    input string     msg
  );
    test_count++;
    if (dut64.ahb_be !== expected) begin
      $display("[FAIL] DUT64 %s : ahb_be=%08b  expected=%08b", msg, dut64.ahb_be, expected);
      err_count++;
    end else begin
      $display("[PASS] DUT64 %s : ahb_be=%08b", msg, dut64.ahb_be);
    end
  endtask

  // -------------------------------------------------------
  //  Test sequence for DUT32  (HDATA_SIZE=32)
  //
  //  address_offset = 7'b000_0011  →  lower 2 bits of addr
  //  gen_be = full_be << (haddr & 2'b11)
  //
  //  HSIZE_BYTE  → full_be[3:0] = 4'h1
  //  HSIZE_HWORD → full_be[3:0] = 4'h3
  //  HSIZE_WORD  → full_be[3:0] = 4'hF
  // -------------------------------------------------------
  initial begin
    clk32 = 0; rst32_n = 0;
    hsel32 = 0; hwrite32 = 0; hready32 = 1;
    haddr32 = 0; hwdata32 = 0;
    hsize32 = HSIZE_WORD; hburst32 = HBURST_SINGLE;
    hprot32 = 4'b0011; htrans32 = HTRANS_IDLE; src32 = 0;

    repeat (4) @(posedge clk32);
    rst32_n = 1;
    @(posedge clk32);

    // ---- BYTE transfers ----
    // BYTE @ addr 0x00 → masked=0, be = 1<<0 = 4'b0001
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_BYTE; haddr32 = 32'h0000_0000;
    @(posedge clk32); #1;  // ahb_be latched
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b0001, "BYTE @ addr 0x00");

    // BYTE @ addr 0x01 → masked=1, be = 1<<1 = 4'b0010
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_BYTE; haddr32 = 32'h0000_0001;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b0010, "BYTE @ addr 0x01");

    // BYTE @ addr 0x02 → masked=2, be = 1<<2 = 4'b0100
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_BYTE; haddr32 = 32'h0000_0002;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b0100, "BYTE @ addr 0x02");

    // BYTE @ addr 0x03 → masked=3, be = 1<<3 = 4'b1000
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_BYTE; haddr32 = 32'h0000_0003;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b1000, "BYTE @ addr 0x03");

    // BYTE @ addr 0x15 → masked = 0x15 & 0x03 = 1, be = 4'b0010
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_BYTE; haddr32 = 32'h0000_0015;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b0010, "BYTE @ addr 0x15");

    // ---- HALFWORD transfers ----
    // HWORD @ addr 0x00 → masked=0, be = 3<<0 = 4'b0011
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_HWORD; haddr32 = 32'h0000_0000;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b0011, "HWORD @ addr 0x00");

    // HWORD @ addr 0x02 → masked=2, be = 3<<2 = 4'b1100
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_HWORD; haddr32 = 32'h0000_0002;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b1100, "HWORD @ addr 0x02");

    // ---- WORD transfer ----
    // WORD @ addr 0x00 → masked=0, be = F<<0 = 4'b1111
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_WORD; haddr32 = 32'h0000_0000;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b1111, "WORD  @ addr 0x00");

    // WORD @ addr 0x04 → masked = 0x04 & 0x03 = 0, be = 4'b1111
    @(posedge clk32); #1;
    hsel32 = 1; hwrite32 = 1; htrans32 = HTRANS_NONSEQ;
    hsize32 = HSIZE_WORD; haddr32 = 32'h0000_0004;
    @(posedge clk32); #1;
    hsel32 = 0; htrans32 = HTRANS_IDLE;
    check_be_32(4'b1111, "WORD  @ addr 0x04");

    // Wait for DUT64 tests to finish
    wait (dut64_done);

    $display("----------------------------------------------");
    if (err_count == 0)
      $display("[TB_REAL] ahb3lite_plic_top address_offset/gen_be ALL %0d tests PASSED", test_count);
    else
      $display("[TB_REAL] ahb3lite_plic_top FAILED %0d / %0d tests", err_count, test_count);
    $display("----------------------------------------------");

    $finish;
  end

  // -------------------------------------------------------
  //  Test sequence for DUT64  (HDATA_SIZE=64)
  //
  //  address_offset = 7'b000_0111  →  lower 3 bits of addr
  //  gen_be = full_be << (haddr & 3'b111)
  //
  //  HSIZE_BYTE  → full_be[7:0] = 8'h01
  //  HSIZE_HWORD → full_be[7:0] = 8'h03
  //  HSIZE_WORD  → full_be[7:0] = 8'h0F
  //  HSIZE_DWORD → full_be[7:0] = 8'hFF
  // -------------------------------------------------------
  initial begin
    clk64 = 0; rst64_n = 0;
    hsel64 = 0; hwrite64 = 0; hready64 = 1;
    haddr64 = 0; hwdata64 = 0;
    hsize64 = HSIZE_DWORD; hburst64 = HBURST_SINGLE;
    hprot64 = 4'b0011; htrans64 = HTRANS_IDLE; src64 = 0;

    repeat (4) @(posedge clk64);
    rst64_n = 1;
    @(posedge clk64);

    // BYTE @ addr 0x00 → masked=0, be = 01<<0 = 8'b0000_0001
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_BYTE; haddr64 = 32'h0000_0000;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b0000_0001, "BYTE  @ addr 0x00");

    // BYTE @ addr 0x05 → masked=5, be = 01<<5 = 8'b0010_0000
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_BYTE; haddr64 = 32'h0000_0005;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b0010_0000, "BYTE  @ addr 0x05");

    // BYTE @ addr 0x07 → masked=7, be = 01<<7 = 8'b1000_0000
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_BYTE; haddr64 = 32'h0000_0007;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b1000_0000, "BYTE  @ addr 0x07");

    // HWORD @ addr 0x02 → masked=2, be = 03<<2 = 8'b0000_1100
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_HWORD; haddr64 = 32'h0000_0002;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b0000_1100, "HWORD @ addr 0x02");

    // HWORD @ addr 0x06 → masked=6, be = 03<<6 = 8'b1100_0000
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_HWORD; haddr64 = 32'h0000_0006;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b1100_0000, "HWORD @ addr 0x06");

    // WORD @ addr 0x04 → masked=4, be = 0F<<4 = 8'b1111_0000
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_WORD; haddr64 = 32'h0000_0004;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b1111_0000, "WORD  @ addr 0x04");

    // WORD @ addr 0x00 → masked=0, be = 0F<<0 = 8'b0000_1111
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_WORD; haddr64 = 32'h0000_0000;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b0000_1111, "WORD  @ addr 0x00");

    // DWORD @ addr 0x00 → masked=0, be = FF<<0 = 8'b1111_1111
    @(posedge clk64); #1;
    hsel64 = 1; hwrite64 = 1; htrans64 = HTRANS_NONSEQ;
    hsize64 = HSIZE_DWORD; haddr64 = 32'h0000_0000;
    @(posedge clk64); #1;
    hsel64 = 0; htrans64 = HTRANS_IDLE;
    check_be_64(8'b1111_1111, "DWORD @ addr 0x00");

    dut64_done = 1;
  end

endmodule
