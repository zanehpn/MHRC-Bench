`timescale 1ns/1ps

// Stubs for sub-modules instantiated by top
// PLL stub: passthrough
module pll (
    input  inclk0,
    output c0
);
    assign c0 = inclk0;
endmodule

// ADC stub: produces valid samples with known values on a regular cadence
module sigma_delta_adc #(
    parameter OVERSAMPLE_RATE = 128,
    parameter CIC_STAGES = 2,
    parameter ADC_BITLEN = 14,
    parameter USE_FIR_COMP = 0,
    parameter FIR_COMP_ALPHA_8 = 0
)(
    input  clk,
    input  rst,
    input  adc_lvds_pin,
    output adc_fb_pin,
    output reg [ADC_BITLEN-1:0] adc_output,
    output reg adc_valid
);
    assign adc_fb_pin = 0;
    // Produce a valid sample every 4 clocks with incrementing values
    reg [7:0] cnt = 0;
    reg [ADC_BITLEN-1:0] sample_val = 0;
    always @(posedge clk) begin
        cnt <= cnt + 1;
        adc_valid <= 0;
        if (cnt == 3) begin
            cnt <= 0;
            adc_valid <= 1;
            adc_output <= sample_val;
            sample_val <= sample_val + 1;
        end
    end
endmodule

// Shifter stub: passthrough
module shifter #(
    parameter DATA_WIDTH = 14,
    parameter RAM_SIZE = 512
)(
    input  clk,
    input  rst,
    input  up,
    input  down,
    input  i_valid,
    input  [DATA_WIDTH-1:0] i_data,
    output o_valid,
    output [DATA_WIDTH-1:0] o_data
);
    assign o_valid = i_valid;
    assign o_data = i_data;
endmodule

// DAC stub
module sigma_delta_dac #(
    parameter DAC_BITLEN = 14
)(
    input  clk,
    input  rst,
    input  [DAC_BITLEN-1:0] dac_input,
    output dac_pin
);
    assign dac_pin = 0;
endmodule

// UART stub: provides rvalid/rdata to trigger the 'S' command,
// and implements tx handshake with a small delay (like real UART).
module uart #(
    parameter CLKRATE = 6250000,
    parameter BAUDRATE = 115200
)(
    input  clk,
    input  rst,
    input  rx,
    output reg tx = 1,
    input  tvalid,
    output reg tready = 0,
    input  [7:0] tdata,
    output reg rvalid = 0,
    input  rready,
    output reg [7:0] rdata = 0
);
    // RX side: produce 'S' once then go idle
    reg sent_s = 0;
    reg [7:0] startup_cnt = 0;
    always @(posedge clk) begin
        if (startup_cnt < 20) begin
            startup_cnt <= startup_cnt + 1;
        end
        if (startup_cnt == 15 && !sent_s) begin
            rvalid <= 1;
            rdata  <= 8'h53; // 'S'
        end
        if (rvalid && rready) begin
            rvalid <= 0;
            sent_s <= 1;
        end
    end

    // TX side: accept data with a small baud-like delay
    reg [3:0] tx_delay = 0;
    reg tx_busy = 0;
    always @(posedge clk) begin
        if (!tx_busy && !rst) begin
            tready <= 1;
        end else begin
            tready <= 0;
        end
        if (tready && tvalid) begin
            tx_busy <= 1;
            tready  <= 0;
            tx_delay <= 0;
        end
        if (tx_busy) begin
            tx_delay <= tx_delay + 1;
            if (tx_delay == 5) begin
                tx_busy <= 0;
            end
        end
    end
endmodule

`include "../top_original.sv"

module top_target_tb;
  // TARGET: The nibble_to_send case statement mux in the pushing state.
  // We test by driving the top module through its normal flow:
  //   sitting -> (UART receives 'S') -> sampling -> (ADC produces samples) -> pushing
  // Then we observe tdata values that come out on the TX handshake.

  bit clk50;
  bit [1:0] sw;
  bit [1:0] key;
  bit pin_i;
  bit fb;
  bit dac_pin;
  bit [7:0] led;
  bit tx_o;
  bit rx_i;

  top dut (
    .clk50(clk50),
    .sw(sw),
    .key(key),
    .pin(pin_i),
    .fb(fb),
    .dac_pin(dac_pin),
    .led(led),
    .tx(tx_o),
    .rx(rx_i)
  );

  initial clk50 = 0;
  always #10 clk50 = ~clk50;

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

  // Check if a byte is a valid ASCII hex char ('0'-'9', 'A'-'F')
  function automatic logic is_hex_char(input [7:0] ch);
    is_hex_char = (ch >= 8'h30 && ch <= 8'h39) || (ch >= 8'h41 && ch <= 8'h46);
  endfunction

  initial begin
    sw    = 2'b00;
    key   = 2'b11;
    pin_i = 0;
    rx_i  = 1;

    // Wait until we see tvalid&&tready (first byte being sent in pushing state)
    begin
      integer timeout_cnt;
      timeout_cnt = 0;
      while (timeout_cnt < 100000) begin
        @(posedge clk50);
        if (dut.tvalid && dut.tready) begin
          break;
        end
        timeout_cnt++;
      end
      check("pushing_started", timeout_cnt < 100000);
    end

    // Collect first sample's 8 bytes (6 hex nibbles + newline + CR)
    begin
      logic [7:0] collected [0:7];
      integer cidx, timeout_cnt;

      collected[0] = dut.tdata;
      cidx = 1;
      timeout_cnt = 0;

      while (cidx < 8 && timeout_cnt < 100000) begin
        @(posedge clk50);
        if (dut.tvalid && dut.tready) begin
          collected[cidx] = dut.tdata;
          cidx++;
        end
        timeout_cnt++;
      end

      check("collected_8_bytes", cidx == 8);

      if (cidx >= 8) begin
        // Verify nibble 0-5 are valid hex characters
        check("nib0_hex", is_hex_char(collected[0]));
        check("nib1_hex", is_hex_char(collected[1]));
        check("nib2_hex", is_hex_char(collected[2]));
        check("nib3_hex", is_hex_char(collected[3]));
        check("nib4_hex", is_hex_char(collected[4]));
        check("nib5_hex", is_hex_char(collected[5]));
        check("nib6_newline",  collected[6] == 8'h0A);
        check("nib7_cr",       collected[7] == 8'h0D);
      end
    end

    // Collect second sample
    begin
      logic [7:0] collected2 [0:7];
      integer cidx2, timeout_cnt2;
      cidx2 = 0;
      timeout_cnt2 = 0;

      while (cidx2 < 8 && timeout_cnt2 < 100000) begin
        @(posedge clk50);
        if (dut.tvalid && dut.tready) begin
          collected2[cidx2] = dut.tdata;
          cidx2++;
        end
        timeout_cnt2++;
      end

      check("collected2_8_bytes", cidx2 == 8);
      if (cidx2 >= 8) begin
        check("s1_nib0_hex", is_hex_char(collected2[0]));
        check("s1_nib1_hex", is_hex_char(collected2[1]));
        check("s1_nib2_hex", is_hex_char(collected2[2]));
        check("s1_nib3_hex", is_hex_char(collected2[3]));
        check("s1_nib4_hex", is_hex_char(collected2[4]));
        check("s1_nib5_hex", is_hex_char(collected2[5]));
        check("s1_nib6_nl", collected2[6] == 8'h0A);
        check("s1_nib7_cr", collected2[7] == 8'h0D);
      end
    end

    // Collect third sample
    begin
      logic [7:0] collected3 [0:7];
      integer cidx3, timeout_cnt3;
      cidx3 = 0;
      timeout_cnt3 = 0;

      while (cidx3 < 8 && timeout_cnt3 < 100000) begin
        @(posedge clk50);
        if (dut.tvalid && dut.tready) begin
          collected3[cidx3] = dut.tdata;
          cidx3++;
        end
        timeout_cnt3++;
      end

      check("collected3_8_bytes", cidx3 == 8);
      if (cidx3 >= 8) begin
        check("s2_nib0_hex", is_hex_char(collected3[0]));
        check("s2_nib1_hex", is_hex_char(collected3[1]));
        check("s2_nib2_hex", is_hex_char(collected3[2]));
        check("s2_nib3_hex", is_hex_char(collected3[3]));
        check("s2_nib4_hex", is_hex_char(collected3[4]));
        check("s2_nib5_hex", is_hex_char(collected3[5]));
        check("s2_nib6_nl", collected3[6] == 8'h0A);
        check("s2_nib7_cr", collected3[7] == 8'h0D);
      end
    end

    if (fail_count == 0)
      $display("[TB_REAL] top all %0d tests PASSED", pass_count);
    else
      $display("[TB_REAL] top FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #50000000;
    $display("[TB_REAL] top FAILED - timeout");
    $finish;
  end
endmodule
