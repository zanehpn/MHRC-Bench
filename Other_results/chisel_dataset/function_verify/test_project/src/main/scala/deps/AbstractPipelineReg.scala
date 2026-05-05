package asyncqueue.modules

import chisel3._

abstract class AbstractPipelineReg(w: Int = 1) extends Module {
  val io = IO(new Bundle {
    val d = Input(UInt(w.W))
    val q = Output(UInt(w.W))
  })
}

object AbstractPipelineReg {
  def apply [T <: Data](gen: => AbstractPipelineReg, in: T, name: Option[String] = None): T = {
    val chain = Module(gen)
    name.foreach{ chain.suggestName(_) }
    chain.io.d := in.asUInt
    chain.io.q.asTypeOf(in)
  }
}
