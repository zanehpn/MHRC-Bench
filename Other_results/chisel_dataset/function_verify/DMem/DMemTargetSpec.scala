package mem

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class DMemTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DMem" should "acknowledge write requests to valid addresses" in {
    test(new DMem) { dut =>
      // Write request
      dut.io.dmem_add.addr.poke(0x100.U)
      dut.io.w_dmem_dat.req.poke(true.B)
      dut.io.w_dmem_dat.data.poke("hAABBCCDD".U)
      dut.io.w_dmem_dat.byteenable.poke(15.U)
      dut.io.r_dmem_dat.req.poke(false.B)
      dut.clock.step()

      dut.io.w_dmem_dat.ack.expect(true.B)
    }
  }
}
