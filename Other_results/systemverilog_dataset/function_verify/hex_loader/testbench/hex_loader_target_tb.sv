`timescale 1ns/1ps

// Stub for the data_loader_8 sub-module used inside hex_loader
module data_loader_8 #(
  parameter [3:0] ADDRESS_MASK_UPPER_4 = 4'h0
)(
  input wire clk_74a,
  input wire bridge_wr,
  input wire bridge_endian_little,
  input wire [31:0] bridge_addr,
  input wire [31:0] bridge_wr_data,
  output reg write_en,
  output reg [14:0] write_addr,
  output reg [7:0] write_data
);
  // Simple pass-through: on bridge_wr, forward byte data
  reg bridge_wr_d;

  always @(posedge clk_74a) begin
    bridge_wr_d <= bridge_wr;
    write_en <= 0;
    if (bridge_wr && !bridge_wr_d) begin
      write_en <= 1;
      write_addr <= bridge_addr[14:0];
      write_data <= bridge_wr_data[7:0];
    end
  end
endmodule

`include "../hex_loader_original.v"

module hex_loader_target_tb;

  logic clk_74a, reset_n;
  logic bridge_wr, bridge_endian_little;
  logic [31:0] bridge_addr;
  logic [31:0] bridge_wr_data;
  wire write_en;
  wire [14:0] write_addr;
  wire [7:0] write_data;

  hex_loader dut (
    .clk_74a(clk_74a),
    .reset_n(reset_n),
    .bridge_wr(bridge_wr),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),
    .write_en(write_en),
    .write_addr(write_addr),
    .write_data(write_data)
  );

  initial clk_74a = 0;
  always #6.75 clk_74a = ~clk_74a;

  integer err = 0;
  integer total_tests = 0;

  // Task to send one byte through the bridge
  task send_byte(input [7:0] data);
    @(posedge clk_74a);
    bridge_wr = 1;
    bridge_wr_data = {24'b0, data};
    bridge_addr = bridge_addr + 1;
    @(posedge clk_74a);
    bridge_wr = 0;
    @(posedge clk_74a);
    @(posedge clk_74a);
  endtask

  // Task to send a full hex record and check outputs
  // hex record: :LLAAAATT[DD...]CC
  // We send ASCII chars one by one
  // byte_count: number of data bytes
  // base_addr: 16-bit address
  // rec_type: record type (00=data)
  // data_bytes: array of data bytes to write
  task send_hex_record(
    input [7:0] byte_count,
    input [15:0] base_addr,
    input [7:0] rec_type,
    input [7:0] data_bytes [0:15]
  );
    integer i;
    // Send ":"
    send_byte(8'h3A);
    // Send byte count as two hex nibbles
    send_byte(nibble_to_ascii(byte_count[7:4]));
    send_byte(nibble_to_ascii(byte_count[3:0]));
    // Send address as four hex nibbles
    send_byte(nibble_to_ascii(base_addr[15:12]));
    send_byte(nibble_to_ascii(base_addr[11:8]));
    send_byte(nibble_to_ascii(base_addr[7:4]));
    send_byte(nibble_to_ascii(base_addr[3:0]));
    // Send record type
    send_byte(nibble_to_ascii(rec_type[7:4]));
    send_byte(nibble_to_ascii(rec_type[3:0]));
    // Send data bytes (each as 2 hex nibbles)
    for (i = 0; i < byte_count; i = i + 1) begin
      send_byte(nibble_to_ascii(data_bytes[i][7:4]));
      send_byte(nibble_to_ascii(data_bytes[i][3:0]));
    end
    // Send dummy checksum (2 nibbles) to transition FSM out of data mode
    // When line_byte_count reaches 0, the next apf_write_en at index 9
    // triggers hex_nibble_index <= 0. Then the checksum nibble is consumed at
    // index 0 (not a colon, so FSM stays at 0 waiting for next ':').
    send_byte(8'h30); // dummy checksum high nibble '0'
    send_byte(8'h30); // dummy checksum low nibble '0'
  endtask

  function [7:0] nibble_to_ascii(input [3:0] nibble);
    if (nibble < 4'hA)
      nibble_to_ascii = 8'h30 + nibble;
    else
      nibble_to_ascii = 8'h37 + nibble; // 'A' = 0x41, 0x41 - 0xA = 0x37
  endfunction

  // Monitor write_en to capture writes
  integer wr_count;
  reg [14:0] captured_addr [0:31];
  reg [7:0]  captured_data [0:31];

  always @(posedge clk_74a) begin
    if (write_en) begin
      captured_addr[wr_count] = write_addr;
      captured_data[wr_count] = write_data;
      wr_count = wr_count + 1;
    end
  end

  task check_write(input integer idx, input [14:0] exp_addr, input [7:0] exp_data);
    total_tests = total_tests + 1;
    if (captured_addr[idx] !== exp_addr) begin
      $display("ERROR: write[%0d] addr=0x%04h, expected=0x%04h", idx, captured_addr[idx], exp_addr);
      err = err + 1;
    end
    if (captured_data[idx] !== exp_data) begin
      $display("ERROR: write[%0d] data=0x%02h, expected=0x%02h", idx, captured_data[idx], exp_data);
      err = err + 1;
    end
  endtask

  reg [7:0] test_data [0:15];
  integer i;

  initial begin
    reset_n = 0;
    bridge_wr = 0;
    bridge_endian_little = 0;
    bridge_addr = 0;
    bridge_wr_data = 0;
    wr_count = 0;

    repeat(4) @(posedge clk_74a);
    reset_n = 1;
    repeat(4) @(posedge clk_74a);

    // =========================================================
    // Test 1: Record at address 0x0000 with 2 data bytes
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'hAB;
    test_data[1] = 8'hCD;
    send_hex_record(8'h02, 16'h0000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 2) begin
      $display("ERROR: Test1 expected 2 writes, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h0000, 8'hAB);
      check_write(1, 15'h0001, 8'hCD);
    end

    // =========================================================
    // Test 2: Record at address 0x1000 - tests addr[15:12] (the TARGET)
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'h11;
    test_data[1] = 8'h22;
    test_data[2] = 8'h33;
    send_hex_record(8'h03, 16'h1000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 3) begin
      $display("ERROR: Test2 expected 3 writes, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h1000, 8'h11);
      check_write(1, 15'h1001, 8'h22);
      check_write(2, 15'h1002, 8'h33);
    end

    // =========================================================
    // Test 3: Record at address 0x2345 - tests all address nibbles
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'hFF;
    send_hex_record(8'h01, 16'h2345, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test3 expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h2345, 8'hFF);
    end

    // =========================================================
    // Test 4: Record at address 0xA000 - letter 'A' in upper nibble
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'h55;
    send_hex_record(8'h01, 16'hA000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test4 expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      // Note: addr is 15-bit, so 0xA000 & 0x7FFF = 0x2000
      check_write(0, 15'h2000, 8'h55);
    end

    // =========================================================
    // Test 5: Record at address 0xF000 - letter 'F' in upper nibble
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'hAA;
    send_hex_record(8'h01, 16'hF000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test5 expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h7000, 8'hAA);
    end

    // =========================================================
    // Test 6: Record at address 0xBCDE
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'h99;
    test_data[1] = 8'h88;
    send_hex_record(8'h02, 16'hBCDE, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 2) begin
      $display("ERROR: Test6 expected 2 writes, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h3CDE, 8'h99);
      check_write(1, 15'h3CDF, 8'h88);
    end

    // =========================================================
    // Test 7: Record at address 0x5678 with 4 bytes
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'h01;
    test_data[1] = 8'h02;
    test_data[2] = 8'h03;
    test_data[3] = 8'h04;
    send_hex_record(8'h04, 16'h5678, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 4) begin
      $display("ERROR: Test7 expected 4 writes, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h5678, 8'h01);
      check_write(1, 15'h5679, 8'h02);
      check_write(2, 15'h567A, 8'h03);
      check_write(3, 15'h567B, 8'h04);
    end

    // =========================================================
    // Test 8: Record at address 0x7FFF (max 15-bit)
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'hDE;
    send_hex_record(8'h01, 16'h7FFF, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test8 expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h7FFF, 8'hDE);
    end

    // =========================================================
    // Test 9: Two consecutive records
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'h10;
    send_hex_record(8'h01, 16'h3000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test9a expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h3000, 8'h10);
    end

    wr_count = 0;
    test_data[0] = 8'h20;
    send_hex_record(8'h01, 16'h4000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test9b expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h4000, 8'h20);
    end

    // =========================================================
    // Test 10: Address 0xD000 - upper nibble D
    // =========================================================
    wr_count = 0;
    test_data[0] = 8'hBB;
    send_hex_record(8'h01, 16'hD000, 8'h00, test_data);
    repeat(10) @(posedge clk_74a);

    total_tests = total_tests + 1;
    if (wr_count !== 1) begin
      $display("ERROR: Test10 expected 1 write, got %0d", wr_count);
      err = err + 1;
    end else begin
      check_write(0, 15'h5000, 8'hBB);
    end

    // Final report
    if (err == 0)
      $display("[TB_REAL] hex_loader all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] hex_loader FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end

  // Timeout
  initial begin
    #5000000;
    $display("[TB_REAL] hex_loader FAILED 1 / 1 tests");
    $finish;
  end

endmodule
