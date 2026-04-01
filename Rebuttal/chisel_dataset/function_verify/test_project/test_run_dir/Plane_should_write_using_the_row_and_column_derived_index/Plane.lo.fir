FIRRTL version 1.2.0
circuit Plane :
  module Plane : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 13:7]
    input clock : Clock @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 13:7]
    input reset : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 13:7]
    input io_we : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_wrrow : UInt<7> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_wrcol : UInt<4> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_wrdata : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_re : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_rdrow0 : UInt<7> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_rdcol0 : UInt<4> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    output io_rddata0 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_rdrow1 : UInt<7> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    input io_rdcol1 : UInt<4> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]
    output io_rddata1 : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 14:14]

    mem mem : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 28:16]
      data-type => UInt<16>
      depth => 2048
      read-latency => 0
      write-latency => 1
      reader => io_rddata0_MPORT
      reader => io_rddata1_MPORT
      writer => MPORT
      read-under-write => undefined
    node _rdindex0_T = shl(io_rdrow0, 4) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 33:26]
    node _rdindex0_T_1 = add(_rdindex0_T, io_rdcol0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 33:32]
    node _rdindex0_T_2 = tail(_rdindex0_T_1, 1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 33:32]
    node _rdindex1_T = shl(io_rdrow1, 4) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 34:26]
    node _rdindex1_T_1 = add(_rdindex1_T, io_rdcol1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 34:32]
    node _rdindex1_T_2 = tail(_rdindex1_T_1, 1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 34:32]
    node _wrindex_T = shl(io_wrrow, 4) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 35:24]
    node _wrindex_T_1 = add(_wrindex_T, io_wrcol) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 35:30]
    node _wrindex_T_2 = tail(_wrindex_T_1, 1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 35:30]
    node wrindex = _wrindex_T_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 32:21 35:11]
    node _GEN_0 = validif(io_we, wrindex) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 37:15 38:8]
    node _GEN_1 = validif(io_we, clock) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 37:15 38:8]
    node _GEN_2 = mux(io_we, UInt<1>("h1"), UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 37:15 28:16 38:8]
    node _GEN_3 = validif(io_we, UInt<1>("h1")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 37:15 38:18]
    node _GEN_4 = validif(io_we, io_wrdata) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 37:15 38:18]
    node rdindex0 = _rdindex0_T_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 30:22 33:12]
    node _GEN_5 = validif(io_re, rdindex0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 43:15 44:22]
    node _GEN_6 = validif(io_re, clock) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 43:15 44:22]
    node _GEN_7 = mux(io_re, UInt<1>("h1"), UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 43:15 28:16 44:22]
    node _GEN_8 = mux(io_re, mem.io_rddata0_MPORT.data, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 41:14 43:15 44:16]
    node rdindex1 = _rdindex1_T_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 31:22 34:12]
    node _GEN_9 = validif(io_re, rdindex1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 43:15 45:22]
    node _GEN_10 = mux(io_re, mem.io_rddata1_MPORT.data, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Plane/Plane.scala 42:14 43:15 45:16]
    io_rddata0 <= _GEN_8
    io_rddata1 <= _GEN_10
    mem.io_rddata0_MPORT.addr <= _GEN_5
    mem.io_rddata0_MPORT.en <= _GEN_7
    mem.io_rddata0_MPORT.clk <= _GEN_6
    mem.io_rddata1_MPORT.addr <= _GEN_9
    mem.io_rddata1_MPORT.en <= _GEN_7
    mem.io_rddata1_MPORT.clk <= _GEN_6
    mem.MPORT.addr <= _GEN_0
    mem.MPORT.en <= _GEN_2
    mem.MPORT.clk <= _GEN_1
    mem.MPORT.data <= _GEN_4
    mem.MPORT.mask <= _GEN_3
