package router.table

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import router._

class ArpCacheTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ArpCache" should "return invalid for empty cache query" in {
    test(new ArpCache(SIZE_LOG2 = 4)) { dut =>
      // No operations - query should return invalid
      dut.io.modify.op.poke(ArpOp.None)
      dut.io.modify.ipv4.bits.poke(0.U)
      dut.io.modify.mac.bits.poke(0.U)
      dut.io.query.ipv4.bits.poke("hC0A80001".U) // 192.168.0.1
      dut.clock.step()

      dut.io.query.mac.valid.expect(false.B)
    }
  }
}
