FIRRTL version 1.2.0
circuit XNOR :
  module XNOR : @[src/main/scala/XNOR.scala 4:7]
    input clock : Clock @[src/main/scala/XNOR.scala 4:7]
    input reset : UInt<1> @[src/main/scala/XNOR.scala 4:7]
    input io_a : SInt<4> @[src/main/scala/XNOR.scala 5:14]
    input io_b : SInt<4> @[src/main/scala/XNOR.scala 5:14]
    output io_c : SInt<4> @[src/main/scala/XNOR.scala 5:14]

    node _io_c_T = xor(io_a, io_b) @[src/main/scala/XNOR.scala 11:15]
    node _io_c_T_1 = asSInt(_io_c_T) @[src/main/scala/XNOR.scala 11:15]
    node _io_c_T_2 = not(_io_c_T_1) @[src/main/scala/XNOR.scala 11:8]
    node _io_c_T_3 = asSInt(_io_c_T_2) @[src/main/scala/XNOR.scala 11:8]
    io_c <= _io_c_T_3 @[src/main/scala/XNOR.scala 11:5]
