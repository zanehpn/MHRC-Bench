from tree_sitter import Language

# Define the output path for the .so file
# GraphCoder expects this name and location
output_path = 'my-languages.so'

# Define the path to the cloned tree-sitter-cpp folder
# Ensure this points to the root of the repo you cloned
cpp_grammar_path = '/home/zqy/LLM4CHIP/tree-sitter-cpp'
verilog_grammar_path = '/home/zqy/LLM4CHIP/tree-sitter-verilog'
vhdl_grammar_path = '/home/zqy/LLM4CHIP/tree-sitter-vhdl'
scala_grammar_path = '/home/zqy/LLM4CHIP/tree-sitter-scala'
# Build the library
# Note: You can add other languages to this list if you clone them too
Language.build_library(
    output_path,
    [
        cpp_grammar_path,
        verilog_grammar_path,
        vhdl_grammar_path,
        scala_grammar_path
    ]
)

print(f"Successfully compiled {output_path}")