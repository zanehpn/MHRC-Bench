package loywong.examples
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class EncoderExampleFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "encoder_example" should "return index of lowest set bit" in {
    test(new encoder_example(4)) { dut =>
      // 16-bit input, 4-bit output
      // PriorityEncoder returns index of lowest set bit

      dut.io.in.poke("b0000000000000001".U)
      dut.io.out.expect(0.U)

      dut.io.in.poke("b0000000000001000".U)
      dut.io.out.expect(3.U)

      // Bits 2 and 5 set -> lowest is 2
      dut.io.in.poke("b0000000000100100".U)
      dut.io.out.expect(2.U)

      dut.io.in.poke("b0000000110000000".U)
      dut.io.out.expect(7.U)

      dut.io.in.poke("b1000000000000000".U)
      dut.io.out.expect(15.U)
    }
  }
}
