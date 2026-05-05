package final_project

import chisel3._
import chisel3.util._
import chisel3.util.HasBlackBoxInline
import chisel3.ChiselEnum

// NOTE: PackedData, RawData are defined in calc8x8.scala
// BigBankReadData, SmallBankReadData are defined in read_pack.scala
// AccumuRawData is defined in accumu.scala
// DSP48Adder is defined in accumu.scala
// Only define types NOT defined in module files here.

class QuantedData(val w: Int) extends Bundle {
  val mat = Vec(64, SInt(w.W))
}

class TransBundle extends Bundle {
  val valid_in = Input(Bool())
  val valid_out = Output(Bool())
}

// ReadType is defined in read.scala

class ACounter(val w: Int) extends Bundle {
  val ccnt = UInt(w.W)
  val cend = UInt(w.W)
  def set(a: UInt, b: UInt): Unit = { ccnt := a; cend := b }
}
object ACounter {
  def apply(w: Int): ACounter = new ACounter(w)
  def apply(w: chisel3.Width): ACounter = new ACounter(w.get)
}

class RCounter(val w: Int) extends Bundle {
  val ccnt = UInt(w.W)
  val cend = UInt(w.W)
  def set(a: UInt, b: UInt): Unit = { ccnt := a; cend := b }
  def inc(): Bool = { val wrap = ccnt === cend; ccnt := Mux(wrap, 0.U, ccnt + 1.U); wrap }
}
object RCounter {
  def apply(w: Int): RCounter = new RCounter(w)
}

object StdPara {
  val w = 8; val addr_w = 16; val h_w = 8; val c_w = 8; val id_w = 8
  val big_w = 8; val para_num = 1; val weight_addr_w = 16
  val bias_addr_w = 16; val bias_w = 16
}
