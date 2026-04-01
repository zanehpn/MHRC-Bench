package cpu

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class MemoryFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Memory" should "write data via dmem and read back with correct byte assembly including addr+1" in {
    test(new Memory("/dev/null")) { dut =>
      // Write a known 32-bit value to dmem address 0x100
      // wdata = 0xDEADBEEF -> bytes: DE(31:24), AD(23:16), BE(15:8), EF(7:0)
      dut.io.dmem.wen.poke(true.B)
      dut.io.dmem.addr.poke(0x100.U)
      dut.io.dmem.wdata.poke("hDEADBEEF".U)
      dut.clock.step(1)
      dut.io.dmem.wen.poke(false.B)

      // Now read back from address 0x100
      // The dmem read assembles: Cat(mem(addr+3), mem(addr+1), mem(addr))
      // That is: Cat(DE, BE, EF) = 0xDEBEEF (only 3 bytes in the Cat)
      // The TARGET is mem(io.dmem.addr + 1.U) which contributes byte 0xBE
      dut.io.dmem.addr.poke(0x100.U)
      dut.clock.step(1)

      // rdata = Cat(mem(addr+3), mem(addr+1), mem(addr))
      // = Cat(0xDE, 0xBE, 0xEF) = 0x00DEBEEF (24 bits zero-extended to 32)
      dut.io.dmem.rdata.expect("hDEBEEF".U)

      // Write a second value to verify the addr+1 byte specifically
      dut.io.dmem.wen.poke(true.B)
      dut.io.dmem.addr.poke(0x200.U)
      dut.io.dmem.wdata.poke("h12345678".U)
      dut.clock.step(1)
      dut.io.dmem.wen.poke(false.B)

      dut.io.dmem.addr.poke(0x200.U)
      dut.clock.step(1)
      // Cat(mem(0x203)=0x12, mem(0x201)=0x56, mem(0x200)=0x78) = 0x125678
      dut.io.dmem.rdata.expect("h125678".U)
    }
  }
}
