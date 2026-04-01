`timescale 1ns/1ps
`include "../shifter_original.sv"

module shifter_target_tb;
  // TARGET: the else branch when ram_select==1 writes to ram_pong,
  // plus write address increment, ram_select toggle, and rd_addr reset.
  //
  // Wrong code only has: ram_pong[ram_wr_addr] <= i_data;
  // Missing: ram_wr_addr increment, ram_select toggle, rd_addr reset.
  // With wrong code, all pong writes go to pong[0] and ram_select never toggles back.

  localparam DATA_WIDTH = 8;
  localparam RAM_SIZE   = 4;

  logic clk, rst, up, down, i_valid;
  logic [DATA_WIDTH-1:0] i_data, o_data;
  logic o_valid;

  shifter #(.DATA_WIDTH(DATA_WIDTH), .RAM_SIZE(RAM_SIZE)) dut (
    .clk(clk), .rst(rst), .up(up), .down(down),
    .i_valid(i_valid), .i_data(i_data),
    .o_valid(o_valid), .o_data(o_data)
  );

  always #5 clk = ~clk;

  integer pass_count = 0;
  integer fail_count = 0;
  integer total_tests = 0;

  task automatic check(input string name, input logic cond);
    total_tests++;
    if (cond) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  task automatic push_sample(input [DATA_WIDTH-1:0] d);
    @(negedge clk);
    i_valid = 1;
    i_data  = d;
    @(posedge clk);
    #1;
  endtask

  logic [DATA_WIDTH-1:0] out_capture [0:31];

  initial begin
    clk = 0; rst = 0; up = 0; down = 0; i_valid = 0; i_data = 0;
    repeat(2) @(posedge clk);

    // ---- Phase 1: Fill ping RAM (ram_select=0) ----
    // ping[0]=0x10, ping[1]=0x20, ping[2]=0x30, ping[3]=0x40
    // After 4th write: ram_select toggles to 1, rd_addr resets to 0
    push_sample(8'h10);
    push_sample(8'h20);
    push_sample(8'h30);
    push_sample(8'h40);

    // ---- Phase 2: Fill pong RAM (ram_select=1, TARGET path) ----
    // Correct: pong[0]=A1, pong[1]=A2, pong[2]=A3, pong[3]=A4, then toggle back
    // Wrong:   pong[0] overwritten each time (A1->A2->A3->A4), pong[1..3]=0, no toggle
    push_sample(8'hA1);
    push_sample(8'hA2);
    push_sample(8'hA3);
    push_sample(8'hA4);

    // ---- Phase 3: Read back pong data ----
    // With correct code: ram_select toggled to 0, rd_addr=0
    // Reads produce: pong[0]=A1, pong[1]=A2, pong[2]=A3, pong[3]=A4
    // With wrong code: ram_select stayed 1, reads from ping instead
    push_sample(8'hB1); out_capture[0] = o_data;
    push_sample(8'hB2); out_capture[1] = o_data;
    push_sample(8'hB3); out_capture[2] = o_data;
    push_sample(8'hB4); out_capture[3] = o_data;

    // Key checks: pong data written at sequential addresses
    // Correct: A1, A2, A3, A4
    // Wrong: would be A4 (last overwrite of pong[0]), then 00, 00, 00
    check("pong_sequential_addr0", out_capture[0] == 8'hA1);
    check("pong_sequential_addr1", out_capture[1] == 8'hA2);
    check("pong_sequential_addr2", out_capture[2] == 8'hA3);
    check("pong_sequential_addr3", out_capture[3] == 8'hA4);

    // ---- Phase 4: Verify ram_select toggled ----
    // After phase 3 writes B1-B4 to ping, ram_select toggles to 1 again
    // Fill pong again: C1-C4
    push_sample(8'hC1);
    push_sample(8'hC2);
    push_sample(8'hC3);
    push_sample(8'hC4);

    // Read back second pong fill
    push_sample(8'hD1); out_capture[4] = o_data;
    push_sample(8'hD2); out_capture[5] = o_data;
    push_sample(8'hD3); out_capture[6] = o_data;
    push_sample(8'hD4); out_capture[7] = o_data;

    // With correct code: pong[0]=C1, pong[1]=C2, pong[2]=C3, pong[3]=C4
    check("second_pong_fill_addr0", out_capture[4] == 8'hC1);
    check("second_pong_fill_addr1", out_capture[5] == 8'hC2);
    check("second_pong_fill_addr2", out_capture[6] == 8'hC3);

    // ---- Test o_valid behavior ----
    check("o_valid_high", o_valid == 1'b1);
    @(negedge clk);
    i_valid = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check("valid_low_when_idle", o_valid == 1'b0);

    i_valid = 0;
    @(posedge clk);

    if (fail_count == 0)
      $display("[TB_REAL] shifter all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] shifter FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #100000;
    $display("[TB_REAL] shifter FAILED - timeout");
    $finish;
  end
endmodule
