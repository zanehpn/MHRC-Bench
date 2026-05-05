`timescale 1ns/1ps
`include "../rgb565_original.sv"

module rgb565_target_tb;
  logic [7:0] image_data [3:0];
  logic image_data_enable;
  logic [15:0] rgb [1:0];
  logic rgb_enable;

  rgb565 dut(
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
  );

  integer err = 0;
  integer total_tests = 0;

  // The TARGET at line 6 is:
  //   );
  //   logic [31:0] unpacked_image_data;
  //   assign unpacked_image_data = {image_data[3], image_data[2], image_data[1], image_data[0]};
  //
  // This closes the port list and creates the unpacked_image_data wire from the
  // packed array, used to extract RGB565 fields.
  //
  // rgb[0] = {unpacked_image_data[15:11], unpacked_image_data[10:5], unpacked_image_data[4:0]}
  //         = {image_data[1][7:3], image_data[1][2:0],image_data[0][7:5], image_data[0][4:0]}
  //
  // rgb[1] = {unpacked_image_data[31:27], unpacked_image_data[26:21], unpacked_image_data[20:16]}
  //         = {image_data[3][7:3], image_data[3][2:0],image_data[2][7:5], image_data[2][4:0]}

  task check_rgb(
    input integer test_num,
    input [7:0] d0, d1, d2, d3,
    input enable
  );
    logic [31:0] unpacked;
    logic [15:0] exp_rgb0, exp_rgb1;

    image_data[0] = d0;
    image_data[1] = d1;
    image_data[2] = d2;
    image_data[3] = d3;
    image_data_enable = enable;
    #1;

    unpacked = {d3, d2, d1, d0};
    exp_rgb0 = {unpacked[15:11], unpacked[10:5], unpacked[4:0]};
    exp_rgb1 = {unpacked[31:27], unpacked[26:21], unpacked[20:16]};

    // Check unpacked_image_data
    total_tests = total_tests + 1;
    if (dut.unpacked_image_data !== unpacked) begin
      $display("ERROR: Test%0d unpacked=0x%08h expected=0x%08h", test_num, dut.unpacked_image_data, unpacked);
      err = err + 1;
    end

    // Check rgb[0]
    total_tests = total_tests + 1;
    if (rgb[0] !== exp_rgb0) begin
      $display("ERROR: Test%0d rgb[0]=0x%04h expected=0x%04h", test_num, rgb[0], exp_rgb0);
      err = err + 1;
    end

    // Check rgb[1]
    total_tests = total_tests + 1;
    if (rgb[1] !== exp_rgb1) begin
      $display("ERROR: Test%0d rgb[1]=0x%04h expected=0x%04h", test_num, rgb[1], exp_rgb1);
      err = err + 1;
    end

    // Check rgb_enable
    total_tests = total_tests + 1;
    if (rgb_enable !== enable) begin
      $display("ERROR: Test%0d rgb_enable=%b expected=%b", test_num, rgb_enable, enable);
      err = err + 1;
    end
  endtask

  initial begin
    // Test 1: All zeros
    check_rgb(1, 8'h00, 8'h00, 8'h00, 8'h00, 1'b1);

    // Test 2: All ones
    check_rgb(2, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 1'b1);

    // Test 3: Known pattern
    check_rgb(3, 8'h11, 8'h22, 8'h33, 8'h44, 1'b1);

    // Test 4: Byte ordering - only byte 0 has value
    check_rgb(4, 8'hAB, 8'h00, 8'h00, 8'h00, 1'b1);

    // Test 5: Only byte 1
    check_rgb(5, 8'h00, 8'hCD, 8'h00, 8'h00, 1'b1);

    // Test 6: Only byte 2
    check_rgb(6, 8'h00, 8'h00, 8'hEF, 8'h00, 1'b1);

    // Test 7: Only byte 3
    check_rgb(7, 8'h00, 8'h00, 8'h00, 8'h99, 1'b1);

    // Test 8: Enable low
    check_rgb(8, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 1'b0);

    // Test 9: Red only in pixel 0 (bits [15:11] of word 0 = image_data[1][7:3])
    // Set image_data[1] = 0xF8 (top 5 bits = 11111), rest 0
    check_rgb(9, 8'h00, 8'hF8, 8'h00, 8'h00, 1'b1);

    // Test 10: Green only in pixel 0 (bits [10:5] of word 0 = image_data[1][2:0],image_data[0][7:5])
    check_rgb(10, 8'hE0, 8'h07, 8'h00, 8'h00, 1'b1);

    // Test 11: Blue only in pixel 0 (bits [4:0] of word 0 = image_data[0][4:0])
    check_rgb(11, 8'h1F, 8'h00, 8'h00, 8'h00, 1'b1);

    // Test 12: Alternating bytes
    check_rgb(12, 8'hAA, 8'h55, 8'hAA, 8'h55, 1'b1);

    // Test 13: Another pattern
    check_rgb(13, 8'h12, 8'h34, 8'h56, 8'h78, 1'b1);

    // Test 14: Max values for each field
    check_rgb(14, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 1'b1);

    // Test 15: Specific RGB565 pure red pixel 0: R=31,G=0,B=0 => 0xF800
    // unpacked[15:0] = 0xF800 => image_data[1]=0xF8, image_data[0]=0x00
    check_rgb(15, 8'h00, 8'hF8, 8'h00, 8'h00, 1'b1);

    if (err == 0)
      $display("[TB_REAL] rgb565 all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] rgb565 FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end
endmodule
