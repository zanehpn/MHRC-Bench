package labs
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class Encoder4to2FuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Encoder4to2" should "elaborate and simulate" in {
    test(new Encoder4to2()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
