package dcr
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class DeviceControlRegisterFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DeviceControlRegister" should "elaborate with write-enable gating logic" in {
    // Original source has io.thread_count unconnected - elaboration will fail.
    // This is an inherent issue in the original code, not the TARGET.
    // The test verifies whether the generated code makes the module elaborate.
    test(new DeviceControlRegister()) { dut =>
      dut.io.device_control_write_enable.poke(true.B)
      dut.io.device_control_data.poke(42.U)
      dut.clock.step(1)
      dut.io.device_control_write_enable.poke(false.B)
      dut.clock.step(1)
      succeed
    }
  }
}
