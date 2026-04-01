package mem

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class IMemFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "IMem" should "write byte 2 when byteenable(2) is set and read back correctly" in {
    test(new IMem()) { dut =>
      val addr = 0x100.U

      // Write all 4 bytes to address 0x100
      dut.io.imem_add.addr.poke(addr)
      dut.io.w_imem_dat.req.poke(true.B)
      dut.io.r_imem_dat.req.poke(false.B)
      dut.io.w_imem_dat.byteenable.poke(15.U)
      dut.io.w_imem_dat.data.poke("h11223344".U)
      dut.clock.step(1)

      dut.io.w_imem_dat.ack.expect(true.B)

      // Read back to verify full write
      dut.io.w_imem_dat.req.poke(false.B)
      dut.io.r_imem_dat.req.poke(true.B)
      dut.io.w_imem_dat.byteenable.poke(15.U)
      dut.io.imem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.r_imem_dat.ack.expect(true.B)
      dut.io.r_imem_dat.data.expect("h11223344".U)

      // Now write ONLY byte 2 (byteenable = 0b0100 = 4)
      dut.io.r_imem_dat.req.poke(false.B)
      dut.io.w_imem_dat.req.poke(true.B)
      dut.io.w_imem_dat.byteenable.poke(4.U)
      dut.io.w_imem_dat.data.poke("h00FF0000".U)
      dut.io.imem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.w_imem_dat.ack.expect(true.B)

      // Read back - byte 2 should be FF, others unchanged (11, 33, 44)
      dut.io.w_imem_dat.req.poke(false.B)
      dut.io.r_imem_dat.req.poke(true.B)
      dut.io.w_imem_dat.byteenable.poke(15.U)
      dut.io.imem_add.addr.poke(addr)
      dut.clock.step(1)

      dut.io.r_imem_dat.ack.expect(true.B)
      dut.io.r_imem_dat.data.expect("h11FF3344".U)
    }
  }
}
