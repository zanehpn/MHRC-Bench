FIRRTL version 1.2.0
circuit Condition :
  module Condition : @[src/main/scala/Conditions.scala 6:7]
    input clock : Clock @[src/main/scala/Conditions.scala 6:7]
    input reset : UInt<1> @[src/main/scala/Conditions.scala 6:7]
    input io_in : UInt<2> @[src/main/scala/Conditions.scala 7:16]
    output io_out : UInt<4> @[src/main/scala/Conditions.scala 7:16]

    node _T = eq(io_in, UInt<1>("h0")) @[src/main/scala/Conditions.scala 13:17]
    node _T_1 = eq(io_in, UInt<1>("h1")) @[src/main/scala/Conditions.scala 15:23]
    node _GEN_0 = mux(_T_1, UInt<3>("h4"), UInt<4>("h8")) @[src/main/scala/Conditions.scala 15:36 16:16 18:16]
    node _GEN_1 = mux(_T, UInt<1>("h1"), _GEN_0) @[src/main/scala/Conditions.scala 13:30 14:16]
    io_out <= _GEN_1
