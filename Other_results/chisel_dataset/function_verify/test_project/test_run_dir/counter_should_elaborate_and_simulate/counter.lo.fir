FIRRTL version 1.2.0
circuit counter :
  module counter : @[src/main/scala/Counter.scala 7:7]
    input clock : Clock @[src/main/scala/Counter.scala 7:7]
    input reset : UInt<1> @[src/main/scala/Counter.scala 7:7]
    output io_out : UInt<3> @[src/main/scala/Counter.scala 8:14]

    reg counter : UInt<3>, clock with :
      reset => (UInt<1>("h0"), counter) @[src/main/scala/Counter.scala 12:24]
    node _count_buffer_T = add(counter, UInt<1>("h1")) @[src/main/scala/Counter.scala 15:65]
    node _count_buffer_T_1 = tail(_count_buffer_T, 1) @[src/main/scala/Counter.scala 15:65]
    node _count_buffer_T_2 = eq(counter, UInt<4>("h8")) @[src/main/scala/Counter.scala 15:84]
    node _count_buffer_T_3 = add(counter, UInt<1>("h1")) @[src/main/scala/Counter.scala 15:110]
    node _count_buffer_T_4 = tail(_count_buffer_T_3, 1) @[src/main/scala/Counter.scala 15:110]
    node _count_buffer_T_5 = mux(_count_buffer_T_2, UInt<1>("h0"), _count_buffer_T_4) @[src/main/scala/Counter.scala 15:75]
    node count_buffer = mux(UInt<1>("h1"), _count_buffer_T_1, _count_buffer_T_5) @[src/main/scala/Counter.scala 15:25]
    io_out <= counter @[src/main/scala/Counter.scala 20:10]
    counter <= mux(reset, UInt<3>("h0"), count_buffer) @[src/main/scala/Counter.scala 12:{24,24} 17:11]
