FIRRTL version 1.2.0
circuit NetDelay :
  module Queue2_StreamChannel : @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    input clock : Clock @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    input reset : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    output io_enq_ready : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_valid : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_bits_data : UInt<64> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_bits_keep : UInt<8> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_bits_last : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_deq_ready : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_valid : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_bits_data : UInt<64> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_bits_keep : UInt<8> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_bits_last : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_count : UInt<2> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]

    mem ram_data : @[src/main/scala/chisel3/util/Decoupled.scala 256:91]
      data-type => UInt<64>
      depth => 2
      read-latency => 0
      write-latency => 1
      reader => io_deq_bits_MPORT
      writer => MPORT
      read-under-write => undefined
    mem ram_keep : @[src/main/scala/chisel3/util/Decoupled.scala 256:91]
      data-type => UInt<8>
      depth => 2
      read-latency => 0
      write-latency => 1
      reader => io_deq_bits_MPORT
      writer => MPORT
      read-under-write => undefined
    mem ram_last : @[src/main/scala/chisel3/util/Decoupled.scala 256:91]
      data-type => UInt<1>
      depth => 2
      read-latency => 0
      write-latency => 1
      reader => io_deq_bits_MPORT
      writer => MPORT
      read-under-write => undefined
    reg enq_ptr_value : UInt<1>, clock with :
      reset => (UInt<1>("h0"), enq_ptr_value) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    reg deq_ptr_value : UInt<1>, clock with :
      reset => (UInt<1>("h0"), deq_ptr_value) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    reg maybe_full : UInt<1>, clock with :
      reset => (UInt<1>("h0"), maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 259:27]
    node ptr_match = eq(enq_ptr_value, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 260:33]
    node _empty_T = eq(maybe_full, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 261:28]
    node empty = and(ptr_match, _empty_T) @[src/main/scala/chisel3/util/Decoupled.scala 261:25]
    node full = and(ptr_match, maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 262:24]
    node _do_enq_T = and(io_enq_ready, io_enq_valid) @[src/main/scala/chisel3/util/Decoupled.scala 51:35]
    node _do_deq_T = and(io_deq_ready, io_deq_valid) @[src/main/scala/chisel3/util/Decoupled.scala 51:35]
    node wrap = eq(enq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _value_T = add(enq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _value_T_1 = tail(_value_T, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node do_enq = _do_enq_T @[src/main/scala/chisel3/util/Decoupled.scala 263:{27,27}]
    node _GEN_0 = validif(do_enq, enq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8]
    node _GEN_1 = validif(do_enq, clock) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8]
    node _GEN_2 = mux(do_enq, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8 256:91]
    node _GEN_3 = validif(do_enq, UInt<1>("h1")) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_4 = validif(do_enq, io_enq_bits_data) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_5 = validif(do_enq, io_enq_bits_keep) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_6 = validif(do_enq, io_enq_bits_last) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_7 = mux(do_enq, _value_T_1, enq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 src/main/scala/chisel3/util/Counter.scala 77:15 61:40]
    node wrap_1 = eq(deq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _value_T_2 = add(deq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _value_T_3 = tail(_value_T_2, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node do_deq = _do_deq_T @[src/main/scala/chisel3/util/Decoupled.scala 264:{27,27}]
    node _GEN_8 = mux(do_deq, _value_T_3, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 273:16 src/main/scala/chisel3/util/Counter.scala 77:15 61:40]
    node _T = neq(do_enq, do_deq) @[src/main/scala/chisel3/util/Decoupled.scala 276:15]
    node _GEN_9 = mux(_T, do_enq, maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 276:27 277:16 259:27]
    node _GEN_10 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_7) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 src/main/scala/chisel3/util/Counter.scala 98:11]
    node _GEN_11 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_8) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 src/main/scala/chisel3/util/Counter.scala 98:11]
    node _GEN_12 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_9) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 282:16]
    node _io_deq_valid_T = eq(empty, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 285:19]
    node _io_enq_ready_T = eq(full, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 286:19]
    node _GEN_13 = mux(io_deq_ready, UInt<1>("h1"), _io_enq_ready_T) @[src/main/scala/chisel3/util/Decoupled.scala 286:16 306:{24,39}]
    node _ptr_diff_T = sub(enq_ptr_value, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 309:32]
    node ptr_diff = tail(_ptr_diff_T, 1) @[src/main/scala/chisel3/util/Decoupled.scala 309:32]
    node _io_count_T = and(maybe_full, ptr_match) @[src/main/scala/chisel3/util/Decoupled.scala 312:32]
    node _io_count_T_1 = mux(_io_count_T, UInt<2>("h2"), UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 312:20]
    node _io_count_T_2 = or(_io_count_T_1, ptr_diff) @[src/main/scala/chisel3/util/Decoupled.scala 312:62]
    io_enq_ready <= _GEN_13
    io_deq_valid <= _io_deq_valid_T @[src/main/scala/chisel3/util/Decoupled.scala 285:16]
    io_deq_bits_data <= ram_data.io_deq_bits_MPORT.data @[src/main/scala/chisel3/util/Decoupled.scala 293:17]
    io_deq_bits_keep <= ram_keep.io_deq_bits_MPORT.data @[src/main/scala/chisel3/util/Decoupled.scala 293:17]
    io_deq_bits_last <= ram_last.io_deq_bits_MPORT.data @[src/main/scala/chisel3/util/Decoupled.scala 293:17]
    io_count <= _io_count_T_2 @[src/main/scala/chisel3/util/Decoupled.scala 312:14]
    ram_data.io_deq_bits_MPORT.addr <= deq_ptr_value @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_keep.io_deq_bits_MPORT.addr <= deq_ptr_value @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_last.io_deq_bits_MPORT.addr <= deq_ptr_value @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_data.io_deq_bits_MPORT.en <= UInt<1>("h1") @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_keep.io_deq_bits_MPORT.en <= UInt<1>("h1") @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_last.io_deq_bits_MPORT.en <= UInt<1>("h1") @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_data.io_deq_bits_MPORT.clk <= clock @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_keep.io_deq_bits_MPORT.clk <= clock @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_last.io_deq_bits_MPORT.clk <= clock @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram_data.MPORT.addr <= _GEN_0
    ram_keep.MPORT.addr <= _GEN_0
    ram_last.MPORT.addr <= _GEN_0
    ram_data.MPORT.en <= _GEN_2
    ram_keep.MPORT.en <= _GEN_2
    ram_last.MPORT.en <= _GEN_2
    ram_data.MPORT.clk <= _GEN_1
    ram_keep.MPORT.clk <= _GEN_1
    ram_last.MPORT.clk <= _GEN_1
    ram_data.MPORT.data <= _GEN_4
    ram_keep.MPORT.data <= _GEN_5
    ram_last.MPORT.data <= _GEN_6
    ram_data.MPORT.mask <= _GEN_3
    ram_keep.MPORT.mask <= _GEN_3
    ram_last.MPORT.mask <= _GEN_3
    enq_ptr_value <= mux(reset, UInt<1>("h0"), _GEN_10) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
    deq_ptr_value <= mux(reset, UInt<1>("h0"), _GEN_11) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
    maybe_full <= mux(reset, UInt<1>("h0"), _GEN_12) @[src/main/scala/chisel3/util/Decoupled.scala 259:{27,27}]

  module NetDelay : @[src/main/scala/TestUtils.scala 91:7]
    input clock : Clock @[src/main/scala/TestUtils.scala 91:7]
    input reset : UInt<1> @[src/main/scala/TestUtils.scala 91:7]
    output io_left_in_ready : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_left_in_valid : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_left_in_bits_data : UInt<64> @[src/main/scala/TestUtils.scala 92:14]
    input io_left_in_bits_keep : UInt<8> @[src/main/scala/TestUtils.scala 92:14]
    input io_left_in_bits_last : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_left_out_ready : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    output io_left_out_valid : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    output io_left_out_bits_data : UInt<64> @[src/main/scala/TestUtils.scala 92:14]
    output io_left_out_bits_keep : UInt<8> @[src/main/scala/TestUtils.scala 92:14]
    output io_left_out_bits_last : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_right_in_ready : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    output io_right_in_valid : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    output io_right_in_bits_data : UInt<64> @[src/main/scala/TestUtils.scala 92:14]
    output io_right_in_bits_keep : UInt<8> @[src/main/scala/TestUtils.scala 92:14]
    output io_right_in_bits_last : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    output io_right_out_ready : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_right_out_valid : UInt<1> @[src/main/scala/TestUtils.scala 92:14]
    input io_right_out_bits_data : UInt<64> @[src/main/scala/TestUtils.scala 92:14]
    input io_right_out_bits_keep : UInt<8> @[src/main/scala/TestUtils.scala 92:14]
    input io_right_out_bits_last : UInt<1> @[src/main/scala/TestUtils.scala 92:14]

    inst io_left_out_pipe of Queue2_StreamChannel @[src/main/scala/deps/RocketChipStubs.scala 49:24]
    inst io_right_in_pipe of Queue2_StreamChannel @[src/main/scala/deps/RocketChipStubs.scala 49:24]
    io_left_in_ready <= io_right_in_pipe.io_enq_ready @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_valid <= io_left_out_pipe.io_deq_valid @[src/main/scala/TestUtils.scala 97:15]
    io_left_out_bits_data <= io_left_out_pipe.io_deq_bits_data @[src/main/scala/TestUtils.scala 97:15]
    io_left_out_bits_keep <= io_left_out_pipe.io_deq_bits_keep @[src/main/scala/TestUtils.scala 97:15]
    io_left_out_bits_last <= io_left_out_pipe.io_deq_bits_last @[src/main/scala/TestUtils.scala 97:15]
    io_right_in_valid <= io_right_in_pipe.io_deq_valid @[src/main/scala/TestUtils.scala 98:15]
    io_right_in_bits_data <= io_right_in_pipe.io_deq_bits_data @[src/main/scala/TestUtils.scala 98:15]
    io_right_in_bits_keep <= io_right_in_pipe.io_deq_bits_keep @[src/main/scala/TestUtils.scala 98:15]
    io_right_in_bits_last <= io_right_in_pipe.io_deq_bits_last @[src/main/scala/TestUtils.scala 98:15]
    io_right_out_ready <= io_left_out_pipe.io_enq_ready @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_pipe.clock <= clock
    io_left_out_pipe.reset <= reset
    io_left_out_pipe.io_enq_valid <= io_right_out_valid @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_pipe.io_enq_bits_data <= io_right_out_bits_data @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_pipe.io_enq_bits_keep <= io_right_out_bits_keep @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_pipe.io_enq_bits_last <= io_right_out_bits_last @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_left_out_pipe.io_deq_ready <= io_left_out_ready @[src/main/scala/TestUtils.scala 97:15]
    io_right_in_pipe.clock <= clock
    io_right_in_pipe.reset <= reset
    io_right_in_pipe.io_enq_valid <= io_left_in_valid @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_right_in_pipe.io_enq_bits_data <= io_left_in_bits_data @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_right_in_pipe.io_enq_bits_keep <= io_left_in_bits_keep @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_right_in_pipe.io_enq_bits_last <= io_left_in_bits_last @[src/main/scala/deps/RocketChipStubs.scala 50:19]
    io_right_in_pipe.io_deq_ready <= io_right_in_ready @[src/main/scala/TestUtils.scala 98:15]
