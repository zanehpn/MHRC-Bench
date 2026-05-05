package icenet
import chisel3._
import chisel3.util._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

// Wrapper module that calls RateLimiter.apply with period<=1 to trigger
// the TARGET else branch: `} else { in }` (bypass, no RateLimiter module).
class RateLimiterBypassWrapper extends Module {
  val io = IO(new Bundle {
    val in = Flipped(Decoupled(UInt(8.W)))
    val out = Decoupled(UInt(8.W))
  })

  // period=1 triggers the else branch: the apply just returns `in` directly
  // (no RateLimiter module is instantiated)
  val result = RateLimiter(io.in, inc = 1, period = 1, size = 4)
  io.out <> result
}

class LimiterFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "RateLimiter.apply with period<=1" should "bypass directly (else branch)" in {
    test(new RateLimiterBypassWrapper()) { dut =>
      // With the bypass, input connects directly to output with no rate limiting.
      // Data should pass through immediately without any token-based throttling.

      // Set up a transaction
      dut.io.in.valid.poke(true.B)
      dut.io.in.bits.poke(42.U)
      dut.io.out.ready.poke(true.B)

      // In bypass mode, output should directly reflect input
      dut.io.out.valid.expect(true.B, "output valid should match input valid in bypass mode")
      dut.io.out.bits.expect(42.U, "output bits should match input bits in bypass mode")
      dut.io.in.ready.expect(true.B, "input ready should match output ready in bypass mode")

      // Change data - should reflect immediately (no pipeline delay)
      dut.io.in.bits.poke(99.U)
      dut.io.out.bits.expect(99.U, "changed data should appear immediately in bypass")

      // Deassert ready - should propagate to input
      dut.io.out.ready.poke(false.B)
      dut.io.in.ready.expect(false.B, "backpressure should propagate in bypass mode")

      // Deassert valid
      dut.io.in.valid.poke(false.B)
      dut.io.out.valid.expect(false.B, "invalid should propagate in bypass mode")

      // Multiple cycles - data always passes through without throttling
      dut.io.out.ready.poke(true.B)
      dut.io.in.valid.poke(true.B)
      for (v <- 0 until 10) {
        dut.io.in.bits.poke(v.U)
        dut.io.out.bits.expect(v.U, s"value $v should pass through immediately")
        dut.io.out.valid.expect(true.B)
        dut.io.in.ready.expect(true.B)
        dut.clock.step(1)
      }
    }
  }

  "RateLimiter with period>1" should "rate-limit data flow" in {
    // This test verifies the non-bypass path for comparison
    test(new RateLimiter(UInt(8.W))) { dut =>
      // Set up rate limiter: inc=1, period=3 (so counter counts 3->2->1->0->3...),
      // size=2 (max 2 tokens)
      dut.io.settings.inc.poke(1.U)
      dut.io.settings.period.poke(3.U)
      dut.io.settings.size.poke(2.U)

      dut.io.in.valid.poke(true.B)
      dut.io.in.bits.poke(55.U)
      dut.io.out.ready.poke(true.B)

      // Initially tokens=0, so ok_to_send=false, output should not be valid
      dut.io.out.valid.expect(false.B, "initially no tokens, output should be invalid")

      // Step until tokens accumulate (counter reaches 0 triggers inc)
      // counter starts at 0, so first cycle: counter=0 -> inc_trigger=true, tokens 0+1=1
      dut.clock.step(1)

      // Now tokens=1, ok_to_send=true
      dut.io.out.valid.expect(true.B, "after token added, output should be valid")
      dut.io.out.bits.expect(55.U)
    }
  }
}
