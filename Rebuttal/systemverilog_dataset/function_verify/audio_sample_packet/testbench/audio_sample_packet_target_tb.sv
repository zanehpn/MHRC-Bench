`timescale 1ns/1ps
`include "../audio_sample_packet_original.sv"

// Test the TARGET: the aligned_frame_counter calculation (else branch) and
// the header bit assignment for B (start of block) bits:
//   aligned_frame_counter[i] = 8'(frame_counter + i - CHANNEL_STATUS_LENGTH);  (when >= 192)
//   else aligned_frame_counter[i] = 8'(frame_counter + i);
//   header[23-(3-i)] = aligned_frame_counter[i] == 8'd0 && audio_sample_word_present[i];

module audio_sample_packet_target_tb;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  logic [7:0] frame_counter;
  logic [1:0] valid_bit [3:0];
  logic [1:0] user_data_bit [3:0];
  logic [23:0] audio_sample_word [3:0] [1:0];
  logic [3:0] audio_sample_word_present;
  logic [23:0] header;
  logic [55:0] sub [3:0];

  audio_sample_packet #(
    .SAMPLING_FREQUENCY(4'b0010),
    .WORD_LENGTH(4'b0101),
    .LAYOUT(1'b0)
  ) dut (
    .frame_counter(frame_counter),
    .valid_bit(valid_bit),
    .user_data_bit(user_data_bit),
    .audio_sample_word(audio_sample_word),
    .audio_sample_word_present(audio_sample_word_present),
    .header(header),
    .sub(sub)
  );

  task automatic check(input string name, input logic actual, input logic expected);
    total_tests++;
    if (actual !== expected) begin
      $display("FAIL %s: expected %b got %b", name, expected, actual);
      fail_count++;
    end else pass_count++;
  endtask

  task automatic check8(input string name, input [7:0] actual, input [7:0] expected);
    total_tests++;
    if (actual !== expected) begin
      $display("FAIL %s: expected %h got %h", name, expected, actual);
      fail_count++;
    end else pass_count++;
  endtask

  task automatic check4(input string name, input [3:0] actual, input [3:0] expected);
    total_tests++;
    if (actual !== expected) begin
      $display("FAIL %s: expected %b got %b", name, expected, actual);
      fail_count++;
    end else pass_count++;
  endtask

  integer i;
  initial begin
    // Initialize constant inputs
    for (i = 0; i < 4; i = i + 1) begin
      valid_bit[i] = 2'b00;
      user_data_bit[i] = 2'b00;
      audio_sample_word[i][0] = 24'hA00000 + i;
      audio_sample_word[i][1] = 24'hB00000 + i;
    end

    // =========================================================
    // Test 1: frame_counter = 0, all present
    // aligned_frame_counter[i] = i, so [0]=0 -> B bit set for sample 0
    // =========================================================
    frame_counter = 8'd0;
    audio_sample_word_present = 4'b1111;
    #1;
    // header[23:20] are B bits for samples 3,2,1,0 respectively
    // header[23-(3-i)] = header[20+i]
    // sample 0: aligned=0 && present -> header[20] = 1
    // sample 1: aligned=1 -> header[21] = 0
    // sample 2: aligned=2 -> header[22] = 0
    // sample 3: aligned=3 -> header[23] = 0
    check("T1_B_bit_sample0", header[20], 1'b1);
    check("T1_B_bit_sample1", header[21], 1'b0);
    check("T1_B_bit_sample2", header[22], 1'b0);
    check("T1_B_bit_sample3", header[23], 1'b0);
    // Present bits in header[11:8]
    check4("T1_present_bits", header[11:8], 4'b1111);
    // Layout
    check8("T1_layout", header[19:12], 8'h00);
    // Packet type
    check8("T1_pkt_type", header[7:0], 8'h02);

    // =========================================================
    // Test 2: frame_counter = 0, only sample 0 not present
    // B bit for sample 0 should be 0 (not present)
    // =========================================================
    audio_sample_word_present = 4'b1110;
    #1;
    check("T2_B_bit_sample0_not_present", header[20], 1'b0);
    check("T2_B_bit_sample1", header[21], 1'b0);

    // =========================================================
    // Test 3: frame_counter = 4, all present
    // aligned[i] = 4+i, none are 0 -> no B bits
    // =========================================================
    frame_counter = 8'd4;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T3_no_B_bits_fc4", header[23], 1'b0);
    check("T3_no_B_bits_fc4_s0", header[20], 1'b0);

    // =========================================================
    // Test 4: frame_counter = 188, all present
    // aligned[0]=188, [1]=189, [2]=190, [3]=191 -- all < 192
    // None are 0, so no B bits
    // =========================================================
    frame_counter = 8'd188;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T4_fc188_no_B", header[20], 1'b0);
    check("T4_fc188_no_B_s3", header[23], 1'b0);

    // =========================================================
    // Test 5: frame_counter = 189, all present
    // aligned[0]=189, [1]=190, [2]=191, [3]=192-192=0
    // sample 3 aligned=0 -> B bit set for sample 3
    // =========================================================
    frame_counter = 8'd189;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T5_fc189_B_sample3", header[23], 1'b1);
    check("T5_fc189_no_B_s0", header[20], 1'b0);
    check("T5_fc189_no_B_s1", header[21], 1'b0);
    check("T5_fc189_no_B_s2", header[22], 1'b0);

    // =========================================================
    // Test 6: frame_counter = 190, all present
    // aligned[0]=190, [1]=191, [2]=192-192=0, [3]=193-192=1
    // sample 2 aligned=0 -> B bit set for sample 2
    // =========================================================
    frame_counter = 8'd190;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T6_fc190_B_sample2", header[22], 1'b1);
    check("T6_fc190_no_B_s0", header[20], 1'b0);
    check("T6_fc190_no_B_s1", header[21], 1'b0);
    check("T6_fc190_no_B_s3", header[23], 1'b0);

    // =========================================================
    // Test 7: frame_counter = 191
    // aligned[0]=191, [1]=192-192=0, [2]=193-192=1, [3]=194-192=2
    // sample 1 aligned=0 -> B bit set for sample 1
    // =========================================================
    frame_counter = 8'd191;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T7_fc191_B_sample1", header[21], 1'b1);
    check("T7_fc191_no_B_s0", header[20], 1'b0);
    check("T7_fc191_no_B_s2", header[22], 1'b0);
    check("T7_fc191_no_B_s3", header[23], 1'b0);

    // =========================================================
    // Test 8: frame_counter = 192 (wraps to 0)
    // 8'(192) = 8'd192. 192+0=192 >= 192 -> aligned[0]=0
    // sample 0 aligned=0 -> B bit set
    // =========================================================
    frame_counter = 8'd192;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T8_fc192_B_sample0", header[20], 1'b1);
    check("T8_fc192_no_B_s1", header[21], 1'b0);

    // =========================================================
    // Test 9: frame_counter = 100, only some present
    // No B bits (none align to 0)
    // =========================================================
    frame_counter = 8'd100;
    audio_sample_word_present = 4'b0101;
    #1;
    check("T9_fc100_no_B", header[20], 1'b0);
    check4("T9_present_0101", header[11:8], 4'b0101);

    // =========================================================
    // Test 10: frame_counter = 189, sample 3 not present
    // aligned[3]=0 but not present -> B bit for sample 3 = 0
    // =========================================================
    frame_counter = 8'd189;
    audio_sample_word_present = 4'b0111;
    #1;
    check("T10_fc189_s3_not_present_no_B", header[23], 1'b0);

    // =========================================================
    // Test 11: Verify sub-packet packing for frame_counter = 0
    // =========================================================
    frame_counter = 8'd0;
    audio_sample_word_present = 4'b1111;
    audio_sample_word[0][0] = 24'h123456;
    audio_sample_word[0][1] = 24'h789ABC;
    #1;
    // sub[0][23:0] = audio_sample_word[0][0]
    // sub[0][47:24] = audio_sample_word[0][1]
    total_tests++;
    if (sub[0][23:0] !== 24'h123456) begin
      $display("FAIL T11_sub0_left: expected 123456 got %h", sub[0][23:0]);
      fail_count++;
    end else pass_count++;

    total_tests++;
    if (sub[0][47:24] !== 24'h789ABC) begin
      $display("FAIL T11_sub0_right: expected 789ABC got %h", sub[0][47:24]);
      fail_count++;
    end else pass_count++;

    // =========================================================
    // Test 12: frame_counter = 50, verify aligned_frame_counter normal path
    // aligned[0] = 50, nothing wraps
    // =========================================================
    frame_counter = 8'd50;
    audio_sample_word_present = 4'b1111;
    #1;
    check("T12_fc50_no_B_s0", header[20], 1'b0);
    check("T12_fc50_no_B_s1", header[21], 1'b0);
    check("T12_fc50_no_B_s2", header[22], 1'b0);
    check("T12_fc50_no_B_s3", header[23], 1'b0);

    if (fail_count == 0)
      $display("[TB_REAL] audio_sample_packet aligned_frame_counter and B-bit logic PASSED");
    else
      $display("[TB_REAL] audio_sample_packet FAILED %0d / %0d tests", fail_count, total_tests);

    $finish;
  end
endmodule
