package icenet
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import IceNetConsts._

class TestUtilsFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "PacketCheck" should "assert finished after receiving all expected data" in {
    val checkData = Seq(BigInt(0xAA), BigInt(0xBB), BigInt(0xCC))
    val fullKeep = (1 << NET_IF_BYTES) - 1
    val checkKeep = Seq(fullKeep, fullKeep, fullKeep)
    val checkLast = Seq(false, false, true)

    test(new PacketCheck(checkData, checkKeep, checkLast)) { dut =>
      dut.io.finished.expect(false.B)

      // Send each expected data word
      for (i <- checkData.indices) {
        dut.io.in.valid.poke(true.B)
        dut.io.in.bits.data.poke(checkData(i).U)
        dut.io.in.bits.keep.poke(checkKeep(i).U)
        dut.io.in.bits.last.poke(checkLast(i).B)

        // Wait for ready then step
        while (!dut.io.in.ready.peek().litToBoolean) {
          dut.clock.step(1)
        }
        dut.clock.step(1)
      }
      dut.io.in.valid.poke(false.B)

      // After receiving all 3 items, checkDone fires and finished becomes true
      dut.clock.step(1)
      dut.io.finished.expect(true.B)
    }
  }

  "NetDelay" should "pass stream data through with correct latency" in {
    test(new NetDelay(latency = 2)) { dut =>
      // Drive defaults
      dut.io.right.out.valid.poke(false.B)
      dut.io.right.out.bits.data.poke(0.U)
      dut.io.right.out.bits.keep.poke(0.U)
      dut.io.right.out.bits.last.poke(false.B)
      dut.io.left.in.valid.poke(false.B)
      dut.io.left.in.bits.data.poke(0.U)
      dut.io.left.in.bits.keep.poke(0.U)
      dut.io.left.in.bits.last.poke(false.B)
      dut.io.left.out.ready.poke(true.B)
      dut.io.right.in.ready.poke(true.B)

      dut.clock.step(1)

      // Send data from right.out -> should appear on left.out after latency
      dut.io.right.out.valid.poke(true.B)
      dut.io.right.out.bits.data.poke(0xDEADBEEFL.U)
      dut.io.right.out.bits.keep.poke(0xFF.U)
      dut.io.right.out.bits.last.poke(true.B)

      dut.clock.step(1)
      dut.io.right.out.valid.poke(false.B)

      // Data should appear on left.out within a few cycles
      var found = false
      for (_ <- 0 until 10 if !found) {
        if (dut.io.left.out.valid.peek().litToBoolean) {
          dut.io.left.out.bits.data.expect(0xDEADBEEFL.U)
          dut.io.left.out.bits.last.expect(true.B)
          found = true
        }
        dut.clock.step(1)
      }
      assert(found, "Data should appear on left.out after latency")
    }
  }
}
