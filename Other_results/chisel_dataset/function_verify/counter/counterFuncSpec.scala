package day17
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class counterFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "counter" should "elaborate and simulate" in {
    test(new counter(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
