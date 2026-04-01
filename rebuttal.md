# Rebuttal Summary

The `Rebuttal/` directory contains supplementary experiments and materials addressing reviewer concerns, organized into six parts:

---

## 1. Context Window Comparison (`context_window_compared.md`)

Systematically evaluates how varying input context window sizes (512 ~ 1,000,000 tokens) affect code completion performance:

- **Repocoder (cross-file retrieval)**: Adds evaluations for Kimi-K2 and GPT-5.1; compares Gemini-2.5 and GPT-5 across multiple window sizes.
- **No RAG (in-file context only)**: Reports DeepSeek-V3.2, GPT-5, and Gemini-2.5 performance under different window sizes.
- **Extreme cross-file context**: Tests GPT-5 (400K) and Gemini-2.5 (1M) with very large context windows.
- **Fine-tuned local models**: Compares DS-Coder-6.7B, Qwen-Coder-3B/7B/14B across window sizes, and benchmarks against the CodeV model.

**Key finding**: 2,048 tokens is generally the most cost-effective window size; larger windows do not always improve performance and may even degrade it due to noise.

---

## 2. Expert-Defined Rule-Based Classification (`expert_rule.md` + `expert_defined_rules_category/`)

Defines a deterministic, expert-designed rule-based classification system that categorizes HDL code snippets into **9 semantic categories**:

1. Property and Assertion Specification
2. Monitoring and Checking Logic
3. Testbench Stimulus and Environment
4. Design Structure
5. Interface
6. Storage Block
7. Control Flow Block
8. Declaration and Definition
9. Computation Block

Language-specific priority-ordered rule chains are designed for **SystemVerilog** (44 rules + 8 fallbacks), **VHDL** (34 rules + 9 fallbacks), **Chisel** (33 rules + 9 fallbacks), and **HLS C/C++** (30 rules + 8 fallbacks). The implementation is provided in `expert_defined_rules_category/rule_based_classifier.py`.

---

## 3. Functional Verification Results (`function_verified.md`)

Validates functional correctness of code completions via **differential testing** across four languages:

- **HLS**: 50 designs, verified via g++ compile + run, mutation testing achieves 50/50 detection.
- **SystemVerilog**: 45 designs, verified via VCS simulation.
- **VHDL**: 48-49 designs, verified via ModelSim/VCS simulation.
- **Chisel**: 30 designs, verified via sbt compilation + ChiselTest.

Reports pass rates for proprietary models (GPT-5, Gemini-2.5, Grok-4, DeepSeek-V3.2) under FIM / Left-only / Repocoder modes, as well as fine-tuned models (Qwen-Coder series, DS-Coder series) under FIM and Left-only modes.

---

## 4. Prompt Strategy Effects (`prompts_effect.md`)

Evaluates the impact of **Few-Shot** and **Chain-of-Thought (CoT)** prompt strategies under both FIM and Left-only context modes:

- **FIM mode**: The standard prompt consistently outperforms both CoT and Few-Shot. CoT causes an average EM drop of 7.42 and ES drop of 11.99.
- **Left-only mode**: Differences are smaller, but the standard prompt remains slightly superior.
- **Model sensitivity**: GPT-5 is the most robust to prompt variations; Gemini-2.5-Pro is the most sensitive, with CoT and Few-Shot significantly degrading its performance.

**Conclusion**: Unlike natural language tasks, HDL code completion does not benefit from additional reasoning chains — they introduce noise rather than helpful guidance. Direct context utilization is the optimal strategy.

---

## 5. Agentic Workflows (`agentic/`)

Provides implementation scripts for two agentic approaches:

- **`agentic_compile_fix.py`**: A compile-fix loop. Round 0 performs single-shot completion; subsequent rounds feed compilation/simulation errors back to the LLM for iterative repair.
- **`agentic_repo_browse.py`**: Repository browsing + compile-fix. The agent browses the original repository, reads related source files (interfaces, type definitions, etc.) for context, then generates completions and verifies them.
- **`rule_based_classifier.py`**: Rule-based classifier used for semantic category annotation of the dataset.

---

## 6. Per-Language Functional Verification Datasets (`chisel_dataset/`, `systemverilog_dataset/`, `vhdl_dataset/`, `hls_dataset/`)

Each language subdirectory contains a `function_verify/` folder with:

- Design source code, header files, original reference implementations, and target testbenches.
- `design_function_verify_candidates_50.jsonl`: Verification candidate data.
- Verification scripts (e.g., `run_function_verify.py`, `eval_model.py`) and execution logs.

Covered design types include CNN convolution layers (conv2/4/5), SpMV sparse matrix-vector multiplication (multiple optimization variants), DSP pipelines, AXI bus modules, RISC-V components, arithmetic encoders, and more.
