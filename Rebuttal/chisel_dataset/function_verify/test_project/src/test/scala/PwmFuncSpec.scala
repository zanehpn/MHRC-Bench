package perfect.util
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class PwmFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Pwm" should "count when enabled and reset at period" in {
    test(new Pwm(8)) { dut =>
      dut.io.enable.poke(true.B)
      dut.io.period.poke(4.U)
      dut.io.pulseWidth.poke(2.U)

      // count=0(Reg init): out = enable && 0<=2 = true
      dut.io.out.expect(true.B)
      dut.clock.step(1)
      // count=1: 1<=2 -> out=true
      dut.io.out.expect(true.B)
      dut.clock.step(1)
      // count=2: 2<=2 -> out=true
      dut.io.out.expect(true.B)
      dut.clock.step(1)
      // count=3: 3<=2 -> out=false
      dut.io.out.expect(false.B)
      dut.clock.step(1)
      // count=4: 4<=2 -> out=false, but 4>=4 so count resets to 0 at this edge
      dut.io.out.expect(false.B)
      dut.clock.step(1)
      // count=0 (was reset): 0<=2 -> out=true (TARGET: period reset works)
      dut.io.out.expect(true.B)
    }
  }

  it should "hold count at zero when disabled (TARGET: ~enable resets count)" in {
    test(new Pwm(8)) { dut =>
      dut.io.enable.poke(false.B)
      dut.io.period.poke(4.U)
      dut.io.pulseWidth.poke(2.U)

      // Disabled: out = enable && ... = false, count stays 0
      dut.io.out.expect(false.B)
      dut.clock.step(3)
      dut.io.out.expect(false.B)

      // Enable: count=0, 0<=2 -> out=true
      dut.io.enable.poke(true.B)
      dut.clock.step(1)
      // count=1 now
      dut.io.out.expect(true.B)
    }
  }
}
