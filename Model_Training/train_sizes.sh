python3 training_qwen.py \
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model Qwen/Qwen2.5-Coder-7B \
  --out qwen_coder_7b_base_512 \
  --log_name trainlog_qwen_coder_7b_512 \
  --max-prompt-tokens 512 \
  --bf16


python3 training_qwen.py \
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model Qwen/Qwen2.5-Coder-7B \
  --out qwen_coder_7b_base_1024 \
  --log_name trainlog_qwen_coder_7b_1024 \
  --max-prompt-tokens 1024 \
  --bf16

  python3 training_qwen.py \
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model Qwen/Qwen2.5-Coder-7B \
  --out qwen_coder_7b_base_4096 \
  --log_name trainlog_qwen_coder_7b_4096 \
  --max-prompt-tokens 4096 \
  --bf16