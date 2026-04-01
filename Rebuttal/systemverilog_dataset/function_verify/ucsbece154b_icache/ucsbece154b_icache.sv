// Standalone FSM model extracted from cva6_icache (ucsbece154b_icache)
// This replicates the exact FSM logic from the original module for testability.

module icache_fsm_model (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic en_i,
    input  logic fetch_valid,
    input  logic dreq_req,
    input  logic dreq_kill_s1,
    input  logic dreq_kill_s2,
    input  logic dreq_spec,
    input  logic addr_ni,
    input  logic cl_hit_any,
    input  logic exception_valid,
    input  logic mem_rtrn_vld_i,
    input  logic mem_rtrn_is_inv,
    input  logic mem_rtrn_is_ifill,
    input  logic mem_data_ack_i,
    input  logic paddr_is_nc,
    input  logic victim_cache_hit,
    input  logic all_ways_valid,
    input  logic inv_q,

    output logic dreq_ready,
    output logic dreq_valid,
    output logic fetch_req,
    output logic mem_data_req_o,
    output logic miss_o,
    output logic cache_wren,
    output logic victim_cache_we,
    output logic cmp_en_out,
    output logic [3:0] state_out
);

    typedef enum logic[3:0] {FLUSH, IDLE, READ, MISS, KILL_ATRANS, KILL_MISS, VICTIM_HIT, VICTIM_MISS} state_e;
    state_e state_d, state_q;

    logic cache_en_d, cache_en_q;
    logic flush_d, flush_q;
    logic cmp_en_d;
    logic flush_en;
    logic cache_rden;
    logic inv_en;

    // Simplified flush counter
    logic [3:0] flush_cnt_q;
    logic flush_done;
    assign flush_done = (flush_cnt_q == 4'd15);

    assign state_out = state_q;
    assign cmp_en_out = cmp_en_d;

    always_comb begin
        state_d = state_q;
        cache_en_d = cache_en_q & en_i;
        flush_en = 1'b0;
        cmp_en_d = 1'b0;
        cache_rden = 1'b0;
        cache_wren = 1'b0;
        inv_en = 1'b0;
        flush_d = flush_q | flush_i;
        victim_cache_we = 1'b0;

        dreq_ready = 1'b0;
        fetch_req = 1'b0;
        dreq_valid = 1'b0;
        mem_data_req_o = 1'b0;
        miss_o = 1'b0;

        if (mem_rtrn_vld_i && mem_rtrn_is_inv) begin
            inv_en = 1'b1;
        end

        unique case (state_q)
            FLUSH: begin
                flush_en = 1'b1;
                if (flush_done) begin
                    state_d = IDLE;
                    flush_d = 1'b0;
                    cache_en_d = en_i;
                end
            end
            IDLE: begin
                cmp_en_d = cache_en_q;
                if (flush_d || (en_i && !cache_en_q)) begin
                    state_d = FLUSH;
                end else begin
                    if (!mem_rtrn_vld_i) begin
                        dreq_ready = 1'b1;
                        if (dreq_req) begin
                            cache_rden = 1'b1;
                            state_d = READ;
                        end
                    end
                    if (dreq_kill_s1) state_d = IDLE;
                end
            end
            READ: begin
                fetch_req = 1'b1;
                cmp_en_d = cache_en_q;
                cache_rden = cache_en_q;

                if (fetch_valid && (!dreq_spec || !addr_ni)) begin
                    if (flush_d) begin
                        state_d = IDLE;
                    end else if (((cl_hit_any && cache_en_q) || exception_valid) && !inv_q) begin
                        dreq_valid = ~dreq_kill_s2;
                        state_d = IDLE;
                        if (!mem_rtrn_vld_i) begin
                            dreq_ready = 1'b1;
                            if (dreq_req) state_d = READ;
                        end
                        if (dreq_kill_s1) state_d = IDLE;
                    end else if (victim_cache_hit) begin
                        state_d = VICTIM_HIT;
                        victim_cache_we = 1'b1;
                    end else if (dreq_kill_s2) begin
                        state_d = IDLE;
                    end else if (!inv_q) begin
                        if (all_ways_valid) begin
                            state_d = VICTIM_MISS;
                            victim_cache_we = 1'b1;
                        end else begin
                            cmp_en_d = 1'b0;
                            mem_data_req_o = 1'b1;
                            if (mem_data_ack_i) begin
                                miss_o = ~paddr_is_nc;
                                state_d = MISS;
                            end
                        end
                    end
                end else if (dreq_kill_s2 || flush_d) begin
                    state_d = KILL_ATRANS;
                end
            end
            MISS: begin
                if (mem_rtrn_vld_i && mem_rtrn_is_ifill) begin
                    state_d = IDLE;
                    if (!(dreq_kill_s2 || flush_d)) begin
                        dreq_valid = 1'b1;
                        cache_wren = ~paddr_is_nc;
                    end
                end else if (dreq_kill_s2 || flush_d) begin
                    state_d = KILL_MISS;
                end
            end
            KILL_ATRANS: begin
                fetch_req = 1'b1;
                if (fetch_valid) state_d = IDLE;
            end
            KILL_MISS: begin
                if (mem_rtrn_vld_i && mem_rtrn_is_ifill) state_d = IDLE;
            end
            VICTIM_HIT: begin
                cache_wren = 1'b1;
                state_d = IDLE;
            end
<TARGET>
                mem_data_req_o = 1'b1;
                if (mem_data_ack_i) begin
                    miss_o = ~paddr_is_nc;
                    state_d = MISS;
                end
            end
            default: state_d = FLUSH;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= FLUSH;
            cache_en_q <= 1'b0;
            flush_q <= 1'b0;
            flush_cnt_q <= '0;
        end else begin
            state_q <= state_d;
            cache_en_q <= cache_en_d;
            flush_q <= flush_d;
            if (flush_en)
                flush_cnt_q <= flush_cnt_q + 1;
            else if (flush_done)
                flush_cnt_q <= '0;
        end
    end
endmodule
