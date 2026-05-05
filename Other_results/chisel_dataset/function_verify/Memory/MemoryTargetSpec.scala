package cpu
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class MemoryTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  private val imagePath = "/ssd1/zqy/Multi-hdl-language-repo/chisel_dataset/function_verify/Memory/memory_test.hex"
  "Memory" should "assemble dmem reads from stored bytes" in {
    test(new Memory(imagePath)) { dut =>
      dut.io.imem.addr.poke(0.U)
      dut.io.dmem.addr.poke(4.U)
      dut.io.dmem.wdata.poke("haabbccdd".U)
      dut.io.dmem.wen.poke(true.B)
      dut.clock.step()
      dut.io.dmem.wen.poke(false.B)
      // Original has 3-byte Cat: Cat(mem(addr+3), mem(addr+1), mem(addr)) = 0xAACCDD
      dut.io.dmem.rdata.expect("haaccdd".U)
    }
  }
}
