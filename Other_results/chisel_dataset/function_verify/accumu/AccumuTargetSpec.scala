package final_project
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class AccumuTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Accumu" should "output zero valid when not flagged" in {
    test(new Accumu(w = 8, addr_w = 16, bias_w = 16, para_num = 1)) { dut =>
      dut.io.flag_job.poke(false.B)
      dut.io.is_in_use.poke(false.B)
      dut.io.valid_in.poke(0.U)
      dut.io.csum.poke(0.U)
      dut.io.bias_begin_addr.poke(0.U)
      dut.io.bias_end_addr.poke(0.U)
      for (i <- 0 until 1) {
        dut.io.bias_in(i).poke(0.S)
        for (j <- 0 until 64) {
          dut.io.in_from_calc8x8(i).mat(j).poke(0.S)
        }
      }
      dut.clock.step()
      dut.io.valid_out.expect(0.U)
    }
  }
}
