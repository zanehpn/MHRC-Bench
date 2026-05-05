FIRRTL version 1.2.0
circuit GPIO :
  extmodule GPIOInOut : @[src/main/scala/GPIO.scala 53:7]
    input dataIn : UInt<8>
    output dataOut : UInt<8>
    input dir : UInt<8>
    output dataIO : Analog<8>
    defname = GPIOInOut

  module GPIO : @[src/main/scala/GPIO.scala 16:7]
    input clock : Clock @[src/main/scala/GPIO.scala 16:7]
    input reset : UInt<1> @[src/main/scala/GPIO.scala 16:7]
    input io_GPIOPort_dataIn : UInt<32> @[src/main/scala/GPIO.scala 21:14]
    output io_GPIOPort_valueOut : UInt<32> @[src/main/scala/GPIO.scala 21:14]
    output io_GPIOPort_directionOut : UInt<32> @[src/main/scala/GPIO.scala 21:14]
    input io_GPIOPort_writeValue : UInt<1> @[src/main/scala/GPIO.scala 21:14]
    input io_GPIOPort_writeDirection : UInt<1> @[src/main/scala/GPIO.scala 21:14]
    output io_GPIOPort_stall : UInt<1> @[src/main/scala/GPIO.scala 21:14]
    output io_externalPort : Analog<8> @[src/main/scala/GPIO.scala 21:14]

    inst InOut of GPIOInOut @[src/main/scala/GPIO.scala 35:23]
    reg GPIO : UInt<32>, clock with :
      reset => (UInt<1>("h0"), GPIO) @[src/main/scala/GPIO.scala 26:26]
    reg direction : UInt<32>, clock with :
      reset => (UInt<1>("h0"), direction) @[src/main/scala/GPIO.scala 27:26]
    node _GEN_0 = mux(io_GPIOPort_writeValue, io_GPIOPort_dataIn, GPIO) @[src/main/scala/GPIO.scala 45:32 46:10 26:26]
    node _GEN_1 = mux(io_GPIOPort_writeDirection, io_GPIOPort_dataIn, direction) @[src/main/scala/GPIO.scala 48:36 49:15 27:26]
    io_GPIOPort_valueOut <= pad(InOut.dataOut, 32) @[src/main/scala/GPIO.scala 36:26]
    io_GPIOPort_directionOut <= direction @[src/main/scala/GPIO.scala 30:28]
    io_GPIOPort_stall <= UInt<1>("h0") @[src/main/scala/GPIO.scala 29:28]
    GPIO <= mux(reset, UInt<32>("h0"), _GEN_0) @[src/main/scala/GPIO.scala 26:{26,26}]
    direction <= mux(reset, UInt<32>("h0"), _GEN_1) @[src/main/scala/GPIO.scala 27:{26,26}]
    InOut.dataIn <= bits(GPIO, 7, 0) @[src/main/scala/GPIO.scala 37:26]
    InOut.dir <= bits(direction, 7, 0) @[src/main/scala/GPIO.scala 38:26]
    attach (io_externalPort, InOut.dataIO)
