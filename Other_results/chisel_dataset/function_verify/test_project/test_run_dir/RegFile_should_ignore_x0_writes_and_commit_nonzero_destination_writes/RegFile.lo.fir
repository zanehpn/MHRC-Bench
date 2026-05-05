FIRRTL version 1.2.0
circuit RegFile :
  module RegFile : @[src/main/scala/RegFile.scala 23:7]
    input clock : Clock @[src/main/scala/RegFile.scala 23:7]
    input reset : UInt<1> @[src/main/scala/RegFile.scala 23:7]
    input io_reader_raddr1 : UInt<5> @[src/main/scala/RegFile.scala 24:14]
    input io_reader_raddr2 : UInt<5> @[src/main/scala/RegFile.scala 24:14]
    output io_reader_rdata1 : UInt<32> @[src/main/scala/RegFile.scala 24:14]
    output io_reader_rdata2 : UInt<32> @[src/main/scala/RegFile.scala 24:14]
    input io_writer_wen : UInt<1> @[src/main/scala/RegFile.scala 24:14]
    input io_writer_waddr : UInt<5> @[src/main/scala/RegFile.scala 24:14]
    input io_writer_wdata : UInt<32> @[src/main/scala/RegFile.scala 24:14]

    mem regs : @[src/main/scala/RegFile.scala 25:17]
      data-type => UInt<32>
      depth => 32
      read-latency => 0
      write-latency => 1
      reader => io_reader_rdata1_MPORT
      reader => io_reader_rdata2_MPORT
      writer => MPORT
      read-under-write => undefined
    node _io_reader_rdata1_T = orr(io_reader_raddr1) @[src/main/scala/RegFile.scala 26:44]
    node _io_reader_rdata1_T_1 = mux(_io_reader_rdata1_T, regs.io_reader_rdata1_MPORT.data, UInt<1>("h0")) @[src/main/scala/RegFile.scala 26:26]
    node _io_reader_rdata2_T = orr(io_reader_raddr2) @[src/main/scala/RegFile.scala 27:44]
    node _io_reader_rdata2_T_1 = mux(_io_reader_rdata2_T, regs.io_reader_rdata2_MPORT.data, UInt<1>("h0")) @[src/main/scala/RegFile.scala 27:26]
    node _T = orr(io_writer_waddr) @[src/main/scala/RegFile.scala 28:40]
    node _T_1 = and(io_writer_wen, _T) @[src/main/scala/RegFile.scala 28:22]
    node _GEN_0 = validif(_T_1, io_writer_waddr) @[src/main/scala/RegFile.scala 28:45 29:9]
    node _GEN_1 = validif(_T_1, clock) @[src/main/scala/RegFile.scala 28:45 29:9]
    node _GEN_2 = mux(_T_1, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/RegFile.scala 25:17 28:45 29:9]
    node _GEN_3 = validif(_T_1, UInt<1>("h1")) @[src/main/scala/RegFile.scala 28:45 29:27]
    node _GEN_4 = validif(_T_1, io_writer_wdata) @[src/main/scala/RegFile.scala 28:45 29:27]
    io_reader_rdata1 <= _io_reader_rdata1_T_1 @[src/main/scala/RegFile.scala 26:20]
    io_reader_rdata2 <= _io_reader_rdata2_T_1 @[src/main/scala/RegFile.scala 27:20]
    regs.io_reader_rdata1_MPORT.addr <= io_reader_raddr1 @[src/main/scala/RegFile.scala 26:53]
    regs.io_reader_rdata1_MPORT.en <= UInt<1>("h1") @[src/main/scala/RegFile.scala 26:53]
    regs.io_reader_rdata1_MPORT.clk <= clock @[src/main/scala/RegFile.scala 26:53]
    regs.io_reader_rdata2_MPORT.addr <= io_reader_raddr2 @[src/main/scala/RegFile.scala 27:53]
    regs.io_reader_rdata2_MPORT.en <= UInt<1>("h1") @[src/main/scala/RegFile.scala 27:53]
    regs.io_reader_rdata2_MPORT.clk <= clock @[src/main/scala/RegFile.scala 27:53]
    regs.MPORT.addr <= _GEN_0
    regs.MPORT.en <= _GEN_2
    regs.MPORT.clk <= _GEN_1
    regs.MPORT.data <= _GEN_4
    regs.MPORT.mask <= _GEN_3
