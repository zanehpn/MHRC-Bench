from tree_sitter import Language, Parser
import os

# Configuration
SO_PATH = './my-languages.so'

# Define test cases: (Language Name in SO, Test Code Snippet)
TEST_CASES = {
    "cpp": "int main() { return 0; }",
    "verilog": "module top; wire a = 1'b0; endmodule",
    "vhdl": "entity e is end entity e;",
    "scala": "object Hello { def main(args: Array[String]) = println(\"Hi\") }"
}

def run_tests():
    if not os.path.exists(SO_PATH):
        print(f"Error: {SO_PATH} not found!")
        return

    print(f"{'Language':<10} | {'Status':<10} | {'Details'}")
    print("-" * 40)

    success_count = 0
    
    for lang_name, code in TEST_CASES.items():
        try:
            # 1. Try to load the language from the .so
            # Note: The second argument must match the name defined in the grammar's index.js
            LANG = Language(SO_PATH, lang_name)
            
            # 2. Initialize Parser
            parser = Parser()
            parser.set_language(LANG)
            
            # 3. Parse snippet
            tree = parser.parse(bytes(code, "utf8"))
            
            # 4. Check for errors in the AST
            if tree.root_node.has_error:
                print(f"{lang_name:<10} | FAILED     | Parsed with syntax errors (Grammar mismatch?)")
            else:
                print(f"{lang_name:<10} | PASSED     | Root node type: {tree.root_node.type}")
                success_count += 1
                
        except Exception as e:
            # If the name doesn't exist in the .so, this will trigger
            print(f"{lang_name:<10} | ERROR      | {str(e)}")

    print("-" * 40)
    print(f"Passed {success_count}/{len(TEST_CASES)} tests.")

if __name__ == "__main__":
    run_tests()