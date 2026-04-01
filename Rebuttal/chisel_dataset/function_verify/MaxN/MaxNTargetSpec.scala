package pythia
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class MaxNTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "MaxN" should "select ids(1) and nums(1) when the middle input is largest" in {
    test(new MaxN) { dut =>
      dut.io.nums(0).poke(3.U)
      dut.io.nums(1).poke(9.U)
      dut.io.nums(2).poke(5.U)
      dut.io.ids(0).poke(1.U)
      dut.io.ids(1).poke(7.U)
      dut.io.ids(2).poke(4.U)
      dut.io.maxNum.expect(9.U)
      dut.io.maxId.expect(7.U)
    }
  }
}
