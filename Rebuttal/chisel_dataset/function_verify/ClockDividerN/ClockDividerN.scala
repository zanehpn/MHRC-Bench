// See LICENSE for license details.

package chipyard.clocking

import chisel3._
import chisel3.util._

class ClockDividerN(div: Int) extends BlackBox(Map("DIV" -> div)) with HasBlackBoxResource {
  require(div > 0);
  val io = IO(new Bundle {
    val clk_out = Output(Clock())
    val clk_in  = Input(Clock())
  })
  addResource("/vsrc/ClockDividerN.sv")
}

object ClockDivideByN {
<TARGET>