`timescale 1ns/1ps
`include "../flat_original.sv"

module flat_target_tb;

    // Use parameters where total is NOT a power of 2 to avoid counter width bug
    // total = DIMENSION * img_width * img_height = 2 * 3 * 2 = 12
    // $clog2(12) = 4 bits, max 15, so counter can reach 12
    parameter PIX_WIDTH  = 8;
    parameter DIMENSION  = 2;
    parameter logic [11:0] img_width  = 3;
    parameter logic [11:0] img_height = 2;

    localparam TOTAL_PIXELS = DIMENSION * img_width * img_height; // 12
    localparam FILL_CYCLES  = img_width * img_height;             // 6

    logic clk, clk_en, rst_n;
    logic [DIMENSION-1:0][PIX_WIDTH-1:0] i_data;
    logic i_valid, i_sop, i_eop;
    logic [PIX_WIDTH-1:0] o_data;
    logic o_valid, o_sop, o_eop, o_ready;

    flat #(
        .PIX_WIDTH(PIX_WIDTH),
        .DIMENSION(DIMENSION),
        .img_width(img_width),
        .img_height(img_height)
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
        .o_ready(o_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count, fail_count;
    integer out_count;
    integer saw_sop, saw_eop;
    integer cycle;
    integer i;

    initial begin
        pass_count = 0;
        fail_count = 0;
        clk_en = 1;
        rst_n = 0;
        i_valid = 0;
        i_sop = 0;
        i_eop = 0;
        i_data = '0;

        // Apply reset
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst_n = 1;
        // Wait for first clk_en cycle to establish defaults
        @(posedge clk); #1;
        @(posedge clk); #1;

        // Test 1: After reset, o_valid should be 0
        if (o_valid === 1'b0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 1: o_valid should be 0 after reset, got %b", o_valid);
            fail_count = fail_count + 1;
        end

        // Test 2: o_ready should be 1 in IDLE
        if (o_ready === 1'b1) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 2: o_ready should be 1 in IDLE state, got %b", o_ready);
            fail_count = fail_count + 1;
        end

        // Test 3: Feed valid data with sop - should transition to FILL
        // Set inputs BETWEEN posedges (after #1 delay) to avoid race conditions
        i_valid = 1; i_sop = 1; i_eop = 0;
        i_data[0] = 8'hA1; i_data[1] = 8'hB1;
        @(posedge clk); #1;
        // After this clock, should be in FILL state, o_valid cleared
        i_sop = 0;
        if (o_valid === 1'b0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 3: o_valid should be 0 during FILL, got %b", o_valid);
            fail_count = fail_count + 1;
        end

        // Continue feeding data (need FILL_CYCLES total including sop cycle)
        // Already sent 1 cycle (sop). Need 5 more, with eop on the last.
        i_data[0] = 8'hA2; i_data[1] = 8'hB2;
        @(posedge clk); #1;

        i_data[0] = 8'hA3; i_data[1] = 8'hB3;
        @(posedge clk); #1;

        i_data[0] = 8'hA4; i_data[1] = 8'hB4;
        @(posedge clk); #1;

        i_data[0] = 8'hA5; i_data[1] = 8'hB5;
        @(posedge clk); #1;

        // Last data cycle with eop
        i_eop = 1;
        i_data[0] = 8'hA6; i_data[1] = 8'hB6;
        @(posedge clk); #1;
        i_valid = 0; i_sop = 0; i_eop = 0;

        // Test 4-7: Wait for RELEASE phase and count outputs
        out_count = 0;
        saw_sop = 0;
        saw_eop = 0;
        for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if (o_valid) begin
                out_count = out_count + 1;
                if (o_sop) saw_sop = 1;
                if (o_eop) begin
                    saw_eop = 1;
                    cycle = 200; // break
                end
            end
        end

        // Test 4: Should have received outputs
        if (out_count > 0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 4: no valid outputs received");
            fail_count = fail_count + 1;
        end

        // Test 5: Expected output count = TOTAL_PIXELS = 12
        if (out_count == TOTAL_PIXELS) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 5: expected %0d outputs, got %0d", TOTAL_PIXELS, out_count);
            fail_count = fail_count + 1;
        end

        // Test 6: SOP was asserted
        if (saw_sop) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 6: never saw o_sop");
            fail_count = fail_count + 1;
        end

        // Test 7: EOP was asserted
        if (saw_eop) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 7: never saw o_eop");
            fail_count = fail_count + 1;
        end

        // Test 8: After RELEASE completes, should return to IDLE with o_ready=1
        // Need to wait a few cycles for transition through o_cntr==TOTAL cycle
        repeat (5) @(posedge clk);
        #1;
        if (o_ready === 1'b1) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 8: o_ready should be 1 after returning to IDLE, got %b", o_ready);
            fail_count = fail_count + 1;
        end

        // Test 9: o_valid should be 0 in IDLE
        if (o_valid === 1'b0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 9: o_valid should be 0 in IDLE, got %b", o_valid);
            fail_count = fail_count + 1;
        end

        // Test 10: Second transaction
        i_valid = 1; i_sop = 1; i_eop = 0;
        i_data[0] = 8'h11; i_data[1] = 8'h22;
        @(posedge clk); #1;
        i_sop = 0;
        i_data[0] = 8'h33; i_data[1] = 8'h44;
        @(posedge clk); #1;
        i_data[0] = 8'h55; i_data[1] = 8'h66;
        @(posedge clk); #1;
        i_data[0] = 8'h77; i_data[1] = 8'h88;
        @(posedge clk); #1;
        i_data[0] = 8'h99; i_data[1] = 8'hAA;
        @(posedge clk); #1;
        i_eop = 1;
        i_data[0] = 8'hBB; i_data[1] = 8'hCC;
        @(posedge clk); #1;
        i_valid = 0; i_sop = 0; i_eop = 0;

        out_count = 0;
        saw_sop = 0;
        saw_eop = 0;
        for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if (o_valid) begin
                out_count = out_count + 1;
                if (o_sop) saw_sop = 1;
                if (o_eop) begin
                    saw_eop = 1;
                    cycle = 200;
                end
            end
        end

        if (out_count == TOTAL_PIXELS && saw_sop && saw_eop) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 10: second transaction output count=%0d, sop=%0d, eop=%0d",
                     out_count, saw_sop, saw_eop);
            fail_count = fail_count + 1;
        end

        // Test 11: Test with clk_en disabled
        repeat (3) @(posedge clk); #1;
        clk_en = 0;
        i_valid = 1; i_sop = 1; i_eop = 0;
        i_data[0] = 8'hFF; i_data[1] = 8'hEE;
        repeat (5) @(posedge clk);
        #1;
        clk_en = 1;
        i_valid = 0; i_sop = 0; i_eop = 0;
        @(posedge clk);
        #1;
        if (o_valid === 1'b0) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL Test 11: o_valid should be 0 after clk_en re-enable");
            fail_count = fail_count + 1;
        end

        // Summary
        if (fail_count == 0)
            $display("[TB_REAL] flat state register reset logic PASSED");
        else
            $display("[TB_REAL] flat FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
