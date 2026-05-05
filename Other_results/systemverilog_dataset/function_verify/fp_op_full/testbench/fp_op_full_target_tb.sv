`timescale 1ns/1ps

`include "fp_macros.svh"

// Stub ufp_resize module for testing (simple pass-through for same-width, or zero-extend/truncate)
module ufp_resize #(
    parameter clip = 0
) (
    ufp.in   in,
    ufp.out  out
);
    localparam in_qw  = `fp_qw(in);
    localparam in_wl  = `fp_wl(in);
    localparam out_qw = `fp_qw(out);
    localparam out_wl = `fp_wl(out);

    // For our test cases, in and out have the same iw and qw
    assign out.val = out_wl'(in.val) << (out_qw - in_qw);
endmodule

// Stub sfp_resize module
module sfp_resize #(
    parameter clip = 0
) (
    sfp.in   in,
    sfp.out  out
);
    localparam in_qw  = `fp_qw(in);
    localparam in_wl  = `fp_wl(in);
    localparam out_qw = `fp_qw(out);
    localparam out_wl = `fp_wl(out);

    assign out.val = out_wl'(in.val) << (out_qw - in_qw);
endmodule

`include "../fp_op_full_original.sv"

module fp_op_full_target_tb;

    integer pass_count, fail_count;

    // ---- Test ufp_sub_full (contains the TARGET) ----
    // in1: ufp #(4, 4) => wl=8, in2: ufp #(4, 4) => wl=8
    // out: sfp #(5, 4) => wl=9 (iw = max(4,4)+1=5, qw = max(4,4)=4)
    ufp #(4, 4) sub_in1();
    ufp #(4, 4) sub_in2();
    sfp #(5, 4) sub_out();

    ufp_sub_full u_sub (.in1(sub_in1), .in2(sub_in2), .out(sub_out));

    // ---- Test ufp_add_full ----
    ufp #(4, 4) add_in1();
    ufp #(4, 4) add_in2();
    ufp #(5, 4) add_out();

    ufp_add_full u_add (.in1(add_in1), .in2(add_in2), .out(add_out));

    // ---- Test sfp_add_full ----
    sfp #(4, 4) sadd_in1();
    sfp #(4, 4) sadd_in2();
    sfp #(5, 4) sadd_out();

    sfp_add_full u_sadd (.in1(sadd_in1), .in2(sadd_in2), .out(sadd_out));

    // ---- Test sfp_sub_full ----
    sfp #(4, 4) ssub_in1();
    sfp #(4, 4) ssub_in2();
    sfp #(5, 4) ssub_out();

    sfp_sub_full u_ssub (.in1(ssub_in1), .in2(ssub_in2), .out(ssub_out));

    // ---- Test ufp_mult_full ----
    ufp #(2, 2) mul_in1();
    ufp #(3, 1) mul_in2();
    ufp #(5, 3) mul_out();

    ufp_mult_full u_mul (.in1(mul_in1), .in2(mul_in2), .out(mul_out));

    // ---- Test sfp_mult_full ----
    sfp #(2, 2) smul_in1();
    sfp #(3, 1) smul_in2();
    sfp #(5, 3) smul_out();

    sfp_mult_full u_smul (.in1(smul_in1), .in2(smul_in2), .out(smul_out));

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ==== ufp_sub_full tests (TARGET module) ====

        // Test 1: 10 - 5 = 5
        sub_in1.val = 8'd10 << 4; // 10.0 in Q4.4 = 160
        sub_in2.val = 8'd5 << 4;  // 5.0 in Q4.4 = 80
        #1;
        // Expected: 160 - 80 = 80 (signed)
        if (sub_out.val === $signed(9'd80)) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 1: 10-5, expected 80, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 2: 0 - 0 = 0
        sub_in1.val = 8'd0;
        sub_in2.val = 8'd0;
        #1;
        if (sub_out.val === 9'sd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 2: 0-0, expected 0, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 3: 5 - 10 = -5 (result should be negative)
        sub_in1.val = 8'd80;  // 5.0
        sub_in2.val = 8'd160; // 10.0
        #1;
        if (sub_out.val === -9'sd80) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 3: 5-10, expected -80, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 4: max - 0 = max
        sub_in1.val = 8'hFF;
        sub_in2.val = 8'd0;
        #1;
        if (sub_out.val === $signed({1'b0, 8'hFF})) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 4: 255-0, expected 255, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 5: 0 - max = -max (negative result)
        sub_in1.val = 8'd0;
        sub_in2.val = 8'hFF;
        #1;
        if (sub_out.val === -$signed({1'b0, 8'hFF})) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 5: 0-255, expected -255, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 6: 1 - 1 = 0
        sub_in1.val = 8'd1;
        sub_in2.val = 8'd1;
        #1;
        if (sub_out.val === 9'sd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 6: 1-1, expected 0, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 7: 100 - 50 = 50
        sub_in1.val = 8'd100;
        sub_in2.val = 8'd50;
        #1;
        if (sub_out.val === 9'sd50) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 7: 100-50, expected 50, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 8: 200 - 100 = 100
        sub_in1.val = 8'd200;
        sub_in2.val = 8'd100;
        #1;
        if (sub_out.val === 9'sd100) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sub test 8: 200-100, expected 100, got %0d", sub_out.val);
            fail_count = fail_count + 1;
        end

        // ==== ufp_add_full tests ====

        // Test 9: 10 + 5 = 15
        add_in1.val = 8'd10;
        add_in2.val = 8'd5;
        #1;
        if (add_out.val === 9'd15) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL add test 9: 10+5, expected 15, got %0d", add_out.val);
            fail_count = fail_count + 1;
        end

        // Test 10: 255 + 255 = 510
        add_in1.val = 8'hFF;
        add_in2.val = 8'hFF;
        #1;
        if (add_out.val === 9'd510) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL add test 10: 255+255, expected 510, got %0d", add_out.val);
            fail_count = fail_count + 1;
        end

        // ==== sfp_sub_full tests ====

        // Test 11: 50 - 30 = 20 (signed)
        ssub_in1.val = 8'sd50;
        ssub_in2.val = 8'sd30;
        #1;
        if (ssub_out.val === 9'sd20) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL ssub test 11: 50-30, expected 20, got %0d", ssub_out.val);
            fail_count = fail_count + 1;
        end

        // Test 12: -50 - 30 = -80
        ssub_in1.val = -8'sd50;
        ssub_in2.val = 8'sd30;
        #1;
        if (ssub_out.val === -9'sd80) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL ssub test 12: -50-30, expected -80, got %0d", ssub_out.val);
            fail_count = fail_count + 1;
        end

        // ==== ufp_mult_full tests ====

        // Test 13: 6 * 3 = 18
        mul_in1.val = 4'd6;
        mul_in2.val = 4'd3;
        #1;
        if (mul_out.val === 8'd18) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL mul test 13: 6*3, expected 18, got %0d", mul_out.val);
            fail_count = fail_count + 1;
        end

        // Test 14: 15 * 15 = 225
        mul_in1.val = 4'd15;
        mul_in2.val = 4'd15;
        #1;
        if (mul_out.val === 8'd225) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL mul test 14: 15*15, expected 225, got %0d", mul_out.val);
            fail_count = fail_count + 1;
        end

        // Test 15: 0 * 7 = 0
        mul_in1.val = 4'd0;
        mul_in2.val = 4'd7;
        #1;
        if (mul_out.val === 8'd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL mul test 15: 0*7, expected 0, got %0d", mul_out.val);
            fail_count = fail_count + 1;
        end

        // ==== sfp_mult_full tests ====

        // Test 16: -2 * 3 = -6
        smul_in1.val = -4'sd2;
        smul_in2.val = 4'sd3;
        #1;
        if (smul_out.val === -8'sd6) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL smul test 16: -2*3, expected -6, got %0d", smul_out.val);
            fail_count = fail_count + 1;
        end

        // Test 17: 3 * 3 = 9
        smul_in1.val = 4'sd3;
        smul_in2.val = 4'sd3;
        #1;
        if (smul_out.val === 8'sd9) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL smul test 17: 3*3, expected 9, got %0d", smul_out.val);
            fail_count = fail_count + 1;
        end

        // ==== sfp_add_full tests ====

        // Test 18: 40 + 60 = 100
        sadd_in1.val = 8'sd40;
        sadd_in2.val = 8'sd60;
        #1;
        if (sadd_out.val === 9'sd100) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sadd test 18: 40+60, expected 100, got %0d", sadd_out.val);
            fail_count = fail_count + 1;
        end

        // Test 19: -40 + -60 = -100
        sadd_in1.val = -8'sd40;
        sadd_in2.val = -8'sd60;
        #1;
        if (sadd_out.val === -9'sd100) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sadd test 19: -40+(-60), expected -100, got %0d", sadd_out.val);
            fail_count = fail_count + 1;
        end

        // Test 20: 127 + 127 = 254
        sadd_in1.val = 8'sd127;
        sadd_in2.val = 8'sd127;
        #1;
        if (sadd_out.val === 9'sd254) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL sadd test 20: 127+127, expected 254, got %0d", sadd_out.val);
            fail_count = fail_count + 1;
        end

        // Summary
        if (fail_count == 0)
            $display("[TB_REAL] fp_op_full aligned operand declarations PASSED");
        else
            $display("[TB_REAL] fp_op_full FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
