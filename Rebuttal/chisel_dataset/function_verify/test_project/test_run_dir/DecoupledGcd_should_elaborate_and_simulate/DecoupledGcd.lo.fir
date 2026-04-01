FIRRTL version 1.2.0
circuit DecoupledGcd :
  module DecoupledGcd : @[src/main/scala/DecoupledGCD.scala 21:7]
    input clock : Clock @[src/main/scala/DecoupledGCD.scala 21:7]
    input reset : UInt<1> @[src/main/scala/DecoupledGCD.scala 21:7]
    output input_ready : UInt<1> @[src/main/scala/DecoupledGCD.scala 22:18]
    input input_valid : UInt<1> @[src/main/scala/DecoupledGCD.scala 22:18]
    input input_bits_value1 : UInt<8> @[src/main/scala/DecoupledGCD.scala 22:18]
    input input_bits_value2 : UInt<8> @[src/main/scala/DecoupledGCD.scala 22:18]
    input output_ready : UInt<1> @[src/main/scala/DecoupledGCD.scala 23:18]
    output output_valid : UInt<1> @[src/main/scala/DecoupledGCD.scala 23:18]
    output output_bits_value1 : UInt<8> @[src/main/scala/DecoupledGCD.scala 23:18]
    output output_bits_value2 : UInt<8> @[src/main/scala/DecoupledGCD.scala 23:18]
    output output_bits_gcd : UInt<8> @[src/main/scala/DecoupledGCD.scala 23:18]

    reg xInitial : UInt<8>, clock with :
      reset => (UInt<1>("h0"), xInitial) @[src/main/scala/DecoupledGCD.scala 25:24]
    reg yInitial : UInt<8>, clock with :
      reset => (UInt<1>("h0"), yInitial) @[src/main/scala/DecoupledGCD.scala 26:24]
    reg x : UInt<8>, clock with :
      reset => (UInt<1>("h0"), x) @[src/main/scala/DecoupledGCD.scala 27:24]
    reg y : UInt<8>, clock with :
      reset => (UInt<1>("h0"), y) @[src/main/scala/DecoupledGCD.scala 28:24]
    reg busy : UInt<1>, clock with :
      reset => (UInt<1>("h0"), busy) @[src/main/scala/DecoupledGCD.scala 29:28]
    reg resultValid : UInt<1>, clock with :
      reset => (UInt<1>("h0"), resultValid) @[src/main/scala/DecoupledGCD.scala 30:28]
    node _input_ready_T = eq(busy, UInt<1>("h0")) @[src/main/scala/DecoupledGCD.scala 32:19]
    node _T = gt(x, y) @[src/main/scala/DecoupledGCD.scala 37:12]
    node _x_T = sub(x, y) @[src/main/scala/DecoupledGCD.scala 38:8]
    node _x_T_1 = tail(_x_T, 1) @[src/main/scala/DecoupledGCD.scala 38:8]
    node _T_1 = lt(x, y) @[src/main/scala/DecoupledGCD.scala 39:18]
    node _y_T = sub(y, x) @[src/main/scala/DecoupledGCD.scala 40:14]
    node _y_T_1 = tail(_y_T, 1) @[src/main/scala/DecoupledGCD.scala 40:14]
    node _T_2 = eq(x, UInt<1>("h0")) @[src/main/scala/DecoupledGCD.scala 41:14]
    node _GEN_0 = mux(_T_2, y, x) @[src/main/scala/DecoupledGCD.scala 41:23 42:25 44:25]
    node _T_3 = and(output_ready, resultValid) @[src/main/scala/DecoupledGCD.scala 51:25]
    node _GEN_1 = mux(_T_3, UInt<1>("h0"), busy) @[src/main/scala/DecoupledGCD.scala 51:41 52:21 29:28]
    node _GEN_2 = mux(_T_3, UInt<1>("h0"), UInt<1>("h1")) @[src/main/scala/DecoupledGCD.scala 51:41 53:21 49:26]
    node _GEN_3 = mux(_T_1, _y_T_1, y) @[src/main/scala/DecoupledGCD.scala 39:23 28:24 40:9]
    node _GEN_4 = validif(_T_1, _GEN_0) @[src/main/scala/DecoupledGCD.scala 39:23]
    node _GEN_5 = validif(_T_1, xInitial) @[src/main/scala/DecoupledGCD.scala 39:23 47:26]
    node _GEN_6 = validif(_T_1, yInitial) @[src/main/scala/DecoupledGCD.scala 39:23 48:26]
    node _GEN_7 = mux(_T_1, _GEN_2, resultValid) @[src/main/scala/DecoupledGCD.scala 39:23 30:28]
    node _GEN_8 = mux(_T_1, _GEN_1, busy) @[src/main/scala/DecoupledGCD.scala 39:23 29:28]
    node _GEN_9 = mux(_T, _x_T_1, x) @[src/main/scala/DecoupledGCD.scala 37:17 27:24 38:3]
    node _GEN_10 = mux(_T, y, _GEN_3) @[src/main/scala/DecoupledGCD.scala 37:17 28:24]
    node _GEN_11 = validif(eq(_T, UInt<1>("h0")), _GEN_4) @[src/main/scala/DecoupledGCD.scala 37:17]
    node _GEN_12 = validif(eq(_T, UInt<1>("h0")), _GEN_5) @[src/main/scala/DecoupledGCD.scala 37:17]
    node _GEN_13 = validif(eq(_T, UInt<1>("h0")), _GEN_6) @[src/main/scala/DecoupledGCD.scala 37:17]
    node _GEN_14 = mux(_T, resultValid, _GEN_7) @[src/main/scala/DecoupledGCD.scala 37:17 30:28]
    node _GEN_15 = mux(_T, busy, _GEN_8) @[src/main/scala/DecoupledGCD.scala 37:17 29:28]
    node _GEN_16 = mux(input_valid, UInt<1>("h1"), _input_ready_T) @[src/main/scala/DecoupledGCD.scala 32:16 57:23 src/main/scala/chisel3/util/Decoupled.scala 76:20]
    node _GEN_17 = mux(input_valid, input_bits_value1, x) @[src/main/scala/DecoupledGCD.scala 57:23 59:16 27:24]
    node _GEN_18 = mux(input_valid, input_bits_value2, y) @[src/main/scala/DecoupledGCD.scala 57:23 60:16 28:24]
    node _GEN_19 = mux(input_valid, input_bits_value1, xInitial) @[src/main/scala/DecoupledGCD.scala 57:23 61:16 25:24]
    node _GEN_20 = mux(input_valid, input_bits_value2, yInitial) @[src/main/scala/DecoupledGCD.scala 57:23 62:16 26:24]
    node _GEN_21 = mux(input_valid, UInt<1>("h1"), busy) @[src/main/scala/DecoupledGCD.scala 57:23 63:16 29:28]
    node _GEN_22 = mux(busy, _GEN_9, _GEN_17) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_23 = mux(busy, _GEN_10, _GEN_18) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_24 = validif(busy, _GEN_11) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_25 = validif(busy, _GEN_12) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_26 = validif(busy, _GEN_13) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_27 = mux(busy, _GEN_14, resultValid) @[src/main/scala/DecoupledGCD.scala 36:14 30:28]
    node _GEN_28 = mux(busy, _GEN_15, _GEN_21) @[src/main/scala/DecoupledGCD.scala 36:14]
    node _GEN_29 = mux(busy, _input_ready_T, _GEN_16) @[src/main/scala/DecoupledGCD.scala 36:14 32:16]
    node _GEN_30 = mux(busy, xInitial, _GEN_19) @[src/main/scala/DecoupledGCD.scala 36:14 25:24]
    node _GEN_31 = mux(busy, yInitial, _GEN_20) @[src/main/scala/DecoupledGCD.scala 36:14 26:24]
    input_ready <= _GEN_29
    output_valid <= resultValid @[src/main/scala/DecoupledGCD.scala 33:16]
    output_bits_value1 <= _GEN_25
    output_bits_value2 <= _GEN_26
    output_bits_gcd <= _GEN_24
    xInitial <= _GEN_30
    yInitial <= _GEN_31
    x <= _GEN_22
    y <= _GEN_23
    busy <= mux(reset, UInt<1>("h0"), _GEN_28) @[src/main/scala/DecoupledGCD.scala 29:{28,28}]
    resultValid <= mux(reset, UInt<1>("h0"), _GEN_27) @[src/main/scala/DecoupledGCD.scala 30:{28,28}]
