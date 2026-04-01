FIRRTL version 1.2.0
circuit Mux_2to1 :
  module Mux_2to1 : @[src/main/scala/lab2ex1.scala 12:7]
    input clock : Clock @[src/main/scala/lab2ex1.scala 12:7]
    input reset : UInt<1> @[src/main/scala/lab2ex1.scala 12:7]
    input io_in_A : UInt<32> @[src/main/scala/lab2ex1.scala 13:13]
    input io_in_B : UInt<32> @[src/main/scala/lab2ex1.scala 13:13]
    input io_select : UInt<1> @[src/main/scala/lab2ex1.scala 13:13]
    output io_out : UInt<32> @[src/main/scala/lab2ex1.scala 13:13]

    node copy = mux(io_select, UInt<32>("hffffffff"), UInt<32>("h0")) @[src/main/scala/lab2ex1.scala 14:17]
    node _io_out_T = not(copy) @[src/main/scala/lab2ex1.scala 16:20]
    node _io_out_T_1 = and(io_in_A, _io_out_T) @[src/main/scala/lab2ex1.scala 16:17]
    node _io_out_T_2 = and(io_in_B, copy) @[src/main/scala/lab2ex1.scala 16:38]
    node _io_out_T_3 = or(_io_out_T_1, _io_out_T_2) @[src/main/scala/lab2ex1.scala 16:28]
    io_out <= _io_out_T_3 @[src/main/scala/lab2ex1.scala 16:7]
