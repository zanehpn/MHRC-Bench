`timescale 1ns/1ps
`include "../clip_original.sv"

module clip_target_tb;

    // ---- Parameters ----
    localparam INW  = 10;
    localparam OUTW = 8;
    localparam NUM_TESTS = 20;

    // ---- Signed DUT ----
    logic signed [INW-1:0]  s_in;
    logic signed [OUTW-1:0] s_out;
    logic                   s_clipping;

    clip_signed #(.inw(INW), .outw(OUTW)) dut_s (
        .in(s_in), .out(s_out), .clipping(s_clipping)
    );

    // ---- Unsigned DUT (to prevent zero-width default elaboration) ----
    logic [INW-1:0]  u_in;
    logic [OUTW-1:0] u_out;
    logic             u_clipping;

    clip_unsigned #(.inw(INW), .outw(OUTW)) dut_u (
        .in(u_in), .out(u_out), .clipping(u_clipping)
    );

    // ---- Reference values ----
    logic signed [OUTW-1:0] maxval = {1'b0, {(OUTW-1){1'b1}}};  // +127
    logic signed [OUTW-1:0] minval = {1'b1, {(OUTW-1){1'b0}}};  // -128

    integer pass_count, fail_count;

    // Expected output for signed clip
    function automatic logic signed [OUTW-1:0] expected_signed(input logic signed [INW-1:0] val);
        if (val > $signed({{(INW-OUTW){1'b0}}, maxval}))
            return maxval;
        else if (val < $signed({{(INW-OUTW){1'b1}}, minval}))
            return minval;
        else
            return val[OUTW-1:0];
    endfunction

    task check_signed(input logic signed [INW-1:0] test_val);
        logic signed [OUTW-1:0] exp;
        logic exp_clip;
        s_in = test_val;
        #1;
        exp = expected_signed(test_val);
        exp_clip = (s_out == maxval && test_val > $signed({{(INW-OUTW){1'b0}}, maxval})) ||
                   (s_out == minval && test_val < $signed({{(INW-OUTW){1'b1}}, minval}));
        if (s_out !== exp) begin
            $display("FAIL signed: in=%0d, expected out=%0d, got out=%0d", test_val, exp, s_out);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
    endtask

    // Expected output for unsigned clip
    function automatic logic [OUTW-1:0] expected_unsigned(input logic [INW-1:0] val);
        if (val > {OUTW{1'b1}})
            return {OUTW{1'b1}};
        else
            return val[OUTW-1:0];
    endfunction

    task check_unsigned(input logic [INW-1:0] test_val);
        logic [OUTW-1:0] exp;
        u_in = test_val;
        #1;
        exp = expected_unsigned(test_val);
        if (u_out !== exp) begin
            $display("FAIL unsigned: in=%0d, expected out=%0d, got out=%0d", test_val, exp, u_out);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // Signed tests: positive clipping
        check_signed(10'sd200);   // > 127 => clip to 127
        check_signed(10'sd300);   // > 127 => clip to 127
        check_signed(10'sd128);   // > 127 => clip to 127
        check_signed(10'sd511);   // max positive 10-bit signed

        // Signed tests: negative clipping
        check_signed(-10'sd200);  // < -128 => clip to -128
        check_signed(-10'sd300);  // < -128 => clip to -128
        check_signed(-10'sd129);  // < -128 => clip to -128
        check_signed(-10'sd512);  // min 10-bit signed

        // Signed tests: passthrough (no clipping)
        check_signed(10'sd0);
        check_signed(10'sd1);
        check_signed(-10'sd1);
        check_signed(10'sd127);   // max positive in 8-bit
        check_signed(-10'sd128);  // min negative in 8-bit
        check_signed(10'sd50);
        check_signed(-10'sd50);
        check_signed(10'sd100);

        // Unsigned tests: clipping
        check_unsigned(10'd300);  // > 255 => clip to 255
        check_unsigned(10'd256);  // > 255 => clip to 255
        check_unsigned(10'd1023); // max 10-bit unsigned

        // Unsigned tests: passthrough
        check_unsigned(10'd0);
        check_unsigned(10'd1);
        check_unsigned(10'd255);  // max 8-bit unsigned, no clip
        check_unsigned(10'd128);
        check_unsigned(10'd200);

        if (fail_count == 0)
            $display("[TB_REAL] clip clipping logic PASSED");
        else
            $display("[TB_REAL] clip FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
