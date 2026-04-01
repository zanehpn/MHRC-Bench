package pc
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class ProgramCounterTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ProgramCounter" should "increment PC sequentially on EXECUTE" in {
    test(new ProgramCounter()) { dut =>
      import statecode.CoreState

      // Enable and set core_state to EXECUTE, no branch
      dut.io.enable.poke(true.B)
      dut.io.core_state.poke(CoreState.EXECUTE)
      dut.io.decoded_pc_mux.poke(false.B)  // sequential mode
      dut.io.decoded_nzp.poke(0.U)
      dut.io.decoded_immediate.poke(0.U)
      dut.io.decoded_nzp_write_enable.poke(false.B)
      dut.io.alu_out.poke(0.U)
      dut.io.current_pc.poke(5.U)

      // Step to update next_pc register to current_pc + 1 = 6
      dut.clock.step()

      // Disable enable so io.next_pc outputs the register value
      dut.io.enable.poke(false.B)
      dut.io.next_pc.expect(6.U)

      // Enable again with new current_pc
      dut.io.enable.poke(true.B)
      dut.io.current_pc.poke(10.U)
      dut.clock.step()

      // Disable enable to read next_pc
      dut.io.enable.poke(false.B)
      dut.io.next_pc.expect(11.U)
    }
  }

  "ProgramCounter" should "branch to immediate when NZP matches" in {
    test(new ProgramCounter()) { dut =>
      import statecode.CoreState

      // First, set NZP register via UPDATE state
      dut.io.enable.poke(true.B)
      dut.io.core_state.poke(CoreState.UPDATE)
      dut.io.decoded_nzp_write_enable.poke(true.B)
      dut.io.alu_out.poke(1.U) // sets nzp = alu_out(2,0) = 1
      dut.io.decoded_nzp.poke(0.U)
      dut.io.decoded_pc_mux.poke(false.B)
      dut.io.decoded_immediate.poke(0.U)
      dut.io.current_pc.poke(0.U)
      dut.clock.step()
      // Now nzp register = 1

      // Execute with branch mux enabled, NZP matches => branch
      dut.io.core_state.poke(CoreState.EXECUTE)
      dut.io.decoded_pc_mux.poke(true.B)
      dut.io.decoded_nzp.poke(1.U)        // check bit 0, nzp=1 => (1 & 1) != 0 => branch
      dut.io.decoded_immediate.poke(100.U) // branch target
      dut.io.decoded_nzp_write_enable.poke(false.B)
      dut.io.current_pc.poke(20.U)
      dut.clock.step()

      // Disable enable to read next_pc => should be branch target 100
      dut.io.enable.poke(false.B)
      dut.io.next_pc.expect(100.U)
    }
  }
}
