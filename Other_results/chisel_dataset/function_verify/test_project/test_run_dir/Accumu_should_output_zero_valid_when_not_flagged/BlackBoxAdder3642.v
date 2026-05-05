(*use_dsp="yes"*)
module DSP48Adder(
    input[35:0] a,
    input[35:0] t,
    input flag,
    input[41:0] b,
    output[41:0] c
);
wire[41:0] x;
assign x = flag? {{6{t[35]}}, t}: b;
assign c = x + $signed({{6{a[35]}}, a});
endmodule
        