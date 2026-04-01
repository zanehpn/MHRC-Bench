package mem

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class IMemTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "IMem" should "acknowledge write requests to valid addresses" in {
    test(new IMem) { dut =>
      // Write request
      dut.io.imem_add.addr.poke(0x100.U)
      dut.io.w_imem_dat.req.poke(true.B)
      dut.io.w_imem_dat.data.poke("hAABBCCDD".U)
      dut.io.w_imem_dat.byteenable.poke(15.U)
      dut.io.r_imem_dat.req.poke(false.B)
      dut.clock.step()

      dut.io.w_imem_dat.ack.expect(true.B)
    }
  }
}
