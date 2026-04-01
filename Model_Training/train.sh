python3 training_deepseek_coder_1B.py \  #Rerun if new results are needed!!!!!!!!!!!
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model deepseek-ai/deepseek-coder-5.7bmqa-base \
  --out ds_coder_5p7b_lora \
  --bf16


python3 training_qwen.py \
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model Qwen/Qwen2.5-Coder-7B \
  --out qwen_coder_7b_base_lora \
  --bf16


python3 training_qwen.py \
  --train-jsonl ../../all_dataset/train_content.jsonl \
  --eval-jsonl ../../all_dataset/valid_content.jsonl \
  --model Qwen/Qwen2.5-Coder-14B \
  --out qwen_coder_14b_base_lora \
  --bf16