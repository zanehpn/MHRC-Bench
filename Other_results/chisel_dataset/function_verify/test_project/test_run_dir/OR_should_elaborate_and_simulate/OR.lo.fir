FIRRTL version 1.2.0
circuit OR :
  module OR : @[src/main/scala/OR.scala 4:7]
    input clock : Clock @[src/main/scala/OR.scala 4:7]
    input reset : UInt<1> @[src/main/scala/OR.scala 4:7]
    input io_a : SInt<4> @[src/main/scala/OR.scala 5:14]
    input io_b : SInt<4> @[src/main/scala/OR.scala 5:14]
    output io_c : UInt<4> @[src/main/scala/OR.scala 5:14]

    node _io_c_T = asUInt(io_a) @[src/main/scala/OR.scala 11:17]
    node _io_c_T_1 = asUInt(io_b) @[src/main/scala/OR.scala 11:31]
    node _io_c_T_2 = or(_io_c_T, _io_c_T_1) @[src/main/scala/OR.scala 11:24]
    io_c <= _io_c_T_2 @[src/main/scala/OR.scala 11:9]
