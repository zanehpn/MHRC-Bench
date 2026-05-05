package magmasi.components

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RegorTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Regor" should "output compressed bitmap based on mat1 and mat2 inputs" in {
    test(new Regor(rows = 4, cols = 4, DATA_TYPE = 16)) { dut =>
      // Set mat1 all zeros
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat1(i)(j).poke(0.U)
      }
      // Set mat2 all zeros
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat2(i)(j).poke(0.U)
      }
      dut.clock.step()
      // With all-zero inputs, compressed bitmap should be all zeros
      dut.io.compressedBitmap(0)(0).expect(0.U)
    }
  }
}
