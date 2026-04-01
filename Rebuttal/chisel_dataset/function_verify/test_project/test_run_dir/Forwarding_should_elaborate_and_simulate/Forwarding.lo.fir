FIRRTL version 1.2.0
circuit Forwarding :
  module Forwarding : @[src/main/scala/lab8ex2.scala 4:7]
    input clock : Clock @[src/main/scala/lab8ex2.scala 4:7]
    input reset : UInt<1> @[src/main/scala/lab8ex2.scala 4:7]
    output io_out_0 : UInt<8> @[src/main/scala/lab8ex2.scala 5:13]
    output io_out_1 : UInt<8> @[src/main/scala/lab8ex2.scala 5:13]
    input io_enable : UInt<1> @[src/main/scala/lab8ex2.scala 5:13]
    input io_rdAddr : UInt<10> @[src/main/scala/lab8ex2.scala 5:13]
    input io_wrAddr : UInt<10> @[src/main/scala/lab8ex2.scala 5:13]
    input io_wrData_0 : UInt<8> @[src/main/scala/lab8ex2.scala 5:13]
    input io_wrData_1 : UInt<8> @[src/main/scala/lab8ex2.scala 5:13]
    input io_mask_0 : UInt<1> @[src/main/scala/lab8ex2.scala 5:13]
    input io_mask_1 : UInt<1> @[src/main/scala/lab8ex2.scala 5:13]
    input io_wr_en : UInt<1> @[src/main/scala/lab8ex2.scala 5:13]

    mem memory_0 : @[src/main/scala/lab8ex2.scala 14:30]
      data-type => UInt<8>
      depth => 1024
      read-latency => 1
      write-latency => 1
      reader => memData
      writer => MPORT
      read-under-write => undefined
    mem memory_1 : @[src/main/scala/lab8ex2.scala 14:30]
      data-type => UInt<8>
      depth => 1024
      read-latency => 1
      write-latency => 1
      reader => memData
      writer => MPORT
      read-under-write => undefined
    reg wrDataReg_0 : UInt<8>, clock with :
      reset => (UInt<1>("h0"), wrDataReg_0) @[src/main/scala/lab8ex2.scala 15:29]
    reg wrDataReg_1 : UInt<8>, clock with :
      reset => (UInt<1>("h0"), wrDataReg_1) @[src/main/scala/lab8ex2.scala 15:29]
    node _doForwardReg_T = eq(io_wrAddr, io_rdAddr) @[src/main/scala/lab8ex2.scala 16:44]
    node _doForwardReg_T_1 = and(_doForwardReg_T, io_wr_en) @[src/main/scala/lab8ex2.scala 16:58]
    reg doForwardReg : UInt<1>, clock with :
      reset => (UInt<1>("h0"), doForwardReg) @[src/main/scala/lab8ex2.scala 16:32]
    node _GEN_0 = validif(io_enable, io_rdAddr) @[src/main/scala/lab8ex2.scala 17:{30,30}]
    node _GEN_1 = mux(io_enable, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/lab8ex2.scala 14:30 17:{30,30}]
    node _memData_WIRE = _GEN_0 @[src/main/scala/lab8ex2.scala 17:30]
    node _GEN_2 = validif(io_enable, _memData_WIRE) @[src/main/scala/lab8ex2.scala 17:{30,30}]
    node _GEN_3 = validif(io_enable, clock) @[src/main/scala/lab8ex2.scala 17:{30,30}]
    node _GEN_4 = validif(io_mask_0, io_wrData_0) @[src/main/scala/lab8ex2.scala 19:{22,22}]
    node _GEN_5 = mux(io_mask_0, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/lab8ex2.scala 19:{22,22,22}]
    node _GEN_6 = validif(io_mask_1, io_wrData_1) @[src/main/scala/lab8ex2.scala 19:{22,22}]
    node _GEN_7 = mux(io_mask_1, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/lab8ex2.scala 19:{22,22,22}]
    node _GEN_8 = validif(io_wr_en, io_wrAddr) @[src/main/scala/lab8ex2.scala 18:22 19:22]
    node _GEN_9 = validif(io_wr_en, clock) @[src/main/scala/lab8ex2.scala 18:22 19:22]
    node _GEN_10 = mux(io_wr_en, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/lab8ex2.scala 18:22 19:22 14:30]
    node _GEN_11 = validif(io_wr_en, _GEN_5) @[src/main/scala/lab8ex2.scala 18:22]
    node _GEN_12 = validif(io_wr_en, _GEN_7) @[src/main/scala/lab8ex2.scala 18:22]
    node _GEN_13 = validif(io_wr_en, _GEN_4) @[src/main/scala/lab8ex2.scala 18:22]
    node _GEN_14 = validif(io_wr_en, _GEN_6) @[src/main/scala/lab8ex2.scala 18:22]
    node _io_out_0_T = mux(doForwardReg, wrDataReg_0, memory_0.memData.data) @[src/main/scala/lab8ex2.scala 21:27]
    node _io_out_1_T = mux(doForwardReg, wrDataReg_1, memory_1.memData.data) @[src/main/scala/lab8ex2.scala 22:27]
    io_out_0 <= _io_out_0_T @[src/main/scala/lab8ex2.scala 21:20]
    io_out_1 <= _io_out_1_T @[src/main/scala/lab8ex2.scala 22:20]
    memory_0.memData.addr <= _GEN_2
    memory_1.memData.addr <= _GEN_2
    memory_0.memData.en <= _GEN_1
    memory_1.memData.en <= _GEN_1
    memory_0.memData.clk <= _GEN_3
    memory_1.memData.clk <= _GEN_3
    memory_0.MPORT.addr <= _GEN_8
    memory_1.MPORT.addr <= _GEN_8
    memory_0.MPORT.en <= _GEN_10
    memory_1.MPORT.en <= _GEN_10
    memory_0.MPORT.clk <= _GEN_9
    memory_1.MPORT.clk <= _GEN_9
    memory_0.MPORT.data <= _GEN_13
    memory_1.MPORT.data <= _GEN_14
    memory_0.MPORT.mask <= _GEN_11
    memory_1.MPORT.mask <= _GEN_12
    wrDataReg_0 <= io_wrData_0 @[src/main/scala/lab8ex2.scala 15:29]
    wrDataReg_1 <= io_wrData_1 @[src/main/scala/lab8ex2.scala 15:29]
    doForwardReg <= _doForwardReg_T_1 @[src/main/scala/lab8ex2.scala 16:32]
