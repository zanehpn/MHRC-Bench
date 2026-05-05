package loywong
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class counter_exampleTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "counter_example" should "count when enabled and wrap around" in {
    test(new examples.counter_example(m = 4)) { dut =>
      // Initially counter should be 0
      dut.io.en.poke(false.B)
      dut.clock.step()
      dut.io.out.expect(0.U)
      dut.io.co.expect(false.B)

      // Enable counting: 0 -> 1 -> 2 -> 3
      dut.io.en.poke(true.B)
      dut.clock.step()
      dut.io.out.expect(1.U)
      dut.io.co.expect(false.B)

      dut.clock.step()
      dut.io.out.expect(2.U)
      dut.io.co.expect(false.B)

      dut.clock.step()
      dut.io.out.expect(3.U)
      dut.io.co.expect(true.B) // carry out at max

      // Wrap around to 0
      dut.clock.step()
      dut.io.out.expect(0.U)
      dut.io.co.expect(false.B)

      // Disable counting: should stay at 0
      dut.io.en.poke(false.B)
      dut.clock.step()
      dut.io.out.expect(0.U)
    }
  }
}
