package magmasi.components
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class BenesFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Benes" should "pass through data when all mux selects are 0" in {
    implicit val config = MagmasiConfig(NUM_PES = 4, DATA_TYPE = 16)
    test(new Benes) { dut =>
      val LEVELS = (2 * (math.log(config.NUM_PES) / math.log(2))).toInt + 1
      val numMuxBits = 2 * (LEVELS - 2) * config.NUM_PES + config.NUM_PES

      // Set all mux selects to 0 (passthrough)
      for (k <- 0 until numMuxBits) {
        dut.io.i_mux_bus(k).poke(false.B)
      }

      // Apply known input data
      val inputData = Seq(10, 20, 30, 40)
      for (i <- 0 until config.NUM_PES) {
        dut.io.i_data_bus2(i).poke(inputData(i).U)
        dut.io.i_data_bus1(i).poke(0.U)
      }

      // Step 2 cycles: one for r_data_bus_ff/r_mux_bus_ff to latch, one for output
      dut.clock.step(2)

      // With all selects = 0, output switches select in0 (straight path)
      for (i <- 0 until config.NUM_PES) {
        dut.io.o_dist_bus2(i).expect(inputData(i).U,
          s"o_dist_bus2($i) should be ${inputData(i)} with all-zero selects")
      }
    }
  }

  it should "route neighbor data to output 0 when output switch 0 sel=1 (in1 from TARGET)" in {
    implicit val config = MagmasiConfig(NUM_PES = 4, DATA_TYPE = 16)
    test(new Benes) { dut =>
      val LEVELS = (2 * (math.log(config.NUM_PES) / math.log(2))).toInt + 1
      val numMuxBits = 2 * (LEVELS - 2) * config.NUM_PES + config.NUM_PES

      // All intermediate selects = 0 (passthrough), only toggle output switch 0
      for (k <- 0 until numMuxBits) {
        dut.io.i_mux_bus(k).poke(false.B)
      }

      val inputData = Seq(10, 20, 30, 40)
      for (i <- 0 until config.NUM_PES) {
        dut.io.i_data_bus2(i).poke(inputData(i).U)
        dut.io.i_data_bus1(i).poke(0.U)
      }

      // Toggle output switch select for element 0
      // Output switch selects start at index 2 * NUM_PES * (LEVELS-2)
      val outSelectBase = 2 * config.NUM_PES * (LEVELS - 2)
      dut.io.i_mux_bus(outSelectBase + 0).poke(true.B)

      dut.clock.step(2)

      // TARGET: out_switch.io.in1 := w_internal(2 * (i+1) * (LEVELS-1) + 2*(LEVELS-2) + 1)
      // For output switch i=0 (even): neighbor is i+1=1
      // in1 = w_internal(2*1*4 + 2*3 + 1) = w_internal(15)
      // With all intermediate selects=0, w_internal(15) traces back to input element 1's
      // data through the diagonal path, which equals r_data_bus_ff(1) = inputData(1) = 20.
      // When sel=1, OutputSwitch selects in1, so output 0 should be 20.
      dut.io.o_dist_bus2(0).expect(20.U,
        "Output 0 with sel=1 should pick in1 from neighbor element 1, which is 20")
    }
  }
}
