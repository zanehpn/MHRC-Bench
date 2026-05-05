package bus

import chisel3._

class AddressChannel extends Bundle {
  val addr: UInt = Output(UInt(32.W))
}

class DataChannel extends Bundle {
  val req: Bool = Input(Bool())
  val ack: Bool = Output(Bool())
  val data: UInt = Output(UInt(32.W))
}

class wDataChannel extends Bundle {
  val req: Bool = Output(Bool())
  val ack: Bool = Input(Bool())
  val data: UInt = Output(UInt(32.W))
  val byteenable: UInt = Output(UInt(4.W))
}

class SlaveIf_Inst extends Bundle {
  val imem_add: AddressChannel = Flipped(new AddressChannel)
  val r_imem_dat: DataChannel = new DataChannel
  val w_imem_dat: wDataChannel = Flipped(new wDataChannel)
}

class SlaveIf_Data extends Bundle {
  val dmem_add: AddressChannel = Flipped(new AddressChannel)
  val r_dmem_dat: DataChannel = new DataChannel
  val w_dmem_dat: wDataChannel = Flipped(new wDataChannel)
}
