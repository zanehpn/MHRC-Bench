FIRRTL version 1.2.0
circuit counter_max_example :
  module counter_max_example : @[src/main/scala/counter.scala 100:11]
    input clock : Clock @[src/main/scala/counter.scala 100:11]
    input reset : UInt<1> @[src/main/scala/counter.scala 100:11]
    input io_max : UInt<4> @[src/main/scala/counter.scala 101:20]
    input io_en : UInt<1> @[src/main/scala/counter.scala 101:20]
    output io_out : UInt<4> @[src/main/scala/counter.scala 101:20]
    output io_co : UInt<1> @[src/main/scala/counter.scala 101:20]

    reg out : UInt<4>, clock with :
      reset => (UInt<1>("h0"), out) @[src/main/scala/counter.scala 73:26]
    node wrap = eq(out, io_max) @[src/main/scala/counter.scala 74:24]
    node _GEN_0 = mux(wrap, UInt<4>("h0"), out) @[src/main/scala/counter.scala 76:24 77:21 73:26]
    node _GEN_1 = mux(io_en, _GEN_0, out) @[src/main/scala/counter.scala 75:18 73:26]
    node co = and(io_en, wrap) @[src/main/scala/counter.scala 80:18]
    io_out <= out @[src/main/scala/counter.scala 108:16]
    io_co <= co @[src/main/scala/counter.scala 109:15]
    out <= mux(reset, UInt<4>("h0"), _GEN_1) @[src/main/scala/counter.scala 73:{26,26}]
