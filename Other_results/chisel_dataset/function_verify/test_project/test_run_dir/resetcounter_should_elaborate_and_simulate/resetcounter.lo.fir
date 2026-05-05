FIRRTL version 1.2.0
circuit resetcounter :
  module resetcounter : @[src/main/scala/lab1ex2.scala 3:7]
    input clock : Clock @[src/main/scala/lab1ex2.scala 3:7]
    input reset : UInt<1> @[src/main/scala/lab1ex2.scala 3:7]
    output io_result : UInt<1> @[src/main/scala/lab1ex2.scala 4:14]

    reg count : UInt<8>, clock with :
      reset => (UInt<1>("h0"), count) @[src/main/scala/lab1ex2.scala 8:22]
    node _T = eq(count, UInt<8>("h80")) @[src/main/scala/lab1ex2.scala 10:16]
    node _count_T = add(count, UInt<1>("h1")) @[src/main/scala/lab1ex2.scala 14:21]
    node _count_T_1 = tail(_count_T, 1) @[src/main/scala/lab1ex2.scala 14:21]
    node _GEN_0 = mux(_T, UInt<1>("h0"), _count_T_1) @[src/main/scala/lab1ex2.scala 10:23 12:14 14:14]
    node _io_result_T = dshr(count, UInt<3>("h4")) @[src/main/scala/lab1ex2.scala 16:21]
    node _io_result_T_1 = bits(_io_result_T, 0, 0) @[src/main/scala/lab1ex2.scala 16:21]
    io_result <= _io_result_T_1 @[src/main/scala/lab1ex2.scala 16:14]
    count <= mux(reset, UInt<8>("h0"), _GEN_0) @[src/main/scala/lab1ex2.scala 8:{22,22}]
