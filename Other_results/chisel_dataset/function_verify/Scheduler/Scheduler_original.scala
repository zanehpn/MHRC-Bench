package scheduler
import chisel3._
import chisel3.util._
import statecode.CoreState
import statecode.LSUState
import statecode.FetcherState
class Scheduler(ThreadsPerBlock: Int = 4) extends Module {
  val io = IO(new Bundle {
    val start = Input(Bool())
    val mem_rw_enable = new Bundle { val read_enable = Input(Bool()); val write_enable = Input(Bool()) }
    val decoded_ret = Input(Bool())
    val fetcher_state = Input(FetcherState())
    val lsu_state = Input(Vec(ThreadsPerBlock, LSUState()))
    val current_pc = Output(UInt(8.W))
    val next_pc = Input(Vec(ThreadsPerBlock, UInt(8.W)))
    val core_state = Output(CoreState())
    val done = Output(Bool())
  })
  val current_pc = RegInit(0.U(8.W)); val core_state = RegInit(CoreState.IDLE); val done = RegInit(false.B)
  when(!reset.asBool) {
    switch(core_state) {
      is(CoreState.IDLE) { when(io.start) { core_state := CoreState.FETCH } }
      is(CoreState.FETCH) { when(io.fetcher_state === FetcherState.FETCHED) { core_state := CoreState.DECODE } }
      is(CoreState.DECODE) { core_state := CoreState.REQUEST }
      is(CoreState.REQUEST) { core_state := CoreState.WAIT }
      is(CoreState.WAIT) {
        val w = io.lsu_state.exists(s => s === LSUState.WAITING || s === LSUState.REQUESTING)
        when(!w) { core_state := CoreState.EXECUTE }
      }
      is(CoreState.EXECUTE) { core_state := CoreState.UPDATE }
      is(CoreState.UPDATE) {
        when(io.decoded_ret) { done := true.B; core_state := CoreState.DONE }
          .otherwise { current_pc := io.next_pc((ThreadsPerBlock-1).U); core_state := CoreState.FETCH }
      }
      is(CoreState.DONE) {}
    }
  }
  io.current_pc := current_pc; io.core_state := core_state; io.done := done
}
