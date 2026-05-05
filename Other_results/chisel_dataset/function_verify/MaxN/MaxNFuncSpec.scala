package pythia
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class MaxNFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "MaxN" should "elaborate and simulate" in {
    test(new MaxN()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
