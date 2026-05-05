package loywong.examples
import chisel3._; import chiseltest._; import org.scalatest.flatspec.AnyFlatSpec
class ShiftRegFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "shift_reg_example" should "load and shift data correctly" in {
    test(new shift_reg_example) { dut =>
      // Initially output should be 0 after reset
      dut.io.shift.poke(false.B)
      dut.io.load.poke(false.B)
      dut.io.din.poke(0.U)
      dut.io.sin.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect(0.U)

      // Load parallel data: 0x2AB (10-bit)
      dut.io.load.poke(true.B)
      dut.io.din.poke("h2AB".U)
      dut.clock.step()
      dut.io.load.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect("h2AB".U)

      // Shift left with sin=1
      // 0x2AB = 10_1010_1011, regs(8,0) = 0_1010_1011, ## 1 => 01_0101_0111 = 0x157
      dut.io.shift.poke(true.B)
      dut.io.sin.poke(true.B)
      dut.clock.step()
      dut.io.shift.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect("h157".U)

      // Shift again with sin=0
      // 0x157 = 01_0101_0111, regs(8,0) = 1_0101_0111, ## 0 => 10_1010_1110 = 0x2AE
      dut.io.shift.poke(true.B)
      dut.io.sin.poke(false.B)
      dut.clock.step()
      dut.io.shift.poke(false.B)
      dut.clock.step()
      dut.io.qout.expect("h2AE".U)
    }
  }
}
