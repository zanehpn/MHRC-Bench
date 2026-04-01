# Function Verification Results (All Languages)

Functional correctness verified via **differential testing** across four HDL/HLS languages.

- **HLS**: 50 designs, verified via g++ compile + run, mutation-tested 50/50 DETECTS
- **SystemVerilog**: 45 designs, verified via VCS simulation
- **VHDL**: 48–49 designs, verified via ModelSim/VCS simulation
- **Chisel**: 30 designs, verified via Chisel/sbt compile + test

---

## 1. Proprietary Models — Fill-in-the-Middle (No RAG)

### HLS (50 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| GPT-5 (4096) | 34 | 50 | 68.0% |
| GPT-5 (default) | 33 | 50 | 66.0% |
| Grok-4 | 33 | 50 | 66.0% |
| GPT-5 (1024) | 32 | 50 | 64.0% |
| GPT-5 (512) | 31 | 50 | 62.0% |
| DeepSeek-V3.2 | 30 | 50 | 60.0% |
| Gemini-2.5 | 24 | 50 | 48.0% |

### SystemVerilog (45 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Gemini-2.5 | 18 | 45 | 40.0% |
| GPT-5 (4096) | 15 | 45 | 33.3% |
| GPT-5 (1024) | 14 | 45 | 31.1% |
| Grok-4 | 14 | 45 | 31.1% |
| GPT-5 (default) | 13 | 45 | 28.9% |
| GPT-5 (512) | 11 | 45 | 24.4% |
| DeepSeek-V3.2 | 11 | 46 | 23.9% |

### VHDL (49 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Gemini-2.5 | 5 | 49 | 10.2% |
| GPT-5 (512) | 5 | 49 | 10.2% |
| DeepSeek-V3.2 | 4 | 49 | 8.2% |
| GPT-5 (1024) | 4 | 49 | 8.2% |
| Grok-4 | 4 | 49 | 8.2% |
| GPT-5 (4096) | 3 | 49 | 6.1% |
| GPT-5 (default) | 0 | 49 | 0.0% |

### Chisel (30 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Gemini-2.5 | 17 | 30 | 56.7% |
| GPT-5 (4096) | 10 | 30 | 33.3% |
| GPT-5 (1024) | 8 | 30 | 26.7% |
| GPT-5 (512) | 8 | 30 | 26.7% |
| GPT-5 (default) | 8 | 30 | 26.7% |
| DeepSeek-V3.2 | 7 | 30 | 23.3% |
| Grok-4 | 6 | 30 | 20.0% |

---

## 2. Proprietary Models — Left-only Context (No RAG)

### HLS (50 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| DeepSeek-V3.2 (2048) | 12 | 50 | 24.0% |
| Grok-4 (2048) | 10 | 50 | 20.0% |
| GPT-5 (2048) | 9 | 50 | 18.0% |
| Gemini-2.5 (2048) | 6 | 50 | 12.0% |

### SystemVerilog (45 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Gemini-2.5 (2048) | 18 | 45 | 40.0% |
| GPT-5 (2048) | 17 | 45 | 37.8% |
| DeepSeek-V3.2 (2048) | 15 | 45 | 33.3% |
| Grok-4 (2048) | 15 | 45 | 33.3% |

### Chisel (30 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| DeepSeek-V3.2 (2048) | 8 | 30 | 26.7% |
| Gemini-2.5 (2048) | 8 | 30 | 26.7% |
| GPT-5 (2048) | 7 | 30 | 23.3% |
| Grok-4 (2048) | 2 | 30 | 6.7% |

---

## 3. Proprietary Models — Repocoder (with retrieval)

### HLS (50 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| GPT-5 (default) | 34 | 50 | 68.0% |
| GPT-5 (512) | 33 | 50 | 66.0% |
| GPT-5 (4096) | 33 | 50 | 66.0% |
| DeepSeek-V3.2 | 32 | 50 | 64.0% |
| GPT-5 (1024) | 30 | 50 | 60.0% |
| Gemini-2.5 | 29 | 50 | 58.0% |
| Grok-4 | 10 | 50 | 20.0% |

---

## 4. Fine-tuned Models — Fill-in-the-Middle

### HLS (50 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Qwen-Coder-14B-LoRA | 36 | 50 | 72.0% |
| DeepSeek-Coder-6.7B-LoRA | 33 | 50 | 66.0% |
| Qwen-Coder-7B-LoRA | 32 | 50 | 64.0% |
| DS-5.7B-LoRA | 31 | 50 | 62.0% |
| Qwen2.5-Coder-3B-LoRA | 28 | 50 | 56.0% |

### SystemVerilog (45 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| DS-5.7B-LoRA | 18 | 45 | 40.0% |
| Qwen-Coder-14B-LoRA | 18 | 45 | 40.0% |
| DeepSeek-Coder-6.7B-LoRA | 16 | 45 | 35.6% |
| Qwen-Coder-7B-LoRA | 15 | 45 | 33.3% |
| Qwen2.5-Coder-3B-LoRA | 14 | 45 | 31.1% |

### VHDL (48–49 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| DS-5.7B-LoRA | 9 | 49 | 18.4% |
| Qwen-Coder-7B-LoRA | 9 | 49 | 18.4% |
| Qwen-Coder-14B-LoRA | 7 | 48 | 14.6% |
| DeepSeek-Coder-6.7B-LoRA | 7 | 49 | 14.3% |
| Qwen2.5-Coder-3B-LoRA | 4 | 48 | 8.3% |

### Chisel (30 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Qwen-Coder-14B-LoRA | 10 | 30 | 33.3% |
| DeepSeek-Coder-6.7B-LoRA | 9 | 30 | 30.0% |
| DS-5.7B-LoRA | 9 | 30 | 30.0% |
| Qwen2.5-Coder-3B-LoRA | 9 | 30 | 30.0% |
| Qwen-Coder-7B-LoRA | 8 | 30 | 26.7% |

---

## 5. Fine-tuned Models — Left-only Context

### HLS (50 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Qwen-Coder-14B-L2R | 16 | 50 | 32.0% |
| Qwen-Coder-3B-L2R | 15 | 50 | 30.0% |
| Qwen-Coder-7B-L2R | 14 | 50 | 28.0% |

### SystemVerilog (45 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| DS-5.7B-L2R | 17 | 45 | 37.8% |
| Qwen-Coder-14B-L2R | 16 | 45 | 35.6% |
| Qwen-Coder-7B-L2R | 15 | 45 | 33.3% |
| DeepSeek-Coder-6.7B-L2R | 14 | 45 | 31.1% |
| Qwen-Coder-3B-L2R | 13 | 45 | 28.9% |
| DeepSeek-Coder-6.7B-RTL-L2R | 8 | 45 | 17.8% |

### VHDL (49 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Qwen-Coder-14B-L2R | 11 | 49 | 22.4% |
| DeepSeek-Coder-6.7B-L2R | 10 | 49 | 20.4% |
| DS-5.7B-L2R | 9 | 49 | 18.4% |
| Qwen-Coder-7B-L2R | 7 | 49 | 14.3% |
| Qwen-Coder-3B-L2R | 4 | 49 | 8.2% |

### Chisel (30 designs)

| Model | Pass | Total | Pass Rate |
|-------|------|-------|-----------|
| Qwen-Coder-7B-L2R | 9 | 30 | 30.0% |
| Qwen-Coder-14B-L2R | 7 | 30 | 23.3% |
| Qwen-Coder-3B-L2R | 6 | 30 | 20.0% |
| DS-5.7B-L2R | 5 | 30 | 16.7% |
| DeepSeek-Coder-6.7B-L2R | 5 | 30 | 16.7% |

---

## Verification Methodology

### HLS (C/C++)
- **Differential testing**: compile with g++ and run; compare stdout + return code against golden (ground-truth code)
- **Mutation validation**: 50/50 DETECTS (42 build_fail + 8 runtime_fail), 0 BLIND, 0 SKIP

### SystemVerilog
- Verified via VCS simulation with design-specific testbenches

### VHDL
- Verified via ModelSim/VCS simulation with design-specific testbenches

### Chisel
- Verified via sbt/Chisel compilation and ChiselTest testbenches
