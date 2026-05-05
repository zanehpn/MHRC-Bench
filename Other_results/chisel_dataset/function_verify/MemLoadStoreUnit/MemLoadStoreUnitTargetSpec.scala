package lsu
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import statecode.CoreState
import statecode.LSUState
class MemLoadStoreUnitTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "MemLoadStoreUnit" should "return to IDLE from DONE during UPDATE on store traffic" in {
    test(new MemLoadStoreUnit) { dut =>
      dut.io.enable.poke(true.B)
      dut.io.mem_rw_enable.read_enable.poke(false.B)
      dut.io.mem_rw_enable.write_enable.poke(true.B)
      dut.io.reg_in.rs.poke("h12".U)
      dut.io.reg_in.rt.poke("hab".U)
      dut.io.mem_read_data.poke(0.U)
      dut.io.mem_write_sender.ready.poke(false.B)
      dut.io.core_state.poke(CoreState.REQUEST)
      dut.clock.step()
      dut.io.lsu_state.expect(LSUState.REQUESTING)
      dut.clock.step()
      dut.io.lsu_state.expect(LSUState.WAITING)
      dut.io.mem_write_sender.ready.poke(true.B)
      dut.clock.step()
      dut.io.lsu_state.expect(LSUState.DONE)
      dut.io.core_state.poke(CoreState.UPDATE)
      dut.clock.step()
      dut.io.lsu_state.expect(LSUState.IDLE)
    }
  }
}
