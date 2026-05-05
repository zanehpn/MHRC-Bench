package perfect
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class CounterModuleFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "CounterModule" should "wrap to zero when reaching max" in {
    test(new CounterModule(16)) { dut =>
      dut.io.extReset.poke(false.B)
      dut.io.max.poke(4.U)
      dut.io.inc.poke(true.B)

      dut.clock.step(1)
      dut.io.value.expect(1.U)
      dut.clock.step(1)
      dut.io.value.expect(2.U)
      dut.clock.step(1)
      dut.io.value.expect(3.U)
      dut.io.wrap.expect(true.B)  // wrap = (value === max-1) = (3 === 3)
      dut.clock.step(1)
      // wrap was true last cycle, so value reset to 0
      dut.io.value.expect(0.U)
    }
  }

  it should "reset to zero on extReset" in {
    test(new CounterModule(16)) { dut =>
      dut.io.extReset.poke(false.B)
      dut.io.max.poke(10.U)
      dut.io.inc.poke(true.B)

      dut.clock.step(1)
      dut.io.value.expect(1.U)
      dut.clock.step(1)
      dut.io.value.expect(2.U)

      // Assert extReset
      dut.io.extReset.poke(true.B)
      dut.clock.step(1)
      dut.io.value.expect(0.U)

      // Release extReset, counter resumes
      dut.io.extReset.poke(false.B)
      dut.clock.step(1)
      dut.io.value.expect(1.U)
    }
  }
}
