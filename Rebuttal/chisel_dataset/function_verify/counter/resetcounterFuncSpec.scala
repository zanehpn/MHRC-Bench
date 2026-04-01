package labs
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class resetcounterFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "resetcounter" should "elaborate and simulate" in {
    test(new resetcounter(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
