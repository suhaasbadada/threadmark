"""Independent-name conformance fixtures, never executed as source or scored."""
import contextlib
from copy import deepcopy
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import selection as s

SCOPE = {"project": "p", "worktree": "w", "revision": "r"}


def task(query="cobalt"):
    return {"schema": "evaluation-scoring/1", "scope": dict(SCOPE),
            "family": "definition_directcall", "query": query,
            "instructions": "Do not send. Do not execute. Permission remains unresolved."}


def source(text, suffix="py"):
    return (("p/a." + suffix, text.encode("utf-8")),)


def result(text, suffix="py", query="cobalt"):
    return json.loads(s.select(source(text, suffix), task(query)))


class SelectionTests(unittest.TestCase):
    def test_python_actual_call_and_original(self):
        value = result("def cobalt(): pass\ndef entry():\n return cobalt()\n")
        self.assertEqual([(x["line"], x["text"]) for x in value["evidence"]],
                         [(1, "def cobalt(): pass"), (3, " return cobalt()")])
        self.assertEqual(value["original_task"], task())
        self.assertEqual(value["selected_categories"], {"definition": 1, "direct_call": 1})

    def test_rust_actual_call(self):
        value = result("fn cobalt() {}\nfn entry() { cobalt(); }", "rs")
        self.assertEqual([x["line"] for x in value["evidence"]], [1, 2])
        self.assertEqual(value["evidence"][1]["categories"], ["direct_call"])

    def test_more_than_eight_declarations_and_callers(self):
        sources = tuple((f"p/{i:02d}.py", b"def cobalt(): pass\ndef entry():\n cobalt()") for i in range(12))
        value = json.loads(s.select(sources, task()))
        self.assertEqual([(x["path"], x["line"]) for x in value["evidence"]],
                         [(f"p/{i:02d}.py", line) for i in range(4) for line in (1, 3)])
        self.assertEqual(value["available_categories"], {"definition": 12, "direct_call": 12})

    def test_definition_only_spills(self):
        value = result("".join(f"class Box{i}:\n def cobalt(self): pass\n" for i in range(10)))
        self.assertEqual([x["line"] for x in value["evidence"]], list(range(2, 17, 2)))
        self.assertEqual(value["selected_categories"]["direct_call"], 0)

    def test_sparse_definitions_spill_calls(self):
        value = result("def cobalt(): pass\ndef entry():\n" + " cobalt()\n" * 10)
        self.assertEqual([x["line"] for x in value["evidence"]], [1, 3, 4, 5, 6, 7, 8, 9])

    def test_empty_match_preserves_coverage(self):
        value = result("def other(): pass\nunknown()")
        self.assertEqual(value["evidence"], [])
        self.assertEqual(value["available_categories"], {"definition": 0, "direct_call": 0})
        self.assertTrue(value["observed_coverage"][0]["unresolved"])

    def test_empty_sources(self):
        value = json.loads(s.select((), task()))
        self.assertEqual(value["evidence"], [])
        self.assertEqual(value["source_scope"]["paths"], [])

    def test_shared_definition_call_and_repeated_calls(self):
        value = result("fn cobalt() { cobalt(); cobalt(); }\nfn entry() { cobalt(); cobalt(); }", "rs")
        self.assertEqual([x["line"] for x in value["evidence"]], [1, 2])
        self.assertEqual(value["evidence"][0]["categories"], ["definition", "direct_call"])
        self.assertEqual(value["selected_categories"], {"definition": 1, "direct_call": 2})

    def test_recursion_dynamic_and_unresolved_gaps_are_extractor_owned(self):
        sources = source("def cobalt():\n return cobalt()\ndef entry():\n obj.cobalt()\n globals()['cobalt']()\n unknown()")
        value = json.loads(s.select(sources, task()))
        self.assertEqual([x["line"] for x in value["evidence"]], [1, 2])
        from dataclasses import asdict
        self.assertEqual(value["observed_coverage"], json.loads(s.canonical(
            [asdict(c) for c in s.directcall.extract(sources, SCOPE).observedcoverage])))
        # globals() is itself an unresolved call as well as its dynamic result.
        self.assertEqual(len(value["observed_coverage"][0]["unresolved"]), 4)

    def test_multiple_identifiers_query_order_and_no_instruction_terms(self):
        text = "def amber(): pass\ndef cobalt(): pass\ndef entry():\n amber()\n cobalt()"
        value = result(text, query="cobalt amber cobalt")
        self.assertEqual([x["line"] for x in value["evidence"]], [2, 5, 1, 4])
        value = result(text, query="COBALT")
        self.assertEqual(value["evidence"], [])

    def test_utf8_path_tie_break_and_repeat_determinism(self):
        sources = (("p/z.py", b"def cobalt(): pass"), ("p/é.py", b"def cobalt(): pass"))
        first = s.select(sources, task())
        self.assertEqual(first, s.select(sources, deepcopy(task())))
        self.assertEqual([x["path"] for x in json.loads(first)["evidence"]], ["p/z.py", "p/é.py"])
        with self.assertRaises(ValueError):
            s.select(tuple(reversed(sources)), task())

    def test_scope_exact_and_foreign_source_closed(self):
        t = task()
        t["scope"] = {"project": "p", "worktree": "new_w", "revision": "new_r"}
        value = json.loads(s.select(source("def cobalt(): pass"), t))
        for item in value["evidence"]:
            self.assertEqual({k: item[k] for k in SCOPE}, t["scope"])
        for scope in ({**SCOPE, "project": "foreign"}, {**SCOPE, "revision": "bad/path"}, {**SCOPE, "extra": "x"}):
            with self.subTest(scope=scope), self.assertRaises(ValueError):
                s.select(source("def cobalt(): pass"), {**task(), "scope": scope})
        with self.assertRaises(ValueError):
            s.select(source("def cobalt(): pass") + (("q/z.py", b"def cobalt(): pass"),), task())

    def test_late_malformed_irrelevant_and_recovery(self):
        good = source("def cobalt(): pass")
        for bad in (b"def broken(", b"\xff", b"x\ry"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                s.select(good + (("p/z.py", bad),), task())
        self.assertEqual(len(json.loads(s.select(good, task()))["evidence"]), 1)

    def test_dependency_failure_no_fallback_fresh_recovery(self):
        sources = source("def cobalt(): pass")
        expected = s.select(sources, task())
        with patch.object(s.directcall, "extract", side_effect=ValueError("private diagnostic")):
            with self.assertRaisesRegex(ValueError, "^invalid or unsupported evidence selection$"):
                s.select(sources, task())
        self.assertEqual(expected, s.select(sources, task()))

    def test_whole_line_unicode_crlf_and_blank_coordinates(self):
        value = result("# é\r\n\r\ndef cobalt(): pass # café\r\ndef entry():\r\n cobalt()\r\n")
        self.assertEqual([(x["line"], x["text"]) for x in value["evidence"]],
                         [(3, "def cobalt(): pass # café"), (5, " cobalt()")])

    def test_task_metadata_exact_not_rewritten_and_input_unmutated(self):
        t = task("Locate cobalt, not amber. Do NOT deploy. é")
        before = deepcopy(t)
        value = json.loads(s.select(source("def cobalt(): pass"), t))
        self.assertEqual(value["original_task"], before)
        self.assertEqual(t, before)
        self.assertEqual(value["policy"], "evidence-selection/1")
        self.assertNotIn("complete", value)

    def test_original_budget_inclusive_and_reject_no_truncation(self):
        t = task()
        t["instructions"] = "x"
        t["instructions"] += "x" * (4096 - len(s.canonical({k: t[k] for k in ("query", "instructions")})))
        value = json.loads(s.select((), t))
        self.assertEqual(value["original_task"], t)
        t["instructions"] += "x"
        with self.assertRaises(ValueError):
            s.select((), t)

    def test_entire_envelope_budget_inclusive_no_cheaper_fallback(self):
        def build(n):
            return source("def cobalt(): pass #" + "x" * n + "\ndef entry():\n cobalt()")
        # Original bytes/coverage digit widths also count. Find the actual boundary.
        low, high = 0, 10000
        while low + 1 < high:
            mid = (low + high) // 2
            try:
                s.select(build(mid), task())
                low = mid
            except ValueError:
                high = mid
        payload = s.select(build(low), task())
        self.assertEqual(len(payload), 8192)
        self.assertEqual(len(json.loads(payload)["evidence"]), 2)
        with self.assertRaises(ValueError):
            s.select(build(high), task())

    def test_invalid_family_schema_and_oracle_fields_fail_before_extract(self):
        for change in ({"family": "generic"}, {"schema": "evidence-selection/1"},
                       {"oracle": []}, {"query": ""}, {"instructions": None}):
            with self.subTest(change=change), patch.object(s.directcall, "extract") as extract:
                with self.assertRaises(ValueError):
                    s.select((), {**task(), **change})
                extract.assert_not_called()

    def test_cli_default_and_invalid_option_have_no_selection_effects(self):
        with patch.object(s, "synthetic") as build, contextlib.redirect_stdout(io.StringIO()) as out:
            s.main([])
            self.assertIn("--synthetic", out.getvalue())
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                s.main(["--synthetic", "/arbitrary/path"])
            build.assert_not_called()

    def test_readable_draft_preserves_request_instructions_and_cited_lines(self):
        original = task("Locate cobalt. Do NOT deploy.")
        payload = s.select(source("def cobalt(): pass\ndef entry():\n cobalt()"), original)
        value = json.loads(payload)
        rendered = s.readable(payload).decode()
        self.assertIn("ORIGINAL REQUEST\n" + original["query"], rendered)
        self.assertIn("INSTRUCTIONS\n" + original["instructions"], rendered)
        for item in value["evidence"]:
            self.assertIn(f'{item["path"]}:{item["line"]}', rendered)
            self.assertIn(item["text"], rendered)
        self.assertIn("not runtime truth", rendered)
        self.assertIn("No execution authorization", rendered)
        self.assertLessEqual(len(rendered.encode()), 8192)
        self.assertEqual(json.loads(payload), value)


if __name__ == "__main__":
    unittest.main()
