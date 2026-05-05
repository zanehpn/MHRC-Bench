package loywong
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class ShiftRegTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "shift_reg_example" should "load and shift data correctly" in {
    test(new examples.shift_reg_example) { dut =>
      // Initially output should be 0 after reset
      dut.io.shift.poke(false.B)
      dut.io.load.poke(false.B)
      dut.io.din.poke(0.U)
      dut.io.sin.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect(0.U)

      // Load parallel data: 0x2AB (10-bit: 1010101011)
      dut.io.load.poke(true.B)
      dut.io.din.poke("h2AB".U)
      dut.clock.step()
      dut.io.load.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect("h2AB".U)

      // Shift left with sin=1: 0x2AB(1010101011) -> 0x157(1010101111) shifted left, sin=1
      dut.io.shift.poke(true.B)
      dut.io.sin.poke(true.B)
      dut.clock.step()
      dut.io.shift.poke(false.B)
      dut.clock.step()
      // After shift: lower 9 bits of 0x2AB = 0x2AB(9:0)=010101011, concat sin=1 => 1010101111 = 0x157...
      // Actually: regs(nBits-2,0) ## sin = regs(8,0) ## 1
      // 0x2AB = 10_1010_1011, regs(8,0) = 0_1010_1011, ## 1 = 10_1010_1111 = 0x15... wait
      // Let me recalc: 0x2AB in 10 bits = 10 1010 1011
      // regs(8,0) = 0 1010 1011 = 0x0AB... wait no
      // 10 1010 1011 => bits 8..0 = 0 1010 1011
      // concat with sin=1 => 0 1010 1011 1 ... that's 10 bits: 01 0101 0111 = 0x157
      dut.io.qout.expect("h157".U)

      // Shift again with sin=0
      dut.io.shift.poke(true.B)
      dut.io.sin.poke(false.B)
      dut.clock.step()
      dut.io.shift.poke(false.B)
      dut.clock.step()
      // 0x157 = 01 0101 0111, bits(8,0) = 1 0101 0111, ## 0 => 01 0101 1110 = ... wait
      // Actually: 0x157 in 10 bits = 01 0101 0111
      // regs(8,0) = 1 0101 0111
      // ## 0 => 10 1011 1100 ... wait let me just be careful
      // 0x157 = 0101010111
      // bits 8..0 = 101010111
      // concat 0 = 1010101110 = 0x2AE
      dut.io.qout.expect("h2AE".U)
    }
  }
}
