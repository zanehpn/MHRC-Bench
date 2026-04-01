`timescale 1ns/1ps
`include "../fir_compensator_original.sv"

module fir_compensator_target_tb;

    bit clk;
    bit rst;
    bit ena;
    bit [31:0] data_in;
    bit [31:0] data_out;

    always #5 clk = ~clk;

    fir_compensator #(.WIDTH(32), .ALPHA_8(2)) dut (
        .clk(clk),
        .rst(rst),
        .ena(ena),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Reference model: implements the same FIR compensator logic
    // with ALPHA_8=2, the shift is d>>>2 (multiply by 0.25)
    bit signed [31:0] ref_d1, ref_d2, ref_sum, ref_dly;
    bit signed [31:0] ref_out;

    function automatic bit signed [31:0] compute_shift(input bit signed [31:0] val, input int alpha);
        bit signed [31:0] e, f, h, s;
        e = 0; f = 0; h = 0;
        if ((alpha % 2) == 1) e = val >>> 3;
        if ((alpha & 3) >= 2) f = val >>> 2;
        if (alpha >= 4)       h = val >>> 1;
        if (alpha == 0)       s = 0;
        else if (alpha == 8)  s = val;
        else                  s = e + f + h;
        return s;
    endfunction

    integer pass_count, fail_count;
    integer i;
    bit signed [31:0] test_values [0:14];

    initial begin
        clk = 0;
        rst = 1;
        ena = 0;
        data_in = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize reference model
        ref_d1 = 0; ref_d2 = 0; ref_sum = 0; ref_dly = 0; ref_out = 0;

        @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test data sequence
        test_values[0]  = 32'sd1000;
        test_values[1]  = 32'sd2000;
        test_values[2]  = 32'sd3000;
        test_values[3]  = 32'sd4000;
        test_values[4]  = 32'sd5000;
        test_values[5]  = -32'sd1000;
        test_values[6]  = -32'sd2000;
        test_values[7]  = 32'sd0;
        test_values[8]  = 32'sd10000;
        test_values[9]  = -32'sd10000;
        test_values[10] = 32'sd100;
        test_values[11] = 32'sd200;
        test_values[12] = 32'sd300;
        test_values[13] = -32'sd500;
        test_values[14] = 32'sd0;

        ena = 1;

        for (i = 0; i < 15; i = i + 1) begin
            data_in = test_values[i];
            @(posedge clk);
            #1;

            // Update reference model (matches the always_ff behavior)
            begin
                bit signed [31:0] new_sum, new_dly;
                bit signed [31:0] sum_mult_ref, dly_mult_ref, dly_dly_ref;

                // Compute outputs from current state (before update)
                sum_mult_ref = compute_shift(ref_sum, 2) >>> 1;
                dly_mult_ref = compute_shift(ref_dly, 2);
                dly_dly_ref  = ref_dly;

                new_sum = ref_d2 + $signed(test_values[i]);
                new_dly = ref_d1;

                ref_out = ~sum_mult_ref + 1 + dly_dly_ref + dly_mult_ref;
                ref_d2 = ref_d1;
                ref_d1 = $signed(test_values[i]);
                ref_sum = new_sum;
                ref_dly = new_dly;
            end

            // Check after pipeline fills (skip first 3 cycles for pipeline warmup)
            if (i >= 3) begin
                if (data_out === ref_out) begin
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL at i=%0d: data_in=%0d, expected=%0d, got=%0d",
                             i, $signed(test_values[i]), ref_out, $signed(data_out));
                    fail_count = fail_count + 1;
                end
            end
        end

        // Additional: verify output is not X
        if ($isunknown(data_out)) begin
            $display("FAIL: data_out contains X/Z");
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end

        // Test reset clears output
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        #1;
        if (data_out === 32'd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: data_out should be 0 after reset, got %0d", data_out);
            fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("[TB_REAL] fir_compensator for loop initialization PASSED");
        else
            $display("[TB_REAL] fir_compensator FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
