#!/bin/bash
# Run aider completion for all language × model combinations.
# Results go to: Model_evaluation/agentic_workflow/aider/{lang}/{model}/results.jsonl
#
# Usage:
#   bash run_all.sh              # Run all combinations sequentially
#   bash run_all.sh chisel gpt-5 # Run single combination

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/run_aider_completion.py"

LANG="${1:-all}"
MODEL="${2:-all}"

if [ "$LANG" = "all" ] && [ "$MODEL" = "all" ]; then
    for lang in chisel hls systemverilog vhdl; do
        for model in gpt-5 gemini-2.5-pro; do
            echo "============================================"
            echo "  Running: $lang / $model"
            echo "============================================"
            python3 "$SCRIPT" --lang "$lang" --model "$model" 2>&1 | tee "$SCRIPT_DIR/${lang}_${model}.log"
        done
    done
else
    python3 "$SCRIPT" --lang "$LANG" --model "$MODEL" 2>&1 | tee "$SCRIPT_DIR/${LANG}_${MODEL}.log"
fi
