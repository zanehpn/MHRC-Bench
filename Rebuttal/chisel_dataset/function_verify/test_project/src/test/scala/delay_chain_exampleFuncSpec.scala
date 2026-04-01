package loywong.examples
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class delay_chain_exampleFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "delay_chain_example" should "elaborate and simulate" in {
    test(new delay_chain_example()) { dut => dut.clock.step(3); succeed }
  }
}
