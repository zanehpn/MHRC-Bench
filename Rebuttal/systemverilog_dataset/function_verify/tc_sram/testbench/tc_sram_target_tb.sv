`timescale 1ns/1ps
`include "../tc_sram_original.sv"

module tc_sram_target_tb;
  // TARGET at line 95: case statement for SimInit SRAM initialization
  // Original:
  //   "zeros":  init_val[i] = {DataWidth{1'b0}};
  //   "ones":   init_val[i] = {DataWidth{1'b1}};
  //   "random": init_val[i] = {DataWidth{$urandom()}};
  //   default:  init_val[i] = {DataWidth{1'bx}};
  //
  // We test that SRAM initializes correctly with "zeros" and "ones" modes.

  localparam NumWords  = 8;
  localparam DataWidth = 16;
  localparam ByteWidth = 8;
  localparam NumPorts  = 1;
  localparam Latency   = 1;
  localparam AddrWidth = $clog2(NumWords);
  localparam BeWidth   = (DataWidth + ByteWidth - 1) / ByteWidth;

  // ---- DUT for "zeros" init ----
  logic                              clk_z;
  logic                              rst_nz;
  logic  [NumPorts-1:0]              req_z;
  logic  [NumPorts-1:0]              we_z;
  logic  [NumPorts-1:0][AddrWidth-1:0] addr_z;
  logic  [NumPorts-1:0][DataWidth-1:0] wdata_z;
  logic  [NumPorts-1:0][BeWidth-1:0]   be_z;
  logic  [NumPorts-1:0][DataWidth-1:0] rdata_z;

  tc_sram #(
    .NumWords(NumWords), .DataWidth(DataWidth), .ByteWidth(ByteWidth),
    .NumPorts(NumPorts), .Latency(Latency), .SimInit("zeros")
  ) dut_zeros (
    .clk_i(clk_z), .rst_ni(rst_nz),
    .req_i(req_z), .we_i(we_z), .addr_i(addr_z),
    .wdata_i(wdata_z), .be_i(be_z), .rdata_o(rdata_z)
  );

  always #5 clk_z = ~clk_z;

  // ---- DUT for "ones" init ----
  logic                              clk_o;
  logic                              rst_no;
  logic  [NumPorts-1:0]              req_o;
  logic  [NumPorts-1:0]              we_o;
  logic  [NumPorts-1:0][AddrWidth-1:0] addr_o;
  logic  [NumPorts-1:0][DataWidth-1:0] wdata_o;
  logic  [NumPorts-1:0][BeWidth-1:0]   be_o;
  logic  [NumPorts-1:0][DataWidth-1:0] rdata_o;

  tc_sram #(
    .NumWords(NumWords), .DataWidth(DataWidth), .ByteWidth(ByteWidth),
    .NumPorts(NumPorts), .Latency(Latency), .SimInit("ones")
  ) dut_ones (
    .clk_i(clk_o), .rst_ni(rst_no),
    .req_i(req_o), .we_i(we_o), .addr_i(addr_o),
    .wdata_i(wdata_o), .be_i(be_o), .rdata_o(rdata_o)
  );

  always #5 clk_o = ~clk_o;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task automatic check(input string name, input logic cond);
    total_tests = total_tests + 1;
    if (cond) pass_count = pass_count + 1;
    else begin
      fail_count = fail_count + 1;
      $display("FAIL: %s", name);
    end
  endtask

  integer i;

  initial begin
    // Initialize
    clk_z = 0; rst_nz = 0; req_z = 0; we_z = 0; addr_z = '0; wdata_z = '0; be_z = '1;
    clk_o = 0; rst_no = 0; req_o = 0; we_o = 0; addr_o = '0; wdata_o = '0; be_o = '1;

    // Apply reset
    @(posedge clk_z); #1;
    rst_nz = 1;
    rst_no = 1;
    @(posedge clk_z); #1;

    // Test 1-8: Read all addresses from "zeros" init - should all be 0
    for (i = 0; i < NumWords; i = i + 1) begin
      @(negedge clk_z);
      req_z[0] = 1; we_z[0] = 0; addr_z[0] = i[AddrWidth-1:0];
      @(posedge clk_z); #1;
      @(posedge clk_z); #1; // latency=1
      check($sformatf("zeros_addr%0d", i), rdata_z[0] == {DataWidth{1'b0}});
    end

    // Test 9-16: Read all addresses from "ones" init - should all be 1s
    for (i = 0; i < NumWords; i = i + 1) begin
      @(negedge clk_o);
      req_o[0] = 1; we_o[0] = 0; addr_o[0] = i[AddrWidth-1:0];
      @(posedge clk_o); #1;
      @(posedge clk_o); #1; // latency=1
      check($sformatf("ones_addr%0d", i), rdata_o[0] == {DataWidth{1'b1}});
    end

    // Test 17-20: Write to zeros-init SRAM and read back
    @(negedge clk_z);
    req_z[0] = 1; we_z[0] = 1; addr_z[0] = 3'd2; wdata_z[0] = 16'hCAFE; be_z[0] = '1;
    @(posedge clk_z); #1;

    @(negedge clk_z);
    req_z[0] = 1; we_z[0] = 1; addr_z[0] = 3'd5; wdata_z[0] = 16'hBEEF; be_z[0] = '1;
    @(posedge clk_z); #1;

    // Read back addr 2
    @(negedge clk_z);
    we_z[0] = 0; addr_z[0] = 3'd2;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_write_read_2", rdata_z[0] == 16'hCAFE);

    // Read back addr 5
    @(negedge clk_z);
    addr_z[0] = 3'd5;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_write_read_5", rdata_z[0] == 16'hBEEF);

    // Read unwritten addr 0 - should still be 0
    @(negedge clk_z);
    addr_z[0] = 3'd0;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_unwritten_0", rdata_z[0] == 16'h0000);

    // Read unwritten addr 7 - should still be 0
    @(negedge clk_z);
    addr_z[0] = 3'd7;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_unwritten_7", rdata_z[0] == 16'h0000);

    // Test 21-24: Write to ones-init SRAM and verify unwritten stays 0xFFFF
    @(negedge clk_o);
    req_o[0] = 1; we_o[0] = 1; addr_o[0] = 3'd1; wdata_o[0] = 16'h1234; be_o[0] = '1;
    @(posedge clk_o); #1;

    @(negedge clk_o);
    we_o[0] = 0; addr_o[0] = 3'd1;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_write_read_1", rdata_o[0] == 16'h1234);

    @(negedge clk_o);
    addr_o[0] = 3'd0;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_unwritten_0", rdata_o[0] == {DataWidth{1'b1}});

    @(negedge clk_o);
    addr_o[0] = 3'd6;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_unwritten_6", rdata_o[0] == {DataWidth{1'b1}});

    // Test: byte enable - write only low byte
    @(negedge clk_o);
    req_o[0] = 1; we_o[0] = 1; addr_o[0] = 3'd3;
    wdata_o[0] = 16'hABCD; be_o[0] = 2'b01; // only low byte
    @(posedge clk_o); #1;

    @(negedge clk_o);
    we_o[0] = 0; addr_o[0] = 3'd3;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    // Low byte should be CD, high byte should be FF (ones init)
    check("be_low_byte", rdata_o[0][7:0] == 8'hCD);
    check("be_high_byte", rdata_o[0][15:8] == 8'hFF);

    // Test: Re-apply reset and verify SRAM re-initializes from init_val
    // For "zeros" DUT: after re-reset, previously written addresses should be zeros again
    @(negedge clk_z);
    rst_nz = 0;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    rst_nz = 1;
    @(posedge clk_z); #1;

    // Read addr 2 (was 0xCAFE) - should be 0 again after re-reset
    @(negedge clk_z);
    req_z[0] = 1; we_z[0] = 0; addr_z[0] = 3'd2;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_rereset_addr2", rdata_z[0] == 16'h0000);

    // Read addr 5 (was 0xBEEF) - should be 0 again
    @(negedge clk_z);
    addr_z[0] = 3'd5;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_rereset_addr5", rdata_z[0] == 16'h0000);

    // For "ones" DUT: after re-reset, previously written addresses should be all 1s again
    @(negedge clk_o);
    rst_no = 0;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    rst_no = 1;
    @(posedge clk_o); #1;

    // Read addr 1 (was 0x1234) - should be 0xFFFF again
    @(negedge clk_o);
    req_o[0] = 1; we_o[0] = 0; addr_o[0] = 3'd1;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_rereset_addr1", rdata_o[0] == 16'hFFFF);

    // Read addr 3 (was partially written) - should be 0xFFFF again
    @(negedge clk_o);
    addr_o[0] = 3'd3;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_rereset_addr3", rdata_o[0] == 16'hFFFF);

    // Test: Verify exact bit patterns - check each bit of the init values
    // For zeros: all 16 bits must be 0
    @(negedge clk_z);
    req_z[0] = 1; we_z[0] = 0; addr_z[0] = 3'd4;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_exact_bits", rdata_z[0] === {DataWidth{1'b0}});

    // For ones: all 16 bits must be 1
    @(negedge clk_o);
    req_o[0] = 1; we_o[0] = 0; addr_o[0] = 3'd4;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_exact_bits", rdata_o[0] === {DataWidth{1'b1}});

    // Test: Verify zeros init produces exact 0 with === (catches X bits)
    @(negedge clk_z);
    req_z[0] = 1; we_z[0] = 0; addr_z[0] = 3'd6;
    @(posedge clk_z); #1;
    @(posedge clk_z); #1;
    check("zeros_no_x_bits", rdata_z[0] === 16'h0000);

    // Test: Verify ones init produces exact 1s with === (catches X bits)
    @(negedge clk_o);
    req_o[0] = 1; we_o[0] = 0; addr_o[0] = 3'd7;
    @(posedge clk_o); #1;
    @(posedge clk_o); #1;
    check("ones_no_x_bits", rdata_o[0] === 16'hFFFF);

    if (fail_count == 0)
      $display("[TB_REAL] tc_sram all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] tc_sram FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #50000;
    $display("[TB_REAL] tc_sram FAILED - timeout");
    $finish;
  end
endmodule
