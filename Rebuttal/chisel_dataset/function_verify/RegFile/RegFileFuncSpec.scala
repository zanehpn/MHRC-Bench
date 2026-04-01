package rself
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class RegFileFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "RegFile" should "elaborate and simulate" in {
    test(new RegFile()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
