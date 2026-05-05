FIRRTL version 1.2.0
circuit Filll :
  module Filll : @[src/main/scala/Filll.scala 6:7]
    input clock : Clock @[src/main/scala/Filll.scala 6:7]
    input reset : UInt<1> @[src/main/scala/Filll.scala 6:7]
    input io_fill : UInt<2> @[src/main/scala/Filll.scala 7:16]
    output io_out : UInt<6> @[src/main/scala/Filll.scala 7:16]

    node _io_out_T = cat(io_fill, io_fill) @[src/main/scala/Filll.scala 13:19]
    node _io_out_T_1 = cat(io_fill, _io_out_T) @[src/main/scala/Filll.scala 13:19]
    io_out <= _io_out_T_1 @[src/main/scala/Filll.scala 13:12]
