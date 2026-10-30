#!/usr/bin/env python3
"""Compile external HDL tree-sitter grammar sources for legacy GraphCoder."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--grammar-root', required=True, type=Path,
                        help='Root containing tree-sitter-cpp/verilog/vhdl/scala directories.')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    from tree_sitter import Language
    if not hasattr(Language, 'build_library'):
        parser.error('Use the GraphCoder requirements environment (tree-sitter 0.20.4).')
    grammars = [args.grammar_root / ('tree-sitter-' + lang) for lang in ['cpp','verilog','vhdl','scala']]
    for grammar in grammars:
        if not (grammar/'src/parser.c').is_file():
            parser.error(f'Missing grammar source: {grammar}')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    Language.build_library(str(args.output), [str(g) for g in grammars])


if __name__ == '__main__': main()
