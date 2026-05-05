`timescale 1ns/1ps
`include "../uart_original.sv"

module uart_target_tb;
  // TARGET at line 142: tx completion logic
  // In the original, when tx_baud_en==1 && tx_data==0:
  //   tx_baud_en <= 0;
  // (then the rst block follows with tx<=1; tx_baud_en<=0;)
  //
  // In the TARGET version, the code at line 142 is:
  //   if(tx_baud_en == 1 && tx_data == 0) begin
  //     <TARGET>   -- should set tx<=1 and tx_baud_en<=0
  //     tx <= 1;
  //     tx_baud_en <= 0;
  //   end
  //
  // The TARGET is the data-sent detection and tx line restoration.
  // We verify that after transmitting a byte:
  // 1. tx returns to idle high
  // 2. tready is re-asserted (baud gen disabled)
  // 3. Multiple bytes can be sent consecutively

  // Use small CLKRATE/BAUDRATE for fast simulation
  localparam CLKRATE  = 100;
  localparam BAUDRATE = 10;
  localparam BAUD_DIV = CLKRATE / BAUDRATE; // = 10

  logic clk, rst, rx, tvalid, tready, rvalid, rready, tx_o;
  logic [7:0] tdata, rdata;

  uart #(.CLKRATE(CLKRATE), .BAUDRATE(BAUDRATE)) dut (
    .clk(clk), .rst(rst), .rx(rx), .tx(tx_o),
    .tvalid(tvalid), .tready(tready), .tdata(tdata),
    .rvalid(rvalid), .rready(rready), .rdata(rdata)
  );

  always #5 clk = ~clk;

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

  task automatic send_byte(input [7:0] data_val);
    // Wait for tready
    begin
      integer timeout;
      timeout = 0;
      while (!tready && timeout < 2000) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
    end
    @(negedge clk);
    tdata = data_val;
    tvalid = 1;
    @(posedge clk);
    @(negedge clk);
    tvalid = 0;
  endtask

  task automatic wait_tx_complete();
    // Wait for tready to come back (means tx is done)
    begin
      integer timeout;
      timeout = 0;
      while (!tready && timeout < 2000) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
    end
  endtask

  // Capture bits from tx line
  logic [9:0] captured_bits;
  integer bit_count;

  initial begin
    clk = 0; rst = 1; rx = 1; tvalid = 0; tdata = 0; rready = 0;
    repeat(3) @(posedge clk);
    rst = 0;

    // Wait for tready
    wait_tx_complete();
    check("initial_tready", tready == 1'b1);
    check("initial_tx_high", tx_o == 1'b1);

    // Test 1: Send byte 0xA5 and verify tx returns to idle
    send_byte(8'hA5);

    // Wait for start bit (tx goes low)
    begin
      integer timeout;
      timeout = 0;
      while (tx_o == 1'b1 && timeout < 200) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      check("start_bit_detected", tx_o == 1'b0);
    end

    // Wait for transmission to complete
    wait_tx_complete();
    check("tx_complete_ready", tready == 1'b1);
    check("tx_idle_after_A5", tx_o == 1'b1);

    // Test 2: Send byte 0x00 (all zeros)
    send_byte(8'h00);
    begin
      integer timeout;
      timeout = 0;
      while (tx_o == 1'b1 && timeout < 200) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
    end
    wait_tx_complete();
    check("tx_idle_after_00", tx_o == 1'b1);
    check("tready_after_00", tready == 1'b1);

    // Test 3: Send byte 0xFF (all ones)
    send_byte(8'hFF);
    begin
      integer timeout;
      timeout = 0;
      while (tx_o == 1'b1 && timeout < 200) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
    end
    wait_tx_complete();
    check("tx_idle_after_FF", tx_o == 1'b1);
    check("tready_after_FF", tready == 1'b1);

    // Test 4: Back-to-back transmissions
    send_byte(8'h55);
    wait_tx_complete();
    check("bb_tx1_complete", tready == 1'b1);

    send_byte(8'hAA);
    wait_tx_complete();
    check("bb_tx2_complete", tready == 1'b1);
    check("bb_tx2_idle", tx_o == 1'b1);

    // Test 5: Three back-to-back
    send_byte(8'h01);
    wait_tx_complete();
    check("triple_1", tready == 1'b1);

    send_byte(8'h02);
    wait_tx_complete();
    check("triple_2", tready == 1'b1);

    send_byte(8'h03);
    wait_tx_complete();
    check("triple_3", tready == 1'b1);
    check("triple_idle", tx_o == 1'b1);

    // Test 6: Verify reset works mid-transmission
    send_byte(8'hDE);
    repeat(5) @(posedge clk); // partial transmission
    rst = 1;
    repeat(3) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);
    check("reset_tx_high", tx_o == 1'b1);

    // After reset, should be able to send again
    wait_tx_complete();
    send_byte(8'hAB);
    wait_tx_complete();
    check("post_reset_send", tready == 1'b1);
    check("post_reset_idle", tx_o == 1'b1);

    // Test 7: Send 0x80 (MSB only)
    send_byte(8'h80);
    wait_tx_complete();
    check("0x80_complete", tready == 1'b1);
    check("0x80_idle", tx_o == 1'b1);

    if (fail_count == 0)
      $display("[TB_REAL] uart all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] uart FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #500000;
    $display("[TB_REAL] uart FAILED - timeout");
    $finish;
  end
endmodule
