package gcd
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class DecoupledGCDTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DecoupledGcd" should "return gcd when one input is zero" in {
    test(new DecoupledGcd(16)) { dut =>
      dut.output.ready.poke(true.B)
      dut.input.valid.poke(true.B)
      dut.input.bits.value1.poke(0.U)
      dut.input.bits.value2.poke(15.U)
      dut.clock.step()
      dut.input.valid.poke(false.B)
      while (!dut.output.valid.peek().litToBoolean) { dut.clock.step() }
      dut.output.bits.gcd.expect(15.U)
    }
  }
}
