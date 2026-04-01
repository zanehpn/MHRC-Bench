FIRRTL version 1.2.0
circuit ClockCrossingReg_w8 :
  module ClockCrossingReg_w8 : @[src/main/scala/SynchronizerReg.scala 191:7]
    input clock : Clock @[src/main/scala/SynchronizerReg.scala 191:7]
    input reset : UInt<1> @[src/main/scala/SynchronizerReg.scala 191:7]
    input io_d : UInt<8> @[src/main/scala/SynchronizerReg.scala 195:14]
    output io_q : UInt<8> @[src/main/scala/SynchronizerReg.scala 195:14]
    input io_en : UInt<1> @[src/main/scala/SynchronizerReg.scala 195:14]

    reg cdc_reg : UInt<8>, clock with :
      reset => (UInt<1>("h0"), cdc_reg) @[src/main/scala/SynchronizerReg.scala 201:38]
    node _GEN_0 = mux(io_en, io_d, cdc_reg) @[src/main/scala/SynchronizerReg.scala 201:{38,38,38}]
    io_q <= cdc_reg @[src/main/scala/SynchronizerReg.scala 202:8]
    cdc_reg <= mux(reset, UInt<8>("h0"), _GEN_0) @[src/main/scala/SynchronizerReg.scala 201:{38,38}]
