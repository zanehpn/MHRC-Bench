package final_project
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SigmoidTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Sigmoid" should "output valid_out after pipeline delay when valid_in is asserted" in {
    test(new Sigmoid) { dut =>
      // Initially valid_out should be false
      dut.io.valid_in.poke(false.B)
      dut.io.input.poke(0.S)
      dut.clock.step()
      dut.io.valid_out.expect(false.B)

      // Assert valid_in for one cycle with input = 0
      dut.io.valid_in.poke(true.B)
      dut.io.input.poke(0.S)
      dut.clock.step()
      dut.io.valid_in.poke(false.B)

      // Wait for pipeline to flush (depth = 44 registers: valid_reg(0)..valid_reg(43))
      // Need 43 more steps after valid_reg(0) was set for valid_reg(43) to be true
      for (_ <- 0 until 43) {
        dut.io.valid_out.expect(false.B)
        dut.clock.step()
      }

      // After 44 total cycles from valid_in assertion, valid_out should be true
      dut.io.valid_out.expect(true.B)
      // For input = 0, sigmoid(0) = 0.5, quantized to 8-bit
      // output should be around 128 (0.5 * 256)
      val output_val = dut.io.output.peek().litValue
      // Sigmoid of 0 should be close to midpoint
      assert(output_val >= 100 && output_val <= 156,
        s"Sigmoid(0) output $output_val should be near 128")

      // Next cycle valid_out should go back to false
      dut.clock.step()
      dut.io.valid_out.expect(false.B)
    }
  }

  "Sigmoid" should "saturate for large negative input" in {
    test(new Sigmoid) { dut =>
      // Large negative input: sigmoid should output near 0
      dut.io.valid_in.poke(true.B)
      dut.io.input.poke((-10000).S)
      dut.clock.step()
      dut.io.valid_in.poke(false.B)

      // Wait for pipeline
      for (_ <- 0 until 43) {
        dut.clock.step()
      }

      dut.io.valid_out.expect(true.B)
      val output_val = dut.io.output.peek().litValue
      assert(output_val <= 50,
        s"Sigmoid(-10000) output $output_val should be near 0")
    }
  }
}
