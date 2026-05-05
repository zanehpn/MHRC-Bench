FIRRTL version 1.2.0
circuit LFSR :
  module LFSR : @[src/main/scala/LFSR.scala 6:7]
    input clock : Clock @[src/main/scala/LFSR.scala 6:7]
    input reset : UInt<1> @[src/main/scala/LFSR.scala 6:7]
    output io_lfsr_6 : UInt<6> @[src/main/scala/LFSR.scala 8:14]
    output io_lfsr_3r : UInt<3> @[src/main/scala/LFSR.scala 8:14]

    reg D0123456 : UInt<6>, clock with :
      reset => (UInt<1>("h0"), D0123456) @[src/main/scala/LFSR.scala 17:25]
    node _nxt_D0123456_T = bits(D0123456, 4, 0) @[src/main/scala/LFSR.scala 21:34]
    node _nxt_D0123456_T_1 = bits(D0123456, 5, 5) @[src/main/scala/LFSR.scala 21:50]
    node _nxt_D0123456_T_2 = bits(D0123456, 4, 4) @[src/main/scala/LFSR.scala 21:64]
    node _nxt_D0123456_T_3 = xor(_nxt_D0123456_T_1, _nxt_D0123456_T_2) @[src/main/scala/LFSR.scala 21:54]
    node nxt_D0123456 = cat(_nxt_D0123456_T, _nxt_D0123456_T_3) @[src/main/scala/LFSR.scala 21:25]
    node _io_lfsr_3r_T = bits(D0123456, 1, 1) @[src/main/scala/LFSR.scala 29:29]
    node _io_lfsr_3r_T_1 = bits(D0123456, 3, 3) @[src/main/scala/LFSR.scala 29:42]
    node _io_lfsr_3r_T_2 = bits(D0123456, 5, 5) @[src/main/scala/LFSR.scala 29:55]
    node io_lfsr_3r_hi = cat(_io_lfsr_3r_T, _io_lfsr_3r_T_1) @[src/main/scala/LFSR.scala 29:20]
    node _io_lfsr_3r_T_3 = cat(io_lfsr_3r_hi, _io_lfsr_3r_T_2) @[src/main/scala/LFSR.scala 29:20]
    io_lfsr_6 <= D0123456 @[src/main/scala/LFSR.scala 27:13]
    io_lfsr_3r <= _io_lfsr_3r_T_3 @[src/main/scala/LFSR.scala 29:14]
    D0123456 <= mux(reset, UInt<6>("h1"), nxt_D0123456) @[src/main/scala/LFSR.scala 17:{25,25} 24:12]
