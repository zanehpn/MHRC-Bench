package mem

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class DMemFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DMem" should "write byte 3 when byteenable(3) is set and read back correctly" in {
    test(new DMem()) { dut =>
      val addr = 0x100.U

      // Write all 4 bytes to address 0x100
      dut.io.dmem_add.addr.poke(addr)
      dut.io.w_dmem_dat.req.poke(true.B)
      dut.io.r_dmem_dat.req.poke(false.B)
      dut.io.w_dmem_dat.byteenable.poke(15.U)
      dut.io.w_dmem_dat.data.poke("hAABBCCDD".U)
      dut.clock.step(1)

      // Verify write ack
      dut.io.w_dmem_dat.ack.expect(true.B)

      // Now read back
      dut.io.w_dmem_dat.req.poke(false.B)
      dut.io.r_dmem_dat.req.poke(true.B)
      dut.io.w_dmem_dat.byteenable.poke(15.U)
      dut.io.dmem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.r_dmem_dat.ack.expect(true.B)
      dut.io.r_dmem_dat.data.expect("hAABBCCDD".U)

      // Now write ONLY byte 3 (byteenable = 0b1000 = 8) with a new value
      dut.io.r_dmem_dat.req.poke(false.B)
      dut.io.w_dmem_dat.req.poke(true.B)
      dut.io.w_dmem_dat.byteenable.poke(8.U)
      dut.io.w_dmem_dat.data.poke("hFF000000".U)
      dut.io.dmem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.w_dmem_dat.ack.expect(true.B)

      // Read back - byte 3 should be FF, others unchanged (BB, CC, DD)
      dut.io.w_dmem_dat.req.poke(false.B)
      dut.io.r_dmem_dat.req.poke(true.B)
      dut.io.w_dmem_dat.byteenable.poke(15.U)
      dut.io.dmem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.r_dmem_dat.ack.expect(true.B)
      dut.io.r_dmem_dat.data.expect("hFFBBCCDD".U)
    }
  }
}
