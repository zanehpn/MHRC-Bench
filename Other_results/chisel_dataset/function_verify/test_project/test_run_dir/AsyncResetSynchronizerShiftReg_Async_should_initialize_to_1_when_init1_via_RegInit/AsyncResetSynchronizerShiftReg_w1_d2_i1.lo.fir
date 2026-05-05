FIRRTL version 1.2.0
circuit AsyncResetSynchronizerShiftReg_w1_d2_i1 :
  module AsyncResetSynchronizerPrimitiveShiftReg_d2_i1 : @[src/main/scala/SynchronizerReg.scala 68:19]
    input clock : Clock @[src/main/scala/SynchronizerReg.scala 68:19]
    input reset : AsyncReset @[src/main/scala/SynchronizerReg.scala 68:19]
    input io_d : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]
    output io_q : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]

    reg sync_0 : UInt<1>, clock with :
      reset => (reset, UInt<1>("h1")) @[src/main/scala/SynchronizerReg.scala 51:22]
    reg sync_1 : UInt<1>, clock with :
      reset => (reset, UInt<1>("h1")) @[src/main/scala/SynchronizerReg.scala 51:22]
    node _sync_1_T = bits(io_d, 0, 0) @[src/main/scala/SynchronizerReg.scala 54:22]
    io_q <= sync_0 @[src/main/scala/SynchronizerReg.scala 59:8]
    sync_0 <= sync_1 @[src/main/scala/SynchronizerReg.scala 51:{22,22} 57:10]
    sync_1 <= _sync_1_T @[src/main/scala/SynchronizerReg.scala 51:{22,22} 54:14]

  module AsyncResetSynchronizerShiftReg_w1_d2_i1 : @[src/main/scala/SynchronizerReg.scala 80:7]
    input clock : Clock @[src/main/scala/SynchronizerReg.scala 80:7]
    input reset : UInt<1> @[src/main/scala/SynchronizerReg.scala 80:7]
    input io_d : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]
    output io_q : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]

    inst output_chain of AsyncResetSynchronizerPrimitiveShiftReg_d2_i1 @[src/main/scala/deps/AbstractPipelineReg.scala 14:23]
    node _output_T = asAsyncReset(reset) @[src/main/scala/SynchronizerReg.scala 86:21]
    node _output_T_1 = bits(io_d, 0, 0) @[src/main/scala/SynchronizerReg.scala 87:41]
    node output_0 = output_chain.io_q @[src/main/scala/deps/AbstractPipelineReg.scala 17:{24,24}]
    io_q <= output_0 @[src/main/scala/SynchronizerReg.scala 90:8]
    output_chain.clock <= clock
    output_chain.reset <= _output_T
    output_chain.io_d <= _output_T_1 @[src/main/scala/deps/AbstractPipelineReg.scala 16:16]
