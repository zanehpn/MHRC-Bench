`timescale 1ns/1ps

module audio_clock_regeneration_packet #(
    parameter real VIDEO_RATE = 0,
    parameter int AUDIO_RATE = 0
)(
    input logic clk_pixel,
    input logic clk_audio,
    output logic clk_audio_counter_wrap,
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign clk_audio_counter_wrap = 1'b0;
  assign header = {8'h00, 8'h00, 8'h01};
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

module audio_sample_packet #(
    parameter bit [3:0] SAMPLING_FREQUENCY = 4'b0000,
    parameter bit [3:0] WORD_LENGTH = 4'b0000
)(
    input logic [7:0] frame_counter,
    input logic [1:0] valid_bit [3:0],
    input logic [1:0] user_data_bit [3:0],
    input logic [23:0] audio_sample_word [3:0] [1:0],
    input logic [3:0] audio_sample_word_present,
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign header = {8'h00, 8'h00, 8'h02};
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

module auxiliary_video_information_info_frame #(
    parameter bit [6:0] VIDEO_ID_CODE = 7'd0,
    parameter bit IT_CONTENT = 1'b0
)(
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign header = {8'h00, 8'h00, 8'h82};
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

module source_product_description_info_frame #(
    parameter bit [8*8-1:0] VENDOR_NAME = 0,
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = 0,
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 0
)(
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign header = {8'h00, 8'h00, 8'h83};
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

module audio_info_frame (
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
  assign header = {8'h00, 8'h00, 8'h84};
  assign sub[0] = '0; assign sub[1] = '0; assign sub[2] = '0; assign sub[3] = '0;
endmodule

`include "../packet_picker_original.sv"

module packet_picker_target_tb;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  logic clk_pixel;
  logic clk_audio;
  logic reset;
  logic video_field_end;
  logic packet_enable;
  logic [4:0] packet_pixel_counter;
  logic [15:0] audio_sample_word [1:0];
  logic [23:0] header;
  logic [55:0] sub [3:0];

  packet_picker #(
    .VIDEO_ID_CODE(1),
    .AUDIO_BIT_WIDTH(16),
    .AUDIO_RATE(44100)
  ) dut (
    .clk_pixel(clk_pixel),
    .clk_audio(clk_audio),
    .reset(reset),
    .video_field_end(video_field_end),
    .packet_enable(packet_enable),
    .packet_pixel_counter(packet_pixel_counter),
    .audio_sample_word(audio_sample_word),
    .header(header),
    .sub(sub)
  );

  always #5 clk_pixel = ~clk_pixel;
  always #50 clk_audio = ~clk_audio;

  task check8;
    input integer test_id;
    input [7:0] actual;
    input [7:0] expected;
    total_tests = total_tests + 1;
    if (actual !== expected) begin
      $display("FAIL T%0d: expected %h got %h", test_id, expected, actual);
      fail_count = fail_count + 1;
    end else begin
      pass_count = pass_count + 1;
    end
  endtask

  // Empirically determined: after reading the DUT packet_type at the #1 point
  // after a posedge, the value shown reflects the JUST-COMPUTED packet_type
  // from this very edge. So with packet_enable=1:
  //   Edge 1 after reset: ptype=0x84 computed, audio_info_frame_sent set to 1
  //     But at #1, ptype shows the RESULT of this edge = 0x82 (NEXT priority)
  //     Wait no - ptype is 0x84 because that's what was assigned this edge.
  //     The assignment `audio_info_frame_sent <= 1` is NBA, so it's set at end of edge.
  //     The assignment `packet_type <= 0x84` is also NBA.
  //     After NBA: packet_type = 0x84, audio_info_frame_sent = 1.
  //     At #1: header = headers[0x84] which is 0x84.
  //
  // But empirically we see ptype=0x82 at the first #1 after reset=0+packet_enable=1.
  // This suggests that the DUT already processed TWO edges with packet_enable=1.
  //
  // The likely reason: VCS processes the repeat(3) @(posedge clk_pixel) and
  // then the TB code `reset=0; packet_enable=1;` runs. But the 3rd @(posedge)
  // returns DURING the posedge event. The always_ff in the DUT hasn't executed
  // yet for this posedge (or has, depending on scheduling). If the TB code
  // runs BEFORE the DUT's always_ff, then on this 3rd posedge, the DUT sees
  // reset=0 and packet_enable=1 (since the TB just set them).
  // Then on the 4th posedge, it's the second edge with packet_enable=1.
  //
  // To handle this, let me set reset=0 and packet_enable=1 on the NEGEDGE,
  // ensuring they're stable before the next posedge.

  initial begin
    clk_pixel = 0;
    clk_audio = 0;
    reset = 1;
    video_field_end = 0;
    packet_enable = 0;
    packet_pixel_counter = 5'd0;
    audio_sample_word[0] = 16'h0000;
    audio_sample_word[1] = 16'h0000;

    // Hold reset for 3 posedge cycles
    repeat (3) @(posedge clk_pixel);
    // Change signals on negedge to avoid race
    @(negedge clk_pixel);
    reset = 0;
    packet_enable = 1;

    // Phase 1: First edge with reset=0, packet_enable=1
    // The DUT will set packet_type on each posedge.
    // After posedge + NBA + #1, packet_type reflects the new computation.
    @(posedge clk_pixel); #1;
    check8(1, header[7:0], 8'h84);

    @(posedge clk_pixel); #1;
    check8(2, header[7:0], 8'h82);

    @(posedge clk_pixel); #1;
    check8(3, header[7:0], 8'h83);

    @(posedge clk_pixel); #1;
    check8(4, header[7:0], 8'h00);

    // Phase 2: video_field_end - set on negedge to avoid race
    @(negedge clk_pixel);
    video_field_end = 1;
    @(posedge clk_pixel); // DUT: video_field_end=1 -> clear flags
    @(negedge clk_pixel);
    video_field_end = 0;

    @(posedge clk_pixel); #1;
    check8(5, header[7:0], 8'h84);

    @(posedge clk_pixel); #1;
    check8(6, header[7:0], 8'h82);

    @(posedge clk_pixel); #1;
    check8(7, header[7:0], 8'h83);

    @(posedge clk_pixel); #1;
    check8(8, header[7:0], 8'h00);

    // Phase 3: Reset
    @(negedge clk_pixel);
    reset = 1;
    @(posedge clk_pixel); // DUT: reset=1 -> clear flags
    @(negedge clk_pixel);
    reset = 0;

    @(posedge clk_pixel); #1;
    check8(9, header[7:0], 8'h84);

    @(posedge clk_pixel); #1;
    check8(10, header[7:0], 8'h82);

    @(posedge clk_pixel); #1;
    check8(11, header[7:0], 8'h83);

    @(posedge clk_pixel); #1;
    check8(12, header[7:0], 8'h00);

    // Phase 4: Another video_field_end
    @(negedge clk_pixel);
    video_field_end = 1;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    video_field_end = 0;

    @(posedge clk_pixel); #1;
    check8(13, header[7:0], 8'h84);

    @(posedge clk_pixel); #1;
    check8(14, header[7:0], 8'h82);

    @(posedge clk_pixel); #1;
    check8(15, header[7:0], 8'h83);

    @(posedge clk_pixel); #1;
    check8(16, header[7:0], 8'h00);

    // Phase 5: packet_enable toggle
    @(negedge clk_pixel);
    packet_enable = 0;
    repeat(2) @(posedge clk_pixel);
    @(negedge clk_pixel);
    packet_enable = 1;
    video_field_end = 1;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    video_field_end = 0;

    @(posedge clk_pixel); #1;
    check8(17, header[7:0], 8'h84);

    if (fail_count == 0)
      $display("[TB_REAL] packet_picker reset/video_field_end flag clearing PASSED");
    else
      $display("[TB_REAL] packet_picker FAILED %0d / %0d tests", fail_count, total_tests);

    $finish;
  end
endmodule
