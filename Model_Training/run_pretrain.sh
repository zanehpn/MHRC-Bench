echo "-----Evaluating deepseek-coder-5.7bmqa-base-----"
python eval_pretrain_hf.py --language vhdl \
  --local_model deepseek-ai/deepseek-coder-5.7bmqa-base \
  --models local_hf \
  --model_tag ds_5p7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language systemverilog \
  --local_model deepseek-ai/deepseek-coder-5.7bmqa-base \
  --models local_hf \
  --model_tag ds_5p7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language chisel \
  --local_model deepseek-ai/deepseek-coder-5.7bmqa-base \
  --models local_hf \
  --model_tag ds_5p7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language hls \
  --local_model deepseek-ai/deepseek-coder-5.7bmqa-base \
  --models local_hf \
  --model_tag ds_5p7b \
  --tokenizer_name auto


echo "-----Evaluating Qwen/Qwen2.5-Coder-7B-----"
python eval_pretrain_hf.py --language vhdl \
  --local_model Qwen/Qwen2.5-Coder-7B \
  --models local_hf \
  --model_tag qwen_7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language systemverilog \
  --local_model Qwen/Qwen2.5-Coder-7B \
  --models local_hf \
  --model_tag qwen_7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language chisel \
  --local_model Qwen/Qwen2.5-Coder-7B \
  --models local_hf \
  --model_tag qwen_7b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language hls \
  --local_model Qwen/Qwen2.5-Coder-7B \
  --models local_hf \
  --model_tag qwen_7b \
  --tokenizer_name auto

  

echo "-----Evaluating Qwen/Qwen2.5-Coder-14B-----"
python eval_pretrain_hf.py --language vhdl \
  --local_model Qwen/Qwen2.5-Coder-14B \
  --models local_hf \
  --model_tag qwen_14b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language systemverilog \
  --local_model Qwen/Qwen2.5-Coder-14B \
  --models local_hf \
  --model_tag qwen_14b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language chisel \
  --local_model Qwen/Qwen2.5-Coder-14B \
  --models local_hf \
  --model_tag qwen_14b \
  --tokenizer_name auto

python eval_pretrain_hf.py --language hls \
  --local_model Qwen/Qwen2.5-Coder-14B \
  --models local_hf \
  --model_tag qwen_14b \
  --tokenizer_name auto