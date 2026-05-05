package perfect

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class CounterTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "CounterModule" should "clear on wrap or external reset" in {
    test(new CounterModule(4)) { dut =>
      dut.io.extReset.poke(false.B)
      dut.io.max.poke(3.U)
      dut.io.inc.poke(true.B)

      dut.clock.step()
      dut.io.value.expect(1.U)
      dut.clock.step()
      dut.io.value.expect(2.U)
      dut.io.wrap.expect(true.B)
      dut.clock.step()
      dut.io.value.expect(0.U)

      dut.io.extReset.poke(true.B)
      dut.clock.step()
      dut.io.value.expect(0.U)
    }
  }
}
