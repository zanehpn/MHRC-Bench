package MSM
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class PMNaiveFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "PMNaive" should "return zero point when scalar s=0 (special case)" in {
    test(new PMNaive(pw = 32, sw = 32)) { dut =>
      dut.io.a.poke(0.S)
      dut.io.p.poke(23.S)
      dut.io.px.poke(5.S)
      dut.io.py.poke(7.S)
      dut.io.s.poke(0.S)
      dut.io.load.poke(false.B)
      dut.clock.step(1)

      // Load triggers idle->specialcases transition
      dut.io.load.poke(true.B)
      dut.clock.step(1)
      dut.io.load.poke(false.B)

      // Wait for valid (specialcases state processes s=0)
      var found = false
      for (_ <- 0 until 10 if !found) {
        if (dut.io.valid.peek().litToBoolean) {
          found = true
          dut.io.outx.expect(0.S)
          dut.io.outy.expect(0.S)
        }
        dut.clock.step(1)
      }
      assert(found, "valid should assert for s=0")
    }
  }

  it should "eventually assert valid for s=2 (working state TARGET path)" in {
    test(new PMNaive(pw = 32, sw = 32)) { dut =>
      dut.io.a.poke(0.S)
      dut.io.p.poke(23.S)
      dut.io.px.poke(5.S)
      dut.io.py.poke(7.S)
      dut.io.s.poke(2.S)
      dut.io.load.poke(false.B)
      dut.clock.step(1)

      dut.io.load.poke(true.B)
      dut.clock.step(1)
      dut.io.load.poke(false.B)

      // s=2 goes to working state, should eventually hit s===2.S completion (TARGET)
      var valid = false
      for (_ <- 0 until 500 if !valid) {
        dut.clock.step(1)
        if (dut.io.valid.peek().litToBoolean) valid = true
      }
      assert(valid, "PMNaive should eventually assert valid for s=2")
    }
  }
}
