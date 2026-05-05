package lsu

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import statecode._

class MemLoadStoreUnitFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "MemLoadStoreUnit" should "transition from DONE to IDLE when core_state is UPDATE" in {
    test(new MemLoadStoreUnit()) { dut =>
      // Initialize
      dut.io.enable.poke(true.B)
      dut.io.mem_rw_enable.read_enable.poke(true.B)
      dut.io.mem_rw_enable.write_enable.poke(false.B)
      dut.io.core_state.poke(CoreState.IDLE)
      dut.io.reg_in.rs.poke(0x10.U)
      dut.io.reg_in.rt.poke(0x20.U)
      dut.io.mem_read_data.poke(0.U)
      dut.io.mem_read_address_sender.ready.poke(false.B)
      dut.io.mem_write_sender.ready.poke(false.B)
      dut.clock.step(1)

      // Should be IDLE
      dut.io.lsu_state.expect(LSUState.IDLE)

      // IDLE -> REQUESTING: set core_state = REQUEST
      dut.io.core_state.poke(CoreState.REQUEST)
      dut.clock.step(1)
      dut.io.lsu_state.expect(LSUState.REQUESTING)

      // REQUESTING -> WAITING: automatically sets up read
      dut.clock.step(1)
      dut.io.lsu_state.expect(LSUState.WAITING)

      // WAITING -> DONE: signal ready on mem_read_address_sender
      dut.io.mem_read_address_sender.ready.poke(true.B)
      dut.io.mem_read_data.poke(0x42.U)
      dut.clock.step(1)
      dut.io.lsu_state.expect(LSUState.DONE)

      // Verify lsu_out captured the read data
      dut.io.lsu_out.expect(0x42.U)

      // DONE -> IDLE: set core_state = UPDATE (TARGET)
      dut.io.core_state.poke(CoreState.UPDATE)
      dut.clock.step(1)
      dut.io.lsu_state.expect(LSUState.IDLE)
    }
  }
}
