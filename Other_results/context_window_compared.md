# Horizontal Comparison of LLMs under fim settings

## Repocoder

Retrieved cross-file context blocks are assembled with in-file context before generation, then outputs are scored with EM, ES, and BLEU. We prioritize cross-file context during truncation (if needed to meet the input token requirements), and keep only a minimal amount of in-file context if necessary. We additionally evaluate `Kimi-K2` and `GPT-5.1`, and also report the effect of varying input context windows on model performance for `Gemini-2.5` and `GPT-5`.

| Model | Context window | Chisel EM | Chisel ES | V/SV EM | V/SV ES | VHDL EM | VHDL ES | HLS EM | HLS ES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| GPT-5.1 | 2,048 | 31.58 | 62.71 | 36.17 | 61.52 | 15.26 | 46.30 | 38.27 | 68.22 |
| Kimi-K2 | 2,048 | 19.81 | 49.62 | 25.10 | 55.26 | 11.94 | 44.10 | 29.65 | 60.96 |
| Gemini-2.5 | 512 | 27.02 | 59.32 | 34.78 | 61.27 | 13.77 | 41.92 | 38.44 | 70.74 |
|  | 1,024 | 29.81 | 64.31 | 34.98 | 61.34 | 16.02 | 48.99 | 27.49 | 52.22 |
|  | 2,048 |  33.7 | 61.7  | 34.8  | 59.6  | 18.0  | 52.3  | 39.4  | 65.3  |
|  | 4,096 | 26.63 | 60.26 | 33.40 | 59.22 | 12.75 | 43.67 | 36.73 | 69.80 |
|  | 8,192 | 32.51 | 66.93 | 36.69 | 64.97 | 17.41 | 53.59 | 41.15 | 71.73 |
| GPT-5 | 512 | 27.24 | 61.34 | 29.13 | 57.98 | 13.91 | 49.67 | 32.02 | 64.02 |
|  | 1,024 | 28.17 | 61.38 | 30.13 | 57.33 | 13.51 | 48.32 | 33.55 | 64.63 |
|  | 2,048 | 27.55 | 59.60 | 32.28 | 58.48 | 14.81 | 50.16 | 34.43 | 63.91 |
|  | 4,096 | 24.46 | 61.25 | 32.87 | 61.16 | 13.51 | 48.82 | 32.24 | 65.67 |
|  | 8,192 | 28.17 | 61.23 | 34.71 | 62.49 | 13.56 | 51.02 | 36.73 | 69.12 |


## No RAG

Direct blank completion with token-bounded in-file context. We also report the effect of varying input context windows on model performance.

| Model | Context window | Chisel EM | Chisel ES | V/SV EM | V/SV ES | VHDL EM | VHDL ES | HLS EM | HLS ES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| DeepSeek-V3.2 | 512 | 17.65 | 47.16 | 21.26 | 50.59 | 12.10 | 41.57 | 20.39 | 53.81 |
|  | 1,024 | 19.20 | 48.83 | 26.97 | 54.81 | 11.90 | 42.69 | 25.22 | 58.37 |
|  | 4,096 | 23.53 | 53.55 | 28.15 | 55.79 | 12.30 | 45.44 | 28.51 | 59.86 |
|  | 2,048 | 22.6| 51.2| 28.7 |54.1| 13.3| 43.0| 30.3| 57.3
|  | 8,192 | 20.12 | 52.66 | 29.13 | 55.92 | 12.70 | 45.72 | 28.07 | 61.19 |
| GPT-5 | 512 | 19.81 | 54.19 | 26.38 | 56.17 | 11.29 | 44.52 | 24.56 | 60.34 |
|  | 1,024 | 24.77 | 57.50 | 31.89 | 59.46 | 13.71 | 49.11 | 28.51 | 64.36 |
|  | 2,048 | 24.77 | 56.70 | 34.45 | 60.87 | 15.40 | 51.99 | 31.36 | 63.73 |
|  | 4,096 | 27.24 | 61.11 | 32.68 | 61.28 | 13.51 | 49.67 | 33.11 | 66.76 |
|  | 8,192 | 29.41 | 62.59 | 34.06 | 61.21 | 7.86 | 30.09 | 31.80 | 66.41 |
| Gemini-2.5 | 512 | 20.12 | 57.26 | 27.56 | 56.00 | 11.69 | 45.46 | 28.73 | 63.09 |
|  | 1,024 | 24.77 | 61.26 | 31.10 | 59.92 | 13.31 | 47.55 | 32.46 | 66.97 |
|  | 2,048 |  33.2 | 59.9  | 33.2  | 59.9  | 16.3  | 50.8  | 34.6  | 63.8  |
|  | 4,096 | 29.72 | 64.17 | 33.66 | 62.33 | 14.52 | 50.68 | 35.53 | 68.42 |
|  | 8,192 | 24.77 | 54.99 | 34.45 | 62.18 | 15.52 | 51.58 | 35.75 | 68.78 |


## Extreme Cross-File Context

Include relavent files up to very large context windows (as defined by the upper limit of the models).

| Model | Context window | Chisel EM | Chisel ES | V/SV EM | V/SV ES | VHDL EM | VHDL ES | HLS EM | HLS ES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| GPT-5 | 400,000 | 30.96 | 63.57 | 38.58 | 62.95 | 14.95 | 50.57 | 44.30 | 71.50 |
| Gemini-2.5 | 1,000,000 | 32.20 | 64.11 | 36.81 | 61.17 | 11.90 | 43.63 | 46.37 | 71.12 |

## Local LLMs

Local LLMs fine-tuned on HDL-repo bench-Train. We also report the effect of varying input context windows on model performance

| Model | Context window | Chisel EM | Chisel ES | V/SV EM | V/SV ES | VHDL EM | VHDL ES | HLS EM | HLS ES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| DS-Coder-6.7B | 512 | 16.10 | 50.64 | 24.41 | 54.34 | 17.14 | 51.33 | 25.00 | 55.00 |
|  | 1,024 | 22.29 | 61.99 | 34.25 | 69.36 | 26.61 | 67.59 | 31.80 | 67.70 |
|  | 2,048 | 25.7| 56.5| 37.8| 67.4| 31.5| 61.1| 36.8| 60.4|
|  | 4,096 | 19.81 | 59.97 | 30.12 | 64.59 | 23.79 | 61.45 | 28.29 | 62.36 |
|  | 8,192 | 19.81 | 57.40 | 30.12 | 62.62 | 22.58 | 58.38 | 28.73 | 61.47 |
| Qwen-Coder-14B | 512 | 26.93 | 64.83 | 32.48 | 67.39 | 26.41 | 64.92 | 30.70 | 66.50 |
|  | 1,024 | 29.10 | 67.42 | 34.45 | 71.29 | 30.65 | 70.46 | 33.55 | 70.59 |
|  | 2,048| 31.3| 68.9| 41.9| 74.4| 35.3| 73.8| 38.2| 71.5|
|  | 4,096 | 28.17 | 65.59 | 36.42 | 67.98 | 29.84 | 64.54 | 32.68 | 66.12 |
|  | 8,192 | 28.17 | 66.68 | 37.60 | 68.63 | 30.65 | 66.97 | 33.77 | 67.76 |
| Qwen-Coder-3B | 512 | 20.74 | 56.64 | 25.00 | 57.43 | 19.15 | 55.33 | 26.75 | 60.07 |
|  | 1,024 | 22.91 | 61.73 | 32.87 | 66.60 | 26.01 | 65.94 | 31.80 | 66.70 |
|  |2,048 | 24.8  |  54.3 |34.8   | 65.5  | 28.2  | 59.1  | 33.1  | 55.0  |
|  | 4,096 | 21.36 | 59.57 | 29.72 | 64.16 | 24.80 | 62.06 | 28.51 | 64.95 |
|  | 8,192 | 18.89 | 56.19 | 26.57 | 57.06 | 22.38 | 54.78 | 26.75 | 58.31 |
| Qwen-Coder-7B | 512 | 22.60 | 61.07 | 33.66 | 66.89 | 25.81 | 65.12 | 32.02 | 65.52 |
|  | 1,024 | 25.08 | 64.78 | 34.65 | 69.69 | 30.04 | 70.83 | 33.77 | 69.42 |
|  | 2,048 | 26.6| 66.7| 39.0| 70.8| 34.5| 71.9| 35.5| 69.5|
|  | 4,096 | 21.98 | 60.68 | 31.69 | 63.93 | 26.81 | 63.79 | 30.26 | 62.97 |
|  | 8,192 | 21.36 | 61.81 | 31.50 | 62.77 | 26.61 | 60.95 | 29.61 | 63.29 |



## Comparison with Similar Fine-tuned fim Models

We compare our models with `CodeV` (Zhao et al., 2025), a model based on `Qwen2.5-Coder-7B` focusing on Chisel and Verilog/SystemVerilog generation under the same FIM evaluation setup.

| Model | Context window | Chisel EM | Chisel ES | V/SV EM | V/SV ES | VHDL EM | VHDL ES | HLS EM | HLS ES |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CodeV-All-QC | 2,048 | 22.91 | 60.73 | 18.11 | 51.36 | 5.44 | 42.34 | 20.39 | 49.79 |
| HDL-repo-Qwen-Coder-7B | 2,048 | 26.6| 66.7| 39.0| 70.8| 34.5| 71.9| 35.5| 69.5|

Note that `VHDL` and `HLS` are not supported by `CodeV` and results are for reference only.

## References


- Zhao, Y., Huang, D., Li, C., Jin, P., Song, M., Xu, Y., et al. `CodeV: Empowering LLMs with HDL generation through multi-level summarization.` *IEEE Transactions on Computer-Aided Design of Integrated Circuits and Systems*, 2025.
