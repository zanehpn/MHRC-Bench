"""MHRC-Bench EM/ES: comment stripping, line trimming, and Levenshtein distance."""

ALIASES = {"sv": "systemverilog", "verilog": "systemverilog", "scala": "chisel",
           "c": "hls", "cpp": "hls", "c++": "hls", "hls_cpp": "hls"}


def normalize_code(code, lang=""):
    language = ALIASES.get(lang.lower(), lang.lower())
    text = str(code)
    result = []
    i = 0
    quote = None
    block_depth = 0
    c_style = language in {"hls", "systemverilog", "chisel"}
    while i < len(text):
        if block_depth:
            if text.startswith("/*", i) and language == "chisel":
                block_depth += 1; i += 2
            elif text.startswith("*/", i):
                block_depth -= 1; i += 2
            else:
                if text[i] == "\n": result.append("\n")
                i += 1
            continue
        if quote:
            if text.startswith(quote, i):
                result.append(quote); i += len(quote)
                if language == "vhdl" and i < len(text) and text[i] == '"':
                    result.append('"'); i += 1
                else:
                    quote = None
            elif text[i] == "\\" and language != "vhdl" and quote != '"""':
                result.append(text[i:i+2]); i += 2
            else:
                result.append(text[i]); i += 1
            continue
        if c_style and text.startswith("/*", i):
            block_depth = 1; result.append(" "); i += 2
        elif (c_style and text.startswith("//", i)) or (language == "vhdl" and text.startswith("--", i)):
            end = text.find("\n", i)
            i = len(text) if end == -1 else end
        elif text[i] == '"':
            quote = '"""' if language == "chisel" and text.startswith('"""', i) else '"'
            result.append(quote); i += len(quote)
        elif text[i] == "'" and language in {"hls", "chisel"}:
            # A closed character literal; Scala type/symbol syntax is not a string.
            end = i + (3 if text[i+1:i+2] == "\\" else 2)
            if end < len(text) and text[end] == "'":
                result.append(text[i:end+1]); i = end + 1
            else:
                result.append(text[i]); i += 1
        else:
            result.append(text[i]); i += 1
    return "\n".join(line.strip() for line in "".join(result).splitlines() if line.strip())


def levenshtein(first, second):
    if len(first) < len(second): first, second = second, first
    previous = list(range(len(second) + 1))
    for row, a in enumerate(first, 1):
        current = [row]
        for col, b in enumerate(second, 1):
            current.append(min(current[-1] + 1, previous[col] + 1, previous[col-1] + (a != b)))
        previous = current
    return previous[-1]


def evaluate_em(prediction, reference, lang=""):
    return float(normalize_code(prediction, lang) == normalize_code(reference, lang))


def evaluate_es(prediction, reference, lang=""):
    a, b = normalize_code(prediction, lang), normalize_code(reference, lang)
    return 1.0 - levenshtein(a, b) / max(1, len(a), len(b))
