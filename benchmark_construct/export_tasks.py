#!/usr/bin/env python3
"""Export exact CST targets into the completion-record format used by training."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tasks', required=True, type=Path)
    parser.add_argument('--repo-root', required=True, type=Path)
    parser.add_argument('--language', required=True, choices=['chisel','hls','systemverilog','vhdl'])
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    records, seen = [], set()
    with args.tasks.open(encoding='utf-8') as stream:
        for line in stream:
            if not line.strip(): continue
            task = json.loads(line)
            relative = Path(task['file'])
            source = (args.repo_root / relative).resolve()
            if not source.is_relative_to(args.repo_root.resolve()):
                raise ValueError('Source must be inside --repo-root')
            if source in seen: raise ValueError(f'Duplicate target for {relative}')
            seen.add(source)
            content = source.read_bytes()
            start, end = task['start_byte'], task['end_byte']
            if not (0 <= start < end <= len(content)): raise ValueError('Invalid CST byte span')
            if content[start:end].decode('utf-8') != task['target']:
                raise ValueError(f'Target mismatch for {relative}')
            records.append({'task_id':relative.parts[0], 'path':str(relative), 'language':args.language,
                            'left_context':content[:start].decode('utf-8'),
                            'groundtruth':task['target'], 'right_context':content[end:].decode('utf-8'),
                            'crossfile_context':'', 'start_byte':start, 'end_byte':end})
    if not records: raise ValueError('No completion tasks')
    ratio = sum(2 <= len(x['groundtruth'].splitlines()) <= 5 for x in records) / len(records)
    if ratio < 0.4:
        raise ValueError(f'Only {ratio:.1%} of targets contain 2-5 lines; the paper requires at least 40%')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('x',encoding='utf-8') as stream:
        for record in records: stream.write(json.dumps(record,ensure_ascii=False)+'\n')
    print(f'Exported {len(records)} tasks; 2-5-line fraction: {ratio:.1%}')


if __name__ == '__main__': main()
