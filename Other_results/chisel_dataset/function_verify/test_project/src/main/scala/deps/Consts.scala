package cpu

import chisel3._
import chisel3.util._

object Consts {
  val WORD_LEN = 32
  val START_ADDR = 0.U(WORD_LEN.W)
  val BUBBLE = 0x00000013.U(WORD_LEN.W)
  val UNIMP = "x_c0001073".U(WORD_LEN.W)
  val ADDR_LEN = 5
  val CSR_ADDR_LEN = 12
}
