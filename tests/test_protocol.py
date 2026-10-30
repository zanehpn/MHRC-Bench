"""Small synthetic checks; no benchmark samples or recorded experiment outputs."""
import ast
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import typing
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from metrics import evaluate_em, evaluate_es, normalize_code
from quickstart_score import load_dataset, score_predictions
from release_io import load_test_data
from functional_evaluate import run_one


class Tokenizer:
    def encode(self, text, **kwargs): return [ord(c) for c in text]
    def decode(self, ids, **kwargs): return ''.join(chr(i) for i in ids)


def function_from_source(file, names):
    tree = ast.parse((ROOT/file).read_text())
    keep = []
    for n in tree.body:
        if isinstance(n, ast.FunctionDef) and n.name in names: keep.append(n)
        if isinstance(n, (ast.Assign, ast.AnnAssign)):
            targets = n.targets if isinstance(n,ast.Assign) else [n.target]
            if any(isinstance(t,ast.Name) and t.id in {'LINE_PROMPT_PREFIX','FIM_TOKEN_MAP'} for t in targets): keep.append(n)
    namespace = dict(vars(typing))
    namespace['get_tokenizer'] = lambda name: Tokenizer()
    exec(compile(ast.Module(body=keep, type_ignores=[]),str(file),'exec'),namespace)
    return namespace


class ProtocolTests(unittest.TestCase):
    def test_comment_normalization_in_all_four_languages(self):
        for language, a, b in [('hls','x = 1; // note','x = 1;'),
                               ('systemverilog',"x = 1'b1; /* comment */", "x = 1'b1;"),
                               ('vhdl',"x <= '1'; -- comment", "x <= '1';"),
                               ('chisel','val x = 1 // comment','val x = 1')]:
            self.assertEqual(evaluate_em(a,b,language),1)
            self.assertEqual(evaluate_es(a,b,language),1)

    def test_strings_do_not_lose_comment_markers(self):
        for language, source in [('hls','puts("http://a/*b*/");'),
                                  ('vhdl','report "a--b";'),
                                  ('chisel','val x = "// keep"')]:
            self.assertEqual(normalize_code(source,language),source)
        self.assertNotEqual(normalize_code('x="a  b"','hls'), normalize_code('x="a b"','hls'))

    def test_real_levenshtein_and_bounds(self):
        self.assertAlmostEqual(evaluate_es('kitten','sitting'),4/7)
        for a in ['', 'a', 'abc', 'abcd']:
            for b in ['', 'b', 'abc', 'ab']:
                self.assertLessEqual(evaluate_em(a,b), evaluate_es(a,b))
                self.assertTrue(0<=evaluate_es(a,b)<=1)

    def test_preceding_mode_cannot_see_right_context(self):
        ns=function_from_source('Model_Training/eval_pretrain_fim.py',{'build_truncated_prompt_ids'})
        f=ns['build_truncated_prompt_ids']
        ids=f('LEFT_SENTINEL','RIGHT_SENTINEL','<TARGET>',2048,'dummy',prompt_mode='ltr')
        prompt=Tokenizer().decode(ids)
        self.assertIn('LEFT_SENTINEL',prompt)
        self.assertNotIn('RIGHT_SENTINEL',prompt)
        self.assertLessEqual(len(ids),2048)

    def test_native_fim_keeps_control_tokens_and_budget(self):
        ns=function_from_source('Model_Training/training_model_fim.py',{'build_truncated_fim_prompt_ids','resolve_fim_tokens'})
        for family in ['qwen','deepseek']:
            tokens=ns['FIM_TOKEN_MAP'][family]
            ids=ns['build_truncated_fim_prompt_ids'](Tokenizer(),'L'*300,'R'*300,100,family)
            prompt=Tokenizer().decode(ids)
            self.assertLessEqual(len(ids),100)
            self.assertTrue(prompt.startswith(tokens[0]))
            self.assertTrue(prompt.endswith(tokens[2]))
            self.assertIn(tokens[1],prompt)
            self.assertIn('L',prompt); self.assertIn('R',prompt)

    def test_cst_target_uses_exact_bytes_on_a_partial_line(self):
        from types import SimpleNamespace
        for language in ['chisel','hls','sv','vhdl']:
            ns=function_from_source(f'benchmark_construct/{language}_completion_ts.py',{'extract_span_within_node'})
            source=b'prefix; target(); suffix;'
            node=SimpleNamespace(start_byte=8,end_byte=17,start_point=(0,8),end_point=(0,17))
            prefix,target,line,count=ns['extract_span_within_node'](source,node,None,5)
            self.assertEqual(prefix,'prefix; ')
            self.assertEqual(target,'target();')
            self.assertEqual(count,1)

    def test_scorer_rejects_incomplete_coverage_and_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'predictions.jsonl'
            dataset={'a':{'reference':'x','language':'hls'},'b':{'reference':'y','language':'hls'}}
            path.write_text(json.dumps({'item_id':'a','prediction':'x'})+'\n')
            with self.assertRaises(SystemExit): score_predictions(dataset,path,False)
            path.write_text((json.dumps({'item_id':'a','prediction':'x'})+'\n')*2)
            with self.assertRaises(SystemExit): score_predictions(dataset,path,False)

    def test_bad_json_is_not_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'input.jsonl'; path.write_text('{broken\n')
            with self.assertRaises(json.JSONDecodeError): load_test_data(path)

    def test_nine_category_classifier(self):
        path=ROOT/'benchmark_construct/rule_based_classifier.py'
        spec=importlib.util.spec_from_file_location('rules',path)
        rules=importlib.util.module_from_spec(spec); spec.loader.exec_module(rules)
        entry={'groundtruth':'-- TODO clarify\nx <= y;', 'left_context':'process(a) begin', 'right_context':''}
        result=rules.classify_entry(entry,'vhdl')
        self.assertNotEqual(result['category'],'Design Issues')
        self.assertTrue(0.50<=result['confidence']<=0.90)

    def test_functional_runner_patches_a_copy_and_uses_exit_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); repo=root/'repo'; repo.mkdir()
            target=repo/'source.c'; target.write_text('x=0;')
            harness={'repository':'repo','target_file':'source.c','start_byte':2,'end_byte':3,
                     'command':[sys.executable,'-c',"from pathlib import Path; assert Path('source.c').read_text() == 'x=1;'"]}
            self.assertTrue(run_one(harness,'1','0',root,10)['passed'])
            self.assertFalse(run_one(harness,'2','0',root,10)['passed'])
            self.assertEqual(target.read_text(),'x=0;')
            with self.assertRaises(ValueError): run_one(harness,'1','wrong',root,10)


if __name__ == '__main__': unittest.main()
