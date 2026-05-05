module onehot_to_bin #(
    parameter int unsigned ONEHOT_WIDTH = 16,
    parameter int unsigned BIN_WIDTH    = ONEHOT_WIDTH == 1 ? 1 : $clog2(ONEHOT_WIDTH)
)   (
    input  logic [ONEHOT_WIDTH-1:0] onehot,
    output logic [BIN_WIDTH-1:0]    bin
);
    for (genvar j = 0; unsigned'(j) < BIN_WIDTH; j++) begin : gen_jloop
        logic [ONEHOT_WIDTH-1:0] tmp_mask;
        for (genvar i = 0; unsigned'(i) < ONEHOT_WIDTH; i++) begin : gen_iloop
            logic [BIN_WIDTH-1:0] tmp_i;
                assign tmp_i = i;
                assign tmp_mask[i] = tmp_i[j];
            end
        assign bin[j] = |(tmp_mask & onehot);
    end

endmodule
