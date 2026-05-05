package fetcher
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import statecode.CoreState
import statecode.FetcherState
class FetcherTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Fetcher" should "return to IDLE after the decode stage consumes a fetched instruction" in {
    test(new Fetcher()) { dut =>
      dut.io.current_pc.poke("h12".U)
      dut.io.mem_read_data.poke("h34".U)
      dut.io.mem_read_address_sender.ready.poke(false.B)
      dut.io.core_state.poke(CoreState.FETCH)
      dut.clock.step()
      dut.io.fetcher_state.expect(FetcherState.FETCHING)
      dut.io.mem_read_address_sender.ready.poke(true.B)
      dut.clock.step()
      dut.io.fetcher_state.expect(FetcherState.FETCHED)
      dut.io.core_state.poke(CoreState.DECODE)
      dut.clock.step()
      dut.io.fetcher_state.expect(FetcherState.IDLE)
    }
  }
}
