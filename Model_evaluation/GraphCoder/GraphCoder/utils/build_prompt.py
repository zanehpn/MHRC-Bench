# Multi-hdl-language-repo/Model_evaluation/GraphCoder/utils/build_prompt.py

def _token_len(tokenizer, text: str) -> int:
    tokens = tokenizer.tokenize(text)
    try:
        # torch Tensor / numpy array
        return int(tokens.shape[0])
    except Exception:
        return len(tokens)


def make_an_extended_block(retrieved_context, tokenizer):
    content = retrieved_context[0]
    f_path_comment = f"-- The below code fragment can be found in:\n"
    f_paths_str = "-- " + "/".join(retrieved_context[-2]) + "\n"
    code_lines = content.splitlines(keepends=True)
    content_lines_comment = [f"-- {line.rstrip()}\n" for line in code_lines]
    seperator = "-- " + "-" * 50 + "\n"
    block_str = "".join([f_path_comment, f_paths_str, seperator] + content_lines_comment + [seperator])
    token_len = _token_len(tokenizer, block_str)
    return block_str, token_len


def make_str_block_with_max_token_length_from_end(tokenizer, max_token_num: int, context_str: str, with_comment=False):
    str_block = ""
    new_line = context_str.splitlines(keepends=True)
    if with_comment:
        new_line = [f"-- {line}" for line in new_line]
    curr_len = 0
    for i in range(1, len(new_line) + 1):
        line_len = _token_len(tokenizer, new_line[-i])
        if line_len + curr_len < max_token_num:
            str_block = new_line[-i] + str_block
            curr_len += line_len
        else:
            break
    return str_block


def make_str_block_with_max_token_length_from_start(tokenizer, max_token_num: int, context_str: str, with_comment=False):
    str_block = ""
    new_line = context_str.splitlines(keepends=True)
    if with_comment:
        new_line = [f"-- {line}" for line in new_line]
    curr_len = 0
    for i in range(0, len(new_line)):
        line_len = _token_len(tokenizer, new_line[i])
        if line_len + curr_len < max_token_num:
            str_block += new_line[i]
            curr_len += line_len
        else:
            break
    return str_block


def _get_prefix_context(case) -> str:
    # Existing pipeline: case['context'] is a list of lines for LEFT context
    ctx = case.get("context", "")
    if isinstance(ctx, list):
        return "".join(ctx)
    if isinstance(ctx, str):
        return ctx
    return ""


def _get_suffix_context(case) -> str:
    # Option A propagation typically stores it under metadata; also allow common fallbacks.
    md = case.get("metadata", {}) or {}
    suffix = (
        case.get("suffix_context", None)
        or case.get("right_context", None)
        or md.get("right_context", None)
        or ""
    )
    if isinstance(suffix, list):
        return "".join(suffix)
    if isinstance(suffix, str):
        return suffix
    return ""


def _build_fim_block(prefix: str, suffix: str, fim_tokens: dict) -> str:
    return f"{fim_tokens['prefix']}{prefix}{fim_tokens['suffix']}{suffix}{fim_tokens['middle']}"


def _truncate_fim_to_budget(
    tokenizer,
    max_num_tokens: int,
    prefix: str,
    suffix: str,
    preamble: str,
    fim_tokens: dict,
    prefix_ratio: float = 0.6,
):
    # Keep both sides, but bias token budget toward prefix.
    prefix_ratio = max(0.0, min(1.0, prefix_ratio))

    overhead = preamble + _build_fim_block("", "", fim_tokens)
    overhead_len = _token_len(tokenizer, overhead)
    if overhead_len >= max_num_tokens:
        return preamble + _build_fim_block("", "", fim_tokens)

    available = max_num_tokens - overhead_len
    prefix_budget = int(available * prefix_ratio)
    suffix_budget = max(0, available - prefix_budget)

    prefix_part = make_str_block_with_max_token_length_from_end(tokenizer, prefix_budget, prefix)
    suffix_part = make_str_block_with_max_token_length_from_start(tokenizer, suffix_budget, suffix)

    # Safety: if tokenization behaves unexpectedly, shrink suffix then prefix a few rounds.
    for _ in range(6):
        prompt = preamble + _build_fim_block(prefix_part, suffix_part, fim_tokens)
        if _token_len(tokenizer, prompt) <= max_num_tokens:
            return prompt
        if suffix_part:
            suffix_budget = max(0, int(suffix_budget * 0.85))
            suffix_part = make_str_block_with_max_token_length_from_start(tokenizer, suffix_budget, suffix)
            continue
        prefix_budget = max(0, int(prefix_budget * 0.85))
        prefix_part = make_str_block_with_max_token_length_from_end(tokenizer, prefix_budget, prefix)

    return preamble + _build_fim_block(prefix_part, suffix_part, fim_tokens)


def build_infile_prompt(case, tokenizer, max_num_tokens):
    comment = "-- Complete the next statement of the following codes:\n"
    comment_length = _token_len(tokenizer, comment)
    max_num_tokens = max_num_tokens // 2 - comment_length
    context = _get_prefix_context(case)
    prompt = make_str_block_with_max_token_length_from_end(tokenizer, max_num_tokens, context)
    return comment + prompt


def build_retrieval_prompt(case, tokenizer, max_num_tokens, max_top_k):
    context_max_tokens = max_num_tokens // 2
    comment = "-- Based on above, complete the next statement of the following codes:\n"
    comment_length = _token_len(tokenizer, comment)
    context = make_str_block_with_max_token_length_from_end(
        tokenizer, context_max_tokens - comment_length, _get_prefix_context(case)
    )
    context_prompt = comment + context

    seperator = "-- " + "-" * 50
    retrieval_prompt = "-- Here are some relevant code fragments from other files of the repo:\n"
    retrieval_prompt += seperator + "\n"

    num_chosen_context = 0
    max_retrieval_length = max_num_tokens // 2
    current_token_length = _token_len(tokenizer, retrieval_prompt)
    retrival_blocks = []
    top_k_context = case.get("top_k_context", [])

    for i in range(1, len(top_k_context) + 1):
        retrieval_context = top_k_context[-i]
        if num_chosen_context >= max_top_k:
            break
        block_str, token_len = make_an_extended_block(retrieval_context, tokenizer)
        if current_token_length + token_len < max_retrieval_length:
            retrival_blocks.insert(0, block_str)
            current_token_length += token_len
            num_chosen_context += 1

    retrieval_prompt += "".join(retrival_blocks)
    return retrieval_prompt + context_prompt


def build_fim_infile_prompt(case, tokenizer, max_num_tokens, fim_tokens=None):
    fim_tokens = fim_tokens or {"prefix": "<fim_prefix>", "suffix": "<fim_suffix>", "middle": "<fim_middle>"}
    prefix = _get_prefix_context(case)
    suffix = _get_suffix_context(case)

    preamble = (
        "-- Fill in the missing middle code between prefix and suffix.\n"
        "-- Output ONLY the missing code for the <fim_middle> region.\n"
    )
    return _truncate_fim_to_budget(
        tokenizer=tokenizer,
        max_num_tokens=max_num_tokens,
        prefix=prefix,
        suffix=suffix,
        preamble=preamble,
        fim_tokens=fim_tokens,
        prefix_ratio=0.6,
    )


def build_fim_retrieval_prompt(case, tokenizer, max_num_tokens, max_top_k, fim_tokens=None):
    fim_tokens = fim_tokens or {"prefix": "<fim_prefix>", "suffix": "<fim_suffix>", "middle": "<fim_middle>"}

    # Retrieval budget stays similar to old retrieval mode (half); other half is FIM block.
    max_retrieval_length = max_num_tokens // 2
    max_fim_length = max_num_tokens - max_retrieval_length

    seperator = "-- " + "-" * 50
    retrieval_prompt = "-- Here are some relevant code fragments from other files of the repo:\n"
    retrieval_prompt += seperator + "\n"

    num_chosen_context = 0
    current_token_length = _token_len(tokenizer, retrieval_prompt)
    retrival_blocks = []
    top_k_context = case.get("top_k_context", [])

    for i in range(1, len(top_k_context) + 1):
        retrieval_context = top_k_context[-i]
        if num_chosen_context >= max_top_k:
            break
        block_str, token_len = make_an_extended_block(retrieved_context=retrieval_context, tokenizer=tokenizer)
        if current_token_length + token_len < max_retrieval_length:
            retrival_blocks.insert(0, block_str)
            current_token_length += token_len
            num_chosen_context += 1

    retrieval_prompt += "".join(retrival_blocks)

    prefix = _get_prefix_context(case)
    suffix = _get_suffix_context(case)
    preamble = (
        "-- Using the retrieved fragments as reference, fill in the missing middle code.\n"
        "-- Output ONLY the missing code for the <fim_middle> region.\n"
    )
    fim_block = _truncate_fim_to_budget(
        tokenizer=tokenizer,
        max_num_tokens=max_fim_length,
        prefix=prefix,
        suffix=suffix,
        preamble=preamble,
        fim_tokens=fim_tokens,
        prefix_ratio=0.6,
    )
    return retrieval_prompt + fim_block


def build_prompt(case, tokenizer, max_num_tokens, max_top_k=10, mode="fim_retrieval"):
    if mode == "infile":
        return build_infile_prompt(case, tokenizer, max_num_tokens)
    if mode == "retrieval":
        return build_retrieval_prompt(case, tokenizer, max_num_tokens, max_top_k)
    if mode == "fim_infile":
        return build_fim_infile_prompt(case, tokenizer, max_num_tokens)
    if mode == "fim_retrieval":
        return build_fim_retrieval_prompt(case, tokenizer, max_num_tokens, max_top_k)

    raise ValueError(f"Unknown mode: {mode}")
