`timescale 1ns/1ps
`include "../audio_info_frame_original.sv"

// Test the TARGET: parameter declarations #( AUDIO_CHANNEL_COUNT, CHANNEL_ALLOCATION, DOWN_MIX_INHIBITED )
// We instantiate multiple instances with different parameter values and verify the outputs.

module audio_info_frame_target_tb;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  // --- Instance 0: defaults ---
  logic [23:0] hdr0;
  logic [55:0] sub0 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd1),
    .CHANNEL_ALLOCATION(8'h00),
    .DOWN_MIX_INHIBITED(1'b0)
  ) dut0 (.header(hdr0), .sub(sub0));

  // --- Instance 1: different channel count ---
  logic [23:0] hdr1;
  logic [55:0] sub1 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd3),
    .CHANNEL_ALLOCATION(8'h00),
    .DOWN_MIX_INHIBITED(1'b0)
  ) dut1 (.header(hdr1), .sub(sub1));

  // --- Instance 2: different channel allocation ---
  logic [23:0] hdr2;
  logic [55:0] sub2 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd1),
    .CHANNEL_ALLOCATION(8'h13),
    .DOWN_MIX_INHIBITED(1'b0)
  ) dut2 (.header(hdr2), .sub(sub2));

  // --- Instance 3: DOWN_MIX_INHIBITED set ---
  logic [23:0] hdr3;
  logic [55:0] sub3 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd1),
    .CHANNEL_ALLOCATION(8'h00),
    .DOWN_MIX_INHIBITED(1'b1)
  ) dut3 (.header(hdr3), .sub(sub3));

  // --- Instance 4: all non-default ---
  logic [23:0] hdr4;
  logic [55:0] sub4 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd7),
    .CHANNEL_ALLOCATION(8'hFF),
    .DOWN_MIX_INHIBITED(1'b1),
    .LEVEL_SHIFT_VALUE(4'd15),
    .LOW_FREQUENCY_EFFECTS_PLAYBACK_LEVEL(2'b11)
  ) dut4 (.header(hdr4), .sub(sub4));

  // --- Instance 5: channel count = 0 ---
  logic [23:0] hdr5;
  logic [55:0] sub5 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd0),
    .CHANNEL_ALLOCATION(8'h00),
    .DOWN_MIX_INHIBITED(1'b0)
  ) dut5 (.header(hdr5), .sub(sub5));

  // --- Instance 6: channel count max, allocation mid ---
  logic [23:0] hdr6;
  logic [55:0] sub6 [3:0];
  audio_info_frame #(
    .AUDIO_CHANNEL_COUNT(3'd5),
    .CHANNEL_ALLOCATION(8'hAB),
    .DOWN_MIX_INHIBITED(1'b1)
  ) dut6 (.header(hdr6), .sub(sub6));

  // Helper: compute expected header (constant for all instances)
  // LENGTH=10, VERSION=1, TYPE=4 -> header = {3'b0,5'd10, 8'd1, 1'b1,7'd4} = {8'h0a, 8'h01, 8'h84}
  localparam [23:0] EXPECTED_HEADER = 24'h0a0184;

  // Helper function: compute expected PB1
  function automatic [7:0] expected_pb1(input [2:0] acc);
    // {AUDIO_CODING_TYPE(4'd0), 1'b0, AUDIO_CHANNEL_COUNT}
    return {4'd0, 1'b0, acc};
  endfunction

  // Helper function: compute expected PB4 (channel allocation)
  function automatic [7:0] expected_pb4(input [7:0] ca);
    return ca;
  endfunction

  // Helper function: compute expected PB5
  function automatic [7:0] expected_pb5(input bit dmi, input [3:0] lsv, input [1:0] lfe);
    return {dmi, lsv, 1'b0, lfe};
  endfunction

  // Helper: compute checksum (PB0)
  // PB0 = 1 + ~(HB0 + HB1 + HB2 + PB1 + PB2 + PB3 + PB4 + PB5)
  // HB = header[7:0], header[15:8], header[23:16]
  function automatic [7:0] expected_checksum(input [7:0] pb1, input [7:0] pb4, input [7:0] pb5);
    logic [7:0] sum;
    sum = EXPECTED_HEADER[7:0] + EXPECTED_HEADER[15:8] + EXPECTED_HEADER[23:16] + pb1 + 8'd0 + 8'd0 + pb4 + pb5;
    return 8'd1 + ~sum;
  endfunction

  task automatic check_instance(
    input string name,
    input [23:0] hdr,
    input [55:0] s0, input [55:0] s1, input [55:0] s2, input [55:0] s3,
    input [2:0] acc, input [7:0] ca, input bit dmi, input [3:0] lsv, input [1:0] lfe
  );
    logic [7:0] pb1, pb4, pb5, pb0;
    pb1 = expected_pb1(acc);
    pb4 = expected_pb4(ca);
    pb5 = expected_pb5(dmi, lsv, lfe);
    pb0 = expected_checksum(pb1, pb4, pb5);

    // Test header
    total_tests++;
    if (hdr !== EXPECTED_HEADER) begin
      $display("FAIL %s: header expected %h got %h", name, EXPECTED_HEADER, hdr);
      fail_count++;
    end else pass_count++;

    // Test PB1 (AUDIO_CHANNEL_COUNT encoded)
    total_tests++;
    if (s0[15:8] !== pb1) begin
      $display("FAIL %s: PB1 expected %h got %h", name, pb1, s0[15:8]);
      fail_count++;
    end else pass_count++;

    // Test PB4 (CHANNEL_ALLOCATION)
    total_tests++;
    if (s0[39:32] !== pb4) begin
      $display("FAIL %s: PB4 expected %h got %h", name, pb4, s0[39:32]);
      fail_count++;
    end else pass_count++;

    // Test PB5 (DOWN_MIX_INHIBITED + LSV + LFE)
    total_tests++;
    if (s0[47:40] !== pb5) begin
      $display("FAIL %s: PB5 expected %h got %h", name, pb5, s0[47:40]);
      fail_count++;
    end else pass_count++;

    // Test PB0 (checksum)
    total_tests++;
    if (s0[7:0] !== pb0) begin
      $display("FAIL %s: PB0(checksum) expected %h got %h", name, pb0, s0[7:0]);
      fail_count++;
    end else pass_count++;

    // Test reserved sub-packets are zero
    total_tests++;
    if (s1 !== 56'd0 || s2 !== 56'd0 || s3 !== 56'd0) begin
      $display("FAIL %s: reserved subpackets not zero", name);
      fail_count++;
    end else pass_count++;

  endtask

  initial begin
    #1;

    // Instance 0: defaults (ACC=1, CA=0, DMI=0, LSV=0, LFE=0)
    check_instance("inst0_defaults", hdr0, sub0[0], sub0[1], sub0[2], sub0[3],
                    3'd1, 8'h00, 1'b0, 4'd0, 2'b00);

    // Instance 1: ACC=3
    check_instance("inst1_acc3", hdr1, sub1[0], sub1[1], sub1[2], sub1[3],
                    3'd3, 8'h00, 1'b0, 4'd0, 2'b00);

    // Instance 2: CA=0x13
    check_instance("inst2_ca13", hdr2, sub2[0], sub2[1], sub2[2], sub2[3],
                    3'd1, 8'h13, 1'b0, 4'd0, 2'b00);

    // Instance 3: DMI=1
    check_instance("inst3_dmi1", hdr3, sub3[0], sub3[1], sub3[2], sub3[3],
                    3'd1, 8'h00, 1'b1, 4'd0, 2'b00);

    // Instance 4: all non-default (ACC=7, CA=0xFF, DMI=1, LSV=15, LFE=3)
    check_instance("inst4_all", hdr4, sub4[0], sub4[1], sub4[2], sub4[3],
                    3'd7, 8'hFF, 1'b1, 4'd15, 2'b11);

    // Instance 5: ACC=0
    check_instance("inst5_acc0", hdr5, sub5[0], sub5[1], sub5[2], sub5[3],
                    3'd0, 8'h00, 1'b0, 4'd0, 2'b00);

    // Instance 6: ACC=5, CA=0xAB, DMI=1
    check_instance("inst6_mix", hdr6, sub6[0], sub6[1], sub6[2], sub6[3],
                    3'd5, 8'hAB, 1'b1, 4'd0, 2'b00);

    if (fail_count == 0)
      $display("[TB_REAL] audio_info_frame parameter declarations PASSED");
    else
      $display("[TB_REAL] audio_info_frame FAILED %0d / %0d tests", fail_count, total_tests);

    $finish;
  end
endmodule
