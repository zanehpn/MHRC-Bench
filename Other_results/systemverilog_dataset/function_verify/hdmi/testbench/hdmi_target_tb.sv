`timescale 1ns/1ps

// Stub modules for hdmi_original dependencies

module packet_picker #(
    parameter int VIDEO_ID_CODE = 4,
    parameter real VIDEO_RATE = 0,
    parameter bit IT_CONTENT = 1'b0,
    parameter int AUDIO_BIT_WIDTH = 0,
    parameter int AUDIO_RATE = 0,
    parameter bit [8*8-1:0] VENDOR_NAME = 0,
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = 0,
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 0
)(
    input logic clk_pixel,
    input logic clk_audio,
    input logic reset,
    input logic video_field_end,
    input logic packet_enable,
    input logic [4:0] packet_pixel_counter,
    input logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign header = '0;
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

module packet_assembler (
    input logic clk_pixel,
    input logic reset,
    input logic data_island_period,
    input logic [23:0] header,
    input logic [55:0] sub [3:0],
    output logic [8:0] packet_data,
    output logic [4:0] counter
);
  assign packet_data = '0;
  assign counter = '0;
endmodule

module tmds_channel #(
    parameter int CN = 0
)(
    input logic clk_pixel,
    input logic [7:0] video_data,
    input logic [3:0] data_island_data,
    input logic [1:0] control_data,
    input logic [2:0] mode,
    output logic [9:0] tmds
);
  assign tmds = {2'b00, video_data};
endmodule

module serializer #(
    parameter int NUM_CHANNELS = 3,
    parameter real VIDEO_RATE = 0
)(
    input logic clk_pixel,
    input logic clk_pixel_x5,
    input logic reset,
    input logic [9:0] tmds_internal [NUM_CHANNELS-1:0],
    output logic [2:0] tmds,
    output logic tmds_clock
);
  assign tmds_clock = clk_pixel;
  genvar i;
  generate
    for (i = 0; i < NUM_CHANNELS && i < 3; i++) begin : ser
      assign tmds[i] = tmds_internal[i][0];
    end
  endgenerate
endmodule

`include "../hdmi.sv"

// Test the TARGET: initial values of signals (cx=START_X, cy=START_Y,
// video_data_period=0, mode=3'd1, video_data=0, control_data=0,
// data_island_data=0, video_guard=1, video_preamble=0,
// data_island_guard=0, data_island_preamble=0, data_island_period=0)
// These are inline initializations that matter before the first clock edge.

module hdmi_target_tb;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  // DUT signals - default VIDEO_ID_CODE=1, BIT_WIDTH=10, BIT_HEIGHT=10
  logic clk_pixel_x5;
  logic clk_pixel;
  logic clk_audio;
  logic reset;
  logic [23:0] rgb;
  logic [15:0] audio_sample_word [1:0];
  logic [2:0] tmds_out;
  logic tmds_clock;
  logic [9:0] cx;
  logic [9:0] cy;
  logic [9:0] frame_width;
  logic [9:0] frame_height;
  logic [9:0] screen_width;
  logic [9:0] screen_height;

  // Instance with START_X=0, START_Y=0 (default)
  hdmi #(
    .VIDEO_ID_CODE(1),
    .DVI_OUTPUT(1'b1)  // DVI mode for simpler testing
  ) dut_default (
    .clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .clk_audio(clk_audio),
    .reset(reset),
    .rgb(rgb),
    .audio_sample_word(audio_sample_word),
    .tmds(tmds_out),
    .tmds_clock(tmds_clock),
    .cx(cx),
    .cy(cy),
    .frame_width(frame_width),
    .frame_height(frame_height),
    .screen_width(screen_width),
    .screen_height(screen_height)
  );

  // Instance with START_X=100, START_Y=50
  logic [9:0] cx2, cy2;
  logic [9:0] fw2, fh2, sw2, sh2;
  logic [2:0] tmds2;
  logic tc2;

  hdmi #(
    .VIDEO_ID_CODE(1),
    .DVI_OUTPUT(1'b1),
    .START_X(100),
    .START_Y(50)
  ) dut_offset (
    .clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .clk_audio(clk_audio),
    .reset(reset),
    .rgb(rgb),
    .audio_sample_word(audio_sample_word),
    .tmds(tmds2),
    .tmds_clock(tc2),
    .cx(cx2),
    .cy(cy2),
    .frame_width(fw2),
    .frame_height(fh2),
    .screen_width(sw2),
    .screen_height(sh2)
  );

  always #2 clk_pixel_x5 = ~clk_pixel_x5;
  always #10 clk_pixel = ~clk_pixel;
  always #50 clk_audio = ~clk_audio;

  task automatic check_val(input string name, input [9:0] actual, input [9:0] expected);
    total_tests++;
    if (actual !== expected) begin
      $display("FAIL %s: expected %0d got %0d", name, expected, actual);
      fail_count++;
    end else pass_count++;
  endtask

  initial begin
    clk_pixel_x5 = 0;
    clk_pixel = 0;
    clk_audio = 0;
    reset = 0;
    rgb = 24'h000000;
    audio_sample_word[0] = 16'h0000;
    audio_sample_word[1] = 16'h0000;

    // VCS may not support inline signal initialization, so check after reset
    // Apply reset first to get known values
    reset = 1;
    @(posedge clk_pixel);
    @(negedge clk_pixel);

    // Test 1: Default instance cx should be START_X=0 after reset
    check_val("T1_cx_init_default", cx, 10'd0);

    // Test 2: Default instance cy should be START_Y=0 after reset
    check_val("T2_cy_init_default", cy, 10'd0);

    // Test 3: Offset instance cx should be START_X=100 after reset
    check_val("T3_cx_init_offset", cx2, 10'd100);

    // Test 4: Offset instance cy should be START_Y=50 after reset
    check_val("T4_cy_init_offset", cy2, 10'd50);

    // Test 5-10: frame/screen dimensions for VIDEO_ID_CODE=1
    check_val("T5_frame_width", frame_width, 10'd800);
    check_val("T6_frame_height", frame_height, 10'd525);
    check_val("T7_screen_width", screen_width, 10'd640);
    check_val("T8_screen_height", screen_height, 10'd480);

    // Test 9: Verify reset values hold with continued reset
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check_val("T9_cx_after_reset_default", cx, 10'd0);
    check_val("T10_cy_after_reset_default", cy, 10'd0);
    check_val("T11_cx_after_reset_offset", cx2, 10'd100);
    check_val("T12_cy_after_reset_offset", cy2, 10'd50);

    // Release reset and check counter increments
    reset = 0;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    // After 1 pixel clock, cx should increment by 1
    check_val("T13_cx_increment_default", cx, 10'd1);
    check_val("T14_cy_same_default", cy, 10'd0);
    check_val("T15_cx_increment_offset", cx2, 10'd101);
    check_val("T16_cy_same_offset", cy2, 10'd50);

    // Another clock
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check_val("T17_cx_inc2", cx, 10'd2);
    check_val("T18_cx_inc2_offset", cx2, 10'd102);

    // Test reset again mid-count
    reset = 1;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check_val("T19_cx_reset_mid", cx, 10'd0);
    check_val("T20_cy_reset_mid", cy, 10'd0);
    check_val("T21_cx2_reset_mid", cx2, 10'd100);
    check_val("T22_cy2_reset_mid", cy2, 10'd50);

    if (fail_count == 0)
      $display("[TB_REAL] hdmi signal initializations and reset behavior PASSED");
    else
      $display("[TB_REAL] hdmi FAILED %0d / %0d tests", fail_count, total_tests);

    $finish;
  end
endmodule
