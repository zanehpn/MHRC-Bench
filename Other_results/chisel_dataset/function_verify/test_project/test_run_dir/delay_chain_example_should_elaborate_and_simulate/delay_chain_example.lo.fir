FIRRTL version 1.2.0
circuit delay_chain_example :
  module delay_chain_example : @[src/main/scala/delay_chain.scala 31:11]
    input clock : Clock @[src/main/scala/delay_chain.scala 31:11]
    input reset : UInt<1> @[src/main/scala/delay_chain.scala 31:11]
    input io_en : UInt<1> @[src/main/scala/delay_chain.scala 34:20]
    input io_in : UInt<8> @[src/main/scala/delay_chain.scala 34:20]
    output io_out : UInt<8> @[src/main/scala/delay_chain.scala 34:20]

    mem io_out_mem : @[src/main/scala/delay_chain.scala 43:40]
      data-type => UInt<8>
      depth => 16
      read-latency => 1
      write-latency => 1
      reader => io_out_out
      writer => io_out_MPORT
      read-under-write => undefined
    reg io_out_raddr : UInt<4>, clock with :
      reset => (UInt<1>("h0"), io_out_raddr) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    node io_out_raddr_wrap_wrap = eq(io_out_raddr, UInt<4>("hf")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _io_out_raddr_wrap_value_T = add(io_out_raddr, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _io_out_raddr_wrap_value_T_1 = tail(_io_out_raddr_wrap_value_T, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _GEN_0 = mux(io_en, _io_out_raddr_wrap_value_T_1, io_out_raddr) @[src/main/scala/chisel3/util/Counter.scala 118:16 77:15 61:40]
    node _GEN_1 = mux(io_en, io_out_raddr_wrap_wrap, UInt<1>("h0")) @[src/main/scala/chisel3/util/Counter.scala 118:{16,23} 117:24]
    node _GEN_2 = validif(io_en, io_out_raddr) @[src/main/scala/delay_chain.scala 43:{40,40}]
    node _GEN_3 = mux(io_en, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/delay_chain.scala 43:{40,40,40}]
    node _io_out_out_WIRE = _GEN_2 @[src/main/scala/delay_chain.scala 43:40]
    node _GEN_4 = validif(io_en, _io_out_out_WIRE) @[src/main/scala/delay_chain.scala 43:{40,40}]
    node _GEN_5 = validif(io_en, clock) @[src/main/scala/delay_chain.scala 43:{40,40}]
    reg io_out_waddr : UInt<4>, clock with :
      reset => (UInt<1>("h0"), io_out_waddr) @[src/main/scala/delay_chain.scala 43:40]
    node _GEN_6 = mux(io_en, io_out_raddr, io_out_waddr) @[src/main/scala/delay_chain.scala 43:{40,40,40}]
    node _io_out_T = or(io_out_waddr, UInt<4>("h0")) @[src/main/scala/delay_chain.scala 43:40]
    node _io_out_T_1 = bits(_io_out_T, 3, 0) @[src/main/scala/delay_chain.scala 43:40]
    node _GEN_7 = validif(io_en, _io_out_T_1) @[src/main/scala/delay_chain.scala 43:{40,40}]
    node _GEN_8 = validif(io_en, UInt<1>("h1")) @[src/main/scala/delay_chain.scala 43:{40,40}]
    node _GEN_9 = validif(io_en, io_in) @[src/main/scala/delay_chain.scala 43:{40,40}]
    node io_out_raddr_wrap = _GEN_1 @[src/main/scala/chisel3/util/Counter.scala 117:24]
    io_out <= io_out_mem.io_out_out.data @[src/main/scala/delay_chain.scala 43:20]
    io_out_mem.io_out_out.addr <= _GEN_4
    io_out_mem.io_out_out.en <= _GEN_3
    io_out_mem.io_out_out.clk <= _GEN_5
    io_out_mem.io_out_MPORT.addr <= _GEN_7
    io_out_mem.io_out_MPORT.en <= _GEN_3
    io_out_mem.io_out_MPORT.clk <= _GEN_5
    io_out_mem.io_out_MPORT.data <= _GEN_9
    io_out_mem.io_out_MPORT.mask <= _GEN_8
    io_out_raddr <= mux(reset, UInt<4>("h0"), _GEN_0) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
    io_out_waddr <= mux(reset, UInt<4>("hf"), _GEN_6) @[src/main/scala/delay_chain.scala 43:{40,40}]
