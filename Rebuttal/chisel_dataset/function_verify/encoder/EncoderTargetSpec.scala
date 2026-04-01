package loywong.examples

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class EncoderTargetSpec extends AnyFlatSpec with ChiselScalatestTester {
  "encoder_example" should "drive PriorityEncoder output" in {
    test(new encoder_example(4)) { dut =>
      dut.io.in.poke("b00010010".U)
      dut.io.out.expect(1.U)

      dut.io.in.poke("b10010000".U)
      dut.io.out.expect(4.U)
    }
  }
}
