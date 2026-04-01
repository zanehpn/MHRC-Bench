FIRRTL version 1.2.0
circuit Mux_Case :
  module Mux_Case : @[src/main/scala/Mux_Case.scala 10:7]
    input clock : Clock @[src/main/scala/Mux_Case.scala 10:7]
    input reset : UInt<1> @[src/main/scala/Mux_Case.scala 10:7]
    input io_select : UInt<3> @[src/main/scala/Mux_Case.scala 11:15]
    output io_out : UInt<32> @[src/main/scala/Mux_Case.scala 11:15]

    node _io_out_T = eq(io_select, UInt<1>("h0")) @[src/main/scala/Mux_Case.scala 15:16]
    node _io_out_T_1 = eq(io_select, UInt<1>("h1")) @[src/main/scala/Mux_Case.scala 16:16]
    node _io_out_T_2 = eq(io_select, UInt<2>("h2")) @[src/main/scala/Mux_Case.scala 17:16]
    node _io_out_T_3 = eq(io_select, UInt<2>("h3")) @[src/main/scala/Mux_Case.scala 18:16]
    node _io_out_T_4 = eq(io_select, UInt<3>("h4")) @[src/main/scala/Mux_Case.scala 19:16]
    node _io_out_T_5 = mux(_io_out_T_4, UInt<6>("h20"), UInt<1>("h0")) @[src/main/scala/chisel3/util/Mux.scala 126:16]
    node _io_out_T_6 = mux(_io_out_T_3, UInt<5>("h18"), _io_out_T_5) @[src/main/scala/chisel3/util/Mux.scala 126:16]
    node _io_out_T_7 = mux(_io_out_T_2, UInt<5>("h10"), _io_out_T_6) @[src/main/scala/chisel3/util/Mux.scala 126:16]
    node _io_out_T_8 = mux(_io_out_T_1, UInt<4>("h8"), _io_out_T_7) @[src/main/scala/chisel3/util/Mux.scala 126:16]
    node _io_out_T_9 = mux(_io_out_T, UInt<1>("h0"), _io_out_T_8) @[src/main/scala/chisel3/util/Mux.scala 126:16]
    io_out <= pad(_io_out_T_9, 32) @[src/main/scala/Mux_Case.scala 14:10]
