# Function Verify Status

## Summary

- Manifest processed: `design_function_verify_candidates_50.jsonl` (50 rows).
- Added DUT-including target testbenches for 21 folders.
- Added explicit `BLOCKER.md` notes for 29 folders where a credible isolated DUT harness would require heavyweight vendor semantics, SystemC, or larger project reconstruction.
- Updated manifest rows with `local_testbench` and `testbench_kind`.

## Generated DUT Testbenches

- `conv2/conv2_target_tb.cpp`
- `norm2/norm2_target_tb.cpp`
- `conv4/conv4_target_tb.cpp`
- `conv5/conv5_target_tb.cpp`
- `spmv/spmv_target_tb.cpp`
- `spmv_fast_stream/spmv_fast_stream_target_tb.cpp`
- `spmv_naive_stream/spmv_naive_stream_target_tb.cpp`
- `spmv_partial_unrolling/spmv_partial_unrolling_target_tb.cpp`
- `Entry/Entry_target_tb.cpp`
- `dsp_pipeline/dsp_pipeline_target_tb.cpp`
- `Example1/Example1_target_tb.cpp`
- `Example3_Time/Example3_Time_target_tb.cpp`
- `Example5/Example5_target_tb.cpp`
- `conv/conv_target_tb.cpp`
- `HLS_MAC_accel/HLS_MAC_accel_target_tb.cpp`
- `lock_free_SPSCq/lock_free_SPSCq_target_tb.cpp`
- `doHiststretch/doHiststretch_target_tb.cpp`
- `doHist/doHist_target_tb.cpp`
- `dense/dense_target_tb.cpp`
- `flat/flat_target_tb.cpp`
- `bubble_sort/bubble_sort_target_tb.cpp`

## Added Local Support

- Shared lightweight headers under `_support/`: `hls_stream.h`, `hls_math.h`, `ap_fixed.h`, `ap_int.h`, `ap_axi_sdata.h`, `mc_scverify.h`.
- Local header shims were added next to DUTs where needed so each generated testbench can include the copied DUT directly.
- Added deterministic local CNN support headers under `03-Headers/` for `definitions.h`, `conv_weights.h`, and `dense_weights.h`.

## Blocked Candidates

- `K_add`, `K_mulWise`, `mod`, `K_ntt`
  Reason: encrypted-computing kernels need faithful arbitrary-width modular arithmetic semantics.
- `forward-unrolling`, `forward-min-area`, `forward`, `llama2`
  Reason: multiple mutated model/config headers and large transformer context.
- `execute`, `fedec`, `memwb`, `hl5_datatypes`
  Reason: SystemC/Stratus-style `hl5` environment required.
- `regionizer_ref`, `regionizer`, `simple_vtx_ref`, `simple_fullpfalgo`
  Reason: GlobalCorrelator firmware types and multi-file HLS context required.
- `present_1`, `present_2`, `aes`, `serpent`
  Reason: crypto code depends on real bit-slice arbitrary-width integer behavior.
- `core_1`, `core_2`
  Reason: Vivado-HLS/OpenCV image container context missing.
- `tsqr_df`
  Reason: fixed-point/HLS numeric stack required for credible validation.
- `rf_doppler_spoof_engine`
  Reason: mixed AXI, ap_uint bit operations, and ap_fixed numerics exceed the lightweight local support.
- `cnn`
  Reason: top-level integration depends on several sibling kernels and mutated headers.
- `main_1`
  Reason: missing project headers and larger application model context.
- `ppu`, `registers`, `main_2`
  Reason: NES emulator translation units depend on shared global state and companion modules.

Each blocked folder has a local `BLOCKER.md`.

## Verification

Lightweight compile checks were attempted with:

```bash
g++ -std=c++17 -I hls_dataset/function_verify/_support -I hls/Fast-Float4HLS <tb> -o /tmp/<name>.out
```

### Compile Checks Reached the Copied DUT and Failed at the Injected Target Hole

These 20 DUT-including testbenches compiled far enough to enter the copied DUT translation unit, then failed on the literal `<TARGET>` marker inside the DUT source:

- `conv2`
- `norm2`
- `conv4`
- `conv5`
- `spmv`
- `spmv_fast_stream`
- `spmv_naive_stream`
- `spmv_partial_unrolling`
- `Entry`
- `dsp_pipeline`
- `Example1`
- `Example3_Time`
- `Example5`
- `conv`
- `HLS_MAC_accel`
- `lock_free_SPSCq`
- `doHiststretch`
- `doHist`
- `dense`
- `flat`

### Compile Blocked by External Toolchain Dependency

- `bubble_sort`
  Result: compile stopped in `fast_float.h` because `ac_fixed.h` is unavailable in the current environment.

## Notes

- The generated testbenches are intentionally target-focused and call/include the copied DUT from each folder instead of relying on snippet-only checks.
- Several DUT sources in this dataset are syntactically incomplete because they still contain literal `<TARGET>` holes; the compile failures above confirm the benches are wired to the real copied DUTs.
