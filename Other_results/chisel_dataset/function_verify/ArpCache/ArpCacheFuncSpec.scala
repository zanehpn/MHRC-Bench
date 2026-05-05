package router.table
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class ArpCacheFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ArpCache" should "elaborate and simulate" in {
    test(new ArpCache()) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
