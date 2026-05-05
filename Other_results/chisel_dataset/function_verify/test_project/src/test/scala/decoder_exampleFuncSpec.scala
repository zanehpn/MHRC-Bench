package loywong.examples
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class decoder_exampleFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "decoder_example" should "elaborate and simulate" in {
    test(new decoder_example()) { dut => dut.clock.step(3); succeed }
  }
}
