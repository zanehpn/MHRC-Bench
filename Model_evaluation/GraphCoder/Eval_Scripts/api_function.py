import random
import subprocess
import requests
import re
import os
from typing import List
import shutil
import json
from typing import Dict, List
from openai import OpenAI


def extract_after_think(text: str) -> str:
    """
    Extracts and returns the content after the '</think>' marker.
    If no marker is found, returns an empty string.
    """
    match = re.search(r'</think>(.*)', text, re.DOTALL)
    if match:
        return match.group(1).strip()
    return ""


###############################################
# DeepseekR1 Client Implementation
###############################################
class DeepseekR1Client:
    def __init__(self, api_key: str,
                 base_url: str = "https://api.deepinfra.com/v1/openai",
                 model: str = "deepseek-ai/DeepSeek-V3",
                 temperature: float = 0.7):
        self.api_key = api_key
        self.base_url = base_url
        self.model = model
        self.temperature = temperature
        self.total_tokens_used = 0

    def chat_with_gpt(self, prompt: str, n: int = 1, stop: str = None) -> List[str]:
        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }
        data = {
            'model': self.model,
            'prompt': prompt,
            'temperature': self.temperature,
            'n': n,
        }
        if stop:
            data['stop'] = stop
        response = requests.post(f"{self.base_url}/completions", headers=headers, json=data)
        response.raise_for_status()

        result = response.json()
        self.total_tokens_used += result['usage']['total_tokens']
        return [choice['text'].strip() for choice in result['choices']]


def parse_code_blocks(text: str) -> Dict[str, str]:
    code_blocks = {
        "header": "",
        "cpp": "",
        "error": ""
    }

    try:
        header_match = re.search(r"```(?:h|hpp|header)[\s]*\n(.*?)```", text, re.DOTALL)
        if header_match:
            code_blocks["header"] = header_match.group(1).strip()

        cpp_match = re.search(r"```(?:cpp|c|c\+\+)[\s]*\n(.*?)```", text, re.DOTALL)
        if cpp_match:
            code_blocks["cpp"] = cpp_match.group(1).strip()

        if not code_blocks["header"] and not code_blocks["cpp"]:
            code_blocks["error"] = "No valid code blocks found in response"

    except Exception as e:
        code_blocks["error"] = f"Parsing error: {str(e)}"

    return code_blocks


def deepseek_R1_mcts(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="deepseek-r1",
            messages=[
                {"role": "system", "content": "You are a FPGA engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"

def deepseek_v3(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="deepseek-v3.2",
            messages=[
                {"role": "system", "content": "You are a FPGA engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"


def gpt5(prompt: str) -> str:
    """
    Use the GPT-5 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="gpt-5",
            messages=[
                {"role": "system", "content": "You are a FPGA engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"


def gpt4o(prompt: str) -> str:
    """
    Use the GPT-4o API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are a FPGA engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"


def Qwen32B(prompt: str) -> str:
    """
    Use the Qwen2.5 Coder API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="qwen2.5-coder-32b-instruct",
            messages=[
                {"role": "system", "content": "You are a FPGA engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"


def deepseek_R1_describe(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="deepseek-r1-0528",
            messages=[
                {"role": "system", "content": "You are a FPGA Engineer"},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"

def grok4(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="grok-4",
            messages=[
                {"role": "system", "content": "You are a FPGA Engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"

def gemini2_5(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="gemini-2.5-pro",
            messages=[
                {"role": "system", "content": "You are a FPGA Engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"

def claude_sonnet_4_5_thinking(prompt: str) -> str:
    """
    Use the Deepseek-R1 API to generate response based on the prompt.
    Returns the raw response from the LLM without any processing.
    """
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", ""),
        base_url=os.environ.get("OPENAI_BASE_URL", ""),
    )
    try:
        completions = client.chat.completions.create(
            model="claude-sonnet-4-5-20250929-thinking",
            messages=[
                {"role": "system", "content": "You are a FPGA Engineer."},
                {"role": "user", "content": prompt},
            ],
        )
        if completions:
            return completions.choices[0].message.content
    except Exception as e:
        return f"API Error: {str(e)}"
