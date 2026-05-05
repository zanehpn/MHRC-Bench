// fplib - fixed point 'signal' (SV interface) definitions
`timescale 1ns/1ps
`include "fp_macros.svh"

// ufp 'signal' : unsigned fixed point scaler
interface ufp #(
    parameter int signed iw = 1,
    parameter int unsigned qw = 1,
    localparam int unsigned wl = iw + qw
) ();
    logic [wl-1:0] val;

    wire [qw:0] dummy_qw = (qw+1)'(qw);
    wire [wl:0] dummy_wl = (wl+1)'(wl);
    wire [1:0] dummy_signed = 2'b0;
    localparam is_signed = 0;

    real fval;
    assign fval = `fp_to_float(val, qw);
    modport out      (output val, input fval, input dummy_qw, input dummy_wl, input dummy_signed);
    modport in       (input  val, input fval, input dummy_qw, input dummy_wl, input dummy_signed);
endinterface

// sfp 'signal': signed fixed point scaler
interface sfp #(
    parameter int signed iw = 1,
    parameter int unsigned qw = 1,
    localparam int unsigned wl = iw + qw
) ();

    logic signed [wl-1:0] val;

    wire [qw:0] dummy_qw = (qw+1)'(qw);
    wire [wl:0] dummy_wl = (wl+1)'(wl);
    wire dummy_signed = 1'b1;
    localparam is_signed = 1;

    real fval;
    assign fval = `fp_to_float(val, qw);
    modport out      (output val, input fval, input dummy_qw, input dummy_wl, input dummy_signed);
    modport in       (input  val, input fval, input dummy_qw, input dummy_wl, input dummy_signed);

endinterface
