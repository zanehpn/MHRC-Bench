FIRRTL version 1.2.0
circuit Bitwidth :
  module Bitwidth : @[src/main/scala/Bitwidth.scala 5:7]
    input clock : Clock @[src/main/scala/Bitwidth.scala 5:7]
    input reset : UInt<1> @[src/main/scala/Bitwidth.scala 5:7]
    input io_input : UInt<4> @[src/main/scala/Bitwidth.scala 6:16]
    output io_output : SInt<4> @[src/main/scala/Bitwidth.scala 6:16]

    node _temp_T = asSInt(io_input) @[src/main/scala/Bitwidth.scala 12:22]
    node temp = _temp_T @[src/main/scala/Bitwidth.scala 11:20 12:10]
    io_output <= temp @[src/main/scala/Bitwidth.scala 13:15]
