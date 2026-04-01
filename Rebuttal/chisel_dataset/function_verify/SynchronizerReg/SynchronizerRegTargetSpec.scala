package asyncqueue.modules

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SynchronizerRegTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ClockCrossingReg" should "latch data on enable" in {
    test(new ClockCrossingReg(w = 8, doInit = true)) { dut =>
      dut.io.d.poke(0.U)
      dut.io.en.poke(false.B)
      dut.clock.step()
      dut.io.q.expect(0.U)

      dut.io.d.poke("hAB".U)
      dut.io.en.poke(true.B)
      dut.clock.step()
      dut.io.q.expect("hAB".U)

      // Hold value when enable is deasserted
      dut.io.en.poke(false.B)
      dut.io.d.poke("hFF".U)
      dut.clock.step()
      dut.io.q.expect("hAB".U)
    }
  }
}
