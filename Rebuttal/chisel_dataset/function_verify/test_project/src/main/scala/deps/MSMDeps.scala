package MSM

import chisel3._
import chisel3.util.RegEnable

class ModularInverse(val w: Int) extends Module {
  val io = IO(new Bundle {
    val a =     Input(SInt(w.W))
    val p =     Input(SInt(w.W))
    val load =  Input(Bool())
    val valid = Output(Bool())
    val out =   Output(SInt(w.W))
  })
  val a = RegInit(0.S(w.W))
  val p = RegInit(0.S(w.W))
  val n = RegInit(0.S(w.W))
  val condition = (a * n) % p
  val neg = io.a < 0.S
  when (io.load) {
    a := Mux(neg, -io.a, io.a)
    p := io.p
    n := 0.S
  }
  io.out := Mux(neg, io.p - n, n)
  io.valid := false.B
  when (condition =/= 1.S && n < p) {
    n := n + 1.S
  } .elsewhen (condition === 1.S && n < p) {
    io.valid := true.B
  } .elsewhen (n === p) {
    io.out := -1.S
    io.valid := true.B
  }
}

class PointAddition(val w: Int) extends Module {
  val io = IO(new Bundle {
    val a =     Input(SInt(w.W))
    val p =     Input(SInt(w.W))
    val p1x =   Input(SInt(w.W))
    val p1y =   Input(SInt(w.W))
    val p2x =   Input(SInt(w.W))
    val p2y =   Input(SInt(w.W))
    val load =  Input(Bool())
    val outx =  Output(SInt(w.W))
    val outy =  Output(SInt(w.W))
    val valid = Output(Bool())
  })
  val p1x = RegEnable(io.p1x, 0.S, io.load)
  val p1y = RegEnable(io.p1y, 0.S, io.load)
  val p2x = RegEnable(io.p2x, 0.S, io.load)
  val p2y = RegEnable(io.p2y, 0.S, io.load)
  val modinv = Module(new ModularInverse(w))
  val l = Wire(SInt())
  val new_x = Wire(SInt())
  val new_y = Wire(SInt())
  val validBit = RegEnable(false.B, false.B, io.load)
  validBit := validBit || RegNext(io.load)
  val p1inf = p1x === 0.S && p1y === 0.S
  val p2inf = p2x === 0.S && p2y === 0.S
  val inverses = p1x === p2x && p1y === -p2y
  modinv.io.p := io.p
  modinv.io.load := RegNext(io.load)
  io.outx := 0.S
  io.outy := 0.S
  new_x := 0.S
  new_y := 0.S
  l := 0.S
  when (!p1inf && !p2inf && !inverses) {
    new_x := ((l * l) - p1x - p2x) % io.p
    io.outx := new_x
    when (new_x < 0.S) { io.outx := new_x + io.p }
    new_y := (l * (p1x - new_x) - p1y) % io.p
    io.outy := new_y
    when (new_y < 0.S) { io.outy := new_y + io.p }
  }
  modinv.io.a := p2x - p1x
  when (p1x === p2x && p1y === p2y) {
    new_x := ((l * l) - p1x - p1x) % io.p
    modinv.io.a := 2.S * p1y
    l := (3.S * p1x * p1x + io.a) * modinv.io.out
  } .otherwise {
    l := (p2y - p1y) * modinv.io.out
  }
  io.valid := modinv.io.valid && !io.load && !RegNext(io.load) && validBit
  when (RegNext(inverses)) {
    io.valid := true.B && validBit
    io.outx := 0.S; io.outy := 0.S
  } .elsewhen (RegNext(p1inf)) {
    io.valid := true.B && validBit
    io.outx := p2x; io.outy := p2y
  } .elsewhen (RegNext(p2inf)) {
    io.valid := true.B && validBit
    io.outx := p1x; io.outy := p1y
  } .elsewhen (modinv.io.valid && modinv.io.out === -1.S) {
    io.valid := true.B && validBit
    io.outx := 0.S; io.outy := 0.S
  }
}
