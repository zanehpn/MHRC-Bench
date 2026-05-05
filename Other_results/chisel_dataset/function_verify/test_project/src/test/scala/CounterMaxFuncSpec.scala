package loywong.examples
import chisel3._; import chiseltest._; import org.scalatest.flatspec.AnyFlatSpec
class CounterMaxFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "counter_max_example" should "signal co when cnt equals max" in {
    test(new counter_max_example(4)) { dut =>
      dut.io.max.poke(0.U); dut.io.en.poke(true.B)
      dut.io.co.expect(true.B); dut.io.out.expect(0.U)
    }
  }
}
