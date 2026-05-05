FIRRTL version 1.2.0
circuit CounterModule :
  module CounterModule : @[src/main/scala/Counter.scala 23:7]
    input clock : Clock @[src/main/scala/Counter.scala 23:7]
    input reset : UInt<1> @[src/main/scala/Counter.scala 23:7]
    input io_inc : UInt<1> @[src/main/scala/Counter.scala 24:14]
    input io_extReset : UInt<1> @[src/main/scala/Counter.scala 24:14]
    input io_max : UInt<3> @[src/main/scala/Counter.scala 24:14]
    output io_wrap : UInt<1> @[src/main/scala/Counter.scala 24:14]
    output io_value : UInt<2> @[src/main/scala/Counter.scala 24:14]

    reg value : UInt<4>, clock with :
      reset => (UInt<1>("h0"), value) @[src/main/scala/Counter.scala 32:22]
    node _value_T = add(value, UInt<1>("h1")) @[src/main/scala/Counter.scala 34:34]
    node _value_T_1 = tail(_value_T, 1) @[src/main/scala/Counter.scala 34:34]
    node _GEN_0 = mux(io_inc, _value_T_1, value) @[src/main/scala/Counter.scala 34:17 32:22 34:25]
    node _io_wrap_T = sub(io_max, UInt<1>("h1")) @[src/main/scala/Counter.scala 35:32]
    node _io_wrap_T_1 = tail(_io_wrap_T, 1) @[src/main/scala/Counter.scala 35:32]
    node _io_wrap_T_2 = eq(value, _io_wrap_T_1) @[src/main/scala/Counter.scala 35:20]
    node _T = or(io_extReset, io_wrap) @[src/main/scala/Counter.scala 36:21]
    node _GEN_1 = mux(_T, UInt<1>("h0"), _GEN_0) @[src/main/scala/Counter.scala 36:{33,41}]
    io_wrap <= _io_wrap_T_2 @[src/main/scala/Counter.scala 35:11]
    io_value <= bits(value, 1, 0) @[src/main/scala/Counter.scala 33:12]
    value <= mux(reset, UInt<4>("h0"), _GEN_1) @[src/main/scala/Counter.scala 32:{22,22}]
