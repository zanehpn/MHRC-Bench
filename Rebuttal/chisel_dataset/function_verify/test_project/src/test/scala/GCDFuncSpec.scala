package gcd
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class GCDFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "GCD" should "compute GCD of 48 and 18 as 6" in {
    test(new GCD()) { dut =>
      dut.io.loadingValues.poke(true.B)
      dut.io.value1.poke(48.U)
      dut.io.value2.poke(18.U)
      dut.clock.step(1)
      dut.io.loadingValues.poke(false.B)
      // Step until outputValid
      var steps = 0
      while (dut.io.outputValid.peek().litToBoolean == false && steps < 100) {
        dut.clock.step(1)
        steps += 1
      }
      dut.io.outputValid.expect(true.B)
      dut.io.outputGCD.expect(6.U)
    }
  }

  it should "compute GCD of 24 and 36 as 12" in {
    test(new GCD()) { dut =>
      dut.io.loadingValues.poke(true.B)
      dut.io.value1.poke(24.U)
      dut.io.value2.poke(36.U)
      dut.clock.step(1)
      dut.io.loadingValues.poke(false.B)
      var steps = 0
      while (dut.io.outputValid.peek().litToBoolean == false && steps < 100) {
        dut.clock.step(1)
        steps += 1
      }
      dut.io.outputValid.expect(true.B)
      dut.io.outputGCD.expect(12.U)
    }
  }

  it should "compute GCD of 7 and 5 as 1 (coprime)" in {
    test(new GCD()) { dut =>
      dut.io.loadingValues.poke(true.B)
      dut.io.value1.poke(7.U)
      dut.io.value2.poke(5.U)
      dut.clock.step(1)
      dut.io.loadingValues.poke(false.B)
      var steps = 0
      while (dut.io.outputValid.peek().litToBoolean == false && steps < 100) {
        dut.clock.step(1)
        steps += 1
      }
      dut.io.outputValid.expect(true.B)
      dut.io.outputGCD.expect(1.U)
    }
  }
}
