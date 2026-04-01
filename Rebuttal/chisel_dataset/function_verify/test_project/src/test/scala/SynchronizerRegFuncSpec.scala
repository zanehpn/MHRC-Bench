package asyncqueue.modules

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SynchronizerRegFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  // TARGET: val reg = if (resetType == SynchronizerResetType.NonSync) Reg(Bool()) else RegInit(init.B)
  // This is inside SynchronizerPrimitiveShiftReg (private class).
  // We test it through the public wrappers:
  // - SynchronizerShiftReg uses NonSync type (Reg(Bool()) -- no reset init)
  // - AsyncResetSynchronizerShiftReg uses Async type (RegInit(init.B))

  "SynchronizerShiftReg (NonSync)" should "propagate signal through sync register stages" in {
    // SynchronizerShiftReg with sync=3 uses NonSync type internally,
    // which means TARGET selects Reg(Bool()) -- no reset initialization.
    // Signal should propagate through 3 register stages.
    test(new SynchronizerShiftReg(w = 1, sync = 3)) { dut =>
      // Poke 0 initially and step to flush pipeline
      dut.io.d.poke(0.U)
      dut.clock.step(5)

      // Now poke 1
      dut.io.d.poke(1.U)
      dut.clock.step(1)

      // After 1 step, signal entered chain.last but hasn't propagated to output yet
      // (output = chain.head, which is 2 more stages away)
      // We can't guarantee the output is 0 since NonSync has no reset,
      // but after flushing with 0s above, chain should be all 0s.
      dut.io.q.expect(0.U, "After 1 step, signal should not have reached output yet")

      dut.clock.step(1)
      // After 2 steps, signal at chain(1), still not at chain.head
      dut.io.q.expect(0.U, "After 2 steps, signal should not have reached output yet")

      dut.clock.step(1)
      // After 3 steps total, signal has propagated through all 3 stages to output
      dut.io.q.expect(1.U, "After 3 steps, signal should appear at output")

      // Now poke 0 and verify it takes 3 steps to propagate
      dut.io.d.poke(0.U)
      dut.clock.step(1)
      dut.io.q.expect(1.U, "Output should still be 1 after only 1 step of 0 input")
      dut.clock.step(1)
      dut.io.q.expect(1.U, "Output should still be 1 after only 2 steps of 0 input")
      dut.clock.step(1)
      dut.io.q.expect(0.U, "Output should be 0 after 3 steps of 0 input")
    }
  }

  "AsyncResetSynchronizerShiftReg (Async)" should "initialize to init value via RegInit" in {
    // AsyncResetSynchronizerShiftReg uses Async type, which means TARGET selects
    // RegInit(init.B) -- reset-initialized registers. With init=0, all regs start at 0.
    test(new AsyncResetSynchronizerShiftReg(w = 1, sync = 3, init = 0)) { dut =>
      // With RegInit(false.B), output should be 0 immediately after reset
      dut.io.q.expect(0.U, "Output should be 0 after reset with init=0")

      // Poke 1 and verify propagation delay
      dut.io.d.poke(1.U)
      dut.clock.step(1)
      dut.io.q.expect(0.U, "After 1 step, output still 0")
      dut.clock.step(1)
      dut.io.q.expect(0.U, "After 2 steps, output still 0")
      dut.clock.step(1)
      dut.io.q.expect(1.U, "After 3 steps, output should be 1")
    }
  }

  it should "initialize to 1 when init=1 via RegInit" in {
    // With init=1, RegInit(true.B) is used, so all chain registers start at 1
    test(new AsyncResetSynchronizerShiftReg(w = 1, sync = 2, init = 1)) { dut =>
      // All RegInit(true.B) registers start at 1, output should be 1
      dut.io.q.expect(1.U, "Output should be 1 after reset with init=1")

      // Poke 0 and verify it takes 2 steps to propagate (sync=2)
      dut.io.d.poke(0.U)
      dut.clock.step(1)
      dut.io.q.expect(1.U, "After 1 step of 0, output still 1 (sync=2)")
      dut.clock.step(1)
      dut.io.q.expect(0.U, "After 2 steps of 0, output should be 0")
    }
  }
}
