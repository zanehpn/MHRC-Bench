FIRRTL version 1.2.0
circuit decoder_example :
  module decoder_example : @[src/main/scala/decoder.scala 34:11]
    input clock : Clock @[src/main/scala/decoder.scala 34:11]
    input reset : UInt<1> @[src/main/scala/decoder.scala 34:11]
    input io_in : UInt<4> @[src/main/scala/decoder.scala 35:20]
    output io_out : UInt<16> @[src/main/scala/decoder.scala 35:20]

    node _io_out_T = dshl(UInt<1>("h1"), io_in) @[src/main/scala/decoder.scala 30:39]
    io_out <= _io_out_T @[src/main/scala/decoder.scala 39:16]
