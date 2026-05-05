package dcr
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class DeviceControlRegisterTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DeviceControlRegister" should "store and output thread count on write enable" in {
    test(new DeviceControlRegister) { dut =>
      // After reset, thread_count should be 0
      dut.io.device_control_write_enable.poke(false.B)
      dut.io.device_control_data.poke(0.U)
      dut.clock.step()
      dut.io.thread_count.expect(0.U)

      // Write thread count = 8
      dut.io.device_control_write_enable.poke(true.B)
      dut.io.device_control_data.poke(8.U)
      dut.clock.step()
      dut.io.thread_count.expect(8.U)

      // Disable write, change data — thread_count should hold
      dut.io.device_control_write_enable.poke(false.B)
      dut.io.device_control_data.poke(99.U)
      dut.clock.step()
      dut.io.thread_count.expect(8.U)

      // Write new value
      dut.io.device_control_write_enable.poke(true.B)
      dut.io.device_control_data.poke(16.U)
      dut.clock.step()
      dut.io.thread_count.expect(16.U)
    }
  }
}
