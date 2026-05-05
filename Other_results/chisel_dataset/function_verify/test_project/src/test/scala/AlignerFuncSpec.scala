package icenet
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class AlignerFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "AlignerTest" should "pass all built-in checks" in {
    test(new AlignerTest()) { dut =>
      // Drive start signal
      dut.io.start.poke(true.B)
      dut.clock.step(1)
      dut.io.start.poke(false.B)
      // Run until finished or timeout
      var cycles = 0
      val maxCycles = 1000
      while (cycles < maxCycles && !dut.io.finished.peek().litToBoolean) {
        dut.clock.step(1)
        cycles += 1
      }
      assert(dut.io.finished.peek().litToBoolean, s"AlignerTest did not finish within $maxCycles cycles")
    }
  }
}
