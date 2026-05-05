`timescale 1ns/1ps
`include "../tmds_channel_original.sv"

// Test the TARGET: TERC4 lookup table entries for 4'b1001 through 4'b1100
// These are the 4 missing entries in the tmds_channel.sv <TARGET> section.
// We also test all 16 TERC4 entries to ensure completeness.

module tmds_channel_target_tb;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  logic clk_pixel;
  logic [7:0] video_data;
  logic [3:0] data_island_data;
  logic [1:0] control_data;
  logic [2:0] mode;
  logic [9:0] tmds;

  tmds_channel #(.CN(0)) dut (
    .clk_pixel(clk_pixel),
    .video_data(video_data),
    .data_island_data(data_island_data),
    .control_data(control_data),
    .mode(mode),
    .tmds(tmds)
  );

  always #5 clk_pixel = ~clk_pixel;

  // Expected TERC4 coding table (Section 5.4.3 of HDMI 1.4a spec)
  logic [9:0] expected_terc4 [15:0];
  initial begin
    expected_terc4[4'b0000] = 10'b1010011100;
    expected_terc4[4'b0001] = 10'b1001100011;
    expected_terc4[4'b0010] = 10'b1011100100;
    expected_terc4[4'b0011] = 10'b1011100010;
    expected_terc4[4'b0100] = 10'b0101110001;
    expected_terc4[4'b0101] = 10'b0100011110;
    expected_terc4[4'b0110] = 10'b0110001110;
    expected_terc4[4'b0111] = 10'b0100111100;
    expected_terc4[4'b1000] = 10'b1011001100;
    expected_terc4[4'b1001] = 10'b0100111001;  // TARGET entry 1
    expected_terc4[4'b1010] = 10'b0110011100;  // TARGET entry 2
    expected_terc4[4'b1011] = 10'b1011000110;  // TARGET entry 3
    expected_terc4[4'b1100] = 10'b1010001110;  // TARGET entry 4
    expected_terc4[4'b1101] = 10'b1001110001;
    expected_terc4[4'b1110] = 10'b0101100011;
    expected_terc4[4'b1111] = 10'b1011000011;
  end

  task automatic check_terc4(input [3:0] din, input [9:0] expected);
    total_tests++;
    if (tmds !== expected) begin
      $display("FAIL TERC4[%b]: expected %b got %b", din, expected, tmds);
      fail_count++;
    end else pass_count++;
  endtask

  task automatic check10(input string name, input [9:0] actual, input [9:0] expected);
    total_tests++;
    if (actual !== expected) begin
      $display("FAIL %s: expected %b got %b", name, expected, actual);
      fail_count++;
    end else pass_count++;
  endtask

  integer idx;
  initial begin
    clk_pixel = 0;
    video_data = 8'h00;
    data_island_data = 4'h0;
    control_data = 2'b00;
    mode = 3'd3; // Data island mode -> TERC4 encoding

    // Wait for initial values to settle
    @(posedge clk_pixel);
    @(negedge clk_pixel);

    // =========================================================
    // Test all 16 TERC4 entries (focus on 4'b1001 - 4'b1100 which are TARGET)
    // =========================================================
    for (idx = 0; idx < 16; idx = idx + 1) begin
      data_island_data = idx[3:0];
      @(posedge clk_pixel);
      @(negedge clk_pixel);
      check_terc4(idx[3:0], expected_terc4[idx]);
    end

    // =========================================================
    // Additional targeted tests for the 4 TARGET entries
    // Run them again individually to make sure they're solid
    // =========================================================

    // TERC4 4'b1001 = 10'b0100111001
    data_island_data = 4'b1001;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("TERC4_1001_recheck", tmds, 10'b0100111001);

    // TERC4 4'b1010 = 10'b0110011100
    data_island_data = 4'b1010;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("TERC4_1010_recheck", tmds, 10'b0110011100);

    // TERC4 4'b1011 = 10'b1011000110
    data_island_data = 4'b1011;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("TERC4_1011_recheck", tmds, 10'b1011000110);

    // TERC4 4'b1100 = 10'b1010001110
    data_island_data = 4'b1100;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("TERC4_1100_recheck", tmds, 10'b1010001110);

    // =========================================================
    // Test control coding mode (mode=0) to verify mode switching works
    // =========================================================
    mode = 3'd0;
    control_data = 2'b00;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("control_00", tmds, 10'b1101010100);

    control_data = 2'b01;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("control_01", tmds, 10'b0010101011);

    control_data = 2'b10;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("control_10", tmds, 10'b0101010100);

    control_data = 2'b11;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("control_11", tmds, 10'b1010101011);

    // =========================================================
    // Test video guard band mode (mode=2) for CN=0
    // =========================================================
    mode = 3'd2;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("video_guard_CN0", tmds, 10'b1011001100);

    // =========================================================
    // Switch back to TERC4 and re-verify a TARGET entry
    // =========================================================
    mode = 3'd3;
    data_island_data = 4'b1001;
    @(posedge clk_pixel);
    @(negedge clk_pixel);
    check10("TERC4_1001_after_mode_switch", tmds, 10'b0100111001);

    if (fail_count == 0)
      $display("[TB_REAL] tmds_channel TERC4 encoding table PASSED");
    else
      $display("[TB_REAL] tmds_channel FAILED %0d / %0d tests", fail_count, total_tests);

    $finish;
  end
endmodule
