package icenet

import chisel3._
import chisel3.util._
import IceNetConsts.NET_IF_WIDTH

class TraceROM extends BlackBox with HasBlackBoxResource{
<TARGET>  addResource("/csrc/TraceROM.cc")
}
