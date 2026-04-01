package MSM

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class PMNaiveTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "PMNaive" should "handle scalar=0 as point at infinity" in {
    test(new PMNaive(pw = 32, sw = 8)) { dut =>
      dut.io.load.poke(true.B)
      dut.io.a.poke(0.S)
      dut.io.p.poke(23.S)
      dut.io.px.poke(5.S)
      dut.io.py.poke(7.S)
      dut.io.s.poke(0.S)
      dut.clock.step()
      dut.io.load.poke(false.B)
      var cycles = 0
      while (!dut.io.valid.peek().litToBoolean && cycles < 50) {
        dut.clock.step()
        cycles += 1
      }
      dut.io.outx.expect(0.S)
      dut.io.outy.expect(0.S)
    }
  }
}
