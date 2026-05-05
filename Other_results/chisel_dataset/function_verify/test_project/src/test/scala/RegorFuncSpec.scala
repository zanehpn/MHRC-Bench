package magmasi.components
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RegorFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  // Regor's TARGET: .otherwise{ matReg1(i)(j) := bitmap.io.bitmap1(i)(j) }
  // The otherwise fires when !(reg(j) === 0.U && bitmap1(i)(j) === 1.U),
  // i.e., when reg(j) !== 0.U or bitmap1(i)(j) !== 1.U.
  //
  // reg(i) := io.mat2(i).map(_ =/= 0.U).reduce(_ || _)
  // So reg(i) is true when ANY element in mat2 row i is non-zero.
  //
  // The Regor uses its own i,j counters (starting at 0,0) to iterate.
  // When i < cols.U, it processes matReg1(i)(j).
  // The when condition: reg(j) === 0.U && bitmap.io.bitmap1(i)(j) === 1.U
  //   => matReg1(i)(j) := 0.U
  // otherwise (TARGET):
  //   => matReg1(i)(j) := bitmap.io.bitmap1(i)(j)
  //
  // To trigger the otherwise branch, we need reg(j) to be non-zero (true).
  // reg is indexed by j (column index used as row index into reg).
  // reg is derived from mat2 rows. So if mat2 row j has any non-zero element,
  // reg(j) = true, and the otherwise branch fires.

  "Regor" should "preserve bitmap1 entries via otherwise when reg(j) is non-zero" in {
    test(new Regor(rows = 4, cols = 4, DATA_TYPE = 16)) { dut =>
      // Set mat2 so that ALL rows have at least one non-zero element.
      // This makes reg = [true, true, true, true].
      // With reg(j) = true for all j, the when condition (reg(j)===0.U && ...)
      // is always false, so the otherwise branch always fires.
      // The otherwise branch sets matReg1(i)(j) := bitmap.io.bitmap1(i)(j).

      // mat1: non-zero values so bitmap1 will have 1s
      val mat1 = Seq(
        Seq(5, 0, 3, 0),
        Seq(0, 7, 0, 2),
        Seq(1, 0, 0, 0),
        Seq(0, 0, 4, 9)
      )

      // mat2: every row has at least one non-zero element
      val mat2 = Seq(
        Seq(1, 0, 0, 0),
        Seq(0, 1, 0, 0),
        Seq(0, 0, 1, 0),
        Seq(0, 0, 0, 1)
      )

      for (i <- 0 until 4; j <- 0 until 4) {
        dut.io.mat1(i)(j).poke(mat1(i)(j).U)
        dut.io.mat2(i)(j).poke(mat2(i)(j).U)
      }

      // Let the design run; Bitmap and Regor iterate with their own counters
      dut.clock.step(30)

      // Regor processes one (i,j) per cycle starting from (0,0).
      // j only advances when i reaches rows-1.
      // Regor's i counter increments but only up to cols.U.
      // In first few cycles, (i=0,j=0) is processed:
      // reg(0) = true (mat2 row 0 has non-zero), so otherwise fires.
      // bitmap1(0)(0) depends on Bitmap: mat1(0)(0)=5 != 0, so bitmap1(0)(0)=1.
      // Otherwise branch: matReg1(0)(0) := bitmap1(0)(0) = 1.
      // So compressedBitmap(0)(0) should be 1 (not zeroed out).
      dut.io.compressedBitmap(0)(0).expect(1.U,
        "compressedBitmap(0)(0) should be 1: reg(0)=true triggers otherwise, preserving bitmap1 value")
    }
  }

  it should "zero out bitmap1 entries when reg(j) is zero via the when branch" in {
    test(new Regor(rows = 4, cols = 4, DATA_TYPE = 16)) { dut =>
      // mat2 all-zero so reg = [false, false, false, false]
      // When reg(j)=0 and bitmap1(i)(j)=1, the when branch fires: matReg1(i)(j) := 0
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

      dut.clock.step(30)

      // With reg all false and bitmap1(0)(0)=1 (mat1(0)(0)=5!=0),
      // the when branch fires: matReg1(0)(0) := 0
      dut.io.compressedBitmap(0)(0).expect(0.U,
        "compressedBitmap(0)(0) should be 0 when reg(0)=false and bitmap1(0)(0)=1")
    }
  }
}
