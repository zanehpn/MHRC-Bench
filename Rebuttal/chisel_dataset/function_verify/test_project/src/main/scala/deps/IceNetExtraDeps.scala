package icenet

import chisel3._
import chisel3.util._
import IceNetConsts._
import freechips.rocketchip.util.HellaPeekingArbiter

object NetworkHelpers {
  def reverse_bytes(a: UInt, n: Int) = {
    val bytes = (0 until n).map(i => a((i + 1) * 8 - 1, i * 8))
    Cat(bytes)
  }

  def ntohl(a: UInt) = reverse_bytes(a, 4)
  def htons(a: UInt) = reverse_bytes(a, 2)
  def ntohs(a: UInt) = reverse_bytes(a, 2)
}


class EthernetHeader extends Bundle {
  val ethType = UInt(ETH_TYPE_BITS.W)
  val srcmac  = UInt(ETH_MAC_BITS.W)
  val dstmac  = UInt(ETH_MAC_BITS.W)
  val padding = UInt(ETH_PAD_BITS.W)

  def toWords(w: Int = NET_IF_WIDTH) =
    this.asTypeOf(Vec(ETH_HEAD_BYTES * 8 / w, UInt(w.W)))
}

object EthernetHeader {
  def apply(dstmac: UInt, srcmac: UInt, ethType: UInt) = {
    val header = Wire(new EthernetHeader)
    header.dstmac := dstmac
    header.srcmac := srcmac
    header.ethType := ethType
    header.padding := DontCare
    header
  }

  def apply(words: Seq[UInt], w: Int = NET_IF_WIDTH) = {
    val headerWords = ETH_HEAD_BYTES * 8 / w
    Cat(words.take(headerWords).reverse).asTypeOf(new EthernetHeader)
  }
}

class PacketArbiter(arbN: Int, rr: Boolean = false)
  extends HellaPeekingArbiter(
    new StreamChannel(NET_IF_WIDTH), arbN)
