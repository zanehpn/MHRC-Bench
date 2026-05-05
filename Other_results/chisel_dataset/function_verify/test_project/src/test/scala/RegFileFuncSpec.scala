package rself
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RegFileFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "RegFile" should "write and read back data" in {
    test(new RegFile()) { dut =>
      // Write 0xDEADBEEF to register 5
      dut.io.writer.wen.poke(true.B)
      dut.io.writer.waddr.poke(5.U)
      dut.io.writer.wdata.poke("hDEADBEEF".U)
      dut.clock.step(1)
      dut.io.writer.wen.poke(false.B)

      // Read from register 5
      dut.io.reader.raddr1.poke(5.U)
      dut.io.reader.rdata1.expect("hDEADBEEF".U)
    }
  }

  it should "keep x0 as zero even when written" in {
    test(new RegFile()) { dut =>
      // Attempt to write to register 0
      dut.io.writer.wen.poke(true.B)
      dut.io.writer.waddr.poke(0.U)
      dut.io.writer.wdata.poke(42.U)
      dut.clock.step(1)
      dut.io.writer.wen.poke(false.B)

      // Read from register 0 should return 0
      dut.io.reader.raddr1.poke(0.U)
      dut.io.reader.rdata1.expect(0.U)
    }
  }

  it should "read two different registers simultaneously" in {
    test(new RegFile()) { dut =>
      dut.io.writer.wen.poke(true.B)
      dut.io.writer.waddr.poke(1.U)
      dut.io.writer.wdata.poke(100.U)
      dut.clock.step(1)
      dut.io.writer.waddr.poke(2.U)
      dut.io.writer.wdata.poke(200.U)
      dut.clock.step(1)
      dut.io.writer.wen.poke(false.B)

      dut.io.reader.raddr1.poke(1.U)
      dut.io.reader.raddr2.poke(2.U)
      dut.io.reader.rdata1.expect(100.U)
      dut.io.reader.rdata2.expect(200.U)
    }
  }
}
