package final_project
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class MaxpoolTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Maxpool" should "output valid_out=false when valid_in is false" in {
    test(new Maxpool(w = 8)) { dut =>
      dut.io.valid_in.poke(false.B)
      dut.clock.step()
      dut.io.valid_out.expect(false.B)

      // Step more cycles, valid_out should remain false
      dut.clock.step()
      dut.io.valid_out.expect(false.B)
      dut.clock.step()
      dut.io.valid_out.expect(false.B)
    }
  }

  "Maxpool" should "alternate valid_out with state machine" in {
    test(new Maxpool(w = 8)) { dut =>
      // Initialize all inputs to zero
      for (t <- 0 until 2) {
        for (i <- 0 until 48) {
          dut.io.from_big(t).data(i).poke(0.S)
        }
        for (s <- 0 until 2) {
          for (i <- 0 until 8) {
            dut.io.from_small(t)(s).data(i).poke(0.S)
          }
        }
      }

      // Step 1: valid_in=true, state=0 -> caches results, state becomes 1
      // After step: state=1. Combinational: valid_in=true && state=1 => valid_out=true
      dut.io.valid_in.poke(true.B)
      dut.clock.step()
      dut.io.valid_out.expect(true.B)
      // With all-zero inputs, result should be all zeros
      dut.io.result.mat(0).expect(0.S)

      // Step 2: state=1 -> outputs results, state becomes 0
      // After step: state=0. Combinational: valid_in=true && state=0 => valid_out=false
      dut.clock.step()
      dut.io.valid_out.expect(false.B)

      // Step 3: state=0 -> caches again, state becomes 1
      // After step: state=1. valid_out=true again
      dut.clock.step()
      dut.io.valid_out.expect(true.B)

      // Deassert valid_in: valid_out should immediately go false (combinational)
      dut.io.valid_in.poke(false.B)
      dut.io.valid_out.expect(false.B)
    }
  }
}
