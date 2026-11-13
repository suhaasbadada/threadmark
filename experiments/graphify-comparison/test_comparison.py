"""Pure tests/mocked transport ONLY; not actual Graphify/native evidence."""
from copy import deepcopy
import contextlib
from importlib import import_module
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
p = import_module("experiments.graphify-comparison.pilot")
a = p.a
SCOPE = {"project": "quartz", "worktree": "w", "revision": "r"}
TASK = {"schema": a.scoring.VERSION, "scope": SCOPE, "family": "definition_directcall",
        "query": "cobalt amber", "instructions": "Do not execute or send."}
SOURCES = (("quartz/a.py", b"def amber(): pass\ndef cobalt(): pass\ncobalt()\namber()\n"),
           ("quartz/n.md", b"# cobalt()\n"))


def node(nid, label, line, **extra):
    return {"id": nid, "label": label, "source_file": "quartz/a.py",
            "source_location": "L" + str(line), "file_type": "code", "_origin": "ast",
            "_callable": True, **extra}


def graph():
    return {"nodes": [node("a", "amber()", 1), node("b", "cobalt()", 2),
            node("m", "cobalt()", 1, source_file="quartz/n.md", file_type="document",
                 node_kind="heading", metadata={"private_unused": "/private/ignored"})],
        "edges": [{"source": "a", "target": "b", "relation": "calls", "confidence": "INFERRED",
                   "_origin": "ast", "source_file": "quartz/a.py", "source_location": "L3"},
                  {"source": "b", "target": "a", "relation": "calls", "confidence": "AMBIGUOUS",
                   "_origin": "ast", "source_file": "quartz/a.py", "source_location": "L4"}],
        "input_tokens": 0, "output_tokens": 0, "failed_sources": [], "skipped_sources": [],
        "extracted_sources": [path for path, _ in SOURCES]}


class ComparisonTests(unittest.TestCase):
    def test_shared_query_order_and_interleaving(self):
        result = a.graphify(graph(), SOURCES, TASK)
        self.assertEqual([v["line"] for v in result["items"]], [2, 3, 1, 4])
        self.assertEqual(result["metadata"]["available_categories"], {"definition": 2, "direct_call": 2})

    def test_markdown_metadata_ignored_not_matched_or_forwarded(self):
        result = a.graphify(graph(), SOURCES, TASK)
        self.assertNotIn(b"private_unused", a.scoring.canonical(result))
        self.assertTrue(all(v["path"].endswith(".py") for v in result["items"]))

    def test_no_callable_or_class_name_fallback(self):
        for change in ({"_callable": False}, {"_callable_class": True}, {"label": "pkg.cobalt()"}):
            value = graph()
            value["nodes"][1].update(change)
            result = a.graphify(value, SOURCES, TASK)
            self.assertEqual([i["line"] for i in result["items"]], [1, 4])

    def test_no_relation_guessing(self):
        value = graph()
        for edge in value["edges"]:
            edge["relation"] = "references"
        self.assertEqual([i["line"] for i in a.graphify(value, SOURCES, TASK)["items"]], [2, 1])

    def test_labels_preserved_without_upgrade(self):
        result = a.graphify(graph(), SOURCES, TASK)
        facts = result["metadata"]["selected"]
        self.assertEqual(facts[1]["facts"], [{"kind": "direct_call", "origin": "ast", "confidence": "INFERRED"}])
        self.assertEqual(facts[3]["facts"][0]["confidence"], "AMBIGUOUS")

    def test_every_source_coverage_required_including_markdown(self):
        for key in ("failed_sources", "skipped_sources", "extracted_sources"):
            value = graph()
            value[key] = [SOURCES[0][0]]
            with self.assertRaisesRegex(ValueError, "unsupported_coverage"):
                a.graphify(value, SOURCES, TASK)

    def test_duplicate_ids_and_dangling_endpoints(self):
        for mutate in (lambda g: g["nodes"].append(g["nodes"][0]),
                       lambda g: g["edges"][0].update(target="absent")):
            value = graph()
            mutate(value)
            with self.assertRaises(ValueError):
                a.graphify(value, SOURCES, TASK)

    def test_all_anchors_even_irrelevant_nodes_must_validate(self):
        for field, value in (("source_file", "other/n.md"), ("source_location", "L2"),
                             ("_origin", "semantic"), ("confidence", "CERTAIN")):
            raw = graph()
            raw["nodes"][-1][field] = value
            with self.assertRaises(ValueError):
                a.graphify(raw, SOURCES, TASK)

    def test_unknown_shape_tokens_and_budgets_fail_closed(self):
        for change in ({"extra": 1}, {"input_tokens": True}, {"nodes": [{}] * 2001},
                       {"edges": [{}] * 4001}):
            with self.assertRaises(ValueError):
                a.graphify({**graph(), **change}, SOURCES, TASK)

    def test_malformed_unicode_label_or_source_rejected(self):
        raw = graph()
        raw["nodes"][0]["label"] = "\ud800"
        with self.assertRaises(UnicodeError):
            a.graphify(raw, SOURCES, TASK)
        with self.assertRaises(UnicodeError):
            a.graphify(graph(), (("quartz/a.py", b"\xff"),), TASK)

    def test_lf_crlf_unicode_separator_anchor(self):
        sources = (("quartz/a.py", 's="a\u2028b"\r\ndef cobalt(): pass\r\ncobalt()\r\namber()\r\n'.encode()), SOURCES[1])
        self.assertEqual(a.graphify(graph(), sources, TASK)["items"][0]["text"], "def cobalt(): pass")

    def test_source_constraints_and_no_task_oracle_fields(self):
        for sources, task in ((tuple(reversed(SOURCES)), TASK),
                              (SOURCES + SOURCES[:1], TASK),
                              (SOURCES, {**TASK, "oracle": []}),
                              ((("quartz/../a.py", b"x"),), TASK),
                              ((("quartz/a.py", b"x" * 65537),), TASK)):
            with self.assertRaises(ValueError):
                a.source_map(sources, task)

    def test_shared_dedup_spill_and_eight_slots(self):
        groups = [[(0, b"a", i) for i in range(1, 20)], [(0, b"a", 1), (0, b"a", 20)]]
        self.assertEqual(a.selection._choose(groups), [("a", 1), ("a", 20)] + [("a", i) for i in range(2, 8)])

    def test_historical_raw_holdout_and_no_missing_marker_guess(self):
        raw = json.loads((p.ROOT / "experiments/extraction/results.json").read_bytes())["runs"][0]["envelope"]["graph"]
        # Rebase only test paths, not symbols or relations; no pilot answers involved.
        for item in raw["nodes"] + raw["edges"]:
            item["source_file"] = "quartz/" + item["source_file"]
        for key in ("extracted_sources", "failed_sources", "skipped_sources"):
            raw[key] = ["quartz/" + path for path in raw[key]]
        sources = tuple(sorted(("quartz/" + f.name, f.read_bytes())
                               for f in (p.s.legacy.FIXTURES / "orbit").iterdir()))
        result = a.graphify(raw, sources, {**TASK, "query": "normalize"})
        self.assertEqual([(i["path"], i["line"]) for i in result["items"]],
                         [("quartz/service.py", 4), ("quartz/service.py", 9)])
        for node in raw["nodes"]:
            node.pop("_callable", None)
        self.assertEqual(a.graphify(raw, sources, {**TASK, "query": "normalize"})["items"], [])

    def test_authored_current_condition_full_gold_existing_scorer(self):
        for project in p.old.PROJECTS:
            case = p.fixed(project)
            result = a.authored(case.arm_input.sources, json.loads(case.arm_input.method_task))
            candidate, score = a.candidate(result, json.loads(case.fixture), "authored")
            self.assertEqual(score["metrics"]["gold_count"], 16)
            self.assertEqual(len(candidate["items"]), 8)
            self.assertEqual([s["facts"][0]["kind"] for s in result["metadata"]["selected"]],
                             ["definition", "direct_call"] * 4)
            # Deliberately overbroad MOCK assigns function/call labels even to
            # macro fixture rows. Existing full gold must count those as FPs.
            # All inputs accounted for; NOT a prediction of Graphify behavior.
            raw = {"nodes": [], "edges": [], "input_tokens": 0, "output_tokens": 0,
                   "failed_sources": [], "skipped_sources": [],
                   "extracted_sources": [path for path, _ in case.arm_input.sources]}
            for path, _ in case.arm_input.sources:
                if path.endswith(".rs"):
                    raw["nodes"].append(node(path, "resolve()", 2, source_file=path))
                    raw["edges"].append({"source": path, "target": path, "relation": "calls",
                        "confidence": "EXTRACTED", "_origin": "ast", "source_file": path,
                        "source_location": "L3"})
            mocked = a.graphify(raw, case.arm_input.sources, json.loads(case.arm_input.method_task))
            candidate, score = a.candidate(mocked, json.loads(case.fixture), "graphify")
            self.assertEqual(score["metrics"]["gold_count"], 16)
            self.assertEqual(score["metrics"]["tp"], 4)
            self.assertEqual(score["metrics"]["fp"], 4)
            self.assertLessEqual(len(a.scoring.canonical(candidate)), 8192)

    def test_candidate_whole_coverage_budget_and_metadata_shape(self):
        case = p.fixed("harbor")
        result = a.authored(case.arm_input.sources, json.loads(case.arm_input.method_task))
        base = json.loads(case.fixture)
        base["coverage"].append("x" * 8192)
        with self.assertRaisesRegex(ValueError, "candidate_invalid"):
            a.candidate(result, base, "authored")
        result["metadata"]["private"] = "forbidden"
        with self.assertRaises(ValueError):
            a.candidate(result, json.loads(case.fixture), "authored")

    def test_historical_demo_bytes_unchanged(self):
        expected = {"harbor": "6c7e1f8dbc827400cf6c8222b5934e5f2abff7059fb8861998a99f07bf148696",
                    "harbour": "a0b79443299b9e2d6bc92ba0cfb730b355e2cd74918d27a0a5b4dbd676827be7"}
        # First historical hash is canonical stdout including CLI newline.
        for project, digest in expected.items():
            self.assertEqual(p.sha(a.selection.synthetic(project) + b"\n"), digest)
        readable = {"harbor": "ac2b042812650885d1fd963eded13cb4ed6ddc49d883ad6aa20c6be453dcc512",
                    "harbour": "92f7c358721c2f99cf22c32de4a6b2cdbd6f6e496d3adbf21fb703572a207a40"}
        for project, digest in readable.items():
            self.assertEqual(p.sha(a.selection.readable(a.selection.synthetic(project)) + b"\n"), digest)

    def test_no_native_imports_during_pure_tests(self):
        for name in ("graphify", "tree_sitter", "tree_sitter_rust", "tree_sitter_python"):
            self.assertNotIn(name, sys.modules)

    def test_mocked_twelve_successes_same_registered_order(self):
        frozen = self.frozen()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            p.old._write(output / "manifest.json", frozen, exclusive=True)
            with patch.object(p, "unchanged", return_value=True), patch.object(p, "condition", return_value={
                    "status": "ready", "candidate_sha256": "mocked-not-native-evidence"}) as condition:
                self.assertEqual(p.run(frozen, output, output), 0)
                self.assertEqual([c.args[0] for c in condition.call_args_list], list(p.CASES))
            report = json.loads((output / "report.json").read_bytes())
            self.assertEqual(report["state"], "complete")
            self.assertTrue(all(row["identical_candidate_bytes"] for row in report["determinism"]))

    def frozen(self):
        with patch.object(p.s, "installed_versions", return_value=p.s.PINS):
            return p.manifest("declared-test-machine", 1)

    def test_manifest_fixed_order_pins_frozen_reference_and_algorithms(self):
        frozen = self.frozen()
        self.assertEqual(len(frozen["cases"]), 12)
        self.assertEqual(frozen["old_reference_hashes"], p.REFERENCES)
        self.assertEqual(len(frozen["old_recorded_quality_not_rescored"]), 18)
        for project, byte_count in (("harbor", 2076), ("harbour", 2088)):
            sources = frozen["tasks"][project]["sources"]
            self.assertEqual(sum(v["bytes"] for v in sources.values()), byte_count)
            self.assertEqual(sum(path.endswith(".md") for path in sources), 4)
            self.assertEqual(frozen["tasks"][project]["gold_count"], 16)

    def test_default_opt_in_never_launches(self):
        with patch.object(p, "condition") as condition, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(p.main([]), 0)
        condition.assert_not_called()

    def test_shared_pilot_helper_drift_rejects_binding(self):
        self.assertIn("evaluation-pilot/pilot.py", p.FILES)
        frozen = self.frozen()
        target = p.ROOT / "experiments/evaluation-pilot/pilot.py"
        original = Path.read_bytes
        def changed(path):
            data = original(path)
            return data + b"\n# mocked dependency drift\n" if path == target else data
        with patch.object(Path, "read_bytes", changed):
            self.assertFalse(p.unchanged(frozen))

    def test_mocked_condition_owner_caps_environment_and_source_cleanup(self):
        case = p.CASES[0]
        captured = []
        def bounded(command, work, env, seconds, limit):
            captured.append(work)
            self.assertEqual(command[:3], [sys.executable, "-I", "-B"])
            self.assertEqual((seconds, limit), (15, 262144))
            self.assertNotIn("PYTHONPATH", env)
            self.assertEqual(len(list((work / "source").rglob("*.md"))), 4)
            request = json.loads((work / "request.json").read_bytes())
            self.assertEqual(set(request), {"arm", "task", "sources"})
            expected = p.fixed(case["project"])
            reply = {"schema": "graphify-comparison-worker/1", "status": "ready",
                     "arm": case["arm"], "task": request["task"], "versions": p.s.PINS,
                     "result": a.authored(expected.arm_input.sources, request["task"])}
            return 0, a.scoring.canonical(reply), b"private diagnostic", 0.1
        with tempfile.TemporaryDirectory() as directory, patch.object(p.s.legacy._process, "bounded", side_effect=bounded):
            result = p.condition(case, Path(directory))
            self.assertEqual(result["cleanup"], "verified")
            self.assertNotIn(b"private diagnostic", a.scoring.canonical(result))
            self.assertEqual((Path(directory) / "1.stderr").read_bytes(), b"private diagnostic")
            self.assertEqual(json.loads((Path(directory) / "1.stdout").read_bytes())["arm"], case["arm"])
        self.assertFalse(captured[0].exists())

    def test_mocked_unavailable_coverage_no_candidate(self):
        reply = a.scoring.canonical({"status": "unavailable", "failure": "unsupported_coverage"})
        with tempfile.TemporaryDirectory() as directory, patch.object(p.s.legacy._process, "bounded", return_value=(0, reply, b"", 0)):
            with self.assertRaisesRegex(ValueError, "unsupported_coverage"):
                p.condition(p.CASES[1], Path(directory))

    def test_manifest_retained_before_launch_stop_first_no_retry(self):
        frozen = self.frozen()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            p.old._write(output / "manifest.json", frozen, exclusive=True)
            def fail(case, private):
                self.assertEqual((output / "manifest.json").read_bytes(), a.scoring.canonical(frozen))
                self.assertTrue((output / "report.json").exists())
                raise ValueError("unsupported_coverage")
            with patch.object(p, "unchanged", return_value=True), patch.object(p, "condition", side_effect=fail) as condition:
                self.assertEqual(p.run(frozen, output, output), 1)
                self.assertEqual(condition.call_count, 1)
            report = json.loads((output / "report.json").read_bytes())
            self.assertEqual(report["state"], "stopped")
            self.assertIsNone(report["results"][0]["score"]["metrics"])
            self.assertEqual(report["results"][0]["failure"], "unsupported_coverage")

    def test_binding_change_and_trial_reserve_prevent_worker(self):
        frozen = self.frozen()
        for unchanged, clock in ((False, [0, 0]), (True, [0, 1790, 1790])):
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                p.old._write(output / "manifest.json", frozen, exclusive=True)
                with patch.object(p, "unchanged", return_value=unchanged), patch.object(p, "condition") as condition, patch.object(p.time, "monotonic", side_effect=clock):
                    self.assertEqual(p.run(frozen, output, output), 1)
                    condition.assert_not_called()

    def test_private_reply_mismatch_and_cleanup_failure_stop(self):
        for response in ((0, b'{}', b'', 0), (1, b'', b'private', 0)):
            with tempfile.TemporaryDirectory() as directory, patch.object(p.s.legacy._process, "bounded", return_value=response):
                with self.assertRaises(ValueError):
                    p.condition(p.CASES[0], Path(directory))
        with tempfile.TemporaryDirectory() as directory, patch.object(p.s.legacy._process, "bounded", side_effect=p.s.legacy.CleanupUnverified("private")):
            with self.assertRaises(p.s.legacy.CleanupUnverified):
                p.condition(p.CASES[0], Path(directory))


if __name__ == "__main__":
    unittest.main()
