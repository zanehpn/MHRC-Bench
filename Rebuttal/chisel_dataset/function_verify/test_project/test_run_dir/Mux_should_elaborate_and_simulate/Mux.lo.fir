FIRRTL version 1.2.0
circuit Mux :
  module Mux : @[src/main/scala/Mux.scala 5:7]
    input clock : Clock @[src/main/scala/Mux.scala 5:7]
    input reset : UInt<1> @[src/main/scala/Mux.scala 5:7]
    input io_a : SInt<4> @[src/main/scala/Mux.scala 6:17]
    input io_b : SInt<4> @[src/main/scala/Mux.scala 6:17]
    input io_sel : UInt<1> @[src/main/scala/Mux.scala 6:17]
    output io_out : SInt<4> @[src/main/scala/Mux.scala 6:17]

    node _io_out_T = mux(io_sel, io_a, io_b) @[src/main/scala/Mux.scala 14:18]
    io_out <= _io_out_T @[src/main/scala/Mux.scala 14:12]
