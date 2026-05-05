module fall_through_register #(
    parameter type T = logic
) (
    input  logic    clk_i,
    input  logic    rst_ni,
    input  logic    clr_i,
    input  logic    testmode_i,
    input  logic    valid_i,
    output logic    ready_o,
    input  T        data_i,
    output logic    valid_o,
    input  logic    ready_i,
    output T        data_o
);
    logic fifo_empty,
            fifo_full;

    fifo_v3 #(
        .FALL_THROUGH   (1'b1),
        .DEPTH          (1),
        .dtype          (T)
    ) i_fifo (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .flush_i        (clr_i),
        .testmode_i     (testmode_i),
        .full_o         (fifo_full),
        .empty_o        (fifo_empty),
        .usage_o        (),
        .data_i         (data_i),
        .push_i         (valid_i & ~fifo_full),
        .data_o         (data_o),
        .pop_i          (ready_i & ~fifo_empty)
    );

    assign ready_o = ~fifo_full;
    assign valid_o = ~fifo_empty;

endmodule
