# MHRC-Bench experiment code

Code for *MHRC-Bench: A Multilingual Hardware Repository-Level Code Completion Benchmark*.
This checkout contains source code, dependency specifications, and synthetic code tests.
Datasets, repository snapshots, testbench assets, model weights, generated predictions,
logs, plots, and experiment results are external inputs or outputs.

## Layout

- `benchmark_construct/`: collection, CST target selection, repository splitting,
  dependency analysis, exact-byte-span export (`export_tasks.py`), overlap checks,
  and the nine-category rule classifier.
- `Model_Training/`: preceding-context and native fill-in-the-middle (FIM) LoRA
  training; pretrained and adapted local model evaluation.
- `Model_evaluation/`: commercial API evaluation, RepoCoder/RLCoder retrieval,
  and the original GraphCoder implementation with HDL traversal adaptations.
- `agents/`: Aider and repository-browsing/compile-feedback harnesses.
- `quickstart_score.py`: strict ID-aligned EM/ES scoring from external files.
- `functional_evaluate.py`: one generated completion per external repository
  test command. Testbenches and canonical I/O vectors must be supplied separately.

## Installation and inputs

Use Python 3.10 or newer and install `requirements.txt`. For the older GraphCoder
parser interface, use a separate environment with its own requirements file and
compile the four HDL grammars with `compile_grammar.py --help`.

Obtain the benchmark separately from
[the dataset hosting page](https://huggingface.co/datasets/Zanehpn/MHRC-Bench).
The [data access guide](https://huggingface.co/datasets/Zanehpn/MHRC-Bench/blob/main/DATA_ACCESS.md)
links the original repository archive, enriched cross-file contexts, and available
testbench assets. Download URLs, sizes, and SHA-256 checksums are listed in the
[resource manifest](https://huggingface.co/datasets/Zanehpn/MHRC-Bench/resolve/main/resources/resource_manifest.json).
Verify the version and split before a full run. Pass external artifact paths
explicitly; the scripts do not download benchmark data automatically.

The dataset's [manual Croissant file](https://huggingface.co/datasets/Zanehpn/MHRC-Bench/resolve/main/croissant.json)
includes Responsible AI metadata and source provenance. Its
[license notice](https://huggingface.co/datasets/Zanehpn/MHRC-Bench/blob/main/LICENSE.md)
distinguishes author-created annotations from third-party source licenses.

A completion record contains `task_id`, `path`, `left_context`, `right_context`,
and `groundtruth`; add `language` for mixed-language files. Preserve `item_id`
when present. Otherwise the scorer derives it from language, repository, path,
and target. Legacy retrieval files without `path` should be regenerated with IDs
before joining their predictions to the original split.

For API evaluation, set `OPENAI_API_KEY` and `OPENAI_BASE_URL` to your provider's
credentials and endpoint. The paper uses ChatfireAPI. Generation parameters are
left at provider defaults. No credentials are included in this repository.

## Paper defaults

The main setting uses a 2,048-token **input** budget and, for local code models,
at most 64 generated tokens with greedy decoding. Preceding-context mode excludes
the right context. Full-context local evaluation uses the model family's native
FIM tokens; commercial evaluation asks for the missing span.

LoRA uses all linear attention/feed-forward layers, rank 16, alpha 32, dropout
0.05, AdamW, learning rate 2e-4, cosine decay, 3% warm-up, and one epoch. Training
masks the prompt labels so loss is computed on the target span. Batch size and
accumulation remain explicit CLI settings; the paper does not specify them.

EM and ES share the same language-aware comment removal and whitespace trimming.
ES uses normalized Levenshtein distance. Reports distinguish sample-weighted
micro averages from an unweighted mean over languages. The complete test split
contains 323 Chisel, 508 V/SV, 496 VHDL, and 456 HLS examples (1,783 total).
Invalid records or incomplete evaluation coverage must not silently reduce the
denominator. Semantic classification has nine categories and preset rule
confidence scores; these scores are not calibrated probabilities.

## Running the main experiments

Paths below refer to external files or output directories of your choice.

```bash
python Model_Training/training_model_fim.py \
  --train-jsonl /path/to/train.jsonl --eval-jsonl /path/to/validation.jsonl \
  --model Qwen/Qwen2.5-Coder-7B --fim-type qwen \
  --out /path/to/adapters/qwen7b --log_name /path/to/logs/qwen7b --bf16

python Model_Training/eval_posttrain_fim.py \
  --test-jsonl /path/to/chisel/test_content.jsonl --language chisel \
  --base_model Qwen/Qwen2.5-Coder-7B --adapter_path /path/to/adapters/qwen7b \
  --fim-type qwen --model_tag qwen7b --output_dir /path/to/predictions

python Model_Training/eval_pretrain_fim.py \
  --test-jsonl /path/to/chisel/test_content.jsonl --language chisel \
  --local_model Qwen/Qwen2.5-Coder-7B --prompt_mode fim \
  --model_tag qwen7b-base --output_dir /path/to/predictions-base

python Model_evaluation/No_RAG/api_evaluate_model_fim.py \
  --test-jsonl /path/to/chisel/test_content.jsonl --language chisel \
  --models gpt5,gemini2_5,grok4,deepseek_v3 \
  --output_dir /path/to/api-predictions
```

The historical CLI alias `deepseek_v3` calls **deepseek-v3.2**. For DeepSeek-Coder
native FIM, use `--fim-type deepseek`. For preceding-context LoRA training use
`Model_Training/training_deepseek_coder_1B.py` (despite its historical filename it
accepts any compatible model through `--model`); evaluate adapters with
`eval_posttrain_hf.py`. Pretrained preceding-context evaluation uses
`eval_pretrain_fim.py --prompt_mode ltr`.

RepoCoder/RLCoder evaluation consumes the external retrieval outputs through
`--test-jsonl`; see the `lib_function/retriever.py --help` and corresponding
`eval_posttrain_*_fim.py --help` interfaces. Retrieval corpora must exclude the
completion's target file. GraphCoder also requires `MHRC_REPOSITORIES_FILE`
(an external JSON object containing `repos` and `repos_language`),
`MHRC_REPO_ROOT`, and optionally `MHRC_DATASET_DIR`, `MHRC_GRAPH_DATABASE`,
`MHRC_QUERY_GRAPH`, and `MHRC_GRAMMAR_LIBRARY`. Set `PROJECT_ROOT` for the Aider harness and
`MHRC_EXPERIMENT_ROOT` for the legacy compile-feedback/browsing harnesses to the
external experiment directory. These harnesses also require their external
candidate/testbench manifests. Run retrieval from an external
working directory so intermediate graphs and prompts remain outside this checkout.

## Scoring and functional checks

```bash
python quickstart_score.py \
  --dataset /path/to/chisel/test_content.jsonl --language chisel \
  --predictions /path/to/predictions/responses_qwen7b_chisel.jsonl

python Model_Training/check_dataset.py \
  --train /path/to/train.jsonl --test /path/to/test.jsonl --normalize-ws

python functional_evaluate.py \
  --dataset /path/to/full_test.jsonl --predictions /path/to/predictions.jsonl \
  --harnesses /path/to/harnesses.jsonl --repo-root /path/to/repositories \
  --output /path/to/functional-results.jsonl --require-full-test
```

Each harness record supplies `item_id`, `repository`, `target_file`, `start_byte`,
`end_byte`, and a `command` argv list. The command must run both compilation and
the behavioral assertions, returning nonzero on failure. The runner verifies the
original target span, patches an isolated copy, and records one pass/fail outcome;
compilation alone does not establish functional correctness. Missing harnesses
abort the run. Use the paper's toolchains: Vitis HLS or g++/ac_int, Icarus Verilog
or Verilator, GHDL, and sbt/ChiselTest. The runner cannot supply missing testbenches.
The separately hosted legacy testbench bundle has partial coverage, recorded in
the [coverage inventory](https://huggingface.co/datasets/Zanehpn/MHRC-Bench/resolve/main/resources/functional_coverage.json).
It uses its own documented runners (including VCS for SystemVerilog/VHDL), not
this runner's JSONL harness schema. Its availability does not establish complete
functional evaluation coverage over all 1,783 test examples.

## Code checks

```bash
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v
```

Tests exercise prompts, scoring, sample coverage, semantic categories, and the
functional runner with temporary synthetic inputs. They do not reproduce the
paper's model results. Real training and model evaluation require the external
artifacts and compute resources above.
