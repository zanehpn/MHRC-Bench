`timescale 1ns/1ps
`include "../sha_padder_original.sv"

module sha_padder_target_tb;
  // TARGET: assign padded = {message, 1'b1, {zero_width{1'b0}}, {back_0_width{1'b0}}, MSG_SIZE};
  // This concatenates: message | 1-bit | zeros | 64-bit length field (with leading zeros + MSG_SIZE)

  // Test with default parameters: MSG_SIZE=24, PADDED_SIZE=512
  logic [23:0] message;
  logic [511:0] padded;

  sha_padder dut (
    .message(message),
    .padded(padded)
  );

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

  initial begin
    // Parameters: MSG_SIZE=24, PADDED_SIZE=512
    // zero_width = 512-24-1-64 = 423
    // back_0_width = 64-$bits(24) = 64-32 = 32
    // padded = {message[23:0], 1'b1, 423'b0, 32'b0, 32'd24}
    // = {message[23:0], 1'b1, 455'b0, 32'd24}

    // Test 1: message = "abc" = 0x616263
    message = 24'h616263;
    #10;
    check("msg_in_MSBs", padded[511:488] == 24'h616263);
    check("padding_bit", padded[487] == 1'b1);
    check("zeros_middle", padded[486:32] == '0);
    // The length field: back_0_width zeros then MSG_SIZE value
    // back_0_width = 64-32 = 32, so bits [63:32] should be 0, bits [31:0] = 24
    check("length_high", padded[63:32] == 32'd0);
    check("length_low", padded[31:0] == 32'd24);

    // Test 2: message = 0x000000 (all zeros)
    message = 24'h000000;
    #10;
    check("zero_msg_MSBs", padded[511:488] == 24'h000000);
    check("zero_msg_pad_bit", padded[487] == 1'b1);
    check("zero_msg_length", padded[31:0] == 32'd24);
    check("zero_msg_no_unknowns", !$isunknown(padded));

    // Test 3: message = 0xFFFFFF (all ones)
    message = 24'hFFFFFF;
    #10;
    check("ff_msg_MSBs", padded[511:488] == 24'hFFFFFF);
    check("ff_msg_pad_bit", padded[487] == 1'b1);
    check("ff_msg_zeros", padded[486:64] == '0);
    check("ff_msg_length", padded[31:0] == 32'd24);

    // Test 4: message = 0x800000 (MSB set)
    message = 24'h800000;
    #10;
    check("msb_msg", padded[511:488] == 24'h800000);
    check("msb_pad_bit", padded[487] == 1'b1);

    // Test 5: message = 0x000001 (LSB set)
    message = 24'h000001;
    #10;
    check("lsb_msg", padded[511:488] == 24'h000001);
    check("lsb_pad_bit", padded[487] == 1'b1);

    // Test 6: Alternating bits
    message = 24'hAAAAAA;
    #10;
    check("alt_msg", padded[511:488] == 24'hAAAAAA);

    // Test 7: 0x555555
    message = 24'h555555;
    #10;
    check("alt2_msg", padded[511:488] == 24'h555555);
    check("alt2_pad_bit", padded[487] == 1'b1);
    check("alt2_length", padded[31:0] == 32'd24);

    // Test 8: Full padded value check for "abc"
    message = 24'h616263;
    #10;
    begin
      logic [511:0] expected;
      expected = {24'h616263, 1'b1, 455'b0, 32'd24};
      check("full_abc_padded", padded == expected);
    end

    // Test 9: Random pattern 1
    message = 24'hDEADBE;
    #10;
    check("deadbe_msg", padded[511:488] == 24'hDEADBE);
    check("deadbe_no_x", !$isunknown(padded));

    // Test 10: Random pattern 2
    message = 24'hCAFE01;
    #10;
    check("cafe01_msg", padded[511:488] == 24'hCAFE01);
    check("cafe01_pad", padded[487] == 1'b1);
    check("cafe01_len", padded[31:0] == 32'd24);

    // Test 11: Verify the total padded size is exactly 512 bits
    // by checking no bits are X
    message = 24'h123456;
    #10;
    check("no_unknowns", !$isunknown(padded));

    // Test 12: Verify zero region is actually zero
    message = 24'hFEDCBA;
    #10;
    check("zero_region", padded[486:64] == '0);

    if (fail_count == 0)
      $display("[TB_REAL] sha_padder all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] sha_padder FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end
endmodule
