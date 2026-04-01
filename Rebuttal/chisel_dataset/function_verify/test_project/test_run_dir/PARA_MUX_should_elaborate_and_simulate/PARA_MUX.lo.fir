FIRRTL version 1.2.0
circuit PARA_MUX :
  module PARA_MUX : @[src/main/scala/parameterizedMux.scala 14:7]
    input clock : Clock @[src/main/scala/parameterizedMux.scala 14:7]
    input reset : UInt<1> @[src/main/scala/parameterizedMux.scala 14:7]
    input io_in1 : UInt<32> @[src/main/scala/parameterizedMux.scala 15:16]
    input io_in2 : UInt<32> @[src/main/scala/parameterizedMux.scala 15:16]
    input io_sel : UInt<1> @[src/main/scala/parameterizedMux.scala 15:16]
    output io_out : UInt<32> @[src/main/scala/parameterizedMux.scala 15:16]

    node _io_out_T = mux(io_sel, io_in2, io_in1) @[src/main/scala/parameterizedMux.scala 17:66]
    io_out <= _io_out_T @[src/main/scala/parameterizedMux.scala 19:12]
