package aha

import scala.math._
import chisel3._
import chisel3.util._

package object dma {
  val MAX_BURST_BYTES  = 4096
  val MAX_BURST_LENGTH = 256

  class CmdBundle(AddrWidth: Int) extends Bundle {
    val NumBytes = UInt(clog2(MAX_BURST_BYTES).W)
    val Address  = UInt(AddrWidth.W)
  }

  class TransBundle(AddrWidth: Int) extends Bundle {
    val NumBytes = UInt(32.W)
    val Address  = UInt(AddrWidth.W)
  }

  def clog2(x: Int): Int = { require(x >= 0); ceil(log(x)/log(2)).toInt }
  def log2(x: Int): Int  = { require(x >= 0); (log(x)/log(2)).toInt }
}
