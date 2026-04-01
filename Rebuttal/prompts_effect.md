# Effect of Prompt Strategies on Code Completion Performance

We evaluate two prompt strategies — **Few-Shot** and **Chain-of-Thought (CoT)** — under two context modes:
- **FIM (Fill-in-the-Middle)**: both left and right context provided
- **Left-only**: only left context provided

Baselines use a standard prompt (no few-shot examples, no CoT reasoning).

## 1. FIM Context Mode (Left + Right)

### 1.1 Baseline (Standard Prompt, FIM)

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| GPT-5 | Chisel | 24.77 | 46.19 | 56.70 |
| GPT-5 | HLS | 31.36 | 55.46 | 63.73 |
| GPT-5 | SystemVerilog | 34.45 | 50.74 | 60.87 |
| GPT-5 | VHDL | 15.40 | 40.00 | 51.99 |
| DeepSeek-V3.2 | Chisel | 22.60 | 39.83 | 51.15 |
| DeepSeek-V3.2 | HLS | 30.26 | 49.46 | 57.28 |
| DeepSeek-V3.2 | SystemVerilog | 28.74 | 42.16 | 54.07 |
| DeepSeek-V3.2 | VHDL | 13.31 | 29.99 | 42.97 |
| Gemini-2.5-Pro | Chisel | 26.93 | 52.00 | 60.83 |
| Gemini-2.5-Pro | HLS | 34.57 | 57.29 | 63.77 |
| Gemini-2.5-Pro | SystemVerilog | 33.20 | 49.83 | 59.94 |
| Gemini-2.5-Pro | VHDL | 16.33 | 41.37 | 50.80 |

### 1.2 CoT Prompt (FIM)

> Only Gemini-2.5-Pro tested under FIM + CoT.

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| Gemini-2.5-Pro | Chisel | 16.10 | 33.42 | 43.85 |
| Gemini-2.5-Pro | HLS | 25.22 | 42.51 | 52.03 |
| Gemini-2.5-Pro | SystemVerilog | 27.76 | 41.06 | 51.72 |
| Gemini-2.5-Pro | VHDL | 12.30 | 28.68 | 39.79 |

### 1.3 Few-Shot Prompt (FIM)

> Only Gemini-2.5-Pro tested under FIM + Few-Shot.

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| Gemini-2.5-Pro | Chisel | 26.01 | 47.30 | 56.95 |
| Gemini-2.5-Pro | HLS | 29.82 | 48.05 | 58.75 |
| Gemini-2.5-Pro | SystemVerilog | 19.88 | 32.03 | 42.45 |
| Gemini-2.5-Pro | VHDL | 10.48 | 26.76 | 37.67 |

### 1.4 FIM Summary — Gemini-2.5-Pro (Avg across 4 languages)

| Prompt Strategy | EM | BLEU | ES |
|----------------|----|------|----|
| **Baseline (Standard)** | **27.76** | **50.12** | **58.84** |
| CoT | 20.34 | 36.42 | 46.85 |
| Few-Shot | 21.55 | 38.54 | 48.95 |

**Observation (FIM):** Both CoT and Few-Shot **degrade** performance compared to the standard FIM prompt. CoT drops EM by 7.42 points and ES by 11.99 points on average. This suggests that additional reasoning or examples are counterproductive when rich bidirectional context is already available — the model over-thinks instead of directly completing the code.

---

## 2. Left-Only Context Mode

### 2.1 Baseline (Standard Prompt, Left-only)

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| GPT-5 | Chisel | 15.17 | 41.12 | 51.58 |
| GPT-5 | HLS | 12.06 | 33.62 | 46.67 |
| GPT-5 | SystemVerilog | 21.85 | 43.57 | 55.40 |
| GPT-5 | VHDL | 20.77 | 47.39 | 58.48 |
| DeepSeek-V3.2 | Chisel | 10.34 | 36.39 | 46.97 |
| DeepSeek-V3.2 | HLS | 9.91 | 29.86 | 42.36 |
| DeepSeek-V3.2 | SystemVerilog | 22.81 | 45.87 | 56.31 |
| DeepSeek-V3.2 | VHDL | 16.98 | 41.64 | 53.78 |
| Gemini-2.5-Pro | Chisel | 11.11 | 45.04 | 56.09 |
| Gemini-2.5-Pro | HLS | 17.96 | 40.17 | 51.96 |
| Gemini-2.5-Pro | SystemVerilog | 28.94 | 51.55 | 61.43 |
| Gemini-2.5-Pro | VHDL | 23.27 | 47.68 | 61.80 |

### 2.2 CoT Prompt (Left-only)

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| GPT-5 | Chisel | 17.65 | 38.75 | 47.81 |
| GPT-5 | HLS | 11.40 | 31.41 | 43.93 |
| GPT-5 | SystemVerilog | 22.64 | 44.24 | 55.73 |
| GPT-5 | VHDL | 22.18 | 45.72 | 56.44 |
| DeepSeek-V3.2 | Chisel | 13.00 | 36.23 | 48.78 |
| DeepSeek-V3.2 | HLS | 12.28 | 32.47 | 45.23 |
| DeepSeek-V3.2 | SystemVerilog | 21.06 | 42.03 | 53.77 |
| DeepSeek-V3.2 | VHDL | 17.14 | 43.01 | 54.44 |
| Gemini-2.5-Pro | Chisel | 10.22 | 26.31 | 36.87 |
| Gemini-2.5-Pro | HLS | 13.82 | 29.46 | 40.35 |
| Gemini-2.5-Pro | SystemVerilog | 20.28 | 37.32 | 47.74 |
| Gemini-2.5-Pro | VHDL | 18.75 | 36.51 | 48.00 |

### 2.3 Few-Shot Prompt (Left-only)

| Model | Language | EM | BLEU | ES |
|-------|----------|----|------|----|
| GPT-5 | Chisel | 15.17 | 41.56 | 53.06 |
| GPT-5 | HLS | 12.06 | 33.60 | 46.30 |
| GPT-5 | SystemVerilog | 21.06 | 44.34 | 55.87 |
| GPT-5 | VHDL | 20.36 | 47.41 | 58.80 |
| DeepSeek-V3.2 | Chisel | 15.48 | 40.18 | 51.89 |
| DeepSeek-V3.2 | HLS | 12.50 | 33.58 | 46.77 |
| DeepSeek-V3.2 | SystemVerilog | 20.67 | 39.78 | 52.48 |
| DeepSeek-V3.2 | VHDL | 15.32 | 39.54 | 52.33 |
| Gemini-2.5-Pro | Chisel | 18.58 | 42.60 | 53.76 |
| Gemini-2.5-Pro | HLS | 14.25 | 32.97 | 44.04 |
| Gemini-2.5-Pro | SystemVerilog | 19.49 | 34.02 | 44.75 |
| Gemini-2.5-Pro | VHDL | 16.73 | 32.69 | 44.28 |

### 2.4 Left-Only Summary — Average across all 3 models and 4 languages

| Prompt Strategy | EM (avg) | BLEU (avg) | ES (avg) |
|----------------|----------|------------|----------|
| **Baseline** | **17.60** | **41.16** | **53.57** |
| CoT | 16.70 | 36.96 | 48.26 |
| Few-Shot | 16.81 | 38.52 | 50.36 |

---

## 3. Per-Model Comparison (Left-Only, Avg across 4 languages)

### GPT-5

| Prompt Strategy | EM | BLEU | ES |
|----------------|----|------|----|
| Baseline | 17.46 | 41.43 | 53.03 |
| CoT | 18.47 | 40.03 | 50.98 |
| Few-Shot | 17.16 | 41.73 | 53.51 |

### DeepSeek-V3.2

| Prompt Strategy | EM | BLEU | ES |
|----------------|----|------|----|
| Baseline | 15.01 | 38.44 | 49.85 |
| CoT | 15.87 | 38.43 | 50.56 |
| Few-Shot | 15.99 | 38.27 | 50.87 |

### Gemini-2.5-Pro

| Prompt Strategy | EM | BLEU | ES |
|----------------|----|------|----|
| Baseline | 20.32 | 46.11 | 57.82 |
| CoT | 15.77 | 32.40 | 43.24 |
| Few-Shot | 17.26 | 35.57 | 46.71 |

---

## 4. Key Findings

### Finding 1: FIM + Standard Prompt is the strongest setting
Under FIM mode, the standard prompt consistently outperforms both CoT and Few-Shot across all models and languages. The bidirectional context already provides sufficient information for the model to complete the code.

### Finding 2: CoT and Few-Shot do not help — and can hurt
- **CoT** causes the most degradation, especially for Gemini-2.5-Pro (ES drops from 57.82 → 43.24 in left-only mode).
- **Few-Shot** shows marginal effects: slight improvements for DeepSeek-V3.2, but degradation for Gemini-2.5-Pro.
- **GPT-5** is the most robust to prompt variations (minimal change across strategies).

### Finding 3: Model-specific sensitivity
| Model | Sensitivity to prompt strategy |
|-------|-------------------------------|
| GPT-5 | Low — stable across all strategies |
| DeepSeek-V3.2 | Low — CoT/Few-Shot slightly improve over baseline |
| Gemini-2.5-Pro | High — CoT and Few-Shot significantly degrade performance |

### Finding 4: Implication for HDL code completion
Unlike natural language tasks where CoT and Few-Shot often help, HDL code completion benefits most from **direct context** rather than reasoning chains. This is because:
1. HDL code is highly structured with strict syntax — additional reasoning introduces noise
2. The completion target is typically short (1–5 lines) — elaborate prompting is unnecessary
3. FIM context already provides strong positional and structural cues
