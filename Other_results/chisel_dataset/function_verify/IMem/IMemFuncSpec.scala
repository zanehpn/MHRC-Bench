package mem
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class IMemFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "IMem" should "elaborate and simulate" in {
    test(new IMem()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
