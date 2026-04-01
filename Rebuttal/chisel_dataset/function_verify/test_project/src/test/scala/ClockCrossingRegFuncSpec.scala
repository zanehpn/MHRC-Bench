package asyncqueue.modules
import chisel3._; import chiseltest._; import org.scalatest.flatspec.AnyFlatSpec
class ClockCrossingRegFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ClockCrossingReg" should "elaborate and simulate" in {
    test(new ClockCrossingReg(8, true)) { dut => dut.clock.step(3); succeed }
  }
}
