`timescale 1ns/1ps
`include "../psram_original.sv"

module psram_target_tb;
  logic clk;
  logic bank_sel;
  logic [21:0] addr;
  logic write_en;
  logic [15:0] data_in;
  logic write_high_byte, write_low_byte;
  logic read_en;
  wire read_avail;
  wire [15:0] data_out;
  wire busy;

  // PSRAM signals
  wire [21:16] cram_a;
  wire [15:0] cram_dq;
  wire cram_clk;
  wire cram_adv_n;
  wire cram_cre;
  wire cram_ce0_n, cram_ce1_n;
  wire cram_oe_n, cram_we_n;
  wire cram_ub_n, cram_lb_n;

  logic cram_wait_sig = 1'b0;

  // External driver for cram_dq during reads (simulates PSRAM chip responding)
  logic [15:0] psram_read_data;
  logic psram_drive_en;
  assign cram_dq = psram_drive_en ? psram_read_data : 16'hZZ;

  psram dut (
    .clk(clk),
    .bank_sel(bank_sel),
    .addr(addr),
    .write_en(write_en),
    .data_in(data_in),
    .write_high_byte(write_high_byte),
    .write_low_byte(write_low_byte),
    .read_en(read_en),
    .read_avail(read_avail),
    .data_out(data_out),
    .busy(busy),
    .cram_a(cram_a),
    .cram_dq(cram_dq),
    .cram_wait(cram_wait_sig),
    .cram_clk(cram_clk),
    .cram_adv_n(cram_adv_n),
    .cram_cre(cram_cre),
    .cram_ce0_n(cram_ce0_n),
    .cram_ce1_n(cram_ce1_n),
    .cram_oe_n(cram_oe_n),
    .cram_we_n(cram_we_n),
    .cram_ub_n(cram_ub_n),
    .cram_lb_n(cram_lb_n)
  );

  always #5 clk = ~clk;

  integer err = 0;
  integer total_tests = 0;

  // The TARGET at line 303 is: cram_a <= addr[21:16];
  // This sets the upper address bits for a READ operation.
  // Without it, cram_a would not reflect the correct upper address during reads.
  //
  // We test by issuing read operations with various addresses and checking
  // that cram_a is set to addr[21:16] during the read cycle.

  // Captured values
  logic [5:0] captured_cram_a;
  logic [15:0] captured_cram_dq_addr;
  logic captured_adv_n;

  task issue_read(
    input [21:0] test_addr,
    input test_bank_sel
  );
    @(posedge clk);
    addr = test_addr;
    bank_sel = test_bank_sel;
    read_en = 1;
    write_en = 0;
    @(posedge clk);
    read_en = 0;
  endtask

  task wait_not_busy;
    integer timeout;
    timeout = 0;
    while (busy && timeout < 100) begin
      @(posedge clk);
      timeout = timeout + 1;
    end
  endtask

  // Monitor cram_a right after read is initiated
  // After the first posedge after read_en, cram_a should have addr[21:16]
  task check_read_addr(
    input integer test_num,
    input [21:0] test_addr,
    input test_bank_sel
  );
    // Issue read: set signals before posedge to avoid race
    @(negedge clk);
    addr = test_addr;
    bank_sel = test_bank_sel;
    read_en = 1;
    write_en = 0;

    // At the next posedge, DUT processes STATE_NONE with read_en=1:
    // transitions to read state, sets cram_a, cram_adv_n=0
    @(posedge clk);
    #1;
    // Immediately after the transition posedge, check signals

    total_tests = total_tests + 1;
    if (cram_a !== test_addr[21:16]) begin
      $display("ERROR: Test%0d cram_a=%h expected=%h (addr=%h)",
               test_num, cram_a, test_addr[21:16], test_addr);
      err = err + 1;
    end

    // Check that adv_n is low (address latching) - only valid for this cycle
    total_tests = total_tests + 1;
    if (cram_adv_n !== 1'b0) begin
      $display("ERROR: Test%0d cram_adv_n should be 0 during addr phase", test_num);
      err = err + 1;
    end

    // Check bank selection
    total_tests = total_tests + 1;
    if (test_bank_sel == 0) begin
      if (cram_ce0_n !== 1'b0) begin
        $display("ERROR: Test%0d cram_ce0_n should be 0 for bank_sel=0", test_num);
        err = err + 1;
      end
    end else begin
      if (cram_ce1_n !== 1'b0) begin
        $display("ERROR: Test%0d cram_ce1_n should be 0 for bank_sel=1", test_num);
        err = err + 1;
      end
    end

    // Deassert read_en
    read_en = 0;

    // Drive read data on bus when oe_n goes low
    psram_drive_en = 0;
    begin : wait_for_oe
      integer cyc;
      for (cyc = 0; cyc < 50; cyc = cyc + 1) begin
        @(posedge clk);
        if (cram_oe_n == 1'b0) begin
          psram_read_data = test_addr[15:0]; // echo lower addr as data
          psram_drive_en = 1;
        end
      end
    end
    psram_drive_en = 0;

    wait_not_busy;
  endtask

  // Also test that write still works (addr setup in write path is not the TARGET
  // but we verify the module doesn't break writes)
  task check_write_addr(
    input integer test_num,
    input [21:0] test_addr,
    input [15:0] test_data
  );
    @(negedge clk);
    addr = test_addr;
    bank_sel = 0;
    write_en = 1;
    read_en = 0;
    data_in = test_data;
    write_high_byte = 1;
    write_low_byte = 1;

    @(posedge clk);
    #1;

    total_tests = total_tests + 1;
    if (cram_a !== test_addr[21:16]) begin
      $display("ERROR: Test%0d write cram_a=%h expected=%h",
               test_num, cram_a, test_addr[21:16]);
      err = err + 1;
    end

    write_en = 0;
    write_high_byte = 0;
    write_low_byte = 0;

    wait_not_busy;
  endtask

  initial begin
    clk = 0;
    bank_sel = 0;
    addr = 22'd0;
    write_en = 0;
    data_in = 16'd0;
    write_high_byte = 0;
    write_low_byte = 0;
    read_en = 0;
    psram_drive_en = 0;
    psram_read_data = 16'h0;

    repeat(5) @(posedge clk);

    // Test 1-5: Read with different upper address values
    check_read_addr(1, 22'h000000, 0);  // addr[21:16] = 0x00
    check_read_addr(2, 22'h010000, 0);  // addr[21:16] = 0x01
    check_read_addr(3, 22'h3F0000, 0);  // addr[21:16] = 0x3F (max)
    check_read_addr(4, 22'h2A1234, 0);  // addr[21:16] = 0x2A
    check_read_addr(5, 22'h150000, 1);  // bank 1, addr[21:16] = 0x15

    // Test 6-8: Different upper address patterns
    check_read_addr(6, 22'h200000, 0);  // addr[21:16] = 0x20
    check_read_addr(7, 22'h3FFFFF, 0);  // all bits set
    check_read_addr(8, 22'h100001, 1);  // addr[21:16] = 0x10, bank 1

    // Test 9-10: Verify write path still works (not the TARGET but sanity check)
    check_write_addr(9,  22'h1A0000, 16'hBEEF);
    check_write_addr(10, 22'h3F5678, 16'hCAFE);

    // Test 11-15: More read addresses focusing on upper bits
    check_read_addr(11, 22'h050000, 0);
    check_read_addr(12, 22'h0A0000, 0);
    check_read_addr(13, 22'h1F0000, 0);
    check_read_addr(14, 22'h300000, 0);
    check_read_addr(15, 22'h3C0000, 1);

    if (err == 0)
      $display("[TB_REAL] psram all %0d tests PASSED", total_tests);
    else
      $display("[TB_REAL] psram FAILED %0d / %0d tests", err, total_tests);
    $finish;
  end

  // Timeout
  initial begin
    #500000;
    $display("[TB_REAL] psram FAILED 1 / 1 tests");
    $finish;
  end
endmodule
