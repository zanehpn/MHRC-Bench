package magmasi.components
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class BitmapTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Bitmap" should "convert non-zero mat2 entries into ones" in {
    implicit val config: MagmasiConfig = MagmasiConfig()
    test(new Bitmap) { dut =>
      for (i <- 0 until config.rowsA; j <- 0 until config.colsA) dut.io.mat1(i)(j).poke(0.U)
      for (i <- 0 until config.rowsB; j <- 0 until config.colsB) {
        dut.io.mat2(i)(j).poke((if (i == 0 && j == 0) 5 else 0).U)
      }
      dut.clock.step()
      dut.io.bitmap2(0)(0).expect(1.U)
    }
  }
}
