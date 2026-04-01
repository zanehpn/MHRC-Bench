FIRRTL version 1.2.0
circuit Encoder4to2 :
  module Encoder4to2 : @[src/main/scala/lab3ex1.scala 9:7]
    input clock : Clock @[src/main/scala/lab3ex1.scala 9:7]
    input reset : UInt<1> @[src/main/scala/lab3ex1.scala 9:7]
    input io_in : UInt<4> @[src/main/scala/lab3ex1.scala 10:17]
    output io_out : UInt<2> @[src/main/scala/lab3ex1.scala 10:17]

    node _T = eq(UInt<1>("h1"), io_in) @[src/main/scala/lab3ex1.scala 12:18]
    node _T_1 = eq(UInt<2>("h2"), io_in) @[src/main/scala/lab3ex1.scala 12:18]
    node _T_2 = eq(UInt<3>("h4"), io_in) @[src/main/scala/lab3ex1.scala 12:18]
    node _T_3 = eq(UInt<4>("h8"), io_in) @[src/main/scala/lab3ex1.scala 12:18]
    node _GEN_0 = mux(_T_3, UInt<2>("h3"), UInt<1>("h0")) @[src/main/scala/lab3ex1.scala 11:11 12:18 16:29]
    node _GEN_1 = mux(_T_2, UInt<2>("h2"), _GEN_0) @[src/main/scala/lab3ex1.scala 12:18 15:29]
    node _GEN_2 = mux(_T_1, UInt<1>("h1"), _GEN_1) @[src/main/scala/lab3ex1.scala 12:18 14:29]
    node _GEN_3 = mux(_T, UInt<1>("h0"), _GEN_2) @[src/main/scala/lab3ex1.scala 12:18 13:29]
    io_out <= _GEN_3
