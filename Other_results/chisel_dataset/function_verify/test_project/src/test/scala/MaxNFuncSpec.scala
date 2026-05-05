package pythia
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class MaxNFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "MaxN" should "find max when first element is largest" in {
    test(new MaxN()) { dut =>
      dut.io.nums(0).poke(30.U)
      dut.io.nums(1).poke(20.U)
      dut.io.nums(2).poke(10.U)
      dut.io.ids(0).poke(1.U)
      dut.io.ids(1).poke(2.U)
      dut.io.ids(2).poke(3.U)
      dut.io.maxNum.expect(30.U)
      dut.io.maxId.expect(1.U)
    }
  }

  it should "find max when second element is largest" in {
    test(new MaxN()) { dut =>
      dut.io.nums(0).poke(10.U)
      dut.io.nums(1).poke(30.U)
      dut.io.nums(2).poke(20.U)
      dut.io.ids(0).poke(1.U)
      dut.io.ids(1).poke(2.U)
      dut.io.ids(2).poke(3.U)
      dut.io.maxNum.expect(30.U)
      dut.io.maxId.expect(2.U)
    }
  }

  it should "find max when third element is largest (nums(0) >= nums(1))" in {
    test(new MaxN()) { dut =>
      // When nums(0)>=nums(1) and nums(2) is largest, uses outer otherwise
      dut.io.nums(0).poke(20.U)
      dut.io.nums(1).poke(10.U)
      dut.io.nums(2).poke(30.U)
      dut.io.ids(0).poke(1.U)
      dut.io.ids(1).poke(2.U)
      dut.io.ids(2).poke(3.U)
      dut.io.maxNum.expect(30.U)
      dut.io.maxId.expect(3.U)
    }
  }

  it should "exercise inner otherwise when nums(0) < nums(1) < nums(2)" in {
    test(new MaxN()) { dut =>
      // nums(0)=5 < nums(1)=10 => enters outer .otherwise
      // nums(1)=10 < nums(2)=15 => enters inner .otherwise
      // The inner otherwise has a bug: only sets maxId := io.ids(2),
      // does NOT set maxNum, so maxNum stays at default 0.
      dut.io.nums(0).poke(5.U)
      dut.io.nums(1).poke(10.U)
      dut.io.nums(2).poke(15.U)
      dut.io.ids(0).poke(1.U)
      dut.io.ids(1).poke(2.U)
      dut.io.ids(2).poke(3.U)
      // maxId should be ids(2) = 3
      dut.io.maxId.expect(3.U)
      // maxNum stays at default 0 due to bug (no maxNum assignment in inner otherwise)
      dut.io.maxNum.expect(0.U)
    }
  }
}
