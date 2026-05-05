FIRRTL version 1.2.0
circuit shift_reg_example :
  module shift_reg_example : @[src/main/scala/shift_reg.scala 65:11]
    input clock : Clock @[src/main/scala/shift_reg.scala 65:11]
    input reset : UInt<1> @[src/main/scala/shift_reg.scala 65:11]
    input io_shift : UInt<1> @[src/main/scala/shift_reg.scala 67:20]
    input io_load : UInt<1> @[src/main/scala/shift_reg.scala 67:20]
    input io_din : UInt<10> @[src/main/scala/shift_reg.scala 67:20]
    input io_sin : UInt<1> @[src/main/scala/shift_reg.scala 67:20]
    output io_qout : UInt<10> @[src/main/scala/shift_reg.scala 67:20]

    reg regs : UInt<10>, clock with :
      reset => (UInt<1>("h0"), regs) @[src/main/scala/shift_reg.scala 52:23]
    node _regs_T = bits(regs, 8, 0) @[src/main/scala/shift_reg.scala 58:21]
    node _regs_T_1 = cat(_regs_T, io_sin) @[src/main/scala/shift_reg.scala 58:36]
    node _GEN_0 = mux(io_shift, _regs_T_1, regs) @[src/main/scala/shift_reg.scala 58:14 52:23 75:24]
    node _GEN_1 = mux(io_load, io_din, _GEN_0) @[src/main/scala/shift_reg.scala 54:14 78:23]
    io_qout <= regs @[src/main/scala/shift_reg.scala 81:17]
    regs <= mux(reset, UInt<10>("h0"), _GEN_1) @[src/main/scala/shift_reg.scala 52:{23,23}]
