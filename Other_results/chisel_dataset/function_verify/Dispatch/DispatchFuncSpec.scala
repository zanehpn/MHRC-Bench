package dispatch
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class DispatchFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Dispatch" should "elaborate and simulate" in {
    test(new Dispatch()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
