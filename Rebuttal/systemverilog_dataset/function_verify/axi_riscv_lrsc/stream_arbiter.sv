module stream_arbiter #(
    parameter type      DATA_T = logic,
    parameter integer   N_INP = -1,
    parameter           ARBITER = "rr"
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    input  DATA_T [N_INP-1:0] inp_data_i,
    input  logic  [N_INP-1:0] inp_valid_i,
    output logic  [N_INP-1:0] inp_ready_o,

    output DATA_T             oup_data_o,
    output logic              oup_valid_o,
    input  logic              oup_ready_i
);

  stream_arbiter_flushable #(
    .DATA_T   (DATA_T),
    .N_INP    (N_INP),
    .ARBITER  (ARBITER)
  ) i_arb (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .flush_i      (1'b0),
    .inp_data_i   (inp_data_i),
    .inp_valid_i  (inp_valid_i),
    .inp_ready_o  (inp_ready_o),
    .oup_data_o   (oup_data_o),
    .oup_valid_o  (oup_valid_o),
    .oup_ready_i  (oup_ready_i)
  );
endmodule
