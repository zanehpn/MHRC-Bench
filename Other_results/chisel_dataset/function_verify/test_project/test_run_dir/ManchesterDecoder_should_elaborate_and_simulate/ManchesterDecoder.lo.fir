FIRRTL version 1.2.0
circuit ManchesterDecoder :
  module ManchesterDecoder : @[src/main/scala/Manc_enco_FSM.scala 6:7]
    input clock : Clock @[src/main/scala/Manc_enco_FSM.scala 6:7]
    input reset : UInt<1> @[src/main/scala/Manc_enco_FSM.scala 6:7]
    input io_encodedSignal : UInt<1> @[src/main/scala/Manc_enco_FSM.scala 7:14]
    output io_decodedData : UInt<1> @[src/main/scala/Manc_enco_FSM.scala 7:14]

    reg stateReg : UInt<1>, clock with :
      reset => (UInt<1>("h0"), stateReg) @[src/main/scala/Manc_enco_FSM.scala 16:25]
    reg prevBitReg : UInt<1>, clock with :
      reset => (UInt<1>("h0"), prevBitReg) @[src/main/scala/Manc_enco_FSM.scala 19:27]
    node _T = eq(UInt<1>("h0"), stateReg) @[src/main/scala/Manc_enco_FSM.scala 25:20]
    node _T_1 = eq(prevBitReg, UInt<1>("h1")) @[src/main/scala/Manc_enco_FSM.scala 28:23]
    node _T_2 = eq(io_encodedSignal, UInt<1>("h0")) @[src/main/scala/Manc_enco_FSM.scala 28:54]
    node _T_3 = and(_T_1, _T_2) @[src/main/scala/Manc_enco_FSM.scala 28:34]
    node _GEN_0 = mux(_T_3, UInt<1>("h1"), stateReg) @[src/main/scala/Manc_enco_FSM.scala 28:67 29:18 16:25]
    node _GEN_1 = mux(_T_3, UInt<1>("h0"), UInt<1>("h0")) @[src/main/scala/Manc_enco_FSM.scala 22:18 28:67 30:24]
    node _T_4 = eq(UInt<1>("h1"), stateReg) @[src/main/scala/Manc_enco_FSM.scala 25:20]
    node _T_5 = eq(prevBitReg, UInt<1>("h0")) @[src/main/scala/Manc_enco_FSM.scala 35:23]
    node _T_6 = eq(io_encodedSignal, UInt<1>("h1")) @[src/main/scala/Manc_enco_FSM.scala 35:55]
    node _T_7 = and(_T_5, _T_6) @[src/main/scala/Manc_enco_FSM.scala 35:35]
    node _GEN_2 = mux(_T_7, UInt<1>("h0"), stateReg) @[src/main/scala/Manc_enco_FSM.scala 35:67 36:18 16:25]
    node _GEN_3 = mux(_T_7, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/Manc_enco_FSM.scala 22:18 35:67 37:24]
    node _GEN_4 = mux(_T_4, _GEN_2, stateReg) @[src/main/scala/Manc_enco_FSM.scala 25:20 16:25]
    node _GEN_5 = mux(_T_4, _GEN_3, UInt<1>("h0")) @[src/main/scala/Manc_enco_FSM.scala 22:18 25:20]
    node _GEN_6 = mux(_T, _GEN_0, _GEN_4) @[src/main/scala/Manc_enco_FSM.scala 25:20]
    node _GEN_7 = mux(_T, _GEN_1, _GEN_5) @[src/main/scala/Manc_enco_FSM.scala 25:20]
    io_decodedData <= _GEN_7
    stateReg <= mux(reset, UInt<1>("h0"), _GEN_6) @[src/main/scala/Manc_enco_FSM.scala 16:{25,25}]
    prevBitReg <= io_encodedSignal @[src/main/scala/Manc_enco_FSM.scala 19:27]
