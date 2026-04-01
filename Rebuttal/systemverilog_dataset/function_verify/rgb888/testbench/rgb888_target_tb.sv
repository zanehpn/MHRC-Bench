`timescale 1ns/1ps
`include "../rgb888_original.sv"

module rgb888_target_tb;
  logic clock_p, clock_n;
  logic [7:0] image_data_0, image_data_1, image_data_2, image_data_3;
  logic image_data_enable;
  wire [23:0] rgb [1:0];
  wire [1:0] rgb_enable;

  wire [7:0] image_data [3:0];
  assign image_data[0] = image_data_0;
  assign image_data[1] = image_data_1;
  assign image_data[2] = image_data_2;
  assign image_data[3] = image_data_3;

  rgb888 dut (
    .clock_p(clock_p),
    .clock_n(clock_n),
    .image_data(image_data),
    .image_data_enable(image_data_enable),
    .rgb(rgb),
    .rgb_enable(rgb_enable)
  );

  initial begin
    clock_p = 0;
    clock_n = 1;
  end
  always #5 begin
    clock_p = ~clock_p;
    clock_n = ~clock_n;
  end

  integer err = 0;
  integer total_tests = 0;

  task set_image;
    input [7:0] d0, d1, d2, d3;
    image_data_0 = d0;
    image_data_1 = d1;
    image_data_2 = d2;
    image_data_3 = d3;
  endtask

  // Wait for one DUT clock edge (either posedge or negedge of clock_p,
  // which corresponds to posedge clock_p or posedge clock_n)
  task dut_edge;
    @(clock_p);
    #1;
  endtask

  initial begin
    image_data_enable = 0;
    set_image(0, 0, 0, 0);

    repeat(3) @(posedge clock_p);
    #1;

    // State = 0 (from initialization `logic [1:0] state = 2'd0;`)
    // image_data_enable = 0, no state transitions yet

    // =========================================================
    // Test 1: rgb_enable[0] = 0 when enable is off
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb_enable[0] !== 1'b0) begin
      $display("ERROR: Test1 rgb_enable[0]=%b expected=0", rgb_enable[0]);
      err = err + 1;
    end

    // =========================================================
    // Test 2: State 0, rgb[0] = {d2, d1, d0}
    // =========================================================
    image_data_enable = 1;
    set_image(8'h10, 8'h20, 8'h30, 8'h40);
    #1;

    total_tests = total_tests + 1;
    if (rgb[0] !== {8'h30, 8'h20, 8'h10}) begin
      $display("ERROR: Test2 state0 rgb[0]=%h expected=302010", rgb[0]);
      err = err + 1;
    end

    // =========================================================
    // Test 3: rgb_enable[0] = image_data_enable = 1
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb_enable[0] !== 1'b1) begin
      $display("ERROR: Test3 rgb_enable[0]=%b expected=1", rgb_enable[0]);
      err = err + 1;
    end

    // =========================================================
    // Test 4: rgb_enable[1] = 0 when state != 2
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb_enable[1] !== 1'b0) begin
      $display("ERROR: Test4 rgb_enable[1]=%b expected=0", rgb_enable[1]);
      err = err + 1;
    end

    // =========================================================
    // Test 5: rgb[1] = {d3, d2, d1}
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb[1] !== {8'h40, 8'h30, 8'h20}) begin
      $display("ERROR: Test5 rgb[1]=%h expected=403020", rgb[1]);
      err = err + 1;
    end

    // DUT state machine triggers on posedge clock_p and posedge clock_n.
    // Since clock_n = ~clock_p, every edge of clock_p (pos and neg) triggers the block.
    // State 0 -> edge -> 1 -> edge -> 2 -> edge -> 0 -> ...
    // We need two edges from state 0 to reach state 2.

    // Edge 1: state 0->1
    dut_edge;
    // Edge 2: state 1->2
    dut_edge;

    // =========================================================
    // Test 6: In state 2, rgb_enable[1] = 1
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb_enable[1] !== 1'b1) begin
      $display("ERROR: Test6 rgb_enable[1]=%b expected=1 (state=2)", rgb_enable[1]);
      err = err + 1;
    end

    // =========================================================
    // Test 7: rgb[1] still = {d3, d2, d1}
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb[1] !== {8'h40, 8'h30, 8'h20}) begin
      $display("ERROR: Test7 rgb[1]=%h expected=403020", rgb[1]);
      err = err + 1;
    end

    // Edge 3: state 2->0
    dut_edge;

    // =========================================================
    // Test 8: State wrapped to 0, rgb_enable[1] = 0
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb_enable[1] !== 1'b0) begin
      $display("ERROR: Test8 rgb_enable[1]=%b expected=0", rgb_enable[1]);
      err = err + 1;
    end

    // =========================================================
    // Test 9: Disable prevents state advance
    // =========================================================
    image_data_enable = 0;
    dut_edge;
    dut_edge;
    dut_edge;

    total_tests = total_tests + 1;
    if (rgb_enable[0] !== 1'b0) begin
      $display("ERROR: Test9 rgb_enable[0]=%b expected=0", rgb_enable[0]);
      err = err + 1;
    end

    // =========================================================
    // Test 10: Re-enable, state should be 0 (frozen during disable)
    // rgb[0] in state 0 = {d2, d1, d0}
    // =========================================================
    image_data_enable = 1;
    set_image(8'h55, 8'h66, 8'h77, 8'h88);
    #1;

    total_tests = total_tests + 1;
    if (rgb[0] !== {8'h77, 8'h66, 8'h55}) begin
      $display("ERROR: Test10 state0 rgb[0]=%h expected=776655", rgb[0]);
      err = err + 1;
    end

    // =========================================================
    // Test 11: rgb[1] = {d3, d2, d1}
    // =========================================================
    total_tests = total_tests + 1;
    if (rgb[1] !== {8'h88, 8'h77, 8'h66}) begin
      $display("ERROR: Test11 rgb[1]=%h expected=887766", rgb[1]);
      err = err + 1;
    end

    if (err == 0)
      $display("[TB_REAL] rgb888 all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] rgb888 FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end

  initial begin
    #100000;
    $display("[TB_REAL] rgb888 FAILED 1 / 1 tests");
    $finish;
  end
endmodule
