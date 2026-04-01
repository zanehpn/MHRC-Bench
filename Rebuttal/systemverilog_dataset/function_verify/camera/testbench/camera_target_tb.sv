`timescale 1ns/1ps

// Stub for d_phy_receiver submodule
// data and enable are regs driven by continuous assigns from module-level regs
module d_phy_receiver #(
    parameter int ZERO_ACCUMULATOR_WIDTH = 3
) (
    input  logic clock_p,
    input  logic data_p,
    input  logic reset,
    output logic [7:0] data,
    output logic enable
);
    // Outputs driven by assign from wrapper - no initial needed
endmodule

`include "../camera_original.sv"

// Wrapper that provides direct access to internal signals
module camera_wrapper #(
    parameter int NUM_LANES = 2,
    parameter int ZERO_ACCUMULATOR_WIDTH = 3
) (
    input logic clock_p,
    input logic [NUM_LANES-1:0] data_p,
    // Testbench drive signals
    input logic [7:0] tb_data0,
    input logic [7:0] tb_data1,
    input logic tb_en0,
    input logic tb_en1,
    // Outputs
    output logic [1:0] virtual_channel,
    output logic [15:0] word_count,
    output logic interrupt,
    output logic [7:0] image_data [3:0],
    output logic [5:0] image_data_type,
    output logic image_data_enable,
    output logic frame_start,
    output logic frame_end,
    output logic line_start,
    output logic line_end,
    output logic generic_short_data_enable,
    output logic [15:0] generic_short_data
);

    camera #(
        .NUM_LANES(NUM_LANES),
        .ZERO_ACCUMULATOR_WIDTH(ZERO_ACCUMULATOR_WIDTH)
    ) cam_inst (
        .clock_p(clock_p),
        .data_p(data_p),
        .virtual_channel(virtual_channel),
        .word_count(word_count),
        .interrupt(interrupt),
        .image_data(image_data),
        .image_data_type(image_data_type),
        .image_data_enable(image_data_enable),
        .frame_start(frame_start),
        .frame_end(frame_end),
        .line_start(line_start),
        .line_end(line_end),
        .generic_short_data_enable(generic_short_data_enable),
        .generic_short_data(generic_short_data)
    );

    // Drive the stub outputs using assign
    assign cam_inst.lane_receivers[0].d_phy_receiver.data = tb_data0;
    assign cam_inst.lane_receivers[0].d_phy_receiver.enable = tb_en0;
    assign cam_inst.lane_receivers[1].d_phy_receiver.data = tb_data1;
    assign cam_inst.lane_receivers[1].d_phy_receiver.enable = tb_en1;

endmodule

module camera_target_tb;

  localparam NUM_LANES = 2;
  localparam ZERO_ACCUMULATOR_WIDTH = 3;

  logic clock_p;
  logic [NUM_LANES-1:0] data_p;

  // TB drive signals
  logic [7:0] tb_data0, tb_data1;
  logic tb_en0, tb_en1;

  wire [1:0] virtual_channel;
  wire [15:0] word_count;
  wire interrupt;
  wire [7:0] image_data [3:0];
  wire [5:0] image_data_type;
  wire image_data_enable;
  wire frame_start, frame_end, line_start, line_end;
  wire generic_short_data_enable;
  wire [15:0] generic_short_data;

  camera_wrapper #(
    .NUM_LANES(NUM_LANES),
    .ZERO_ACCUMULATOR_WIDTH(ZERO_ACCUMULATOR_WIDTH)
  ) dut (
    .clock_p(clock_p),
    .data_p(data_p),
    .tb_data0(tb_data0),
    .tb_data1(tb_data1),
    .tb_en0(tb_en0),
    .tb_en1(tb_en1),
    .virtual_channel(virtual_channel),
    .word_count(word_count),
    .interrupt(interrupt),
    .image_data(image_data),
    .image_data_type(image_data_type),
    .image_data_enable(image_data_enable),
    .frame_start(frame_start),
    .frame_end(frame_end),
    .line_start(line_start),
    .line_end(line_end),
    .generic_short_data_enable(generic_short_data_enable),
    .generic_short_data(generic_short_data)
  );

  always #5 clock_p = ~clock_p;

  integer pass_count, fail_count, total_tests;

  task check;
    input integer test_id;
    input logic cond;
    total_tests = total_tests + 1;
    if (cond) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("FAIL: test %0d (dt=%0d, fs=%b, fe=%b, ls=%b, le=%b, vc=%b, wc=%h)",
               test_id, image_data_type, frame_start, frame_end, line_start, line_end,
               virtual_channel, word_count);
    end
  endtask

  task send_short_and_wait;
    input [5:0] dt;
    input [1:0] vc;
    input [7:0] data0;
    input [7:0] data1;
    input [7:0] ecc;

    // Drive header bytes 0,1 before posedge
    @(negedge clock_p);
    tb_data0 = {vc, dt};
    tb_data1 = data0;
    tb_en0 = 1'b1;
    tb_en1 = 1'b1;
    @(posedge clock_p); // Header bytes 0,1 processed

    // Drive header bytes 2,3
    @(negedge clock_p);
    tb_data0 = data1;
    tb_data1 = ecc;
    @(posedge clock_p); // Header bytes 2,3 processed

    // Disable lanes
    @(negedge clock_p);
    tb_data0 = 8'd0;
    tb_data1 = 8'd0;
    tb_en0 = 1'b0;
    tb_en1 = 1'b0;

    // Wait for DUT reset cycle
    repeat(5) @(posedge clock_p);
    #1;
  endtask

  initial begin
    clock_p = 0;
    data_p = '0;
    pass_count = 0;
    fail_count = 0;
    total_tests = 0;

    tb_data0 = 8'd0;
    tb_data1 = 8'd0;
    tb_en0 = 1'b0;
    tb_en1 = 1'b0;

    repeat (5) @(posedge clock_p); #1;

    // Test 1-3: frame_start (dt=0, vc=0)
    send_short_and_wait(6'd0, 2'b00, 8'h00, 8'h00, 8'h00);
    check(1, image_data_type == 6'd0);
    check(2, frame_start == 1'b1);
    check(3, frame_end == 1'b0);

    // Test 4-5: frame_end (dt=1, vc=0)
    send_short_and_wait(6'd1, 2'b00, 8'h00, 8'h00, 8'h00);
    check(4, frame_end == 1'b1);
    check(5, frame_start == 1'b0);

    // Test 6-7: line_start (dt=2)
    send_short_and_wait(6'd2, 2'b00, 8'h00, 8'h00, 8'h00);
    check(6, line_start == 1'b1);
    check(7, line_end == 1'b0);

    // Test 8-9: line_end (dt=3)
    send_short_and_wait(6'd3, 2'b00, 8'h00, 8'h00, 8'h00);
    check(8, line_end == 1'b1);
    check(9, line_start == 1'b0);

    // Test 10: vc=3 (dt=0)
    send_short_and_wait(6'd0, 2'b11, 8'h00, 8'h00, 8'h00);
    check(10, virtual_channel == 2'b11);

    // Test 11: vc=1 (dt=1)
    send_short_and_wait(6'd1, 2'b01, 8'h00, 8'h00, 8'h00);
    check(11, virtual_channel == 2'b01);

    // Test 12: word_count (dt=8)
    send_short_and_wait(6'd8, 2'b00, 8'hAB, 8'hCD, 8'h00);
    check(12, word_count == 16'hCDAB);

    // Test 13-14: vc=2 frame_start
    send_short_and_wait(6'd0, 2'b10, 8'h00, 8'h00, 8'h00);
    check(13, virtual_channel == 2'b10);
    check(14, frame_start == 1'b1);

    if (fail_count == 0)
      $display("[TB_REAL] camera all %0d / %0d tests PASSED", pass_count, pass_count);
    else
      $display("[TB_REAL] camera FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #200000;
    $display("[TB_REAL] camera FAILED - timeout");
    $finish;
  end
endmodule
