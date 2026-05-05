FIRRTL version 1.2.0
circuit DeviceControlRegister :
  module DeviceControlRegister : @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 8:7]
    input clock : Clock @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 8:7]
    input reset : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 8:7]
    input io_device_control_write_enable : UInt<1> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 9:14]
    input io_device_control_data : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 9:14]
    output io_thread_count : UInt<8> @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 9:14]

    reg device_control_register : UInt<8>, clock with :
      reset => (UInt<1>("h0"), device_control_register) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 16:40]
    node _T = eq(reset, UInt<1>("h0")) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 18:8]
    node _T_1 = and(_T, io_device_control_write_enable) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 18:22]
    node _GEN_0 = mux(_T_1, io_device_control_data, device_control_register) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 18:57 19:29 16:40]
    io_thread_count <= device_control_register @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 22:19]
    device_control_register <= mux(reset, UInt<8>("h0"), _GEN_0) @[ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/DeviceControlRegister/DeviceControlRegister.scala 16:{40,40}]
