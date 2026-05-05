package chiseltest.iotesters
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class DecoupledGcdFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "DecoupledGcd" should "elaborate and simulate" in {
    test(new DecoupledGcd(8)) { dut =>
      dut.clock.step(3)
      succeed
    }
  }
}
