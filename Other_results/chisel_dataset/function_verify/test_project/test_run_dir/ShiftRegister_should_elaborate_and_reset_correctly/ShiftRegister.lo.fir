FIRRTL version 1.2.0
circuit ShiftRegister :
  module ShiftRegister : @[src/main/scala/ShiftRegister.scala 6:7]
    input clock : Clock @[src/main/scala/ShiftRegister.scala 6:7]
    input reset : UInt<1> @[src/main/scala/ShiftRegister.scala 6:7]
    input io_in : UInt<4> @[src/main/scala/ShiftRegister.scala 8:14]
    output io_out : UInt<1> @[src/main/scala/ShiftRegister.scala 8:14]

    reg state : UInt<4>, clock with :
      reset => (UInt<1>("h0"), state) @[src/main/scala/ShiftRegister.scala 17:22]
    reg flag : UInt<4>, clock with :
      reset => (UInt<1>("h0"), flag) @[src/main/scala/ShiftRegister.scala 20:21]
    node _T = neq(flag, UInt<1>("h0")) @[src/main/scala/ShiftRegister.scala 23:13]
    node _state_T = shr(state, 1) @[src/main/scala/ShiftRegister.scala 25:20]
    node _flag_T = add(flag, UInt<1>("h1")) @[src/main/scala/ShiftRegister.scala 28:18]
    node _flag_T_1 = tail(_flag_T, 1) @[src/main/scala/ShiftRegister.scala 28:18]
    node _GEN_0 = mux(_T, state, UInt<1>("h0")) @[src/main/scala/ShiftRegister.scala 14:10 23:22 24:12]
    node _GEN_1 = mux(_T, _state_T, io_in) @[src/main/scala/ShiftRegister.scala 23:22 25:11 29:11]
    node _GEN_2 = mux(_T, flag, _flag_T_1) @[src/main/scala/ShiftRegister.scala 20:21 23:22 28:10]
    io_out <= bits(_GEN_0, 0, 0)
    state <= mux(reset, UInt<4>("h0"), _GEN_1) @[src/main/scala/ShiftRegister.scala 17:{22,22}]
    flag <= mux(reset, UInt<4>("h0"), _GEN_2) @[src/main/scala/ShiftRegister.scala 20:{21,21}]
