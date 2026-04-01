FIRRTL version 1.2.0
circuit BitPattern :
  module BitPattern : @[src/main/scala/BitPattern.scala 12:7]
    input clock : Clock @[src/main/scala/BitPattern.scala 12:7]
    input reset : UInt<1> @[src/main/scala/BitPattern.scala 12:7]
    input io_in : UInt<8> @[src/main/scala/BitPattern.scala 13:16]
    output io_out : UInt<1> @[src/main/scala/BitPattern.scala 13:16]

    node _T = and(io_in, UInt<8>("h9e")) @[src/main/scala/BitPattern.scala 17:17]
    node _T_1 = eq(UInt<5>("h16"), _T) @[src/main/scala/BitPattern.scala 17:17]
    node _GEN_0 = mux(_T_1, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/BitPattern.scala 17:30 18:16 20:16]
    io_out <= _GEN_0
