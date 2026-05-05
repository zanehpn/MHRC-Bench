FIRRTL version 1.2.0
circuit My_Queue :
  module Queue5_UInt8 : @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    input clock : Clock @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    input reset : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 243:7]
    output io_enq_ready : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_valid : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_enq_bits : UInt<8> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    input io_deq_ready : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_valid : UInt<1> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_deq_bits : UInt<8> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]
    output io_count : UInt<3> @[src/main/scala/chisel3/util/Decoupled.scala 255:14]

    mem ram : @[src/main/scala/chisel3/util/Decoupled.scala 256:91]
      data-type => UInt<8>
      depth => 5
      read-latency => 0
      write-latency => 1
      reader => io_deq_bits_MPORT
      writer => MPORT
      read-under-write => undefined
    reg enq_ptr_value : UInt<3>, clock with :
      reset => (UInt<1>("h0"), enq_ptr_value) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    reg deq_ptr_value : UInt<3>, clock with :
      reset => (UInt<1>("h0"), deq_ptr_value) @[src/main/scala/chisel3/util/Counter.scala 61:40]
    reg maybe_full : UInt<1>, clock with :
      reset => (UInt<1>("h0"), maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 259:27]
    node ptr_match = eq(enq_ptr_value, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 260:33]
    node _empty_T = eq(maybe_full, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 261:28]
    node empty = and(ptr_match, _empty_T) @[src/main/scala/chisel3/util/Decoupled.scala 261:25]
    node full = and(ptr_match, maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 262:24]
    node _do_enq_T = and(io_enq_ready, io_enq_valid) @[src/main/scala/chisel3/util/Decoupled.scala 51:35]
    node _do_deq_T = and(io_deq_ready, io_deq_valid) @[src/main/scala/chisel3/util/Decoupled.scala 51:35]
    node wrap = eq(enq_ptr_value, UInt<3>("h4")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _value_T = add(enq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _value_T_1 = tail(_value_T, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _GEN_0 = mux(wrap, UInt<1>("h0"), _value_T_1) @[src/main/scala/chisel3/util/Counter.scala 77:15 87:{20,28}]
    node do_enq = _do_enq_T @[src/main/scala/chisel3/util/Decoupled.scala 263:{27,27}]
    node _GEN_1 = validif(do_enq, enq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8]
    node _GEN_2 = validif(do_enq, clock) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8]
    node _GEN_3 = mux(do_enq, UInt<1>("h1"), UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:8 256:91]
    node _GEN_4 = validif(do_enq, UInt<1>("h1")) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_5 = validif(do_enq, io_enq_bits) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 270:24]
    node _GEN_6 = mux(do_enq, _GEN_0, enq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 269:16 src/main/scala/chisel3/util/Counter.scala 61:40]
    node wrap_1 = eq(deq_ptr_value, UInt<3>("h4")) @[src/main/scala/chisel3/util/Counter.scala 73:24]
    node _value_T_2 = add(deq_ptr_value, UInt<1>("h1")) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _value_T_3 = tail(_value_T_2, 1) @[src/main/scala/chisel3/util/Counter.scala 77:24]
    node _GEN_7 = mux(wrap_1, UInt<1>("h0"), _value_T_3) @[src/main/scala/chisel3/util/Counter.scala 77:15 87:{20,28}]
    node do_deq = _do_deq_T @[src/main/scala/chisel3/util/Decoupled.scala 264:{27,27}]
    node _GEN_8 = mux(do_deq, _GEN_7, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 273:16 src/main/scala/chisel3/util/Counter.scala 61:40]
    node _T = neq(do_enq, do_deq) @[src/main/scala/chisel3/util/Decoupled.scala 276:15]
    node _GEN_9 = mux(_T, do_enq, maybe_full) @[src/main/scala/chisel3/util/Decoupled.scala 276:27 277:16 259:27]
    node _GEN_10 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_6) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 src/main/scala/chisel3/util/Counter.scala 98:11]
    node _GEN_11 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_8) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 src/main/scala/chisel3/util/Counter.scala 98:11]
    node _GEN_12 = mux(UInt<1>("h0"), UInt<1>("h0"), _GEN_9) @[src/main/scala/chisel3/util/Decoupled.scala 279:15 282:16]
    node _io_deq_valid_T = eq(empty, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 285:19]
    node _io_enq_ready_T = eq(full, UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 286:19]
    node _ptr_diff_T = sub(enq_ptr_value, deq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 309:32]
    node ptr_diff = tail(_ptr_diff_T, 1) @[src/main/scala/chisel3/util/Decoupled.scala 309:32]
    node _io_count_T = mux(maybe_full, UInt<3>("h5"), UInt<1>("h0")) @[src/main/scala/chisel3/util/Decoupled.scala 316:10]
    node _io_count_T_1 = gt(deq_ptr_value, enq_ptr_value) @[src/main/scala/chisel3/util/Decoupled.scala 317:25]
    node _io_count_T_2 = add(UInt<3>("h5"), ptr_diff) @[src/main/scala/chisel3/util/Decoupled.scala 317:57]
    node _io_count_T_3 = tail(_io_count_T_2, 1) @[src/main/scala/chisel3/util/Decoupled.scala 317:57]
    node _io_count_T_4 = mux(_io_count_T_1, _io_count_T_3, ptr_diff) @[src/main/scala/chisel3/util/Decoupled.scala 317:10]
    node _io_count_T_5 = mux(ptr_match, _io_count_T, _io_count_T_4) @[src/main/scala/chisel3/util/Decoupled.scala 314:20]
    io_enq_ready <= _io_enq_ready_T @[src/main/scala/chisel3/util/Decoupled.scala 286:16]
    io_deq_valid <= _io_deq_valid_T @[src/main/scala/chisel3/util/Decoupled.scala 285:16]
    io_deq_bits <= ram.io_deq_bits_MPORT.data @[src/main/scala/chisel3/util/Decoupled.scala 293:17]
    io_count <= _io_count_T_5 @[src/main/scala/chisel3/util/Decoupled.scala 314:14]
    ram.io_deq_bits_MPORT.addr <= deq_ptr_value @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram.io_deq_bits_MPORT.en <= UInt<1>("h1") @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram.io_deq_bits_MPORT.clk <= clock @[src/main/scala/chisel3/util/Decoupled.scala 293:23]
    ram.MPORT.addr <= _GEN_1
    ram.MPORT.en <= _GEN_3
    ram.MPORT.clk <= _GEN_2
    ram.MPORT.data <= _GEN_5
    ram.MPORT.mask <= _GEN_4
    enq_ptr_value <= mux(reset, UInt<3>("h0"), _GEN_10) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
    deq_ptr_value <= mux(reset, UInt<3>("h0"), _GEN_11) @[src/main/scala/chisel3/util/Counter.scala 61:{40,40}]
    maybe_full <= mux(reset, UInt<1>("h0"), _GEN_12) @[src/main/scala/chisel3/util/Decoupled.scala 259:{27,27}]

  module My_Queue : @[src/main/scala/TwoStageQueue.scala 7:7]
    input clock : Clock @[src/main/scala/TwoStageQueue.scala 7:7]
    input reset : UInt<1> @[src/main/scala/TwoStageQueue.scala 7:7]
    output io_in_ready : UInt<1> @[src/main/scala/TwoStageQueue.scala 8:14]
    input io_in_valid : UInt<1> @[src/main/scala/TwoStageQueue.scala 8:14]
    input io_in_bits : UInt<8> @[src/main/scala/TwoStageQueue.scala 8:14]
    input io_out_ready : UInt<1> @[src/main/scala/TwoStageQueue.scala 8:14]
    output io_out_valid : UInt<1> @[src/main/scala/TwoStageQueue.scala 8:14]
    output io_out_bits : UInt<8> @[src/main/scala/TwoStageQueue.scala 8:14]

    inst queue_q of Queue5_UInt8 @[src/main/scala/chisel3/util/Decoupled.scala 362:21]
    inst q1_q of Queue5_UInt8 @[src/main/scala/chisel3/util/Decoupled.scala 362:21]
    io_in_ready <= queue_q.io_enq_ready @[src/main/scala/chisel3/util/Decoupled.scala 366:17]
    io_out_valid <= q1_q.io_deq_valid @[src/main/scala/TwoStageQueue.scala 21:10]
    io_out_bits <= q1_q.io_deq_bits @[src/main/scala/TwoStageQueue.scala 21:10]
    queue_q.clock <= clock
    queue_q.reset <= reset
    queue_q.io_enq_valid <= io_in_valid @[src/main/scala/chisel3/util/Decoupled.scala 364:22]
    queue_q.io_enq_bits <= io_in_bits @[src/main/scala/chisel3/util/Decoupled.scala 365:21]
    queue_q.io_deq_ready <= q1_q.io_enq_ready @[src/main/scala/chisel3/util/Decoupled.scala 366:17]
    q1_q.clock <= clock
    q1_q.reset <= reset
    q1_q.io_enq_valid <= queue_q.io_deq_valid @[src/main/scala/chisel3/util/Decoupled.scala 364:22]
    q1_q.io_enq_bits <= queue_q.io_deq_bits @[src/main/scala/chisel3/util/Decoupled.scala 365:21]
    q1_q.io_deq_ready <= io_out_ready @[src/main/scala/TwoStageQueue.scala 21:10]
