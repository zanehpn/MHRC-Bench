`timescale 1ns/1ps
`include "../sigma_delta_dac_original.sv"

module sigma_delta_dac_target_tb;
  // DUT: sigma_delta_dac with DAC_BITLEN=8
  // acc1 is 9 bits [8:0], dac_input is 8 bits
  // always_ff @(posedge clk):
  //   acc1 <= acc1[7:0] + dac_input;
  //   dac_pin <= acc1[8];
  //   if (rst) begin dac_pin <= 0; acc1 <= 0; end

  bit clk, rst;
  bit [7:0] dac_input;
  bit dac_pin;

  sigma_delta_dac #(.DAC_BITLEN(8)) dut (
    .clk(clk),
    .rst(rst),
    .dac_input(dac_input),
    .dac_pin(dac_pin)
  );

  always #5 clk = ~clk;

  integer err = 0;
  integer total_tests = 0;

  task reset_dut;
    rst = 1;
    dac_input = 0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
    @(posedge clk); // first edge with rst=0 and dac_input=0
    #1;
  endtask

  // Test that reset clears dac_pin and acc1
  task test_reset;
    rst = 1;
    dac_input = 0;
    @(posedge clk);
    @(posedge clk);
    #1;
    total_tests++;
    if (dac_pin !== 0) begin
      $display("ERROR: after reset dac_pin=%b expected=0", dac_pin);
      err++;
    end
    total_tests++;
    if (dut.acc1 !== 0) begin
      $display("ERROR: after reset acc1=%h expected=0", dut.acc1);
      err++;
    end
    rst = 0;
    @(posedge clk); #1;
  endtask

  // Test that with dac_input=0xFF, dac_pin goes high frequently
  task test_overflow;
    integer cyc;
    integer pin_high_count;
    reset_dut;
    dac_input = 8'hFF;
    pin_high_count = 0;
    for (cyc = 0; cyc < 10; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) pin_high_count++;
    end
    total_tests++;
    if (pin_high_count < 5) begin
      $display("ERROR: test_overflow pin_high_count=%0d expected >= 5 (input=FF)", pin_high_count);
      err++;
    end
  endtask

  // Test that with dac_input=0, dac_pin stays low
  task test_zero_input;
    integer cyc;
    reset_dut;
    dac_input = 8'h00;
    for (cyc = 0; cyc < 20; cyc++) begin
      @(posedge clk);
      #1;
      total_tests++;
      if (dac_pin !== 1'b0) begin
        $display("ERROR: test_zero cyc=%0d dac_pin=%b expected=0", cyc, dac_pin);
        err++;
      end
    end
  endtask

  // Test with dac_input=0x80 (half scale): ~50% duty
  task test_half_scale;
    integer cyc;
    integer pin_high_count;
    reset_dut;
    dac_input = 8'h80;
    pin_high_count = 0;
    for (cyc = 0; cyc < 256; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) pin_high_count++;
    end
    total_tests++;
    if (pin_high_count < 100 || pin_high_count > 156) begin
      $display("ERROR: test_half pin_high=%0d expected ~128", pin_high_count);
      err++;
    end
  endtask

  // Test with dac_input=0x40 (quarter scale): ~25% duty
  task test_quarter_scale;
    integer cyc;
    integer pin_high_count;
    reset_dut;
    dac_input = 8'h40;
    pin_high_count = 0;
    for (cyc = 0; cyc < 256; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) pin_high_count++;
    end
    total_tests++;
    if (pin_high_count < 40 || pin_high_count > 90) begin
      $display("ERROR: test_quarter pin_high=%0d expected ~64", pin_high_count);
      err++;
    end
  endtask

  // Verify exact accumulator behavior cycle by cycle
  // The DUT: on posedge clk (when rst=0):
  //   acc1_next = acc1_current[7:0] + dac_input
  //   dac_pin_next = acc1_current[8]
  // So dac_pin reflects the OLD acc1[8], and acc1 gets the new sum.
  task test_exact_accumulation;
    bit [8:0] model_acc;
    bit model_pin;
    integer cyc;

    reset_dut;
    dac_input = 8'h33;

    // After reset_dut, acc1 = 0+0 = 0 (one edge with dac_input=0 after rst goes low).
    // Now we set dac_input = 0x33.
    // The model tracks acc1 AFTER each posedge clk.
    model_acc = 9'h000; // acc1 after the first reset-free edge (with dac_input=0)

    for (cyc = 0; cyc < 20; cyc++) begin
      // Before this posedge: model_acc is the current acc1 value
      // On posedge: dac_pin_new = model_acc[8]; acc1_new = model_acc[7:0] + 0x33
      model_pin = model_acc[8];
      model_acc = model_acc[7:0] + 8'h33;

      @(posedge clk);
      #1;

      total_tests++;
      if (dut.acc1 !== model_acc) begin
        $display("ERROR: test_exact cyc=%0d acc1=%h expected=%h", cyc, dut.acc1, model_acc);
        err++;
      end
      total_tests++;
      if (dac_pin !== model_pin) begin
        $display("ERROR: test_exact cyc=%0d dac_pin=%b expected=%b", cyc, dac_pin, model_pin);
        err++;
      end
    end
  endtask

  // Test input=1: only overflows every 256 cycles
  task test_input_one;
    integer cyc;
    integer pin_high_count;
    reset_dut;
    dac_input = 8'h01;
    pin_high_count = 0;
    for (cyc = 0; cyc < 512; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) pin_high_count++;
    end
    total_tests++;
    if (pin_high_count < 1 || pin_high_count > 4) begin
      $display("ERROR: test_input_one pin_high=%0d expected ~2", pin_high_count);
      err++;
    end
  endtask

  // Test proportionality
  task test_proportionality;
    integer cyc;
    integer count_low, count_high;
    reset_dut;
    dac_input = 8'h20;
    count_low = 0;
    for (cyc = 0; cyc < 256; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) count_low++;
    end

    reset_dut;
    dac_input = 8'hC0;
    count_high = 0;
    for (cyc = 0; cyc < 256; cyc++) begin
      @(posedge clk);
      #1;
      if (dac_pin) count_high++;
    end

    total_tests++;
    if (count_high <= count_low) begin
      $display("ERROR: proportionality failed: 0xC0 count=%0d <= 0x20 count=%0d", count_high, count_low);
      err++;
    end
  endtask

  initial begin
    clk = 0;
    rst = 1;
    dac_input = 0;

    test_reset;
    test_overflow;
    test_zero_input;
    test_half_scale;
    test_quarter_scale;
    test_exact_accumulation;
    test_input_one;
    test_proportionality;

    if (err == 0)
      $display("[TB_REAL] sigma_delta_dac all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] sigma_delta_dac FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end

  initial begin
    #5000000;
    $display("[TB_REAL] sigma_delta_dac FAILED 1 / 1 tests");
    $finish;
  end
endmodule
