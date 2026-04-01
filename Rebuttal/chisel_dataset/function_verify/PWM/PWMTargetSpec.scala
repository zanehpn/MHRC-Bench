package perfect.util

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class PWMTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Pwm" should "advance count while enabled" in {
    test(new Pwm(4)) { dut =>
      dut.io.enable.poke(false.B)
      dut.io.pulseWidth.poke(0.U)
      dut.io.period.poke(3.U)
      dut.clock.step()

      dut.io.enable.poke(true.B)
      dut.io.out.expect(true.B)
      dut.clock.step()
      dut.io.out.expect(false.B)
    }
  }
}
