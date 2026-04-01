FIRRTL version 1.2.0
circuit SynchronizerShiftReg_w1_d3 :
  module NonSyncResetSynchronizerPrimitiveShiftReg_d3 : @[src/main/scala/SynchronizerReg.scala 37:15]
    input clock : Clock @[src/main/scala/SynchronizerReg.scala 37:15]
    input reset : UInt<1> @[src/main/scala/SynchronizerReg.scala 37:15]
    input io_d : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]
    output io_q : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]

    reg sync_0 : UInt<1>, clock with :
      reset => (UInt<1>("h0"), sync_0) @[src/main/scala/SynchronizerReg.scala 51:22]
    reg sync_1 : UInt<1>, clock with :
      reset => (UInt<1>("h0"), sync_1) @[src/main/scala/SynchronizerReg.scala 51:22]
    reg sync_2 : UInt<1>, clock with :
      reset => (UInt<1>("h0"), sync_2) @[src/main/scala/SynchronizerReg.scala 51:22]
    node _sync_2_T = bits(io_d, 0, 0) @[src/main/scala/SynchronizerReg.scala 54:22]
    io_q <= sync_0 @[src/main/scala/SynchronizerReg.scala 59:8]
    sync_0 <= mux(reset, UInt<1>("h0"), sync_1) @[src/main/scala/SynchronizerReg.scala 51:{22,22} 57:10]
    sync_1 <= mux(reset, UInt<1>("h0"), sync_2) @[src/main/scala/SynchronizerReg.scala 51:{22,22} 57:10]
    sync_2 <= mux(reset, UInt<1>("h0"), _sync_2_T) @[src/main/scala/SynchronizerReg.scala 51:{22,22} 54:14]

  module SynchronizerShiftReg_w1_d3 : @[src/main/scala/SynchronizerReg.scala 169:7]
    input clock : Clock @[src/main/scala/SynchronizerReg.scala 169:7]
    input reset : UInt<1> @[src/main/scala/SynchronizerReg.scala 169:7]
    input io_d : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]
    output io_q : UInt<1> @[src/main/scala/deps/AbstractPipelineReg.scala 6:14]

    inst output_chain of NonSyncResetSynchronizerPrimitiveShiftReg_d3 @[src/main/scala/deps/AbstractPipelineReg.scala 14:23]
    node _output_T = bits(io_d, 0, 0) @[src/main/scala/SynchronizerReg.scala 173:39]
    node output_0 = output_chain.io_q @[src/main/scala/deps/AbstractPipelineReg.scala 17:{24,24}]
    io_q <= output_0 @[src/main/scala/SynchronizerReg.scala 175:8]
    output_chain.clock <= clock
    output_chain.reset <= reset
    output_chain.io_d <= _output_T @[src/main/scala/deps/AbstractPipelineReg.scala 16:16]
