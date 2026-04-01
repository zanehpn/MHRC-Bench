package final_project

import chisel3._
import chisel3.util._

// Stubs for read module deps
class AddressReadGroup(val addr_w: Int, val cnt: Int) extends Bundle {
  val addr = Vec(cnt, UInt(addr_w.W))
  val valid = Vec(cnt, Bool())
}

class ReadJobs(val addr_w: Int, val h_w: Int, val c_w: Int, val id_w: Int, val big_w: Int) extends Bundle {
  val dummy = UInt(1.W)
}

// Stub for read_pack deps  
class PackJob(val w: Int, val h_w: Int, val c_w: Int, val big_w: Int) extends Bundle {
  val dummy = UInt(1.W)
}

// Types normally defined in calc8x8.scala
class PackedData(val w: Int) extends Bundle {
  val mat = Vec(64, SInt(w.W))
  val up = Vec(10, SInt(w.W))
  val down = Vec(10, SInt(w.W))
  val left = Vec(8, SInt(w.W))
  val right = Vec(8, SInt(w.W))
}
class RawData(val w: Int) extends Bundle {
  val mat = Vec(64, SInt((w*2+4).W))
}

class BigBankReadData(val w: Int) extends Bundle {
  val data = Vec(48, SInt(w.W))
}
class SmallBankReadData(val w: Int) extends Bundle {
  val data = Vec(8, SInt(w.W))
}
