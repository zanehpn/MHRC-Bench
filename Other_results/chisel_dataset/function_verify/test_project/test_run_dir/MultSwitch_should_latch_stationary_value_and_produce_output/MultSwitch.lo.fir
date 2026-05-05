FIRRTL version 1.2.0
circuit MultSwitch :
  module SimpleMultiplier : @[src/main/scala/deps/SimpleMultiplier.scala 6:7]
    input clock : Clock @[src/main/scala/deps/SimpleMultiplier.scala 6:7]
    input reset : UInt<1> @[src/main/scala/deps/SimpleMultiplier.scala 6:7]
    input io_A : UInt<16> @[src/main/scala/deps/SimpleMultiplier.scala 7:14]
    input io_B : UInt<16> @[src/main/scala/deps/SimpleMultiplier.scala 7:14]
    output io_O : UInt<16> @[src/main/scala/deps/SimpleMultiplier.scala 7:14]

    node _io_O_T = mul(io_A, io_B) @[src/main/scala/deps/SimpleMultiplier.scala 12:17]
    node _io_O_T_1 = bits(_io_O_T, 15, 0) @[src/main/scala/deps/SimpleMultiplier.scala 12:24]
    io_O <= _io_O_T_1 @[src/main/scala/deps/SimpleMultiplier.scala 12:8]

  module MultSwitch : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 6:7]
    input clock : Clock @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 6:7]
    input reset : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 6:7]
    input io_i_valid : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 7:14]
    input io_i_data : UInt<16> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 7:14]
    input io_i_stationary : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 7:14]
    output io_o_valid : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 7:14]
    output io_o_data : UInt<32> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 7:14]

    inst multiplier_module of SimpleMultiplier @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 43:33]
    reg r_buffer : UInt<16>, clock with :
      reset => (UInt<1>("h0"), r_buffer) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 16:25]
    reg r_buffer_valid : UInt<1>, clock with :
      reset => (UInt<1>("h0"), r_buffer_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 17:31]
    node _T = and(io_i_stationary, io_i_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 25:24]
    node _GEN_0 = mux(_T, io_i_data, r_buffer) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 25:39 26:14 16:25]
    node _GEN_1 = mux(_T, UInt<1>("h1"), r_buffer_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 25:39 27:20 17:31]
    node _w_A_T = and(r_buffer_valid, io_i_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 31:32]
    node w_A = mux(_w_A_T, io_i_data, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 31:16]
    node _w_B_T = and(r_buffer_valid, io_i_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 32:32]
    node w_B = mux(_w_B_T, r_buffer, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 32:16]
    reg o_validReg : UInt<1>, clock with :
      reset => (UInt<1>("h0"), o_validReg) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 35:27]
    node _T_1 = and(r_buffer_valid, io_i_valid) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 37:24]
    node _GEN_2 = mux(_T_1, UInt<1>("h0"), o_validReg) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 37:39 38:16 35:27]
    node multiplier_output = pad(multiplier_module.io_O, 32) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 41:32 47:21]
    node _io_o_data_T = bits(multiplier_output, 15, 0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 49:48]
    node _io_o_data_T_1 = cat(UInt<16>("h0"), _io_o_data_T) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 49:19]
    io_o_valid <= o_validReg @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 40:14]
    io_o_data <= _io_o_data_T_1 @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 49:13]
    r_buffer <= mux(reset, UInt<16>("h0"), _GEN_0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 16:{25,25}]
    r_buffer_valid <= mux(reset, UInt<1>("h0"), _GEN_1) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 17:{31,31}]
    o_validReg <= mux(reset, UInt<1>("h0"), _GEN_2) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 35:{27,27}]
    multiplier_module.clock <= clock
    multiplier_module.reset <= reset
    multiplier_module.io_A <= w_A @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 44:26]
    multiplier_module.io_B <= w_B @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/MultSwitch/MultSwitch.scala 45:26]
