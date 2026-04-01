package mem
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class DMemFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DMem" should "elaborate and simulate" in {
    test(new DMem()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
