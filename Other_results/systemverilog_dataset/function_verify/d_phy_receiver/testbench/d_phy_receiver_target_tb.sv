`timescale 1ns/1ps

// Inline the d_phy_receiver module with always_ff replaced by always
// to avoid VCS "Illegal combination of procedural drivers" errors
// caused by inline initialization combined with always_ff.
module d_phy_receiver #(
    parameter int ZERO_ACCUMULATOR_WIDTH = 3
) (
    input logic clock_p,
    input logic data_p,
    input logic reset,
    output logic [7:0] data,
    output logic enable
);

logic dataout_h = 1'd0, dataout_l = 1'd0;

always @(posedge clock_p) dataout_h <= data_p;
always @(negedge clock_p) dataout_l <= data_p;

logic [8:0] internal_data = 9'd0;

always @(posedge clock_p)
    internal_data <= {dataout_l, dataout_h, internal_data[8:2]};

localparam bit [1:0] STATE_UNKNOWN = 2'd0;
localparam bit [1:0] STATE_SYNC_IN_PHASE = 2'd1;
localparam bit [1:0] STATE_SYNC_OUT_OF_PHASE = 2'd2;
logic [1:0] state = STATE_UNKNOWN;

assign data = state == STATE_SYNC_IN_PHASE ? internal_data[7:0] : state == STATE_SYNC_OUT_OF_PHASE ? internal_data[8:1] : 8'dx;

logic [1:0] counter = 2'd0;

assign enable = state != STATE_UNKNOWN && counter == 2'd0;

logic [ZERO_ACCUMULATOR_WIDTH-1:0] zero_accumulator = ZERO_ACCUMULATOR_WIDTH'(0);
always @(posedge clock_p)
begin
    if (internal_data[1] || internal_data[0])
        zero_accumulator <= ZERO_ACCUMULATOR_WIDTH'(0);
    else if (zero_accumulator + 1'd1 == ZERO_ACCUMULATOR_WIDTH'(0))
        zero_accumulator <= zero_accumulator;
    else
        zero_accumulator <= zero_accumulator + 1'd1;
end

always @(posedge clock_p)
begin
    if (reset)
    begin
        state <= STATE_UNKNOWN;
        counter <= 2'dx;
    end
    else
    begin
        if (state == STATE_UNKNOWN)
        begin
            if (internal_data == 9'b101110000 && zero_accumulator + 1'd1 == ZERO_ACCUMULATOR_WIDTH'(0))
            begin
                state <= STATE_SYNC_OUT_OF_PHASE;
                counter <= 2'd3;
            end
            else if (internal_data[7:0] == 8'b10111000 && zero_accumulator + 1'd1 == ZERO_ACCUMULATOR_WIDTH'(0))
            begin
                state <= STATE_SYNC_IN_PHASE;
                counter <= 2'd3;
            end
            else
            begin
                state <= STATE_UNKNOWN;
                counter <= 2'dx;
            end
        end
        else
        begin
            state <= state;
            counter <= counter - 2'd1;
            `ifdef MODEL_TECH
                if (counter == 2'd0)
                    $display("%h", data);
            `endif
        end
    end
end

endmodule

module d_phy_receiver_target_tb;

    logic clock_p;
    logic data_p;
    logic reset;
    logic [7:0] data;
    logic enable;

    d_phy_receiver #(
        .ZERO_ACCUMULATOR_WIDTH(3)
    ) dut (
        .clock_p(clock_p),
        .data_p(data_p),
        .reset(reset),
        .data(data),
        .enable(enable)
    );

    // Clock: 10ns period
    always #5 clock_p = ~clock_p;

    integer pass_count, fail_count;

    task automatic send_bit(input logic b);
        // Send one DDR bit: data_p changes before posedge
        @(negedge clock_p);
        data_p = b;
    endtask

    initial begin
        clock_p = 0;
        data_p = 0;
        reset = 1;
        pass_count = 0;
        fail_count = 0;

        // Hold reset for a few cycles
        repeat (4) @(posedge clock_p);
        #1;
        reset = 0;

        // ---- Test 1: zero_accumulator increments when data_p stays 0 ----
        // Feed zeros for enough cycles to let zero_accumulator reach near-saturation
        // With WIDTH=3, max value is 7 (3'b111), saturation at value 7 (since +1 == 0 wraps)
        // The accumulator saturates when zero_accumulator + 1 == 0 (i.e., at 3'b111 = 7)
        data_p = 0;
        repeat (20) @(posedge clock_p);
        #1;

        // After 20 cycles of zeros, zero_accumulator should have reached saturation (7)
        // We can check indirectly: the accumulator should be saturated
        // The state should still be UNKNOWN since no sync sequence was sent
        if (dut.state === 2'd0) begin
            $display("  Test 1 PASS: state is UNKNOWN as expected");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 1 FAIL: state should be UNKNOWN, got %0d", dut.state);
            fail_count = fail_count + 1;
        end

        // ---- Test 2: Check zero_accumulator saturation value ----
        // After many zero cycles, accumulator should be at max (all 1s = 7 for width 3)
        if (dut.zero_accumulator === 3'd7) begin
            $display("  Test 2 PASS: zero_accumulator saturated at 7");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 2 FAIL: zero_accumulator should be 7, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Test 3: Non-zero data resets the accumulator ----
        // internal_data is 9-bits shifted 2-bits per cycle from MSB side.
        // data_p=1 needs ~5 posedge cycles to reach internal_data[1:0].
        data_p = 1;
        repeat (6) @(posedge clock_p);
        #1;
        // After enough cycles with data_p=1, internal_data should have non-zero LSBs
        // which resets zero_accumulator to 0
        if (dut.zero_accumulator === 3'd0) begin
            $display("  Test 3 PASS: zero_accumulator reset after non-zero data");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 3 FAIL: zero_accumulator should be 0 after non-zero data, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Test 4: Accumulator increments from 0 when zeros resume ----
        data_p = 0;
        @(posedge clock_p);
        // Need to wait for internal_data LSBs to become 0 (takes a few cycles due to shift register)
        repeat (5) @(posedge clock_p);
        #1;
        // After internal_data becomes all zeros, accumulator should start counting
        // It won't be 0 anymore (should be > 0 if the increment works)
        if (dut.zero_accumulator > 3'd0) begin
            $display("  Test 4 PASS: zero_accumulator incrementing (value=%0d)", dut.zero_accumulator);
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 4 FAIL: zero_accumulator should have incremented from 0, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Test 5: enable should be 0 when in UNKNOWN state ----
        if (enable === 1'b0) begin
            $display("  Test 5 PASS: enable is 0 in UNKNOWN state");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 5 FAIL: enable should be 0 in UNKNOWN state");
            fail_count = fail_count + 1;
        end

        // ---- Test 6: Reset clears state ----
        reset = 1;
        @(posedge clock_p);
        @(posedge clock_p);
        #1;
        if (dut.state === 2'd0) begin
            $display("  Test 6 PASS: reset clears state to UNKNOWN");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 6 FAIL: state should be UNKNOWN after reset");
            fail_count = fail_count + 1;
        end
        reset = 0;

        // ---- Test 7: Accumulator counts up step by step ----
        // Send non-zero to reset accumulator, then send zeros and track
        data_p = 1;
        repeat (5) @(posedge clock_p);
        data_p = 0;
        // Wait for internal_data LSBs to clear
        repeat (6) @(posedge clock_p);
        #1;
        // Record current value
        begin
            logic [2:0] val_before;
            val_before = dut.zero_accumulator;
            @(posedge clock_p);
            #1;
            if (dut.zero_accumulator === val_before + 3'd1 || dut.zero_accumulator === val_before) begin
                // Either incremented by 1 or saturated -- both valid
                $display("  Test 7 PASS: accumulator increments correctly (before=%0d, after=%0d)", val_before, dut.zero_accumulator);
                pass_count = pass_count + 1;
            end else begin
                $display("  Test 7 FAIL: accumulator increment wrong (before=%0d, after=%0d)", val_before, dut.zero_accumulator);
                fail_count = fail_count + 1;
            end
        end

        // ---- Test 8: Accumulator does not exceed saturation ----
        data_p = 0;
        repeat (30) @(posedge clock_p);
        #1;
        if (dut.zero_accumulator === 3'd7) begin
            $display("  Test 8 PASS: accumulator stays saturated at 7");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 8 FAIL: accumulator should saturate at 7, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Test 9: Verify accumulator doesn't wrap past saturation ----
        repeat (10) @(posedge clock_p);
        #1;
        if (dut.zero_accumulator === 3'd7) begin
            $display("  Test 9 PASS: accumulator still saturated after more cycles");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 9 FAIL: accumulator should still be 7, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Test 10: Non-zero data eventually resets accumulator ----
        // Need enough cycles of data_p=1 for 1s to propagate through
        // the 9-bit shift register to internal_data[1:0]
        data_p = 1;
        repeat (7) @(posedge clock_p);
        #1;
        if (dut.zero_accumulator === 3'd0) begin
            $display("  Test 10 PASS: non-zero data resets accumulator to 0");
            pass_count = pass_count + 1;
        end else begin
            $display("  Test 10 FAIL: accumulator should be 0 with sustained non-zero data, got %0d", dut.zero_accumulator);
            fail_count = fail_count + 1;
        end

        // ---- Summary ----
        if (fail_count == 0)
            $display("[TB_REAL] d_phy_receiver zero_accumulator increment PASSED");
        else
            $display("[TB_REAL] d_phy_receiver FAILED %0d / %0d tests", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule
