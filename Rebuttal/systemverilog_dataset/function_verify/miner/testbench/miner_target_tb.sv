`timescale 1ns/1ps

`default_nettype none

// Stub sha_256 module that miner depends on
module sha_256 #(
    parameter MSG_SIZE = 640,
    parameter PADDED_SIZE = 1024
)(
    input  logic [MSG_SIZE-1:0] message,
    input  logic clk,
    input  logic rst,
    output logic [255:0] hashed,
    output logic done
);
    // Simple stub: after reset deasserts, produce a hash after a few cycles.
    // IMPORTANT: The second sha_256 (MSG_SIZE=256) must produce a
    // non-palindromic (non-byte-symmetric) output so that byte-reversal
    // is actually testable. We use a simple scramble that is NOT symmetric
    // at byte level.
    integer count;
    always @(posedge clk) begin
        if (rst) begin
            done <= 0;
            count <= 0;
            hashed <= '0;
        end else begin
            if (count < 5) begin
                count <= count + 1;
                done <= 0;
            end else begin
                // Produce a deterministic hash based on the message.
                // Use a non-trivial transform that yields non-byte-palindromic
                // results, especially for the second hash (MSG_SIZE=256).
                // Rotate by 13 bits and XOR with a non-symmetric constant.
                hashed <= ({message[242:0], message[255:243]} ^
                           256'hA3B1C2D4_E5F60718_293A4B5C_6D7E8F90_01122334_45566778_899AABBC_CDDEEFF0)
                          ^ {message[MSG_SIZE-1 -: 128], message[127:0]};
                done <= 1;
            end
        end
    end
endmodule

`include "../miner_original.sv"

`default_nettype wire

module miner_target_tb;

    logic [639:0] block;
    logic clk, rst;
    logic [255:0] hashed;
    logic done;

    miner dut (
        .block(block),
        .clk(clk),
        .rst(rst),
        .hashed(hashed),
        .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer err = 0;
    integer total_tests = 0;

    // The TARGET is:
    // assign hashed = {secnd_hash[7:0], secnd_hash[15:8], ..., secnd_hash[255:248]};
    // This byte-reverses secnd_hash (which is the second sha_256 output).
    //
    // To test, we drive the miner, wait for done, then verify that hashed is
    // exactly the byte-reversed version of the internal secnd_hash.

    // Function to byte-reverse a 256-bit value
    function automatic [255:0] byte_reverse(input [255:0] val);
        integer i;
        logic [255:0] result;
        for (i = 0; i < 32; i = i + 1) begin
            result[i*8 +: 8] = val[(31-i)*8 +: 8];
        end
        return result;
    endfunction

    task run_test(input integer test_num, input [639:0] test_block);
        logic [255:0] secnd_hash_val;
        logic [255:0] expected;

        rst = 1;
        block = test_block;
        repeat(4) @(posedge clk);
        rst = 0;

        // Wait for done
        repeat(200) @(posedge clk);

        total_tests = total_tests + 1;
        if (done !== 1'b1) begin
            $display("ERROR: Test%0d done not asserted", test_num);
            err = err + 1;
            return;
        end

        // Get the internal secnd_hash value
        secnd_hash_val = dut.secnd_hash;
        expected = byte_reverse(secnd_hash_val);

        // Sanity: secnd_hash should not be all-zero (our stub should avoid that)
        total_tests = total_tests + 1;
        if (secnd_hash_val === 256'h0) begin
            $display("ERROR: Test%0d secnd_hash is all zero - test is not meaningful", test_num);
            err = err + 1;
        end

        // Sanity: secnd_hash should not be byte-palindromic (otherwise test is weak)
        total_tests = total_tests + 1;
        if (expected === secnd_hash_val) begin
            $display("ERROR: Test%0d secnd_hash is byte-palindromic - test is not meaningful", test_num);
            err = err + 1;
        end

        // Core check: hashed must equal byte-reversed secnd_hash
        total_tests = total_tests + 1;
        if (hashed !== expected) begin
            $display("ERROR: Test%0d hashed mismatch", test_num);
            $display("  secnd_hash = %h", secnd_hash_val);
            $display("  expected   = %h", expected);
            $display("  got        = %h", hashed);
            err = err + 1;
        end

        // Additional check: verify specific bytes
        total_tests = total_tests + 1;
        if (hashed[7:0] !== secnd_hash_val[255:248]) begin
            $display("ERROR: Test%0d LSB byte mismatch: got %h expected %h",
                     test_num, hashed[7:0], secnd_hash_val[255:248]);
            err = err + 1;
        end

        total_tests = total_tests + 1;
        if (hashed[255:248] !== secnd_hash_val[7:0]) begin
            $display("ERROR: Test%0d MSB byte mismatch: got %h expected %h",
                     test_num, hashed[255:248], secnd_hash_val[7:0]);
            err = err + 1;
        end

        // Additional check: hashed must NOT equal secnd_hash (since it is non-palindromic)
        total_tests = total_tests + 1;
        if (hashed === secnd_hash_val) begin
            $display("ERROR: Test%0d hashed equals secnd_hash - byte reversal not applied", test_num);
            err = err + 1;
        end
    endtask

    initial begin
        rst = 1;
        block = 640'h0;
        repeat(4) @(posedge clk);

        // Test 1: All zeros
        run_test(1, 640'h0);

        // Test 2: All ones
        run_test(2, {640{1'b1}});

        // Test 3: Pattern A
        run_test(3, {160{4'hA}});

        // Test 4: Pattern 5
        run_test(4, {160{4'h5}});

        // Test 5: Incrementing pattern
        run_test(5, {80{8'h01}});

        // Test 6: 0xDEADBEEF repeating
        run_test(6, {20{32'hDEADBEEF}});

        // Test 7: Single bit set
        run_test(7, 640'h1);

        // Test 8: High bit set
        run_test(8, {1'b1, 639'h0});

        // Test 9: Alternating bytes
        run_test(9, {40{8'hFF, 8'h00}});

        // Test 10: Random-ish pattern
        run_test(10, {16{40'h123456789A}});

        if (err == 0)
            $display("[TB_REAL] miner all %0d tests PASSED", total_tests);
        else
            $display("[TB_REAL] miner FAILED %0d / %0d tests", err, total_tests);
        $finish;
    end

    // Safety timeout
    initial begin
        #500000;
        $display("[TB_REAL] miner FAILED 1 / 1 tests");
        $finish;
    end

endmodule
