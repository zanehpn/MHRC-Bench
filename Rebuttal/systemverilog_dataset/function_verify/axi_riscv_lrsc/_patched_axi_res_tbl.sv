module axi_res_tbl #(
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic [AXI_ADDR_WIDTH-1:0]   check_clr_addr_i,
    input  logic [AXI_ID_WIDTH-1:0]     check_id_i,
    input  logic                        check_clr_excl_i,
    output logic                        check_res_o,
    input  logic                        check_clr_req_i,
    output logic                        check_clr_gnt_o,
    input  logic [AXI_ADDR_WIDTH-1:0]   set_addr_i,
    input  logic [AXI_ID_WIDTH-1:0]     set_id_i,
    input  logic                        set_req_i,
    output logic                        set_gnt_o
);

    localparam integer N_IDS = 2**AXI_ID_WIDTH;

    logic [N_IDS-1:0][AXI_ADDR_WIDTH-1:0]   tbl_d,                      tbl_q;
    logic                                   clr,
                                            set,
                                            match;

    assign match = (tbl_q[check_id_i] == check_clr_addr_i);

    generate for (genvar i = 0; i < N_IDS; ++i) begin: gen_tbl
        always @( * ) begin
            tbl_d[i] = tbl_q[i];
            if (set && i == set_id_i) begin
                tbl_d[i] = set_addr_i;
            end else if (clr && tbl_q[i] == check_clr_addr_i) begin
                tbl_d[i] = '0;
            end
        end
    end endgenerate

    always @( * ) begin
        clr             = 1'b0;
        set             = 1'b0;
        set_gnt_o       = 1'b0;
        check_res_o     = 1'b0;
        check_clr_gnt_o = 1'b0;

        if (check_clr_req_i) begin
            check_clr_gnt_o = 1'b1;
            check_res_o     = match;
            clr             = !(check_clr_excl_i && !match);
        end else if (set_req_i) begin
            set         = 1'b1;
            set_gnt_o   = 1'b1;
        end
    end

    always @(posedge clk_i, negedge rst_ni) begin
        if (~rst_ni) begin
            tbl_q   <= '0;
        end else begin
            tbl_q   <= tbl_d;
        end
    end

endmodule
