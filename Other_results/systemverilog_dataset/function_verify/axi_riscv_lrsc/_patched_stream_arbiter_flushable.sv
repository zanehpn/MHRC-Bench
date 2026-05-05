module stream_arbiter_flushable #(
    parameter type      DATA_T = logic,
    parameter integer   N_INP = -1,
    parameter           ARBITER = "rr"
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    input  logic              flush_i,

    input  DATA_T [N_INP-1:0] inp_data_i,
    input  logic  [N_INP-1:0] inp_valid_i,
    output logic  [N_INP-1:0] inp_ready_o,

    output DATA_T             oup_data_o,
    output logic              oup_valid_o,
    input  logic              oup_ready_i
);

  if (ARBITER == "rr") begin : gen_rr_arb
    rr_arb_tree #(
      .NumIn      (N_INP),
      .DataType   (DATA_T),
      .ExtPrio    (1'b0),
      .AxiVldRdy  (1'b1),
      .LockIn     (1'b1)
    ) i_arbiter (
      .clk_i,
      .rst_ni,
      .flush_i,
      .rr_i   ('0),
      .req_i  (inp_valid_i),
      .gnt_o  (inp_ready_o),
      .data_i (inp_data_i),
      .gnt_i  (oup_ready_i),
      .req_o  (oup_valid_o),
      .data_o (oup_data_o),
      .idx_o  ()
    );

  end else if (ARBITER == "prio") begin : gen_prio_arb
    rr_arb_tree #(
      .NumIn      (N_INP),
      .DataType   (DATA_T),
      .ExtPrio    (1'b1),
      .AxiVldRdy  (1'b1),
      .LockIn     (1'b0)
    ) i_arbiter (
      .clk_i,
      .rst_ni,
      .flush_i,
      .rr_i   ('0),
      .req_i  (inp_valid_i),
      .gnt_o  (inp_ready_o),
      .data_i (inp_data_i),
      .gnt_i  (oup_ready_i),
      .req_o  (oup_valid_o),
      .data_o (oup_data_o),
      .idx_o  ()
    );

  end else begin : gen_arb_error
    `ifndef SYNTHESIS
    initial $fatal(1, "Invalid value for parameter 'ARBITER'!");
    `endif
  end

endmodule
