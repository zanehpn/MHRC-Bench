FIRRTL version 1.2.0
circuit ReductionMux :
  module ReductionMux : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 6:7]
    input clock : Clock @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 6:7]
    input reset : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 6:7]
    input io_i_data_0 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    input io_i_data_1 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    input io_i_data_2 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    input io_i_data_3 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    input io_i_sel : UInt<4> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    output io_o_data_0 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]
    output io_o_data_1 : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 13:14]

    node w_sel_in_left = bits(io_i_sel, 1, 0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 28:32]
    node w_sel_in_right = bits(io_i_sel, 3, 2) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 29:33]
    node _T = lt(w_sel_in_left, UInt<2>("h2")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 32:32]
    node _GEN_0 = mux(_T, UInt<1>("h0"), UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 31:16 32:39 33:18]
    node _io_o_data_1_T = lt(w_sel_in_right, UInt<2>("h2")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:47]
    node _io_o_data_1_T_1 = bits(w_sel_in_right, 0, 0)
    node w_data_right_0 = io_i_data_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 22:26 24:21]
    node _GEN_1 = validif(eq(UInt<1>("h0"), _io_o_data_1_T_1), w_data_right_0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:{22,22}]
    node w_data_right_1 = io_i_data_3 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 22:26 24:21]
    node _GEN_2 = mux(eq(UInt<1>("h1"), _io_o_data_1_T_1), w_data_right_1, _GEN_1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:{22,22}]
    node _w_data_right_io_o_data_1_T_1 = _GEN_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:22]
    node _io_o_data_1_T_2 = mux(_io_o_data_1_T, _w_data_right_io_o_data_1_T_1, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:22]
    node w_data_left_0 = io_i_data_0 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 18:25 20:20]
    node w_data_left_1 = io_i_data_1 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 18:25 20:20]
    io_o_data_0 <= pad(_GEN_0, 8)
    io_o_data_1 <= _io_o_data_1_T_2 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/ReductionMux/ReductionMux.scala 35:16]
