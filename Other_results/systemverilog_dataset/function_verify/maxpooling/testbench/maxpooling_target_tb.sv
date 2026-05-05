`timescale 1ns/1ps

`include "../maxpooling_original.sv"

module maxpooling_target_tb;

  parameter PIX_WIDTH      = 8;
  parameter POOL_DIMENSION = 2;
  parameter WIDTH          = 4;
  parameter HEIGHT         = 4;

  logic clk, clk_en, rst_n;
  logic [PIX_WIDTH-1:0] i_data;
  logic i_valid, i_sop, i_eop;
  wire [PIX_WIDTH-1:0] o_data;
  wire o_valid, o_sop, o_eop;
  wire ready;
  wire [11:0] cols_cntr, rows_cntr;

  maxpooling #(
    .PIX_WIDTH(PIX_WIDTH),
    .POOL_DIMENSION(POOL_DIMENSION),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
  ) dut (
    .clk(clk),
    .clk_en(clk_en),
    .rst_n(rst_n),
    .i_data(i_data),
    .i_valid(i_valid),
    .i_sop(i_sop),
    .i_eop(i_eop),
    .o_data(o_data),
    .o_valid(o_valid),
    .o_sop(o_sop),
    .o_eop(o_eop),
    .ready(ready),
    .cols_cntr(cols_cntr),
    .rows_cntr(rows_cntr)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  integer err = 0;
  integer total_tests = 0;

  logic [PIX_WIDTH-1:0] out_values [0:15];
  integer out_count;

  logic [PIX_WIDTH-1:0] img [0:15];
  logic [PIX_WIDTH-1:0] expected [0:3];

  task reset_dut;
    rst_n = 0;
    clk_en = 1;
    i_valid = 0;
    i_sop = 0;
    i_eop = 0;
    i_data = 0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

  // Feed image and collect outputs simultaneously
  task feed_and_collect;
    integer i;
    integer cyc;
    out_count = 0;

    // Feed pixels
    for (i = 0; i < WIDTH * HEIGHT; i = i + 1) begin
      @(posedge clk);
      #1;
      // Check for output before feeding next pixel
      if (o_valid) begin
        out_values[out_count] = o_data;
        out_count = out_count + 1;
      end
      i_valid = 1;
      i_data = img[i];
      i_sop = (i == 0);
      i_eop = (i == WIDTH * HEIGHT - 1);
    end
    @(posedge clk);
    #1;
    if (o_valid) begin
      out_values[out_count] = o_data;
      out_count = out_count + 1;
    end
    i_valid = 0;
    i_sop = 0;
    i_eop = 0;

    // Wait for pipeline to flush
    for (cyc = 0; cyc < 20; cyc = cyc + 1) begin
      @(posedge clk);
      #1;
      if (o_valid) begin
        out_values[out_count] = o_data;
        out_count = out_count + 1;
      end
    end
  endtask

  function automatic [PIX_WIDTH-1:0] max4(
    input [PIX_WIDTH-1:0] a, b, c, d
  );
    logic [PIX_WIDTH-1:0] m;
    m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    if (d > m) m = d;
    return m;
  endfunction

  task run_test;
    input integer test_num;
    integer i;
    // Compute expected 2x2 maxpool of 4x4 image
    expected[0] = max4(img[0],  img[1],  img[4],  img[5]);
    expected[1] = max4(img[2],  img[3],  img[6],  img[7]);
    expected[2] = max4(img[8],  img[9],  img[12], img[13]);
    expected[3] = max4(img[10], img[11], img[14], img[15]);

    reset_dut;
    feed_and_collect;

    total_tests = total_tests + 1;
    if (out_count != 4) begin
      $display("ERROR: Test%0d expected 4 outputs, got %0d", test_num, out_count);
      err = err + 1;
    end else begin
      for (i = 0; i < 4; i = i + 1) begin
        total_tests = total_tests + 1;
        if (out_values[i] !== expected[i]) begin
          $display("ERROR: Test%0d pool[%0d] got %0d expected %0d", test_num, i, out_values[i], expected[i]);
          err = err + 1;
        end
      end
    end
  endtask

  initial begin
    // Test 1: Simple ascending
    img[0]=1; img[1]=2; img[2]=3; img[3]=4;
    img[4]=5; img[5]=6; img[6]=7; img[7]=8;
    img[8]=9; img[9]=10; img[10]=11; img[11]=12;
    img[12]=13; img[13]=14; img[14]=15; img[15]=16;
    run_test(1);

    // Test 2: Max in top-left of each pool
    img[0]=100; img[1]=1; img[2]=200; img[3]=1;
    img[4]=1;   img[5]=1; img[6]=1;   img[7]=1;
    img[8]=150; img[9]=1; img[10]=250; img[11]=1;
    img[12]=1;  img[13]=1; img[14]=1;  img[15]=1;
    run_test(2);

    // Test 3: Max in top-right of each pool
    img[0]=1;  img[1]=100; img[2]=1;  img[3]=200;
    img[4]=1;  img[5]=1;   img[6]=1;  img[7]=1;
    img[8]=1;  img[9]=150; img[10]=1; img[11]=250;
    img[12]=1; img[13]=1;  img[14]=1; img[15]=1;
    run_test(3);

    // Test 4: Max in bottom-left
    img[0]=1; img[1]=1; img[2]=1; img[3]=1;
    img[4]=100; img[5]=1; img[6]=200; img[7]=1;
    img[8]=1; img[9]=1; img[10]=1; img[11]=1;
    img[12]=150; img[13]=1; img[14]=250; img[15]=1;
    run_test(4);

    // Test 5: Max in bottom-right
    img[0]=1; img[1]=1; img[2]=1; img[3]=1;
    img[4]=1; img[5]=100; img[6]=1; img[7]=200;
    img[8]=1; img[9]=1; img[10]=1; img[11]=1;
    img[12]=1; img[13]=150; img[14]=1; img[15]=250;
    run_test(5);

    // Test 6: All same value
    img[0]=42; img[1]=42; img[2]=42; img[3]=42;
    img[4]=42; img[5]=42; img[6]=42; img[7]=42;
    img[8]=42; img[9]=42; img[10]=42; img[11]=42;
    img[12]=42; img[13]=42; img[14]=42; img[15]=42;
    run_test(6);

    // Test 7: Sparse
    img[0]=0; img[1]=255; img[2]=0; img[3]=0;
    img[4]=0; img[5]=0;   img[6]=0; img[7]=128;
    img[8]=0; img[9]=0;   img[10]=64; img[11]=0;
    img[12]=32; img[13]=0; img[14]=0; img[15]=0;
    run_test(7);

    // Test 8: Descending values
    img[0]=16; img[1]=15; img[2]=14; img[3]=13;
    img[4]=12; img[5]=11; img[6]=10; img[7]=9;
    img[8]=8;  img[9]=7;  img[10]=6; img[11]=5;
    img[12]=4; img[13]=3; img[14]=2; img[15]=1;
    run_test(8);

    // Test 9: Checkerboard pattern
    img[0]=255; img[1]=0; img[2]=255; img[3]=0;
    img[4]=0; img[5]=255; img[6]=0; img[7]=255;
    img[8]=255; img[9]=0; img[10]=255; img[11]=0;
    img[12]=0; img[13]=255; img[14]=0; img[15]=255;
    run_test(9);

    // Test 10: Row-wise pattern
    img[0]=10; img[1]=50; img[2]=10; img[3]=50;
    img[4]=50; img[5]=10; img[6]=50; img[7]=10;
    img[8]=10; img[9]=50; img[10]=10; img[11]=50;
    img[12]=50; img[13]=10; img[14]=50; img[15]=10;
    run_test(10);

    if (err == 0)
      $display("[TB_REAL] maxpooling all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] maxpooling FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end

  initial begin
    #1000000;
    $display("[TB_REAL] maxpooling FAILED 1 / 1 tests");
    $finish;
  end

endmodule
