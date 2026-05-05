FIRRTL version 1.2.0
circuit MaxN :
  module MaxN : @[src/main/scala/MaxN.scala 6:7]
    input clock : Clock @[src/main/scala/MaxN.scala 6:7]
    input reset : UInt<1> @[src/main/scala/MaxN.scala 6:7]
    input io_nums_0 : UInt<16> @[src/main/scala/MaxN.scala 10:15]
    input io_nums_1 : UInt<16> @[src/main/scala/MaxN.scala 10:15]
    input io_nums_2 : UInt<16> @[src/main/scala/MaxN.scala 10:15]
    input io_ids_0 : UInt<4> @[src/main/scala/MaxN.scala 10:15]
    input io_ids_1 : UInt<4> @[src/main/scala/MaxN.scala 10:15]
    input io_ids_2 : UInt<4> @[src/main/scala/MaxN.scala 10:15]
    output io_maxNum : UInt<16> @[src/main/scala/MaxN.scala 10:15]
    output io_maxId : UInt<4> @[src/main/scala/MaxN.scala 10:15]

    node _T = geq(io_nums_0, io_nums_1) @[src/main/scala/MaxN.scala 21:20]
    node _T_1 = geq(io_nums_0, io_nums_2) @[src/main/scala/MaxN.scala 22:23]
    node _GEN_0 = mux(_T_1, io_ids_0, io_ids_2) @[src/main/scala/MaxN.scala 22:37 23:19 26:19]
    node _GEN_1 = mux(_T_1, io_nums_0, io_nums_2) @[src/main/scala/MaxN.scala 22:37 24:20 27:20]
    node _T_2 = geq(io_nums_1, io_nums_2) @[src/main/scala/MaxN.scala 30:23]
    node _GEN_2 = mux(_T_2, io_ids_1, io_ids_2) @[src/main/scala/MaxN.scala 30:37 31:19 34:19]
    node _GEN_3 = mux(_T_2, io_nums_1, UInt<1>("h0")) @[src/main/scala/MaxN.scala 17:14 30:37 32:20]
    node _GEN_4 = mux(_T, _GEN_0, _GEN_2) @[src/main/scala/MaxN.scala 21:34]
    node _GEN_5 = mux(_T, _GEN_1, _GEN_3) @[src/main/scala/MaxN.scala 21:34]
    io_maxNum <= _GEN_5
    io_maxId <= _GEN_4
