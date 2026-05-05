`timescale 1ns/1ps
`include "../fp_convert_original.sv"

module fp_convert_target_tb;

    // ---- Test creal_to_sfp: convert real constant to signed fixed point ----
    // sfp #(iw=4, qw=4) => wl=8, range is [-8.0, 7.9375] with step 0.0625
    // Test with float=1.5: ival = longint'(1.5 * 16) = 24 = 8'b00011000
    sfp #(4, 4) fp_1p5();
    creal_to_sfp #(.float(1.5)) u_1p5 (.fp(fp_1p5));

    // Test with float=-2.0: ival = longint'(-2.0 * 16) = -32 = 8'b11100000
    sfp #(4, 4) fp_n2p0();
    creal_to_sfp #(.float(-2.0)) u_n2p0 (.fp(fp_n2p0));

    // Test with float=0.0: ival = 0
    sfp #(4, 4) fp_0p0();
    creal_to_sfp #(.float(0.0)) u_0p0 (.fp(fp_0p0));

    // Test with float=0.25: ival = longint'(0.25 * 16) = 4
    sfp #(4, 4) fp_0p25();
    creal_to_sfp #(.float(0.25)) u_0p25 (.fp(fp_0p25));

    // Test with float=-0.5: ival = longint'(-0.5 * 16) = -8
    sfp #(4, 4) fp_n0p5();
    creal_to_sfp #(.float(-0.5)) u_n0p5 (.fp(fp_n0p5));

    // Test with float=7.0: ival = longint'(7.0 * 16) = 112
    sfp #(4, 4) fp_7p0();
    creal_to_sfp #(.float(7.0)) u_7p0 (.fp(fp_7p0));

    // Test with float=-8.0: ival = longint'(-8.0 * 16) = -128 (min for 8-bit signed)
    sfp #(4, 4) fp_n8p0();
    creal_to_sfp #(.float(-8.0)) u_n8p0 (.fp(fp_n8p0));

    // Test with float=3.75: ival = longint'(3.75 * 16) = 60
    sfp #(4, 4) fp_3p75();
    creal_to_sfp #(.float(3.75)) u_3p75 (.fp(fp_3p75));

    // ---- Test creal_to_ufp: convert real constant to unsigned fixed point ----
    // ufp #(iw=4, qw=4) => wl=8, range is [0, 15.9375] with step 0.0625
    ufp #(4, 4) ufp_2p5();
    creal_to_ufp #(.float(2.5)) u_ufp_2p5 (.fp(ufp_2p5));

    ufp #(4, 4) ufp_0p0();
    creal_to_ufp #(.float(0.0)) u_ufp_0p0 (.fp(ufp_0p0));

    // ---- Test ufp_to_sfp_full ----
    ufp #(2, 2) in_u();
    sfp #(3, 2) out_s();
    ufp_to_sfp_full u_ufp_to_sfp (.in(in_u), .out(out_s));

    integer pass_count, fail_count;

    initial begin
        pass_count = 0;
        fail_count = 0;

        #1;

        // Test creal_to_sfp: float=1.5, qw=4 => ival=24
        if (fp_1p5.val === 8'sd24) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp 1.5 => expected 24, got %0d", fp_1p5.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=-2.0, qw=4 => ival=-32
        if (fp_n2p0.val === -8'sd32) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp -2.0 => expected -32, got %0d", $signed(fp_n2p0.val));
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=0.0 => ival=0
        if (fp_0p0.val === 8'sd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp 0.0 => expected 0, got %0d", fp_0p0.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=0.25, qw=4 => ival=4
        if (fp_0p25.val === 8'sd4) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp 0.25 => expected 4, got %0d", fp_0p25.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=-0.5, qw=4 => ival=-8
        if (fp_n0p5.val === -8'sd8) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp -0.5 => expected -8, got %0d", $signed(fp_n0p5.val));
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=7.0, qw=4 => ival=112
        if (fp_7p0.val === 8'sd112) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp 7.0 => expected 112, got %0d", fp_7p0.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=-8.0, qw=4 => ival=-128
        if (fp_n8p0.val === -8'sd128) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp -8.0 => expected -128, got %0d", $signed(fp_n8p0.val));
            fail_count = fail_count + 1;
        end

        // Test creal_to_sfp: float=3.75, qw=4 => ival=60
        if (fp_3p75.val === 8'sd60) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_sfp 3.75 => expected 60, got %0d", fp_3p75.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_ufp: float=2.5, qw=4 => ival=40
        if (ufp_2p5.val === 8'd40) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_ufp 2.5 => expected 40, got %0d", ufp_2p5.val);
            fail_count = fail_count + 1;
        end

        // Test creal_to_ufp: float=0.0 => ival=0
        if (ufp_0p0.val === 8'd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: creal_to_ufp 0.0 => expected 0, got %0d", ufp_0p0.val);
            fail_count = fail_count + 1;
        end

        // Test ufp_to_sfp_full
        in_u.val = 4'd5;
        #1;
        if (out_s.val === $signed({1'b0, 4'd5})) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: ufp_to_sfp_full 5 => expected %0d, got %0d", $signed({1'b0, 4'd5}), out_s.val);
            fail_count = fail_count + 1;
        end

        in_u.val = 4'd15;
        #1;
        if (out_s.val === $signed({1'b0, 4'd15})) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: ufp_to_sfp_full 15 => expected %0d, got %0d", $signed({1'b0, 4'd15}), out_s.val);
            fail_count = fail_count + 1;
        end

        in_u.val = 4'd0;
        #1;
        if (out_s.val === 5'sd0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: ufp_to_sfp_full 0 => expected 0, got %0d", out_s.val);
            fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("[TB_REAL] fp_convert parameter/generate block PASSED");
        else
            $display("[TB_REAL] fp_convert FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
