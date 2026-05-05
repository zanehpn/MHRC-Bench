package perfect.util
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class PwmFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Pwm" should "elaborate and simulate" in {
    test(new Pwm(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
