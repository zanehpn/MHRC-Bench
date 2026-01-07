import glob
import networkx as nx
import pickle
import json
import os
from networkx.readwrite import json_graph
import tiktoken

device = "cuda"


class CodeGenTokenizer:
    def __init__(self, tokenizer_raw):
        self.tokenizer = tokenizer_raw

    def tokenize(self, text):
        return self.tokenizer(text, return_tensors="pt")['input_ids'][0].to(device)

    def decode(self, token_ids):
        return self.tokenizer.decode(token_ids, skip_special_tokens=True)


class StarCoderTokenizer:
    def __init__(self, tokenizer_raw):
        self.tokenizer = tokenizer_raw

    def tokenize(self, text):
        return self.tokenizer.encode(text, return_tensors="pt")[0].to(device)

    def decode(self, token_ids):
        return self.tokenizer.decode(token_ids, skip_special_tokens=True)


class CONSTANTS:
    max_hop = 5
    max_search_top_k = 10
    max_statement = 20
    repo_base_dir = f"/home/zqy/LLM4CHIP/Multi-hdl-language-repo/vhdl"
    graph_database_save_dir = f"./context_database_vhdl"
    query_graph_save_dir = "./graph_based_query_fim"
    dataset_dir = "./HW_Repo_Bench"
    repos = [
             "General-CNN-Accelerator",
             "fos",
             "cpu_for_nscscc2022_single",
             "acSLAM",
             "AppleIISd",
             "FPGA-I2C-Minion",
             "FPGA-Speech-Recognition",
             "NTSC-composite-encoder",
             "Spiking_NN_RGB_FPGA",
             "VGA-Text-Generator",
             "spi-to-axi-bridge",
             "uart",
             "FPGA-Class-D-Amplifier",
             "ZynqBTC",
             "bit-serial",
             "formal_hw_verification",
             "ipxact2systemverilog",
             "lfsr-vhdl",
             "vgg16-on-Zynq",
             "FPGA-Vision",
             "FPGA_GigabitTx",
             "FPGA_image_process",
             "Z80-512K",
             "fpga_bitcoin_miner",
             "vic64-t9k",
             "MicroPET",
             "PYNQ_softmax",
             "HDLab-FPGA-Development-Board",
             "JSON-for-VHDL",
             "PipelineC",
             "ZYNQ-PYNQ-Z2-Gobang",
             "boxlambda",
             "vhdl-hdmi-out",
             "FPGA-OV2640",
             "LibreSDRB210",
             "ZYNQ7010-7020_AD9363",
             "forth-cpu",
             "muhammadaldacher",
             "spi-fpga",
             "MandelbrotInVHDL",
             "NN_RGB_FPGA",
             "SiaFpgaMiner",
             "openfpga-asteroids",
             "uart-for-fpga",
             "MIPS-processor",
             "gnss-baseband",
             "neoapple2",
             "neppielight",
             "Basys3",
             "XJTU-Tripler",
             "Zybo-Z7-20-pcam-5c",
             "flexray-interceptor",
             "fmcw3",
             "mce2vga",
             "rgb2vga",
             "zynq_tdc",
             "Designing-a-Custom-AXI-Slave-Peripheral",
             "Pacman-TangNano9k",
             "flearadio"
             ]

    repos_language = {
         "General-CNN-Accelerator": "vhdl",
         "fos": "vhdl",
         "cpu_for_nscscc2022_single": "vhdl",
         "acSLAM": "vhdl",
         "AppleIISd": "vhdl",
         "FPGA-I2C-Minion": "vhdl",
         "FPGA-Speech-Recognition": "vhdl",
         "NTSC-composite-encoder": "vhdl",
         "Spiking_NN_RGB_FPGA": "vhdl",
         "VGA-Text-Generator": "vhdl",
         "spi-to-axi-bridge": "vhdl",
         "uart": "vhdl",
         "FPGA-Class-D-Amplifier": "vhdl",
         "ZynqBTC": "vhdl",
         "bit-serial": "vhdl",
         "formal_hw_verification": "vhdl",
         "ipxact2systemverilog": "vhdl",
         "lfsr-vhdl": "vhdl",
         "vgg16-on-Zynq": "vhdl",
         "FPGA-Vision": "vhdl",
         "FPGA_GigabitTx": "vhdl",
         "FPGA_image_process": "vhdl",
         "Z80-512K": "vhdl",
         "fpga_bitcoin_miner": "vhdl",
         "vic64-t9k": "vhdl",
         "MicroPET": "vhdl",
         "PYNQ_softmax": "vhdl",
         "HDLab-FPGA-Development-Board": "vhdl",
         "JSON-for-VHDL": "vhdl",
         "PipelineC": "vhdl",
         "ZYNQ-PYNQ-Z2-Gobang": "vhdl",
         "boxlambda": "vhdl",
         "vhdl-hdmi-out": "vhdl",
         "FPGA-OV2640": "vhdl",
         "LibreSDRB210": "vhdl",
         "ZYNQ7010-7020_AD9363": "vhdl",
         "forth-cpu": "vhdl",
         "muhammadaldacher": "vhdl",
         "spi-fpga": "vhdl",
         "MandelbrotInVHDL": "vhdl",
         "NN_RGB_FPGA": "vhdl",
         "SiaFpgaMiner": "vhdl",
         "openfpga-asteroids": "vhdl",
         "uart-for-fpga": "vhdl",
         "MIPS-processor": "vhdl",
         "gnss-baseband": "vhdl",
         "neoapple2": "vhdl",
         "neppielight": "vhdl",
         "Basys3": "vhdl",
         "XJTU-Tripler": "vhdl",
         "Zybo-Z7-20-pcam-5c": "vhdl",
         "flexray-interceptor": "vhdl",
         "fmcw3": "vhdl",
         "mce2vga": "vhdl",
         "rgb2vga": "vhdl",
         "zynq_tdc": "vhdl",
         "Designing-a-Custom-AXI-Slave-Peripheral": "vhdl",
         "Pacman-TangNano9k": "vhdl",
         "flearadio": "vhdl"
    }


class CodexTokenizer:
    def __init__(self):
        self.tokenizer = tiktoken.encoding_for_model("gpt-3.5-turbo-instruct")
        # self.tokenizer = tiktoken.get_encoding("p50k_base")

    def tokenize(self, text):
        # return self.tokenizer.encode(text)
        return self.tokenizer.encode(text, allowed_special={'<|endoftext|>'})

    def decode(self, token_ids):
        return self.tokenizer.decode(token_ids)


class CodeGenTokenizer_v2: # Renamed slightly to avoid duplicate class name conflict if necessary
    def __init__(self, tokenizer):
        self.tokenizer = tokenizer

    def tokenize(self, text):
        return self.tokenizer.encode(text)

    def decode(self, token_ids):
        return self.tokenizer.decode(token_ids)


def iterate_repository_file(base_dir, repo):
    lang = CONSTANTS.repos_language.get(repo, "").lower()
    
    if lang == "python":
        pattern = os.path.join(f'{base_dir}/{repo}', "**", f"*.py")
        return glob.glob(pattern, recursive=True)
    
    elif lang == "java":
        pattern = os.path.join(f'{base_dir}/{repo}', "**", f"*.java")
        return glob.glob(pattern, recursive=True)
    
    elif lang == "cpp":
        # C++ projects use various extensions for headers and source files
        extensions = ["*.cpp", "*.hpp", "*.h", "*.cc", "*.cxx", "*.hxx", "*.c"]
        files = []
        for ext in extensions:
            pattern = os.path.join(f'{base_dir}/{repo}', "**", ext)
            files.extend(glob.glob(pattern, recursive=True))
        return files

    elif lang == "verilog":
        # Supports both Verilog (.v, .vh) and SystemVerilog (.sv, .svh)
        extensions = ["*.v", "*.sv", "*.vh", "*.svh"]
        files = []
        for ext in extensions:
            pattern = os.path.join(f'{base_dir}/{repo}', "**", ext)
            files.extend(glob.glob(pattern, recursive=True))
        return files

    elif lang == "vhdl":
        # Standard VHDL extensions
        extensions = ["*.vhd", "*.vhdl"]
        files = []
        for ext in extensions:
            pattern = os.path.join(f'{base_dir}/{repo}', "**", ext)
            files.extend(glob.glob(pattern, recursive=True))
        return files

    elif lang == "scala":
        # Standard Scala and Scala Script extensions (common for Chisel)
        extensions = ["*.scala", "*.sc"]
        files = []
        for ext in extensions:
            pattern = os.path.join(f'{base_dir}/{repo}', "**", ext)
            files.extend(glob.glob(pattern, recursive=True))
        return files
    
    else:
        raise NotImplementedError(f"Language support for {lang} not implemented.")


def iterate_repository_json_file(base_dir, repo):
    pattern = os.path.join(f'{base_dir}/{repo}', "**", "*.json")
    files = glob.glob(pattern, recursive=True)
    return files


def make_needed_dir(file_path):
    dir_path = os.path.dirname(file_path)
    if not os.path.exists(dir_path):
        os.makedirs(dir_path)
    return


def load_pickle(fname):
    with open(fname, 'rb') as f:
        return pickle.load(f)


def set_default(obj):
    if isinstance(obj, set):
        return list(obj)
    raise TypeError


def dump_jsonl(obj, fname):
    with open(fname, 'w', encoding='utf8') as f:
        for item in obj:
            f.write(json.dumps(item, default=set_default) + '\n')


def load_jsonl(fname):
    with open(fname, 'r', encoding='utf8') as f:
        lines = []
        for line in f:
            lines.append(json.loads(line))
        return lines


def graph_to_json(obj: nx.MultiDiGraph):
    return json.dumps(json_graph.node_link_data(obj), default=set_default)


def json_to_graph(json_format):
    graph_js = json.loads(json_format)
    graph = json_graph.node_link_graph(graph_js)
    return graph


def tokenize(code):
    tokenizer = CodexTokenizer()
    return tokenizer.tokenize(code)