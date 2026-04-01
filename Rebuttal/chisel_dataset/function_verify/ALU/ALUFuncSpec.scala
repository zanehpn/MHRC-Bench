package core
import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
class ALUFuncSpec extends AnyFlatSpec with ChiselScalatestTester {
  "ALU" should "perform ADD correctly" in {
    test(new ALU()) { dut =>
      // Test ADD: 10 + 20 = 30
      dut.io.op1.poke(10.U)
      dut.io.op2.poke(20.U)
      dut.io.alu_op.poke(0.U) // ALU_ADD
      dut.clock.step()
      dut.io.out.expect(30.U)

      // Test SUB: 50 - 15 = 35
      dut.io.op1.poke(50.U)
      dut.io.op2.poke(15.U)
      dut.io.alu_op.poke(10.U) // ALU_SUB
      dut.clock.step()
      dut.io.out.expect(35.U)

      // Test XOR: 0xFF ^ 0x0F = 0xF0
      dut.io.op1.poke("hFF".U)
      dut.io.op2.poke("h0F".U)
      dut.io.alu_op.poke(4.U) // ALU_XOR
      dut.clock.step()
      dut.io.out.expect("hF0".U)

      // Test OR: 0xA0 | 0x0B = 0xAB
      dut.io.op1.poke("hA0".U)
      dut.io.op2.poke("h0B".U)
      dut.io.alu_op.poke(6.U) // ALU_OR
      dut.clock.step()
      dut.io.out.expect("hAB".U)

      // Test SLL: 1 << 4 = 16
      dut.io.op1.poke(1.U)
      dut.io.op2.poke(4.U)
      dut.io.alu_op.poke(1.U) // ALU_SLL
      dut.clock.step()
      dut.io.out.expect(16.U)

      // Test SRL: 256 >> 4 = 16
      dut.io.op1.poke(256.U)
      dut.io.op2.poke(4.U)
      dut.io.alu_op.poke(5.U) // ALU_SRL
      dut.clock.step()
      dut.io.out.expect(16.U)

      // Test COPY1: out = op1
      dut.io.op1.poke(42.U)
      dut.io.op2.poke(99.U)
      dut.io.alu_op.poke(8.U) // ALU_COPY1
      dut.clock.step()
      dut.io.out.expect(42.U)

      // Test COPY2: out = op2
      dut.io.op1.poke(42.U)
      dut.io.op2.poke(99.U)
      dut.io.alu_op.poke(9.U) // ALU_COPY2
      dut.clock.step()
      dut.io.out.expect(99.U)

      // Test SEQ (cmp_out): 5 == 5 => true
      dut.io.op1.poke(5.U)
      dut.io.op2.poke(5.U)
      dut.io.alu_op.poke(2.U) // ALU_SEQ
      dut.clock.step()
      dut.io.cmp_out.expect(true.B)

      // Test SNE (cmp_out): 5 != 3 => true
      dut.io.op1.poke(5.U)
      dut.io.op2.poke(3.U)
      dut.io.alu_op.poke(3.U) // ALU_SNE
      dut.clock.step()
      dut.io.cmp_out.expect(true.B)
    }
  }
}
