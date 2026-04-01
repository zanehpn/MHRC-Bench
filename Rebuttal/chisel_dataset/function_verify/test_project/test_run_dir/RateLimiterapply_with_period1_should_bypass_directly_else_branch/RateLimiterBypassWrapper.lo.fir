FIRRTL version 1.2.0
circuit RateLimiterBypassWrapper :
  module RateLimiterBypassWrapper : @[src/test/scala/LimiterFuncSpec.scala 9:7]
    input clock : Clock @[src/test/scala/LimiterFuncSpec.scala 9:7]
    input reset : UInt<1> @[src/test/scala/LimiterFuncSpec.scala 9:7]
    output io_in_ready : UInt<1> @[src/test/scala/LimiterFuncSpec.scala 10:14]
    input io_in_valid : UInt<1> @[src/test/scala/LimiterFuncSpec.scala 10:14]
    input io_in_bits : UInt<8> @[src/test/scala/LimiterFuncSpec.scala 10:14]
    input io_out_ready : UInt<1> @[src/test/scala/LimiterFuncSpec.scala 10:14]
    output io_out_valid : UInt<1> @[src/test/scala/LimiterFuncSpec.scala 10:14]
    output io_out_bits : UInt<8> @[src/test/scala/LimiterFuncSpec.scala 10:14]

    io_in_ready <= io_out_ready @[src/test/scala/LimiterFuncSpec.scala 18:10]
    io_out_valid <= io_in_valid @[src/test/scala/LimiterFuncSpec.scala 18:10]
    io_out_bits <= io_in_bits @[src/test/scala/LimiterFuncSpec.scala 18:10]
