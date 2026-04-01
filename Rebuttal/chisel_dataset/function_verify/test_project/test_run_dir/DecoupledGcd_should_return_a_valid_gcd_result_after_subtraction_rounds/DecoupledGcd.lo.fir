FIRRTL version 1.2.0
circuit DecoupledGcd :
  module DecoupledGcd : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 21:7]
    input clock : Clock @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 21:7]
    input reset : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 21:7]
    output input_ready : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 22:18]
    input input_valid : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 22:18]
    input input_bits_value1 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 22:18]
    input input_bits_value2 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 22:18]
    input output_ready : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 23:18]
    output output_valid : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 23:18]
    output output_bits_value1 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 23:18]
    output output_bits_value2 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 23:18]
    output output_bits_gcd : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 23:18]

    reg xInitial : UInt<16>, clock with :
      reset => (UInt<1>("h0"), xInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 25:24]
    reg yInitial : UInt<16>, clock with :
      reset => (UInt<1>("h0"), yInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 26:24]
    reg x : UInt<16>, clock with :
      reset => (UInt<1>("h0"), x) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 27:24]
    reg y : UInt<16>, clock with :
      reset => (UInt<1>("h0"), y) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 28:24]
    reg busy : UInt<1>, clock with :
      reset => (UInt<1>("h0"), busy) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 29:28]
    reg resultValid : UInt<1>, clock with :
      reset => (UInt<1>("h0"), resultValid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 30:28]
    node _input_ready_T = eq(busy, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 32:19]
    node _T = gt(x, y) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:12]
    node _x_T = sub(x, y) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 38:14]
    node _x_T_1 = tail(_x_T, 1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 38:14]
    node _y_T = sub(y, x) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 40:14]
    node _y_T_1 = tail(_y_T, 1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 40:14]
    node _T_1 = eq(x, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 41:14]
    node _GEN_0 = mux(_T_1, y, x) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 41:23 42:25 44:25]
    node _T_2 = and(output_ready, resultValid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 51:25]
    node _GEN_1 = mux(_T_2, UInt<1>("h0"), busy) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 51:41 52:21 29:28]
    node _GEN_2 = mux(_T_2, UInt<1>("h0"), UInt<1>("h1")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 51:41 53:21 49:26]
    node _GEN_3 = mux(_T, _x_T_1, x) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 27:24 38:9]
    node _GEN_4 = mux(_T, y, _y_T_1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 28:24 40:9]
    node _GEN_5 = validif(eq(_T, UInt<1>("h0")), _GEN_0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17]
    node _GEN_6 = validif(eq(_T, UInt<1>("h0")), xInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 47:26]
    node _GEN_7 = validif(eq(_T, UInt<1>("h0")), yInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 48:26]
    node _GEN_8 = mux(_T, resultValid, _GEN_2) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 30:28]
    node _GEN_9 = mux(_T, busy, _GEN_1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 37:17 29:28]
    node _GEN_10 = mux(input_valid, UInt<1>("h1"), _input_ready_T) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 src/main/scala/chisel3/util/Decoupled.scala 76:20 ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 32:16]
    node _GEN_11 = mux(input_valid, input_bits_value1, x) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 59:16 27:24]
    node _GEN_12 = mux(input_valid, input_bits_value2, y) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 60:16 28:24]
    node _GEN_13 = mux(input_valid, input_bits_value1, xInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 61:16 25:24]
    node _GEN_14 = mux(input_valid, input_bits_value2, yInitial) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 62:16 26:24]
    node _GEN_15 = mux(input_valid, UInt<1>("h1"), busy) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 57:23 63:16 29:28]
    node _GEN_16 = mux(busy, _GEN_3, _GEN_11) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_17 = mux(busy, _GEN_4, _GEN_12) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_18 = validif(busy, _GEN_5) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_19 = validif(busy, _GEN_6) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_20 = validif(busy, _GEN_7) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_21 = mux(busy, _GEN_8, resultValid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14 30:28]
    node _GEN_22 = mux(busy, _GEN_9, _GEN_15) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14]
    node _GEN_23 = mux(busy, _input_ready_T, _GEN_10) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14 32:16]
    node _GEN_24 = mux(busy, xInitial, _GEN_13) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14 25:24]
    node _GEN_25 = mux(busy, yInitial, _GEN_14) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 36:14 26:24]
    input_ready <= _GEN_23
    output_valid <= resultValid @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 33:16]
    output_bits_value1 <= _GEN_19
    output_bits_value2 <= _GEN_20
    output_bits_gcd <= _GEN_18
    xInitial <= _GEN_24
    yInitial <= _GEN_25
    x <= _GEN_16
    y <= _GEN_17
    busy <= mux(reset, UInt<1>("h0"), _GEN_22) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 29:{28,28}]
    resultValid <= mux(reset, UInt<1>("h0"), _GEN_21) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DecoupledGCD/DecoupledGCD_original.scala 30:{28,28}]
