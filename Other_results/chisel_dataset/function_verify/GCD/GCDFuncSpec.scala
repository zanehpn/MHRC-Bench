package gcd
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class GCDFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "GCD" should "elaborate and simulate" in {
    test(new GCD()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
