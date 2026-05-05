// Minimal stubs for freechips.rocketchip types used by icenet modules
package freechips.rocketchip.unittest {
  import chisel3._
  // UnitTest is a trait/class used for test harnesses - we stub it out
  abstract class UnitTest(timeout: Int = 4096) extends Module {
    val io = IO(new Bundle {
      val start = Input(Bool())
      val finished = Output(Bool())
    })
  }
}

package freechips.rocketchip.util {
  import chisel3._
  import chisel3.util._

  object DecoupledHelper {
    def apply(rvs: Bool*) = new DecoupledHelper(rvs)
  }
  class DecoupledHelper(rvs: Seq[Bool]) {
    def fire(exclude: Bool, includes: Bool*): Bool = {
      (rvs.filter(_ ne exclude) ++ includes).reduce(_ && _)
    }
    def fire(): Bool = rvs.reduce(_ && _)
  }

  class HellaPeekingArbiter[T <: Data](gen: T, n: Int) extends Module {
    val io = IO(new Bundle {
      val in = Flipped(Vec(n, Decoupled(gen)))
      val out = Decoupled(gen)
    })
    val arb = Module(new RRArbiter(gen, n))
    for (i <- 0 until n) { arb.io.in(i) <> io.in(i) }
    io.out <> arb.io.out
  }

  object TwoWayCounter {
    def apply(up: Bool, down: Bool, max: Int): UInt = {
      val cnt = RegInit(0.U(chisel3.util.log2Ceil(max + 1).W))
      when(up && !down) { cnt := cnt + 1.U }
      when(down && !up) { cnt := cnt - 1.U }
      cnt
    }
  }

  object LatencyPipe {
    def apply[T <: Data](in: DecoupledIO[T], latency: Int): DecoupledIO[T] = {
      if (latency == 0) return in
      val pipe = Module(new Queue(chiselTypeOf(in.bits), latency, pipe = true))
      pipe.io.enq <> in
      pipe.io.deq
    }
  }

  object UIntIsOneOf {
    implicit class UIntIsOneOfImpl(private val x: UInt) extends AnyVal {
      def isOneOf(s: UInt*): Bool = s.map(_ === x).reduce(_ || _)
    }
  }

}
