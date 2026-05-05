package final_project
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class AccumuFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Accumu" should "elaborate and simulate" in {
    test(new Accumu(8, 8, 8, 8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
