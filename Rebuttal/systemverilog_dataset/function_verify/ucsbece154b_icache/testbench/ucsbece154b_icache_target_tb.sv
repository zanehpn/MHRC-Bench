`timescale 1ns/1ps
`include "../ucsbece154b_icache_original.sv"

// Tests the VICTIM_MISS state FSM logic.
// TARGET: VICTIM_MISS state body should set cmp_en_d=0, mem_data_req_o=1,
// and transition to MISS on mem_data_ack_i.
// Wrong code: state_d = VICTIM_MISS (self-assignment, no mem_data_req_o, no transition)

module ucsbece154b_icache_target_tb;
    logic clk, rst_n;
    logic flush_i, en_i;
    logic fetch_valid, dreq_req, dreq_kill_s1, dreq_kill_s2, dreq_spec, addr_ni;
    logic cl_hit_any, exception_valid;
    logic mem_rtrn_vld_i, mem_rtrn_is_inv, mem_rtrn_is_ifill;
    logic mem_data_ack_i, paddr_is_nc;
    logic victim_cache_hit, all_ways_valid, inv_q;

    logic dreq_ready, dreq_valid, fetch_req, mem_data_req_o, miss_o, cache_wren, victim_cache_we;
    logic cmp_en_out;
    logic [3:0] state_out;

    icache_fsm_model dut (
        .clk_i(clk), .rst_ni(rst_n),
        .flush_i(flush_i), .en_i(en_i),
        .fetch_valid(fetch_valid), .dreq_req(dreq_req),
        .dreq_kill_s1(dreq_kill_s1), .dreq_kill_s2(dreq_kill_s2),
        .dreq_spec(dreq_spec), .addr_ni(addr_ni),
        .cl_hit_any(cl_hit_any), .exception_valid(exception_valid),
        .mem_rtrn_vld_i(mem_rtrn_vld_i), .mem_rtrn_is_inv(mem_rtrn_is_inv),
        .mem_rtrn_is_ifill(mem_rtrn_is_ifill),
        .mem_data_ack_i(mem_data_ack_i), .paddr_is_nc(paddr_is_nc),
        .victim_cache_hit(victim_cache_hit), .all_ways_valid(all_ways_valid),
        .inv_q(inv_q),
        .dreq_ready(dreq_ready), .dreq_valid(dreq_valid),
        .fetch_req(fetch_req), .mem_data_req_o(mem_data_req_o),
        .miss_o(miss_o), .cache_wren(cache_wren),
        .victim_cache_we(victim_cache_we), .cmp_en_out(cmp_en_out),
        .state_out(state_out)
    );

    always #5 clk = ~clk;

    // State encoding
    localparam FLUSH = 4'd0, IDLE = 4'd1, READ = 4'd2, MISS = 4'd3;
    localparam KILL_ATRANS = 4'd4, KILL_MISS = 4'd5, VICTIM_HIT = 4'd6, VICTIM_MISS = 4'd7;

    integer pass_count = 0;
    integer fail_count = 0;
    integer total_tests = 0;

    task automatic check(input string name, input logic cond);
        total_tests = total_tests + 1;
        if (cond) pass_count = pass_count + 1;
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s (state=%0d, mem_req=%0b, cmp_en=%0b)", name, state_out, mem_data_req_o, cmp_en_out);
        end
    endtask

    task automatic reset_all();
        rst_n = 0;
        flush_i = 0; en_i = 1;
        fetch_valid = 0; dreq_req = 0; dreq_kill_s1 = 0; dreq_kill_s2 = 0;
        dreq_spec = 0; addr_ni = 0;
        cl_hit_any = 0; exception_valid = 0;
        mem_rtrn_vld_i = 0; mem_rtrn_is_inv = 0; mem_rtrn_is_ifill = 0;
        mem_data_ack_i = 0; paddr_is_nc = 0;
        victim_cache_hit = 0; all_ways_valid = 0; inv_q = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        // Wait for FLUSH to complete (16 cycles)
        repeat(20) @(posedge clk);
    endtask

    task automatic go_to_victim_miss();
        // Navigate: IDLE -> READ -> VICTIM_MISS
        dreq_req = 1;
        @(posedge clk); // should transition to READ
        dreq_req = 0;
        @(posedge clk);
        // In READ: set fetch_valid, no hit, no victim hit, all_ways_valid
        fetch_valid = 1;
        cl_hit_any = 0;
        victim_cache_hit = 0;
        all_ways_valid = 1;
        inv_q = 0;
        @(posedge clk); // should transition to VICTIM_MISS
        fetch_valid = 0;
        all_ways_valid = 0;
        @(posedge clk);
    endtask

    initial begin
        clk = 0;
        reset_all();

        // Verify we're in IDLE
        check("start_idle", state_out == IDLE);

        // Test 1: Navigate to VICTIM_MISS state
        go_to_victim_miss();
        check("reached_victim_miss", state_out == VICTIM_MISS);

        // Test 2: In VICTIM_MISS, mem_data_req_o MUST be asserted
        // Wrong code (state_d = VICTIM_MISS) would leave mem_data_req_o at default 0
        check("vm_mem_req_asserted", mem_data_req_o == 1'b1);

        // Test 3: In VICTIM_MISS, cmp_en_d should be 0
        check("vm_cmp_en_zero", cmp_en_out == 1'b0);

        // Test 4: Without ack, should stay in VICTIM_MISS
        mem_data_ack_i = 0;
        @(posedge clk);
        check("vm_stays_no_ack", state_out == VICTIM_MISS);
        check("vm_req_persistent", mem_data_req_o == 1'b1);

        // Test 5: With ack and cacheable, transition to MISS with miss_o=1
        mem_data_ack_i = 1;
        paddr_is_nc = 0;
        #1; // combinational check before clock
        check("vm_miss_signal", miss_o == 1'b1);
        check("vm_mem_req_with_ack", mem_data_req_o == 1'b1);
        @(posedge clk);
        mem_data_ack_i = 0;
        @(posedge clk); #1;
        check("vm_to_miss", state_out == MISS);

        // Test 6: Complete MISS -> IDLE
        mem_rtrn_vld_i = 1;
        mem_rtrn_is_ifill = 1;
        @(posedge clk);
        mem_rtrn_vld_i = 0;
        mem_rtrn_is_ifill = 0;
        @(posedge clk);
        check("miss_to_idle", state_out == IDLE);

        // Test 7: VICTIM_MISS with NC address - miss_o should be 0
        reset_all();
        go_to_victim_miss();
        check("vm_state_7", state_out == VICTIM_MISS);
        paddr_is_nc = 1;
        mem_data_ack_i = 1;
        #1;
        check("vm_nc_no_miss", miss_o == 1'b0);
        check("vm_nc_mem_req", mem_data_req_o == 1'b1);
        @(posedge clk);
        mem_data_ack_i = 0;
        paddr_is_nc = 0;
        @(posedge clk);
        check("vm_nc_to_miss", state_out == MISS);

        // Test 8: VICTIM_MISS holds for multiple cycles without ack
        reset_all();
        go_to_victim_miss();
        mem_data_ack_i = 0;
        repeat(5) begin
            @(posedge clk);
            check("vm_hold", state_out == VICTIM_MISS);
            check("vm_hold_mem_req", mem_data_req_o == 1'b1);
        end

        // Test 9: Eventually ack arrives
        mem_data_ack_i = 1;
        paddr_is_nc = 0;
        @(posedge clk);
        mem_data_ack_i = 0;
        @(posedge clk);
        check("vm_delayed_ack_miss", state_out == MISS);

        // Test 10: Full path IDLE->READ->VICTIM_MISS->MISS->IDLE
        reset_all();
        go_to_victim_miss();
        mem_data_ack_i = 1;
        paddr_is_nc = 0;
        @(posedge clk);
        mem_data_ack_i = 0;
        @(posedge clk);
        check("full_path_miss", state_out == MISS);
        mem_rtrn_vld_i = 1;
        mem_rtrn_is_ifill = 1;
        @(posedge clk);
        mem_rtrn_vld_i = 0;
        mem_rtrn_is_ifill = 0;
        @(posedge clk);
        check("full_path_idle", state_out == IDLE);

        if (fail_count == 0)
            $display("[TB_REAL] ucsbece154b_icache all %0d tests PASSED", pass_count);
        else
            $display("[TB_REAL] ucsbece154b_icache FAILED %0d / %0d tests", fail_count, total_tests);
        $finish;
    end

    initial begin
        #100000;
        $display("[TB_REAL] ucsbece154b_icache FAILED - timeout");
        $finish;
    end
endmodule
