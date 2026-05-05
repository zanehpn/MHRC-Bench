package final_project

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class AccumuFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  val w = 8
  val addr_w = 16
  val bias_w = 16
  val para_num = 1

  "Accumu" should "trigger ccnt===cend path and observe bias_addr change" in {
    test(new Accumu(w, addr_w, bias_w, para_num)) { dut =>
      // Initialize all inputs
      dut.io.flag_job.poke(false.B)
      dut.io.is_in_use.poke(false.B)
      dut.io.valid_in.poke(0.U)
      dut.io.csum.poke(0.U)
      dut.io.bias_begin_addr.poke(0.U)
      dut.io.bias_end_addr.poke(0.U)
      for (t <- 0 until para_num) {
        dut.io.bias_in(t).poke(0.S)
        for (i <- 0 until 64) {
          dut.io.in_from_calc8x8(t).mat(i).poke(0.S)
        }
      }
      dut.clock.step(1)

      // Start a job: flag_job sets counter.ccnt = csum, counter.cend = csum
      // Use csum=2 so counter starts with ccnt=2, cend=2
      // bias_begin_addr=10, bias_end_addr=14
      dut.io.flag_job.poke(true.B)
      dut.io.is_in_use.poke(true.B)
      dut.io.csum.poke(2.U)
      dut.io.bias_begin_addr.poke(10.U)
      dut.io.bias_end_addr.poke(14.U)
      dut.clock.step(1)

      // After flag_job: counter.ccnt=2, counter.cend=2, enable=true
      // now_addr.ccnt=10, now_addr.cend=14
      // bias_addr = now_addr.ccnt = 10
      dut.io.flag_job.poke(false.B)
      dut.io.bias_addr.expect(10.U, "bias_addr should be bias_begin_addr after job setup")

      // Now feed valid_in=1 to trigger the ccnt===cend path (ccnt=2, cend=2)
      // TARGET: when(counter.ccnt===counter.cend){ valid_out_reg := 0.U; counter.ccnt := counter.ccnt-1.U }
      // Also: when(counter.ccnt===1.U){ now_addr.inc() } -- ccnt is 2 not 1, so no inc yet
      dut.io.valid_in.poke(1.U)
      dut.clock.step(1)

      // After step: ccnt was 2===cend=2, so TARGET fired: ccnt decremented to 1
      // valid_out_reg set to 0, so valid_out=0
      dut.io.valid_out.expect(0.U, "valid_out should be 0 after ccnt===cend path")

      // Now ccnt=1, cend=2. Feed another valid_in.
      // ccnt(1) !== cend(2), so ccnt===cend path does NOT fire
      // ccnt(1) !== 0, so ccnt===0 path does NOT fire
      // But ccnt===1.U IS true, so now_addr.inc() fires
      dut.clock.step(1)

      // After this step: now_addr.inc() was called, now_addr.ccnt goes 10->11
      // bias_addr should now be 11
      dut.io.bias_addr.expect(11.U, "bias_addr should increment after ccnt===1 triggers now_addr.inc()")

      // This proves the TARGET path (ccnt===cend) actually fired:
      // ccnt went from 2 to 1 (decremented), which then caused the ccnt===1 path
      // to trigger on the next cycle, incrementing now_addr (observable via bias_addr).
    }
  }
}
