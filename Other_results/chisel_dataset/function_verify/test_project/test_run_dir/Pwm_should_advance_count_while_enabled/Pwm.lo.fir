FIRRTL version 1.2.0
circuit Pwm :
  module Pwm : @[src/main/scala/PWM.scala 25:7]
    input clock : Clock @[src/main/scala/PWM.scala 25:7]
    input reset : UInt<1> @[src/main/scala/PWM.scala 25:7]
    input io_enable : UInt<1> @[src/main/scala/PWM.scala 26:14]
    input io_pulseWidth : UInt<4> @[src/main/scala/PWM.scala 26:14]
    input io_period : UInt<4> @[src/main/scala/PWM.scala 26:14]
    output io_out : UInt<1> @[src/main/scala/PWM.scala 26:14]

    reg count : UInt<4>, clock with :
      reset => (UInt<1>("h0"), count) @[src/main/scala/PWM.scala 28:18]
    node _io_out_T = leq(count, io_pulseWidth) @[src/main/scala/PWM.scala 30:32]
    node _io_out_T_1 = and(io_enable, _io_out_T) @[src/main/scala/PWM.scala 30:23]
    node _count_T = add(count, UInt<1>("h1")) @[src/main/scala/PWM.scala 31:60]
    node _count_T_1 = tail(_count_T, 1) @[src/main/scala/PWM.scala 31:60]
    node _GEN_0 = mux(io_enable, _count_T_1, count) @[src/main/scala/PWM.scala 28:18 31:{43,51}]
    node _T = geq(count, io_period) @[src/main/scala/PWM.scala 32:15]
    node _T_1 = not(io_enable) @[src/main/scala/PWM.scala 32:31]
    node _T_2 = or(_T, _T_1) @[src/main/scala/PWM.scala 32:28]
    node _GEN_1 = mux(_T_2, UInt<1>("h0"), _GEN_0) @[src/main/scala/PWM.scala 32:{43,51}]
    io_out <= _io_out_T_1 @[src/main/scala/PWM.scala 30:10]
    count <= _GEN_1
