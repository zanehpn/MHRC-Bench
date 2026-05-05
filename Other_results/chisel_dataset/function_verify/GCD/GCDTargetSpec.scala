package gcd

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class GCDTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "GCD" should "converge by repeated subtraction when x is larger than y" in {
    test(new GCD) { dut =>
      dut.io.loadingValues.poke(true.B)
      dut.io.value1.poke(21.U)
      dut.io.value2.poke(15.U)
      dut.clock.step()

      dut.io.loadingValues.poke(false.B)
      while (!dut.io.outputValid.peek().litToBoolean) {
        dut.clock.step()
      }

      dut.io.outputGCD.expect(3.U)
    }
  }
}
