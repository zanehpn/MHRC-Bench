package magmasi.components
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class BitmapFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  // The Bitmap module's j counter only increments in the .otherwise branch
  // of the mat2 non-zero check. This means j advances only when mat2(i)(j)==0.
  // When mat2(i)(j) != 0, matReg2(i)(j) is set to 1 but j does NOT advance
  // (the module stays on that element). So we test two scenarios.

  "Bitmap" should "convert mat1 non-zero to 1 and mat2 zero to 0 when mat2 is all-zero" in {
    implicit val config = MagmasiConfig(rowsA = 4, colsA = 4, rowsB = 4, colsB = 4, DATA_TYPE = 16)
    test(new Bitmap) { dut =>
      // mat2 all zeros so j always advances through the otherwise branch
      val mat1 = Seq(
        Seq(5, 0, 3, 0),
        Seq(0, 7, 0, 2),
        Seq(1, 0, 0, 0),
        Seq(0, 0, 4, 9)
      )

      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat1(i)(j).poke(mat1(i)(j).U)
        dut.io.mat2(i)(j).poke(0.U)
      }

      // With mat2 all zero, j increments each cycle. Need 4*4=16 cycles to scan all.
      // i increments when j hits colsB-1. But i width is log2Ceil(4)=2 bits so wraps at 4.
      dut.clock.step(20)

      // bitmap1: 1 where mat1 != 0, 0 where mat1 == 0
      val expectedBitmap1 = mat1.map(_.map(v => if (v != 0) 1 else 0))
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.bitmap1(i)(j).expect(expectedBitmap1(i)(j).U,
          s"bitmap1($i)($j) should be ${expectedBitmap1(i)(j)}")
      }

      // bitmap2 should all be 0 since mat2 is all-zero (the otherwise path sets nothing to 1)
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.bitmap2(i)(j).expect(0.U, s"bitmap2($i)($j) should be 0 for all-zero mat2")
      }
    }
  }

  it should "set matReg2 to 1 when mat2 entry is non-zero (TARGET path)" in {
    implicit val config = MagmasiConfig(rowsA = 4, colsA = 4, rowsB = 4, colsB = 4, DATA_TYPE = 16)
    test(new Bitmap) { dut =>
      // mat2(0)(0) is non-zero -- the TARGET when branch fires: matReg2(0)(0) := 1.U
      // j won't advance past 0 because the otherwise (j := j+1) doesn't fire
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat1(i)(j).poke(3.U)
        dut.io.mat2(i)(j).poke(0.U)
      }
      // Set mat2(0)(0) non-zero
      dut.io.mat2(0)(0).poke(42.U)

      // Step a few cycles -- mat2(0)(0)!=0 triggers matReg2(0)(0):=1
      dut.clock.step(3)

      // Verify the TARGET: bitmap2(0)(0) = matReg2(0)(0) = 1
      dut.io.bitmap2(0)(0).expect(1.U, "bitmap2(0)(0) should be 1 when mat2(0)(0) is non-zero")

      // Also verify bitmap1(0)(0) was processed (mat1(0)(0)=3 != 0 => 1)
      dut.io.bitmap1(0)(0).expect(1.U, "bitmap1(0)(0) should be 1 when mat1(0)(0) is non-zero")
    }
  }

  it should "handle all-zero inputs producing all-zero bitmaps" in {
    implicit val config = MagmasiConfig(rowsA = 4, colsA = 4, rowsB = 4, colsB = 4, DATA_TYPE = 16)
    test(new Bitmap) { dut =>
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat1(i)(j).poke(0.U)
        dut.io.mat2(i)(j).poke(0.U)
      }
      dut.clock.step(20)
      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.bitmap1(i)(j).expect(0.U)
        dut.io.bitmap2(i)(j).expect(0.U)
      }
    }
  }
}
