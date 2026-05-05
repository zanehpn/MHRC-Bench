package router.table

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import router._

class ArpCacheFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ArpCache" should "insert, query, remove, and verify invalidation" in {
    test(new ArpCache(4)) { dut =>
      // Helper: set modify to None each cycle unless overridden
      def setModifyNone(): Unit = {
        dut.io.modify.op.poke(ArpOp.None)
        dut.io.modify.ipv4.bits.poke(0.U)
        dut.io.modify.mac.bits.poke(0.U)
      }

      def setQueryNone(): Unit = {
        dut.io.query.ipv4.bits.poke(0.U)
      }

      // After reset, all entries should be invalid
      setModifyNone()
      setQueryNone()
      dut.clock.step(1)

      // Insert an entry: IP=10.0.0.1 (0x0A000001), MAC=0x112233445566
      val ipVal = "h0A000001".U
      val macVal = "h112233445566".U

      dut.io.modify.op.poke(ArpOp.Insert)
      dut.io.modify.ipv4.bits.poke(ipVal)
      dut.io.modify.mac.bits.poke(macVal)
      dut.io.query.ipv4.bits.poke(0.U)
      dut.clock.step(1)

      // Query the inserted entry
      setModifyNone()
      dut.io.query.ipv4.bits.poke(ipVal)
      dut.clock.step(1)

      // Verify the entry is valid and MAC matches
      dut.io.query.mac.valid.expect(true.B)
      dut.io.query.mac.bits.bits.expect(macVal)

      // Remove the entry
      dut.io.modify.op.poke(ArpOp.Remove)
      dut.io.modify.ipv4.bits.poke(ipVal)
      dut.io.modify.mac.bits.poke(0.U)
      dut.io.query.ipv4.bits.poke(ipVal)
      dut.clock.step(1)

      // Query again after remove - should be invalid
      setModifyNone()
      dut.io.query.ipv4.bits.poke(ipVal)
      dut.clock.step(1)

      dut.io.query.mac.valid.expect(false.B)

      // Test Clear: insert again, then clear all
      dut.io.modify.op.poke(ArpOp.Insert)
      dut.io.modify.ipv4.bits.poke(ipVal)
      dut.io.modify.mac.bits.poke(macVal)
      dut.clock.step(1)

      // Verify it's there
      setModifyNone()
      dut.io.query.ipv4.bits.poke(ipVal)
      dut.clock.step(1)
      dut.io.query.mac.valid.expect(true.B)

      // Clear all entries
      dut.io.modify.op.poke(ArpOp.Clear)
      dut.io.modify.ipv4.bits.poke(0.U)
      dut.io.modify.mac.bits.poke(0.U)
      dut.clock.step(1)

      // Query after clear - should be invalid
      setModifyNone()
      dut.io.query.ipv4.bits.poke(ipVal)
      dut.clock.step(1)
      dut.io.query.mac.valid.expect(false.B)
    }
  }
}
