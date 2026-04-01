FIRRTL version 1.2.0
circuit DeviceControlRegister :
  module DeviceControlRegister : @[src/main/scala/DeviceControlRegister.scala 8:7]
    input clock : Clock @[src/main/scala/DeviceControlRegister.scala 8:7]
    input reset : UInt<1> @[src/main/scala/DeviceControlRegister.scala 8:7]
    input io_device_control_write_enable : UInt<1> @[src/main/scala/DeviceControlRegister.scala 9:14]
    input io_device_control_data : UInt<8> @[src/main/scala/DeviceControlRegister.scala 9:14]
    output io_thread_count : UInt<8> @[src/main/scala/DeviceControlRegister.scala 9:14]

    reg device_control_register : UInt<8>, clock with :
      reset => (UInt<1>("h0"), device_control_register) @[src/main/scala/DeviceControlRegister.scala 16:40]
    node _GEN_0 = mux(io_device_control_write_enable, io_device_control_data, device_control_register) @[src/main/scala/DeviceControlRegister.scala 16:40 18:{40,66}]
    io_thread_count <= device_control_register @[src/main/scala/DeviceControlRegister.scala 20:19]
    device_control_register <= mux(reset, UInt<8>("h0"), _GEN_0) @[src/main/scala/DeviceControlRegister.scala 16:{40,40}]
