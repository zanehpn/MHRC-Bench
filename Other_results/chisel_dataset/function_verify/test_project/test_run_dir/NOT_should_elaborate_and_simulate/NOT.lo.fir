FIRRTL version 1.2.0
circuit NOT :
  module NOT : @[src/main/scala/NOT.scala 4:7]
    input clock : Clock @[src/main/scala/NOT.scala 4:7]
    input reset : UInt<1> @[src/main/scala/NOT.scala 4:7]
    input io_a : SInt<4> @[src/main/scala/NOT.scala 5:14]
    output io_c : SInt<4> @[src/main/scala/NOT.scala 5:14]

    node _io_c_T = not(io_a) @[src/main/scala/NOT.scala 10:8]
    node _io_c_T_1 = asSInt(_io_c_T) @[src/main/scala/NOT.scala 10:8]
    io_c <= _io_c_T_1 @[src/main/scala/NOT.scala 10:5]
