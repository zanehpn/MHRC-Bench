package magmasi.components

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class BenesTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Benes" should "pass input data through to output when all mux selects are zero" in {
    implicit val config: MagmasiConfig = MagmasiConfig(NUM_PES = 4, DATA_TYPE = 16)
    test(new Benes) { dut =>
      // Set all mux selects to 0 (straight-through)
      for (i <- 0 until dut.io.i_mux_bus.length) {
        dut.io.i_mux_bus(i).poke(false.B)
      }
      // Set input data
      for (i <- 0 until config.NUM_PES) {
        dut.io.i_data_bus2(i).poke((i + 1).U)
        dut.io.i_data_bus1(i).poke(0.U)
      }
      dut.clock.step()
      // After one cycle, data should appear at outputs (with straight-through routing)
      dut.io.o_dist_bus2(0).expect(1.U)
      dut.io.o_dist_bus2(1).expect(2.U)
    }
  }
}
