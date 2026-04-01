package scheduler

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import statecode._

class SchedulerFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Scheduler" should "transition FETCH -> DECODE -> REQUEST when fetcher signals FETCHED" in {
    test(new Scheduler(ThreadsPerBlock = 4)) { dut =>
      // Initialize inputs
      dut.io.start.poke(false.B)
      dut.io.fetcher_state.poke(FetcherState.IDLE)
      dut.io.decoded_ret.poke(false.B)
      dut.io.mem_rw_enable.read_enable.poke(false.B)
      dut.io.mem_rw_enable.write_enable.poke(false.B)
      for (i <- 0 until 4) {
        dut.io.lsu_state(i).poke(LSUState.IDLE)
        dut.io.next_pc(i).poke(0.U)
      }
      dut.clock.step(1)

      // Should start in IDLE
      dut.io.core_state.expect(CoreState.IDLE)

      // Assert start -> transition to FETCH
      dut.io.start.poke(true.B)
      dut.clock.step(1)
      dut.io.core_state.expect(CoreState.FETCH)

      // Deassert start, set fetcher_state to FETCHED -> transition to DECODE (TARGET)
      dut.io.start.poke(false.B)
      dut.io.fetcher_state.poke(FetcherState.FETCHED)
      dut.clock.step(1)
      dut.io.core_state.expect(CoreState.DECODE)

      // DECODE -> REQUEST (unconditional, TARGET)
      dut.clock.step(1)
      dut.io.core_state.expect(CoreState.REQUEST)
    }
  }
}
