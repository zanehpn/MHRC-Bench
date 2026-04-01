# Function Verify Status

- Manifest rows processed: 50
- Real local testbenches added: 18
- Blocker notes added: 32
- Verification actually run: filesystem coverage checks and static sanity checks on the new spec files.
- Verification blocked: no `sbt`, `mill`, `scala`, or `scalac` is installed in this environment, so no Scala compile or chiseltest run was possible here.

## Added Testbenches

- `accumulator/AccumulatorTargetSpec.scala`
- `counter/CounterTargetSpec.scala`
- `Bitmap/BitmapTargetSpec.scala`
- `RegFile/RegFileTargetSpec.scala`
- `encoder/EncoderTargetSpec.scala`
- `MaxN/MaxNTargetSpec.scala`
- `Plane/PlaneTargetSpec.scala`
- `GCD/GCDTargetSpec.scala`
- `Memory/MemoryTargetSpec.scala`
- `Counter/CounterTargetSpec.scala`
- `PWM/PWMTargetSpec.scala`
- `DecoupledGCD/DecoupledGCDTargetSpec.scala`
- `DeviceControlRegister/DeviceControlRegisterTargetSpec.scala`
- `Fetcher/FetcherTargetSpec.scala`
- `MemLoadStoreUnit/MemLoadStoreUnitTargetSpec.scala`
- `ReductionMux/ReductionMuxTargetSpec.scala`
- `Scheduler/SchedulerTargetSpec.scala`
- `Controller/ControllerTargetSpec.scala`

## Blocked Candidates

- `maxpool`: see `maxpool/BLOCKER.md`.
- `show_on_board`: see `show_on_board/BLOCKER.md`.
- `wrapper`: see `wrapper/BLOCKER.md`.
- `read`: see `read/BLOCKER.md`.
- `MultSwitch`: see `MultSwitch/BLOCKER.md`.
- `Regor`: see `Regor/BLOCKER.md`.
- `PMNaive`: see `PMNaive/BLOCKER.md`.
- `AdderSwitch`: see `AdderSwitch/BLOCKER.md`.
- `APLIC`: see `APLIC/BLOCKER.md`.
- `PAddReduction`: see `PAddReduction/BLOCKER.md`.
- `MasterModule`: see `MasterModule/BLOCKER.md`.
- `CSR`: see `CSR/BLOCKER.md`.
- `Datapath`: see `Datapath/BLOCKER.md`.
- `ArpCache`: see `ArpCache/BLOCKER.md`.
- `Bucket`: see `Bucket/BLOCKER.md`.
- `Top`: see `Top/BLOCKER.md`.
- `csr`: see `csr/BLOCKER.md`.
- `DMem`: see `DMem/BLOCKER.md`.
- `IMem`: see `IMem/BLOCKER.md`.
- `Example-axi`: see `Example-axi/BLOCKER.md`.
- `Example`: see `Example/BLOCKER.md`.
- `AsyncQueue`: see `AsyncQueue/BLOCKER.md`.
- `IMSIC`: see `IMSIC/BLOCKER.md`.
- `SynchronizerReg`: see `SynchronizerReg/BLOCKER.md`.
- `accumu`: see `accumu/BLOCKER.md`.
- `FanCtrl`: see `FanCtrl/BLOCKER.md`.
- `FanNetwork`: see `FanNetwork/BLOCKER.md`.
- `calc8x8`: see `calc8x8/BLOCKER.md`.
- `read_pack`: see `read_pack/BLOCKER.md`.
- `Benes`: see `Benes/BLOCKER.md`.
- `common`: see `common/BLOCKER.md`.
- `Core`: see `Core/BLOCKER.md`.

## Static Checks

- Confirmed every manifest folder now contains either a `*Spec.scala` testbench or a `BLOCKER.md` note.
- Confirmed `spec_count = 18` and `blocker_count = 32`.
- Checked newly added specs for a basic `chisel3._` import when Chisel literals are used.
