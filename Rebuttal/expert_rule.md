# Expert-Defined Rule-Based Classification Rules

This document describes the deterministic, expert-defined rules used to classify HDL code snippets into 9 semantic categories. Each rule inspects the **groundtruth** (code completion content) and **nearby context** (last 400 chars of left context + first 400 chars of right context) using regex pattern matching.

Classification is performed per-language with a priority-ordered rule chain: the **first matching rule** determines the category. Each rule also produces a subcategory, a confidence score (0.50–0.90), and a human-readable reason.

---

## Overview: 9 Semantic Categories

| # | Category | Description |
|---|----------|-------------|
| 1 | Property and Assertion Specification | Assertions, properties, assumptions, coverage |
| 2 | Monitoring and Checking Logic | Signal monitoring, error reporting, scoreboarding |
| 3 | Testbench Stimulus and Environment | Stimulus generation, test scenarios, DUT harness |
| 4 | Design Structure | Module/entity definitions, packages, parameterization |
| 5 | Interface | Port definitions, protocol interfaces, handshake, connections |
| 6 | Storage Block | Registers, memory arrays, FIFOs, state encoding |
| 7 | Control Flow Block | Conditionals, state machines, loops, sequential control |
| 8 | Declaration and Definition | Signals, types, parameters, function signatures |
| 9 | Computation Block | Arithmetic, bit manipulation, mux/selection, type casting |

> **Note:** A 10th category "Design Issues" exists for edge cases (e.g., TODO/FIXME comments) but is rarely triggered.

---

## SystemVerilog Rules

Rules are applied in priority order. The first match wins.

### Priority 1 — Property and Assertion Specification

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R1 | `assert property`, `cover property`, `assume property` | — | Assertion Definition | 0.90 |
| SV-R2 | `property <name>` + `endproperty` | — | Assertion Definition | 0.85 |
| SV-R3 | `property <name>` | `assert property` in near context | Assertion Definition | 0.80 |

### Priority 2 — Monitoring and Checking Logic

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R4 | `` `define `` or `` `ASSERT `` + `$display/$error/$warning/$fatal` | — | Error Reporting and Logging | 0.85 |
| SV-R5 | `$display/$error/$warning/$fatal/$info/$write/$monitor/$fwrite` (≥2 matches or not in `initial` context) | Not inside `initial` block | Error Reporting and Logging | 0.75 |

### Priority 3 — Testbench Stimulus and Environment

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R6 | `extends uvm_test/env/agent/driver/monitor/scoreboard/subscriber` | — | Environment and Harness Construction | 0.90 |
| SV-R7 | `extends uvm_sequence` | — | Test Scenario and Sequencing | 0.90 |
| SV-R8 | `uvm_config_db` | — | Environment and Harness Construction | 0.85 |
| SV-R9 | `initial` + (`clk`/`clock` assignment, `forever`, `#delay`, `$finish`, `$stop`) | — | Stimulus Generation | 0.85 |
| SV-R10 | `initial` (standalone) | — | Stimulus Generation | 0.70 |
| SV-R11 | `#<delay>` appears ≥2 times | Not in `always` block | Stimulus Generation | 0.75 |
| SV-R12 | `$finish` or `$stop` | — | Stimulus Generation | 0.70 |
| SV-R13 | `dut`/`uut` + `.<port>(<signal>)` | — | Environment and Harness Construction | 0.80 |
| SV-R14 | `wait(...)` | `initial`/`$finish` in near context | Test Scenario and Sequencing | 0.75 |
| SV-R15 | `clocking` + `endclocking` | — | Environment and Harness Construction | 0.80 |
| SV-R16 | `forever` | — | Stimulus Generation | 0.75 |

### Priority 4 — Design Structure

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R17 | `module <name>` | — | Top-level Structure | 0.85 |
| SV-R18 | `endmodule` | — | Top-level Structure | 0.80 |
| SV-R19 | `package <name>` or `endpackage` | — | Package and Namespace Definition | 0.85 |
| SV-R20 | `import <pkg>::` or `` `include `` | No `always`/`initial`/`assign` | Package and Namespace Definition | 0.75 |

### Priority 5 — Interface

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R21 | `input`/`output`/`inout` declarations (≥1) | No `always`/`initial`/`if`/`case` | Port Definition | 0.85 |
| SV-R22 | `uvm_*_port/imp/export` | — | Port Definition | 0.85 |
| SV-R23 | `.<port>(<signal>)` pattern (≥2) | No `always`/`initial`/`input`/`output` | Component and Module Connection | 0.80 |
| SV-R24 | `valid` + `ready` signal assignments | — | Handshake and Flow Control | 0.80 |
| SV-R25 | AXI handshake signals (`tvalid`/`tready`/`awvalid`/...) | With assignment | Handshake and Flow Control | 0.80 |

### Priority 6 — Storage Block

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R26 | `always_ff @(...)` + `memory[`/`mem[`/`ram[` | — | Memory and Array Storage | 0.85 |
| SV-R27 | `always_ff @(...)` | — | Register-based Storage | 0.85 |
| SV-R28 | `always @(posedge ...)` + `<=` + `memory/mem/ram[` | — | Memory and Array Storage | 0.80 |
| SV-R29 | `always @(posedge ...)` + `<=` | — | Register-based Storage | 0.80 |
| SV-R30 | `memory[`/`mem[`/`ram[` + `<=` | — | Memory and Array Storage | 0.75 |

### Priority 7 — Control Flow Block

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R31 | `case` + `state`/`STATE_` or `next_state` in near context | — | State-machine Control | 0.85 |
| SV-R32 | `case` (general) | — | State-machine Control | 0.75 |
| SV-R33 | `next_*state` assignment | — | State-machine Control | 0.85 |
| SV-R34 | `STATE_*` constants (≥2) | — | State-machine Control | 0.80 |
| SV-R35 | `if(...)` in `always_comb` or `always @(*)` | — | Conditional Control | 0.75 |

### Priority 8 — Declaration and Definition

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R36 | `parameter` or `localparam` | — | Parameter and Generic Definition | 0.85 |
| SV-R37 | `` `define `` or `` `timescale `` | — | Parameter and Generic Definition | 0.85 |
| SV-R38 | `function`/`endfunction`/`task`/`endtask` | — | Function and Procedure Signature | 0.80 |
| SV-R39 | `typedef` | — | Type Definition | 0.80 |
| SV-R40 | `wire`/`logic`/`reg` declaration | No `input`/`output`/`always`/`initial` | Signal and Wire Declaration | 0.75 |

### Priority 9 — Computation Block

| Rule ID | Pattern (in groundtruth) | Context Check | Subcategory | Confidence |
|---------|--------------------------|---------------|-------------|------------|
| SV-R41 | `assign` + bit ops (`{}`, `[n:m]`, `<<`/`>>`, `^`/`~`/`\|`/`&`) | — | Bit-level Manipulation | 0.80 |
| SV-R42 | `assign` + arithmetic (`+`/`-`/`*`/`/`/`%`) | — | Bit-level Manipulation | 0.75 |
| SV-R43 | `assign` (general) | — | Bit-level Manipulation | 0.65 |
| SV-R44 | `{..., ...}` + `[n:m]` | — | Bit-level Manipulation | 0.70 |

### Fallback Rules (SV)

| Rule ID | Condition | Category | Confidence |
|---------|-----------|----------|------------|
| SV-F1 | `<=` in `always_ff`/`posedge` context | Storage Block | 0.60 |
| SV-F2 | Ternary `? :` | Computation Block | 0.65 |
| SV-F3 | `begin` + `if` | Control Flow Block | 0.60 |
| SV-F4 | `uvm_*` macro | Testbench Stimulus | 0.65 |
| SV-F5 | `<=` (non-blocking, no other match) | Storage Block | 0.55 |
| SV-F6 | Near `initial`/`$finish` | Testbench Stimulus | 0.60 |
| SV-F7 | Near `always` | Control Flow Block | 0.60 |
| SV-F8 | No match | Declaration and Definition | 0.50 |

---

## VHDL Rules

### Priority 1 — Testbench / Monitoring

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R1 | `wait for` | Stimulus Generation | 0.85 |
| VH-R2 | `wait until` | Stimulus Generation | 0.80 |
| VH-R3 | `assert` + `report` | Error Reporting and Logging | 0.85 |
| VH-R4 | `report "..."` | Error Reporting and Logging | 0.75 |
| VH-R5 | `assert` + `severity` | Error Reporting and Logging | 0.80 |

### Priority 2 — Design Structure

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R6 | `entity <name> is` | Top-level Structure | 0.90 |
| VH-R7 | `architecture <name> of` | Top-level Structure | 0.90 |
| VH-R8 | `end entity`/`end architecture` | Top-level Structure | 0.80 |
| VH-R9 | `package <name> is` or `package body` | Package and Namespace Definition | 0.85 |
| VH-R10 | `library` + `use` | Package and Namespace Definition | 0.80 |
| VH-R11 | `generic(` | Parameterization and Configuration | 0.80 |
| VH-R12 | `generate` | Hierarchical Composition | 0.80 |

### Priority 3 — Interface

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R13 | `port map` | Component and Module Connection | 0.85 |
| VH-R14 | `generic map` | Component and Module Connection | 0.80 |
| VH-R15 | `component <name>` | Component and Module Connection | 0.75 |
| VH-R16 | `: in/out/inout/buffer std_logic/unsigned/signed/integer/...` | Port Definition | 0.85 |
| VH-R17 | `port(` | Port Definition | 0.80 |
| VH-R18 | `axi`/`wishbone`/`amba`/`avalon` + direction or assignment | Protocol-based Interface | 0.75 |

### Priority 4 — Storage Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R19 | `rising_edge()`/`falling_edge()`/`'event and` | Register-based Storage | 0.85 |
| VH-R20 | `process` + `clk`/`clock` + `<=` | Register-based Storage | 0.80 |

### Priority 5 — Control Flow Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R21 | `case ... is` | Conditional Control | 0.80 |
| VH-R22 | `process` + `if ... then` | Conditional Control | 0.75 |
| VH-R23 | `if ... then` in `process` context | Conditional Control | 0.70 |

### Priority 6 — Computation Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R24 | `with ... select` | Mux and Selection Logic | 0.85 |
| VH-R25 | `<= ... when ... else` | Mux and Selection Logic | 0.80 |
| VH-R26 | `<= ... when` | Mux and Selection Logic | 0.75 |
| VH-R27 | `<=` + arithmetic (`+`/`-`/`*`) | Arithmetic Computation | 0.75 |
| VH-R28 | `to_unsigned`/`to_signed`/`to_integer`/`std_logic_vector()` | Type Casting and Conversion | 0.75 |
| VH-R29 | `sll`/`srl`/`sla`/`sra`/`rol`/`ror` | Bit-level Manipulation | 0.75 |

### Priority 7 — Declaration and Definition

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| VH-R30 | `signal <name>` | Signal and Wire Declaration | 0.85 |
| VH-R31 | `variable <name>` | Signal and Wire Declaration | 0.80 |
| VH-R32 | `constant <name>` | Parameter and Generic Definition | 0.80 |
| VH-R33 | `type <name> is` | Type Definition | 0.85 |
| VH-R34 | `subtype <name>` | Type Definition | 0.80 |

### Fallback Rules (VHDL)

| Rule ID | Condition | Category | Confidence |
|---------|-----------|----------|------------|
| VH-F1 | `<=` in clocked `process` context | Storage Block | 0.60 |
| VH-F2 | `<=` in combinational `process` context | Control Flow Block | 0.60 |
| VH-F3 | `elsif`/`else` in `process` | Control Flow Block | 0.65 |
| VH-F4 | `end if`/`end process`/`end case` | Control Flow Block | 0.60 |
| VH-F5 | `when ... =>` in `case` context | Control Flow Block | 0.65 |
| VH-F6 | `:=` in `process` | Control Flow Block | 0.60 |
| VH-F7 | `: in/out` keyword | Interface | 0.55 |
| VH-F8 | `=>` operator | Interface | 0.55 |
| VH-F9 | No match | Computation Block | 0.50 |

---

## Chisel (Scala) Rules

### Priority 1 — Monitoring / Testbench

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R1 | `expect(` | Error Reporting and Logging | 0.85 |
| CH-R2 | `poke(`/`peek(`/`step(` | Stimulus Generation | 0.85 |

### Priority 2 — Design Structure

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R3 | `package <name>` | Package and Namespace Definition | 0.85 |
| CH-R4 | `import <pkg>.` (standalone) | Package and Namespace Definition | 0.75 |
| CH-R5 | `class <name> extends *Module` | Top-level Structure | 0.85 |
| CH-R6 | `object <name> extends App` | Top-level Structure | 0.80 |
| CH-R7 | `case class ... Params/Config` | Parameterization and Configuration | 0.85 |

### Priority 3 — Interface

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R8 | `val io = IO(` | Port Definition | 0.90 |
| CH-R9 | `class <name> extends Bundle` | Port Definition | 0.90 |
| CH-R10 | `Input(` + `Output(` | Port Definition | 0.85 |
| CH-R11 | `Decoupled(` | Handshake and Flow Control | 0.85 |
| CH-R12 | `Irrevocable` | Handshake and Flow Control | 0.80 |
| CH-R13 | `.ready :=` or `.valid :=` | Handshake and Flow Control | 0.80 |
| CH-R14 | `Flipped(` | Port Definition | 0.75 |

### Priority 4 — Storage Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R15 | `RegInit` | Register-based Storage | 0.85 |
| CH-R16 | `RegNext` | Register-based Storage | 0.85 |
| CH-R17 | `RegEnable` | Register-based Storage | 0.85 |
| CH-R18 | `Reg(` | Register-based Storage | 0.80 |
| CH-R19 | `ShiftRegister` | Register-based Storage | 0.80 |
| CH-R20 | `Mem(`/`SyncReadMem` | Memory and Array Storage | 0.85 |

### Priority 5 — Control Flow Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R21 | `when(` | Conditional Control | 0.85 |
| CH-R22 | `.elsewhen(` | Conditional Control | 0.85 |
| CH-R23 | `.otherwise` | Conditional Control | 0.80 |
| CH-R24 | `switch(` | Conditional Control | 0.85 |
| CH-R25 | `is(` in `switch` context | Conditional Control | 0.75 |
| CH-R26 | `for(` | Loop-based Control | 0.80 |
| CH-R27 | `.foreach`/`.map`/`.foldLeft`/`.reduce` | Loop-based Control | 0.75 |

### Priority 6 — Computation Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R28 | `Mux(`/`Mux1H`/`MuxLookup`/`MuxCase`/`PriorityMux` | Mux and Selection Logic | 0.85 |
| CH-R29 | `.asUInt`/`.asSInt`/`.asBool`/`.asTypeOf` | Type Casting and Conversion | 0.80 |
| CH-R30 | `Cat(`/`Fill(` | Type Casting and Conversion | 0.75 |

### Priority 7 — Declaration and Definition

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| CH-R31 | `Wire(`/`WireInit`/`WireDefault` | Signal and Wire Declaration | 0.85 |
| CH-R32 | `def <name>[(:=` | Function and Procedure Signature | 0.80 |
| CH-R33 | `ChiselEnum` | Type Definition | 0.80 |

### Fallback Rules (Chisel)

| Rule ID | Condition | Category | Confidence |
|---------|-----------|----------|------------|
| CH-F1 | `:=` in `when`/`switch` context | Control Flow Block | 0.60 |
| CH-F2 | `:=` in `valid`/`ready`/`Decoupled` context | Interface | 0.55 |
| CH-F3 | `:=` to `io.*` | Interface | 0.50 |
| CH-F4 | `case <name> =>` (Scala match) | Control Flow Block | 0.70 |
| CH-F5 | `Module(new ...)` | Design Structure | 0.70 |
| CH-F6 | `require(`/`assert(` | Property and Assertion | 0.65 |
| CH-F7 | `val <name> =` | Declaration and Definition | 0.60 |
| CH-F8 | `:=` (general) | Control Flow Block | 0.55 |
| CH-F9 | No match | Declaration and Definition | 0.50 |

---

## HLS (C/C++) Rules

### Priority 1 — Testbench / Monitoring

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R1 | `testbench` or `golden`/`reference`/`expected` comparison in loop | Stimulus Generation | 0.75 |
| HL-R2 | `sc_main`/`sc_start`/`sc_trace` | Stimulus Generation | 0.80 |
| HL-R3 | `int main(` + `golden`/`reference`/`test` in context | Stimulus Generation | 0.70 |
| HL-R4 | `golden`/`reference`/`expected` + `!=`/`==` | Error Reporting and Logging | 0.75 |
| HL-R5 | `printf`/`fprintf`/`cout` + `error`/`fail`/`mismatch` | Error Reporting and Logging | 0.75 |

### Priority 2 — Interface

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R6 | `#pragma HLS INTERFACE` + `axi`/`axis`/`ap_ctrl`/`s_axilite`/`m_axi` | Protocol-based Interface | 0.85 |
| HL-R7 | `#pragma HLS INTERFACE` (general) | Port Definition | 0.80 |
| HL-R8 | `hls::stream` + `read(`/`write(` | Protocol-based Interface | 0.75 |

### Priority 3 — Design Structure

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R9 | `#pragma HLS top`/`interface` or `#pragma hls_design` | Top-level Structure | 0.85 |
| HL-R10 | `#include` (standalone) | Package and Namespace Definition | 0.80 |
| HL-R11 | `#ifndef`/`#endif`/`#pragma once` | Package and Namespace Definition | 0.75 |
| HL-R12 | `namespace`/`using namespace` | Package and Namespace Definition | 0.75 |

### Priority 4 — Storage Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R13 | `hls::stream`/`ac_channel` | Memory and Array Storage | 0.85 |
| HL-R14 | `#pragma HLS array_partition/array_reshape/stream/bind_storage` | Memory and Array Storage | 0.85 |
| HL-R15 | `int/float/ap_uint/... <name>[` (array declaration) | Memory and Array Storage | 0.80 |

### Priority 5 — Control Flow Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R16 | `for(` | Conditional Control | 0.80 |
| HL-R17 | `while(` | Conditional Control | 0.80 |
| HL-R18 | `#pragma HLS unroll/pipeline/loop` | Conditional Control | 0.80 |
| HL-R19 | `if(` | Conditional Control | 0.75 |
| HL-R20 | `switch(` | Conditional Control | 0.75 |

### Priority 6 — Declaration and Definition

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R21 | `void/int/float/... <name>(` (function signature) | Function and Procedure Signature | 0.80 |
| HL-R22 | `template<` | Function and Procedure Signature | 0.75 |
| HL-R23 | `class`/`struct` | Function and Procedure Signature | 0.75 |
| HL-R24 | `#define <name>` | Parameter and Generic Definition | 0.80 |
| HL-R25 | `static const`/`constexpr` | Parameter and Generic Definition | 0.80 |
| HL-R26 | `typedef`/`enum` | Parameter and Generic Definition | 0.75 |
| HL-R27 | `int/float/ap_uint/... <name>;` or `= ...;` | Signal and Wire Declaration | 0.70 |

### Priority 7 — Computation Block

| Rule ID | Pattern | Subcategory | Confidence |
|---------|---------|-------------|------------|
| HL-R28 | Compound assignment (`+=`, `-=`, `*=`, `/=`, `%=`) | Arithmetic Computation | 0.75 |
| HL-R29 | `= <var> +/-/*/ <var>` | Arithmetic Computation | 0.70 |
| HL-R30 | Ternary `? :` | Mux and Selection Logic | 0.70 |

### Fallback Rules (HLS)

| Rule ID | Condition | Category | Confidence |
|---------|-----------|----------|------------|
| HL-F1 | `stream<` type | Interface | 0.65 |
| HL-F2 | `new[]`/`malloc`/`calloc` | Storage Block | 0.65 |
| HL-F3 | `<type>* <name>` (pointer) | Declaration and Definition | 0.60 |
| HL-F4 | `return` | Control Flow Block | 0.60 |
| HL-F5 | `<var> = <var>` (general assignment) | Computation Block | 0.55 |
| HL-F6 | `}` (closing brace) | Design Structure | 0.55 |
| HL-F7 | `=` (any) | Declaration and Definition | 0.55 |
| HL-F8 | No match | Declaration and Definition | 0.50 |

---

## Rule Design Principles

1. **Verification-first priority**: Testbench, assertion, and monitoring rules are checked before design rules, because file-level context (test vs. design) is the strongest classification signal.

2. **Keyword + context**: Most rules combine a keyword match in the groundtruth with a context check (e.g., `<=` alone is ambiguous, but `<=` inside `always_ff` context → Storage Block).

3. **Confidence scoring**: Each rule carries a confidence score (0.50–0.90) reflecting the reliability of the pattern:
   - **0.85–0.90**: Unambiguous keyword (e.g., `always_ff`, `entity ... is`, `RegInit`)
   - **0.70–0.80**: Strong but context-dependent signal (e.g., `if` inside `always_comb`)
   - **0.50–0.65**: Fallback rules using weak signals (e.g., general `<=` assignment)

4. **Language-specific adaptation**: Each language has its own classifier function with rules tailored to its syntax and idioms, while mapping to the same 9 unified categories.

5. **First-match wins**: Rules are ordered by priority; the first matching rule determines the classification. This avoids ambiguity when multiple patterns match.
