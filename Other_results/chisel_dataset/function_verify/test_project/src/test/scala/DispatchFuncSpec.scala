package dispatch
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class DispatchFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "Dispatch" should "dispatch blocks sequentially and signal done" in {
    // 1 core, 4 threads per core, 8 total threads = 2 blocks dispatched one at a time
    test(new Dispatch(NumCores = 1, ThreadsPerCore = 4)) { dut =>
      // Initially done should be false
      dut.io.start.poke(false.B)
      dut.io.thread_count.poke(8.U)
      dut.io.core_done(0).poke(false.B)
      dut.clock.step()
      dut.io.done.expect(false.B)

      // Start dispatch — core_reset(0) is initially true, so first block dispatches immediately
      dut.io.start.poke(true.B)
      dut.clock.step()

      // Core 0 should be running block 0
      dut.io.core_start(0).expect(true.B)
      dut.io.core_block_id(0).expect(0.U)
      dut.io.core_thread_count(0).expect(4.U)
      dut.io.done.expect(false.B)

      // Signal core 0 done with block 0
      dut.io.core_done(0).poke(true.B)
      dut.clock.step()
      dut.io.core_done(0).poke(false.B)

      // Core resets, then dispatches block 1
      dut.clock.step()
      dut.io.core_start(0).expect(true.B)
      dut.io.core_block_id(0).expect(1.U)
      dut.io.core_thread_count(0).expect(4.U)
      dut.io.done.expect(false.B)

      // Signal core 0 done with block 1
      dut.io.core_done(0).poke(true.B)
      dut.clock.step()
      dut.io.core_done(0).poke(false.B)
      dut.clock.step()

      // All blocks done
      dut.io.done.expect(true.B)
    }
  }
}
