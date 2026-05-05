package rself

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RegFileTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "RegFile" should "ignore x0 writes and commit non-zero destination writes" in {
    test(new RegFile) { dut =>
      dut.io.reader.raddr1.poke(0.U)
      dut.io.reader.raddr2.poke(0.U)
      dut.io.writer.wen.poke(true.B)
      dut.io.writer.waddr.poke(0.U)
      dut.io.writer.wdata.poke("hdeadbeef".U)
      dut.clock.step()
      dut.io.reader.rdata1.expect(0.U)

      dut.io.writer.waddr.poke(5.U)
      dut.io.writer.wdata.poke("h12345678".U)
      dut.clock.step()

      dut.io.writer.wen.poke(false.B)
      dut.io.reader.raddr1.poke(5.U)
      dut.io.reader.rdata1.expect("h12345678".U)
    }
  }
}
