package chiseltest.tests
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class AluFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Alu" should "elaborate and simulate" in {
    test(new Alu(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
