`timescale 1ns/1ps
`include "../ffd_synchro_original.v"
`timescale 1ns/1ps

module ffd_synchro_target_tb;

    logic aclk;
    logic arstn;
    logic tvalid_i;
    wire  tvalid_o;

    ffd_synchro dut (
        .aclk(aclk),
        .arstn(arstn),
        .tvalid_i(tvalid_i),
        .tvalid_o(tvalid_o)
    );

    always #5 aclk = ~aclk;

    integer pass_count, fail_count;

    task automatic check(input string msg, input logic expected);
        if (tvalid_o !== expected) begin
            $display("FAIL: %s - expected %b, got %b", msg, expected, tvalid_o);
            fail_count = fail_count + 1;
        end else begin
            pass_count = pass_count + 1;
        end
    endtask

    initial begin
        aclk = 0;
        arstn = 0;
        tvalid_i = 0;
        pass_count = 0;
        fail_count = 0;

        // Test 1-2: Reset behavior - output should be 0
        @(posedge aclk); #1;
        check("reset cycle 1: output should be 0", 1'b0);
        @(posedge aclk); #1;
        check("reset cycle 2: output should be 0", 1'b0);

        // Release reset
        arstn = 1;

        // Test 3: input=0, output stays 0
        tvalid_i = 0;
        @(posedge aclk); #1;
        check("after reset release, input=0, output=0", 1'b0);

        // Test 4: Set input=1, first clock - output still 0 (needs 2 stages)
        tvalid_i = 1;
        @(posedge aclk); #1;
        check("input=1 after 1 clock: output should be 0 (1st stage)", 1'b0);

        // Test 5: Second clock with input=1 - output becomes 1
        @(posedge aclk); #1;
        check("input=1 after 2 clocks: output should be 1 (2nd stage)", 1'b1);

        // Test 6: Keep input=1, output stays 1
        @(posedge aclk); #1;
        check("input=1 sustained: output stays 1", 1'b1);

        // Test 7: Drop input to 0, output still 1 (pipeline delay)
        tvalid_i = 0;
        @(posedge aclk); #1;
        check("input=0 after 1 clock: output still 1 (pipeline)", 1'b1);

        // Test 8: Second clock with input=0, output goes to 0
        @(posedge aclk); #1;
        check("input=0 after 2 clocks: output should be 0", 1'b0);

        // Test 9: Output stays 0
        @(posedge aclk); #1;
        check("input=0 sustained: output stays 0", 1'b0);

        // Test 10: Pulse input for one cycle only
        tvalid_i = 1;
        @(posedge aclk); #1;
        check("pulse: input=1, 1 clock, output=0", 1'b0);
        tvalid_i = 0;
        @(posedge aclk); #1;
        check("pulse: input back to 0, output=1 (delayed)", 1'b1);
        @(posedge aclk); #1;
        check("pulse: after 2nd clock, output=0", 1'b0);

        // Test 13: Async reset mid-operation
        tvalid_i = 1;
        @(posedge aclk); #1;
        @(posedge aclk); #1;
        // Now output should be 1
        check("before async reset: output=1", 1'b1);
        arstn = 0;
        #2;
        check("during async reset: output=0", 1'b0);
        @(posedge aclk); #1;
        check("async reset held: output=0", 1'b0);

        // Test 16: Release reset with input still high
        arstn = 1;
        @(posedge aclk); #1;
        check("after reset release with input=1: output=0 (1st stage)", 1'b0);
        @(posedge aclk); #1;
        check("after reset release with input=1: output=1 (2nd stage)", 1'b1);

        // Test 18-20: Toggle input rapidly (set between posedges to avoid races)
        tvalid_i = 0;
        @(posedge aclk); #1;
        tvalid_i = 1;
        @(posedge aclk); #1;
        tvalid_i = 0;
        @(posedge aclk); #1;
        tvalid_i = 1;
        @(posedge aclk); #1;
        // Trace: before toggle, synchro={1,1}
        // posedge 1 (in=0): synchro <= {1,0}, out=1
        // posedge 2 (in=1): synchro <= {0,1}, out=0
        // posedge 3 (in=0): synchro <= {1,0}, out=1
        // posedge 4 (in=1): synchro <= {0,1}, out=0
        check("rapid toggle: output reflects 2-stage delay", 1'b0);
        @(posedge aclk); #1;
        check("rapid toggle +1: output=1", 1'b1);

        if (fail_count == 0)
            $display("[TB_REAL] ffd_synchro synchronizer shift register PASSED");
        else
            $display("[TB_REAL] ffd_synchro FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
