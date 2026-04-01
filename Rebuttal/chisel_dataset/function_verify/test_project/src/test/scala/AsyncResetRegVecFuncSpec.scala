package freechips.rocketchip.util
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class AsyncResetRegVecFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "AsyncResetRegVec" should "reset to init value and store data on enable" in {
    test(new AsyncResetRegVec(w = 8, init = 0xAB)) { dut =>
      // After reset, q should be the init value 0xAB
      dut.io.en.poke(false.B)
      dut.io.d.poke(0.U)
      dut.clock.step()
      dut.io.q.expect("hAB".U)

      // Write new value with enable
      dut.io.en.poke(true.B)
      dut.io.d.poke("h55".U)
      dut.clock.step()
      dut.io.q.expect("h55".U)

      // Disable write, value should hold
      dut.io.en.poke(false.B)
      dut.io.d.poke("hFF".U)
      dut.clock.step()
      dut.io.q.expect("h55".U)

      // Re-enable write with new value
      dut.io.en.poke(true.B)
      dut.io.d.poke("h00".U)
      dut.clock.step()
      dut.io.q.expect("h00".U)
    }
  }
}
