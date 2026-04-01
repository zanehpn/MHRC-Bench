FIRRTL version 1.2.0
circuit AsyncResetRegVec_w8_i171 :
  module AsyncResetRegVec_w8_i171 : @[src/main/scala/AsyncResetReg.scala 56:7]
    input clock : Clock @[src/main/scala/AsyncResetReg.scala 56:7]
    input reset : UInt<1> @[src/main/scala/AsyncResetReg.scala 56:7]
    input io_d : UInt<8> @[src/main/scala/AsyncResetReg.scala 59:14]
    output io_q : UInt<8> @[src/main/scala/AsyncResetReg.scala 59:14]
    input io_en : UInt<1> @[src/main/scala/AsyncResetReg.scala 59:14]

    node _reg_T = asAsyncReset(reset) @[src/main/scala/AsyncResetReg.scala 61:29]
    reg reg : UInt<8>, clock with :
      reset => (_reg_T, UInt<8>("hab")) @[src/main/scala/AsyncResetReg.scala 61:50]
    node _GEN_0 = mux(io_en, io_d, reg) @[src/main/scala/AsyncResetReg.scala 62:16 61:50 63:9]
    io_q <= reg @[src/main/scala/AsyncResetReg.scala 65:8]
    reg <= _GEN_0 @[src/main/scala/AsyncResetReg.scala 61:{50,50}]
