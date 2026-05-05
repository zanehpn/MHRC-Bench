package cpu
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class MemoryFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Memory" should "elaborate and simulate" in {
    test(new Memory("/dev/null")) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
