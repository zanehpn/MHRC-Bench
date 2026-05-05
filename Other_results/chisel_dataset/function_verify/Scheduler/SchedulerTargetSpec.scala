package scheduler
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import statecode.CoreState
import statecode.FetcherState
import statecode.LSUState
class SchedulerTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Scheduler" should "move from FETCH into DECODE once the fetcher reports FETCHED" in {
    test(new Scheduler(1)) { dut =>
      dut.io.start.poke(true.B)
      dut.io.mem_rw_enable.read_enable.poke(false.B)
      dut.io.mem_rw_enable.write_enable.poke(false.B)
      dut.io.decoded_ret.poke(false.B)
      dut.io.fetcher_state.poke(FetcherState.IDLE)
      dut.io.lsu_state(0).poke(LSUState.IDLE)
      dut.io.next_pc(0).poke(9.U)
      dut.clock.step()
      dut.io.core_state.expect(CoreState.FETCH)
      dut.io.start.poke(false.B)
      dut.io.fetcher_state.poke(FetcherState.FETCHED)
      dut.clock.step()
      dut.io.core_state.expect(CoreState.DECODE)
    }
  }
}
