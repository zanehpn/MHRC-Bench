FIRRTL version 1.2.0
circuit GCD :
  module GCD : @[src/main/scala/GCD.scala 12:7]
    input clock : Clock @[src/main/scala/GCD.scala 12:7]
    input reset : UInt<1> @[src/main/scala/GCD.scala 12:7]
    input io_value1 : UInt<16> @[src/main/scala/GCD.scala 13:14]
    input io_value2 : UInt<16> @[src/main/scala/GCD.scala 13:14]
    input io_loadingValues : UInt<1> @[src/main/scala/GCD.scala 13:14]
    output io_outputGCD : UInt<16> @[src/main/scala/GCD.scala 13:14]
    output io_outputValid : UInt<1> @[src/main/scala/GCD.scala 13:14]

    reg x : UInt<16>, clock with :
      reset => (UInt<1>("h0"), x) @[src/main/scala/GCD.scala 21:15]
    reg y : UInt<16>, clock with :
      reset => (UInt<1>("h0"), y) @[src/main/scala/GCD.scala 22:15]
    node _y_T = sub(y, x) @[src/main/scala/GCD.scala 25:25]
    node _y_T_1 = tail(_y_T, 1) @[src/main/scala/GCD.scala 25:25]
    node _GEN_0 = mux(io_loadingValues, io_value1, x) @[src/main/scala/GCD.scala 21:15 24:{27,31}]
    node _GEN_1 = mux(io_loadingValues, io_value2, _y_T_1) @[src/main/scala/GCD.scala 24:{27,47} 25:20]
    node _GEN_2 = mux(io_loadingValues, io_value1, _GEN_0) @[src/main/scala/GCD.scala 27:26 28:7]
    node _GEN_3 = mux(io_loadingValues, io_value2, _GEN_1) @[src/main/scala/GCD.scala 27:26 29:7]
    node _io_outputValid_T = eq(y, UInt<1>("h0")) @[src/main/scala/GCD.scala 33:23]
    io_outputGCD <= x @[src/main/scala/GCD.scala 32:16]
    io_outputValid <= _io_outputValid_T @[src/main/scala/GCD.scala 33:18]
    x <= _GEN_2
    y <= _GEN_3
