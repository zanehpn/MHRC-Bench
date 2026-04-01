FIRRTL version 1.2.0
circuit Memory :
  module Memory : @[src/main/scala/Memory.scala 26:7]
    input clock : Clock @[src/main/scala/Memory.scala 26:7]
    input reset : UInt<1> @[src/main/scala/Memory.scala 26:7]
    input io_imem_addr : UInt<32> @[src/main/scala/Memory.scala 27:14]
    output io_imem_inst : UInt<32> @[src/main/scala/Memory.scala 27:14]
    input io_dmem_addr : UInt<32> @[src/main/scala/Memory.scala 27:14]
    output io_dmem_rdata : UInt<32> @[src/main/scala/Memory.scala 27:14]
    input io_dmem_wen : UInt<1> @[src/main/scala/Memory.scala 27:14]
    input io_dmem_wdata : UInt<32> @[src/main/scala/Memory.scala 27:14]

    mem mem : @[src/main/scala/Memory.scala 34:16]
      data-type => UInt<8>
      depth => 16384
      read-latency => 0
      write-latency => 1
      reader => io_imem_inst_MPORT
      reader => io_imem_inst_MPORT_1
      reader => io_imem_inst_MPORT_2
      reader => io_imem_inst_MPORT_3
      reader => io_dmem_rdata_MPORT
      reader => io_dmem_rdata_MPORT_1
      reader => io_dmem_rdata_MPORT_2
      writer => MPORT
      writer => MPORT_1
      writer => MPORT_2
      writer => MPORT_3
      read-under-write => undefined
    node _io_imem_inst_T = add(io_imem_addr, UInt<32>("h3")) @[src/main/scala/Memory.scala 39:22]
    node _io_imem_inst_T_1 = tail(_io_imem_inst_T, 1) @[src/main/scala/Memory.scala 39:22]
    node _io_imem_inst_T_2 = bits(_io_imem_inst_T_1, 13, 0) @[src/main/scala/Memory.scala 39:8]
    node _io_imem_inst_T_3 = add(io_imem_addr, UInt<32>("h2")) @[src/main/scala/Memory.scala 40:22]
    node _io_imem_inst_T_4 = tail(_io_imem_inst_T_3, 1) @[src/main/scala/Memory.scala 40:22]
    node _io_imem_inst_T_5 = bits(_io_imem_inst_T_4, 13, 0) @[src/main/scala/Memory.scala 40:8]
    node _io_imem_inst_T_6 = add(io_imem_addr, UInt<32>("h1")) @[src/main/scala/Memory.scala 41:22]
    node _io_imem_inst_T_7 = tail(_io_imem_inst_T_6, 1) @[src/main/scala/Memory.scala 41:22]
    node _io_imem_inst_T_8 = bits(_io_imem_inst_T_7, 13, 0) @[src/main/scala/Memory.scala 41:8]
    node _io_imem_inst_T_9 = bits(io_imem_addr, 13, 0) @[src/main/scala/Memory.scala 42:8]
    node io_imem_inst_lo = cat(mem.io_imem_inst_MPORT_2.data, mem.io_imem_inst_MPORT_3.data) @[src/main/scala/Memory.scala 38:22]
    node io_imem_inst_hi = cat(mem.io_imem_inst_MPORT.data, mem.io_imem_inst_MPORT_1.data) @[src/main/scala/Memory.scala 38:22]
    node _io_imem_inst_T_10 = cat(io_imem_inst_hi, io_imem_inst_lo) @[src/main/scala/Memory.scala 38:22]
    node _io_dmem_rdata_T = add(io_dmem_addr, UInt<32>("h3")) @[src/main/scala/Memory.scala 46:22]
    node _io_dmem_rdata_T_1 = tail(_io_dmem_rdata_T, 1) @[src/main/scala/Memory.scala 46:22]
    node _io_dmem_rdata_T_2 = bits(_io_dmem_rdata_T_1, 13, 0) @[src/main/scala/Memory.scala 46:8]
    node _io_dmem_rdata_T_3 = add(io_dmem_addr, UInt<32>("h1")) @[src/main/scala/Memory.scala 47:22]
    node _io_dmem_rdata_T_4 = tail(_io_dmem_rdata_T_3, 1) @[src/main/scala/Memory.scala 47:22]
    node _io_dmem_rdata_T_5 = bits(_io_dmem_rdata_T_4, 13, 0) @[src/main/scala/Memory.scala 47:8]
    node _io_dmem_rdata_T_6 = bits(io_dmem_addr, 13, 0) @[src/main/scala/Memory.scala 48:8]
    node io_dmem_rdata_hi = cat(mem.io_dmem_rdata_MPORT.data, mem.io_dmem_rdata_MPORT_1.data) @[src/main/scala/Memory.scala 45:21]
    node _io_dmem_rdata_T_7 = cat(io_dmem_rdata_hi, mem.io_dmem_rdata_MPORT_2.data) @[src/main/scala/Memory.scala 45:21]
    node _T = add(io_dmem_addr, UInt<32>("h3")) @[src/main/scala/Memory.scala 52:22]
    node _T_1 = tail(_T, 1) @[src/main/scala/Memory.scala 52:22]
    node _T_2 = bits(_T_1, 13, 0) @[src/main/scala/Memory.scala 52:8]
    node _T_3 = bits(io_dmem_wdata, 31, 24) @[src/main/scala/Memory.scala 52:57]
    node _T_4 = add(io_dmem_addr, UInt<32>("h2")) @[src/main/scala/Memory.scala 53:22]
    node _T_5 = tail(_T_4, 1) @[src/main/scala/Memory.scala 53:22]
    node _T_6 = bits(_T_5, 13, 0) @[src/main/scala/Memory.scala 53:8]
    node _T_7 = bits(io_dmem_wdata, 23, 16) @[src/main/scala/Memory.scala 53:57]
    node _T_8 = add(io_dmem_addr, UInt<32>("h1")) @[src/main/scala/Memory.scala 54:22]
    node _T_9 = tail(_T_8, 1) @[src/main/scala/Memory.scala 54:22]
    node _T_10 = bits(_T_9, 13, 0) @[src/main/scala/Memory.scala 54:8]
    node _T_11 = bits(io_dmem_wdata, 15, 8) @[src/main/scala/Memory.scala 54:57]
    node _T_12 = bits(io_dmem_addr, 13, 0) @[src/main/scala/Memory.scala 55:8]
    node _T_13 = bits(io_dmem_wdata, 7, 0) @[src/main/scala/Memory.scala 55:39]
    node _GEN_0 = validif(io_dmem_wen, _T_2) @[src/main/scala/Memory.scala 51:21 52:8]
    node _GEN_1 = validif(io_dmem_wen, clock) @[src/main/scala/Memory.scala 51:21 52:8]
    node _GEN_2 = mux(io_dmem_wen, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/Memory.scala 34:16 51:21 52:8]
    node _GEN_3 = validif(io_dmem_wen, UInt<1>("h1")) @[src/main/scala/Memory.scala 51:21 52:41]
    node _GEN_4 = validif(io_dmem_wen, _T_3) @[src/main/scala/Memory.scala 51:21 52:41]
    node _GEN_5 = validif(io_dmem_wen, _T_6) @[src/main/scala/Memory.scala 51:21 53:8]
    node _GEN_6 = validif(io_dmem_wen, _T_7) @[src/main/scala/Memory.scala 51:21 53:41]
    node _GEN_7 = validif(io_dmem_wen, _T_10) @[src/main/scala/Memory.scala 51:21 54:8]
    node _GEN_8 = validif(io_dmem_wen, _T_11) @[src/main/scala/Memory.scala 51:21 54:41]
    node _GEN_9 = validif(io_dmem_wen, _T_12) @[src/main/scala/Memory.scala 51:21 55:8]
    node _GEN_10 = validif(io_dmem_wen, _T_13) @[src/main/scala/Memory.scala 51:21 55:23]
    io_imem_inst <= _io_imem_inst_T_10 @[src/main/scala/Memory.scala 38:16]
    io_dmem_rdata <= pad(_io_dmem_rdata_T_7, 32) @[src/main/scala/Memory.scala 45:15]
    mem.io_imem_inst_MPORT.addr <= _io_imem_inst_T_2 @[src/main/scala/Memory.scala 39:8]
    mem.io_imem_inst_MPORT.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 39:8]
    mem.io_imem_inst_MPORT.clk <= clock @[src/main/scala/Memory.scala 39:8]
    mem.io_imem_inst_MPORT_1.addr <= _io_imem_inst_T_5 @[src/main/scala/Memory.scala 40:8]
    mem.io_imem_inst_MPORT_1.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 40:8]
    mem.io_imem_inst_MPORT_1.clk <= clock @[src/main/scala/Memory.scala 40:8]
    mem.io_imem_inst_MPORT_2.addr <= _io_imem_inst_T_8 @[src/main/scala/Memory.scala 41:8]
    mem.io_imem_inst_MPORT_2.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 41:8]
    mem.io_imem_inst_MPORT_2.clk <= clock @[src/main/scala/Memory.scala 41:8]
    mem.io_imem_inst_MPORT_3.addr <= _io_imem_inst_T_9 @[src/main/scala/Memory.scala 42:8]
    mem.io_imem_inst_MPORT_3.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 42:8]
    mem.io_imem_inst_MPORT_3.clk <= clock @[src/main/scala/Memory.scala 42:8]
    mem.io_dmem_rdata_MPORT.addr <= _io_dmem_rdata_T_2 @[src/main/scala/Memory.scala 46:8]
    mem.io_dmem_rdata_MPORT.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 46:8]
    mem.io_dmem_rdata_MPORT.clk <= clock @[src/main/scala/Memory.scala 46:8]
    mem.io_dmem_rdata_MPORT_1.addr <= _io_dmem_rdata_T_5 @[src/main/scala/Memory.scala 47:8]
    mem.io_dmem_rdata_MPORT_1.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 47:8]
    mem.io_dmem_rdata_MPORT_1.clk <= clock @[src/main/scala/Memory.scala 47:8]
    mem.io_dmem_rdata_MPORT_2.addr <= _io_dmem_rdata_T_6 @[src/main/scala/Memory.scala 48:8]
    mem.io_dmem_rdata_MPORT_2.en <= UInt<1>("h1") @[src/main/scala/Memory.scala 48:8]
    mem.io_dmem_rdata_MPORT_2.clk <= clock @[src/main/scala/Memory.scala 48:8]
    mem.MPORT.addr <= _GEN_0
    mem.MPORT.en <= _GEN_2
    mem.MPORT.clk <= _GEN_1
    mem.MPORT.data <= _GEN_4
    mem.MPORT.mask <= _GEN_3
    mem.MPORT_1.addr <= _GEN_5
    mem.MPORT_1.en <= _GEN_2
    mem.MPORT_1.clk <= _GEN_1
    mem.MPORT_1.data <= _GEN_6
    mem.MPORT_1.mask <= _GEN_3
    mem.MPORT_2.addr <= _GEN_7
    mem.MPORT_2.en <= _GEN_2
    mem.MPORT_2.clk <= _GEN_1
    mem.MPORT_2.data <= _GEN_8
    mem.MPORT_2.mask <= _GEN_3
    mem.MPORT_3.addr <= _GEN_9
    mem.MPORT_3.en <= _GEN_2
    mem.MPORT_3.clk <= _GEN_1
    mem.MPORT_3.data <= _GEN_10
    mem.MPORT_3.mask <= _GEN_3
