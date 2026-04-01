package final_project
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class MaxpoolFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Maxpool" should "elaborate and simulate" in {
    test(new Maxpool(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
