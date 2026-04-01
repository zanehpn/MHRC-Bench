package router

import chisel3._
import chisel3.util._
import chisel3.experimental.BundleLiterals._

class WrapBits(w: Int) extends Bundle {
  val bits = Bits(w.W)
  def ===(that: WrapBits) = bits === that.bits
  def =/=(that: WrapBits) = bits =/= that.bits
}

class MacAddr extends WrapBits(48)

object MacAddr {
  def apply(s: String) =
    (new MacAddr).Lit(_.bits -> ("h" + s.replace(":", "")).U)
  val BROADCAST = MacAddr("ff:ff:ff:ff:ff:ff")
}

class Ipv4Addr extends WrapBits(32) {
  def &(that: Ipv4Addr) = (bits & that.bits).asTypeOf(new Ipv4Addr)
}

object Ipv4Addr {
  def apply(s: String) =
    (new Ipv4Addr).Lit(
      _.bits -> ("h" + s.split("\\.").map(d => f"${d.toInt}%02x").mkString).U
    )
  val LOCALHOST = Ipv4Addr("127.0.0.1")
}
