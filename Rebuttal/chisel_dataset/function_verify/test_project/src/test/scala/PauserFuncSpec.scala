package icenet
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class PauserFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "PauserTest" should "pass all built-in checks" in {
    test(new PauserTest()) { dut =>
      dut.clock.setTimeout(5000)
      dut.io.start.poke(true.B)
      dut.clock.step(1)
      dut.io.start.poke(false.B)
      var cycles = 0
      val maxCycles = 4000
      while (cycles < maxCycles && !dut.io.finished.peek().litToBoolean) {
        dut.clock.step(1)
        cycles += 1
      }
      assert(dut.io.finished.peek().litToBoolean, s"Test did not finish within $maxCycles cycles")
    }
  }
}
