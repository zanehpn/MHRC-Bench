FIRRTL version 1.2.0
circuit counter_example :
  module counter_example : @[src/main/scala/counter.scala 31:11]
    input clock : Clock @[src/main/scala/counter.scala 31:11]
    input reset : UInt<1> @[src/main/scala/counter.scala 31:11]
    input io_en : UInt<1> @[src/main/scala/counter.scala 32:20]
    output io_out : UInt<3> @[src/main/scala/counter.scala 32:20]
    output io_co : UInt<1> @[src/main/scala/counter.scala 32:20]

    reg cnt : UInt<3>, clock with :
      reset => (UInt<1>("h0"), cnt) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    node wrap_wrap = eq(cnt, UInt<3>("h7")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _wrap_value_T = add(cnt, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _wrap_value_T_1 = tail(_wrap_value_T, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _GEN_0 = mux(io_en, _wrap_value_T_1, cnt) @[src/main/scala/chisel3/util/Counter.scala 118:16 77:15 61:40]
    node _GEN_1 = mux(io_en, wrap_wrap, UInt<1>("h0")) @[src/main/scala/chisel3/util/Counter.scala 118:{16,23} 117:24]
    node co = _GEN_1 @[src/main/scala/chisel3/util/Counter.scala 117:24]
    io_out <= cnt @[src/main/scala/counter.scala 39:16]
    io_co <= co @[src/main/scala/counter.scala 40:15]
    cnt <= mux(reset, UInt<3>("h0"), _GEN_0) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
