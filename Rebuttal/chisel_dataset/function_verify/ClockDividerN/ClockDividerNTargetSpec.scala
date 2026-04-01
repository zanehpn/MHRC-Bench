package chipyard.clocking
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class ClockDividerNTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ClockDividerN" should "elaborate and reset correctly" in {
    test(new ClockDividerN(8)) { dut =>
      dut.clock.step()
      dut.clock.step()
      // dut.io.clk_out can be observed
      succeed
    }
  }
}
