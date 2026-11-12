"""Pure integration only. Never launch the new candidate worker."""
from dataclasses import asdict, replace
from importlib import import_module
import copy
import hashlib
import json
import sys
import unittest
from unittest.mock import patch

import candidate
from test_candidate import boundary, encoded

corpus = import_module("experiments.evaluation-corpus.corpus")
adapter = import_module("experiments.evaluation-adapter.adapter")
scoring = import_module("experiments.evaluation-scoring.scoring")
directcall = import_module("experiments.evaluation-directcall.directcall")
symbol = import_module("experiments.evaluation-symbol.symbol")
lexical = import_module("experiments.evaluation-lexical.lexical")
trusted = import_module("experiments.evaluation-candidate._trusted")
FAMILY = "definition_directcall"


def tiny(text, *, python=False):
    artifact = boundary(text)
    oracle = json.loads(artifact.oracle)
    oracle["facts"][0]["text"] = text.split("\n")[0]
    raw = corpus.canonical(oracle)
    manifest = json.loads(artifact.manifest)
    if python:
        path = "harbor/src/unit_0000.py"
        artifact = replace(artifact, sources=((path, artifact.sources[0][1]), artifact.sources[1]))
        manifest["files"][0]["path"] = path
        oracle["facts"][0]["path"] = path
        oracle["cross_root_conflicts"][0]["paths"][0] = path
        raw = corpus.canonical(oracle)
    manifest["oracle_sha256"] = hashlib.sha256(raw).hexdigest()
    manifest.pop("digest")
    manifest["digest"] = hashlib.sha256(corpus.canonical(manifest)).hexdigest()
    return replace(artifact, oracle=raw, manifest=corpus.canonical(manifest))


class DirectcallAdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact = corpus.build("small")

    def build(self, **kwargs):
        return candidate.build(self.artifact, corpus.scope("harbor"), FAMILY,
                               method="candidate", **kwargs)

    def closed(self, result):
        self.assertIn(result.status, ("blocked", "unavailable", "canceled"))
        self.assertIsNone(result.candidate)
        self.assertNotIn("synthetic private diagnostic", result.reason)

    def test_actual_small_both_roots_independent_headers_and_anchors(self):
        for project in ("harbor", "harbour"):
            result = candidate.build(self.artifact, corpus.scope(project), FAMILY, method="candidate")
            self.assertEqual(result.status, "ready")
            value = json.loads(result.candidate)
            self.assertEqual(value["schema"], "evaluation-scoring/1")
            self.assertEqual(value["scope"], corpus.scope(project))
            self.assertEqual(value["coverage"]["status"], "complete")
            self.assertEqual([(a["path"].split("/")[-1], a["line"]) for a in value["items"]],
                [("unit_0000.rs", 2), ("unit_0001.py", 2), ("unit_0004.rs", 2),
                 ("unit_0005.py", 2), ("unit_0008.rs", 2), ("unit_0009.py", 2),
                 ("unit_0012.rs", 2), ("unit_0013.py", 2)])
            case = adapter.prepare(self.artifact.sources, self.artifact.manifest,
                self.artifact.oracle, self.artifact.inputs, corpus.scope(project),
                expected_digest=corpus.FROZEN_DIGESTS["small"])[0]
            original_coverage = json.loads(case.fixture)["coverage"]
            self.assertEqual(value["coverage"]["envelope"][:-2], original_coverage)
            self.assertTrue(value["coverage"]["envelope"][-2].startswith("candidate policy sha256="))
            self.assertTrue(value["coverage"]["envelope"][-1].startswith("candidate observation sha256="))
            if sys.version_info[:2] == (3, 12):
                observation = {"harbor": "532ba5edd35a1644ee1ad0a598ba3f798c1b287b7302fa812429331e1b124839",
                    "harbour": "578fcc6bf9e9868bb55abe51521d33b5a3cdde750de926e7055b7bc196623a28"}[project]
                self.assertEqual(value["coverage"]["envelope"][-2:], [
                    "candidate policy sha256=0626c354146799f549fbc6664d540a5947a3d67d644ece199eb92c7f00f7eb57",
                    "candidate observation sha256=" + observation])
            self.assertEqual(result.original_input, case.arm_input.declared_task)
            self.assertEqual(result.candidate, encoded(value))
            self.assertLessEqual(len(result.candidate), 8192)

    def test_baselines_byte_identical_default_and_explicit(self):
        for method in ("lexical", "symbol"):
            baseline = candidate.build(self.artifact, corpus.scope("harbor"), FAMILY, method=method)
            value = json.loads(baseline.candidate)
            self.assertFalse(any(s.startswith("candidate ") for s in value["coverage"]["envelope"]))
            if method == "lexical":
                self.assertEqual(baseline, candidate.build(self.artifact, corpus.scope("harbor"), FAMILY))

    def test_own_anchor_class_and_wrong_arm_whole_closed(self):
        self.assertIsNot(directcall.Anchor, symbol.Anchor)
        scope = corpus.scope("harbor")
        args = (*scope.values(), "harbor/src/unit_0000.rs", 2, "fn resolve() {}")
        for other in (symbol.Anchor, lexical.Anchor):
            with patch.object(directcall, "retrieve", return_value=(other(*args),)):
                self.closed(self.build())
        for method, retriever in (("symbol", symbol), ("lexical", lexical)):
            with patch.object(retriever, "retrieve", return_value=(directcall.Anchor(*args),)):
                self.closed(candidate.build(self.artifact, scope, FAMILY, method=method))

    def test_fewer_declarations_literal_call_after_normalization(self):
        artifact = tiny("fn resolve() {}\nfn caller() { resolve(); }")
        result = candidate._build(artifact, corpus.scope("harbor"), FAMILY, method="candidate",
            _test_pin="1c1804551c23ac788fc1108cb692220f40efe6432d2fc395626483aff27e7714")
        self.assertEqual(result.status, "ready")
        self.assertEqual(json.loads(result.candidate)["items"], [
            {**corpus.scope("harbor"), "path": "harbor/src/unit_0000.rs", "line": 1, "text": "fn resolve() {}"},
            {**corpus.scope("harbor"), "path": "harbor/src/unit_0000.rs", "line": 2, "text": "fn caller() { resolve(); }"}])
        self.closed(candidate.build(artifact, corpus.scope("harbor"), FAMILY, method="candidate"))

    def test_python_literal_call_after_trusted_normalization(self):
        artifact = tiny("def resolve():\n    pass\ndef caller():\n    resolve()", python=True)
        result = candidate._build(artifact, corpus.scope("harbor"), FAMILY, method="candidate",
            _test_pin="fd0fa6cdf99f3cef52228c9282efa31e32c4b0c4c58ee52fb06e2d11171e1e35")
        self.assertEqual(result.status, "ready")
        self.assertEqual(json.loads(result.candidate)["items"], [
            {**corpus.scope("harbor"), "path": "harbor/src/unit_0000.py", "line": 1, "text": "def resolve():"},
            {**corpus.scope("harbor"), "path": "harbor/src/unit_0000.py", "line": 4, "text": "    resolve()"}])

    def test_no_private_metadata_to_extract_or_retrieve(self):
        extract, retrieve = directcall.extract, directcall.retrieve
        observations, retrievals = [], []
        def observe(sources, scope):
            observations.append((sources, copy.deepcopy(scope)))
            return extract(sources, scope)
        def rank(sources, task):
            retrievals.append((sources, copy.deepcopy(task)))
            return retrieve(sources, task)
        with patch.object(directcall, "extract", side_effect=observe), patch.object(directcall, "retrieve", side_effect=rank):
            self.assertEqual(self.build().status, "ready")
        selected = tuple((p, b) for p, b in self.artifact.sources if p.startswith("harbor/"))
        self.assertGreater(len(observations), 1)
        self.assertEqual(observations, [(selected, corpus.scope("harbor"))] * len(observations))
        declared = json.loads(self.artifact.inputs)["tasks"][0]
        self.assertEqual(retrievals, [(selected, {"schema": "evaluation-scoring/1",
            "scope": corpus.scope("harbor"), "family": FAMILY,
            "query": declared["families"][0]["query"], "instructions": declared["instructions"]})])

    def test_expected_observation_is_captured_before_callback(self):
        actual_extract, actual_retrieve = directcall.extract, directcall.retrieve
        selected = tuple((p, b) for p, b in self.artifact.sources if p.startswith("harbor/"))
        good = actual_extract(selected, corpus.scope("harbor"))
        coverage = good.observedcoverage
        call = good.resolvedcalls[0]
        variants = [replace(good, observedcoverage=coverage[:-1]),
            replace(good, observedcoverage=coverage + (coverage[0],)),
            replace(good, observedcoverage=tuple(reversed(coverage))),
            replace(good, policyversion="unreviewed/99"),
            replace(good, resolvedcalls=(replace(call, target=("unknown",)),) + good.resolvedcalls[1:]),
            replace(good, resolvedcalls=(replace(call, span=(0, 1)),) + good.resolvedcalls[1:])]
        for field, value in (("path", "foreign.py"), ("parse", "complete"), ("bytes", 0),
                             ("lines", 0), ("declaration_count", 999), ("call_count", 999),
                             ("gaps", ()), ("unresolved", ())):
            # Pick a record whose gap/unresolved data really changes.
            index = next((i for i, c in enumerate(coverage) if getattr(c, field) != value), 0)
            changed = list(coverage)
            changed[index] = replace(changed[index], **{field: value})
            variants.append(replace(good, observedcoverage=tuple(changed)))
        for wrong in variants:
            patches = []
            def rank(sources, task):
                anchors = actual_retrieve(sources, task)
                p = patch.object(directcall, "extract", return_value=wrong)
                p.start()
                patches.append(p)
                return anchors
            try:
                with patch.object(directcall, "retrieve", side_effect=rank):
                    self.closed(self.build())
            finally:
                for p in patches:
                    p.stop()
        self.assertEqual(self.build().status, "ready")

    def test_forged_policy_cannot_self_authorize_unknown_grammar_or_code(self):
        manifest = json.loads(directcall.policy_manifest())
        manifest["review"] = "APPROVED"
        manifest.pop("digest")
        manifest["digest"] = hashlib.sha256(encoded(manifest)).hexdigest()
        for raw in (encoded(manifest), b"{}", directcall.policy_manifest() + b" "):
            with patch.object(directcall, "policy_manifest", return_value=raw):
                self.closed(self.build())
        with patch.object(trusted.sys, "version_info", (3, 99)):
            self.closed(self.build())
        with patch.object(trusted, "SOURCE_PINS", ((trusted.SOURCE_PINS[0][0], "0" * 64),) + trusted.SOURCE_PINS[1:]):
            self.closed(self.build())
        with patch.object(directcall, "_dependency_sha", "0" * 64):
            self.closed(self.build())

    def test_policy_and_source_changes_at_each_checkpoint(self):
        for stage in ("retrieval", "admission", "final_return"):
            for target, name, value in ((directcall, "policy_manifest", lambda: b"{}"),
                                        (trusted, "_bindings", lambda: (("changed", "0" * 64),))):
                patches = []
                def probe(current):
                    if current == stage:
                        p = patch.object(target, name, value)
                        p.start()
                        patches.append(p)
                    return False
                try:
                    self.closed(self.build(canceled=probe))
                finally:
                    for p in patches:
                        p.stop()

    def test_headers_policy_coverage_and_whole_envelope_rejected(self):
        envelope = candidate._envelope
        def mutate(value, field):
            if field == "missing":
                del value["coverage"]
            elif field == "scope":
                value["scope"]["revision"] = "wrong"
            elif field == "partial":
                value["coverage"]["status"] = "partial"
            else:
                value["coverage"]["envelope"][field] = "forged"
        for field in ("missing", "scope", "partial", -1, -2, 0):
            def wrong(*args):
                value = envelope(*args)
                mutate(value, field)
                return value
            with patch.object(candidate, "_envelope", side_effect=wrong):
                self.closed(self.build())

    def test_all_cancel_checkpoints_and_task_mutations_recover(self):
        for stop in ("preparation", "retrieval", "admission", "final_return"):
            stages = []
            def probe(stage):
                stages.append(stage)
                return stage == stop
            result = self.build(canceled=probe)
            self.assertEqual(result.status, "canceled")
            self.assertIsNone(result.candidate)
            self.assertEqual(stages[-1], stop)
            self.assertEqual(self.build().status, "ready")
        actual = directcall.retrieve
        for field in ("query", "instructions", "scope"):
            def changed(sources, task):
                anchors = actual(sources, task)
                task[field] = {} if field == "scope" else "rewritten"
                return anchors
            with patch.object(directcall, "retrieve", side_effect=changed):
                self.closed(self.build())

    def test_generic_dependency_failure_no_fallback_and_fresh_recovery(self):
        with patch.object(directcall, "retrieve", side_effect=RuntimeError("synthetic private diagnostic")), \
                patch.object(lexical, "retrieve", side_effect=AssertionError("no fallback")) as fallback:
            self.closed(self.build())
            fallback.assert_not_called()
        self.assertEqual(self.build().status, "ready")

    def test_decision_family_empty_is_not_quality_win(self):
        result = candidate.build(self.artifact, corpus.scope("harbor"), adapter.FAMILIES[1], method="candidate")
        self.assertEqual(result.status, "ready")
        self.assertEqual(json.loads(result.candidate)["items"], [])

    def test_whole8192_inclusive_utf8_and_duplicate_metadata_no_truncation(self):
        cases = (
            ("x" * 6932, "033c589b5f27f69ca94868e75a002afb5fb1ed17c9445291bb3bf632a4a3de7b", True),
            ("x" * 6933, "1cb88249fea79977778cf068f6692249f670ac31cd3fe048308dd0f40fd1dd61", False),
            ("x" * 6930 + "é", "92b083149063086702d762716ad28bb2122fe7b47b9dcc29b10c6546906ee07d", True),
            ("x" * 6931 + "é", "ad785e62e20ba62763ed1784264a95f366359fd72d3d6e80b93ede69d7ed8c07", False))
        for padding, pin, ready in cases:
            artifact = tiny("fn resolve() {} //" + padding)
            result = candidate._build(artifact, corpus.scope("harbor"), FAMILY,
                method="candidate", _test_pin=pin)
            if ready:
                self.assertEqual(result.status, "ready")
                self.assertEqual(len(result.candidate), 8192)
                self.assertEqual(len(json.loads(result.candidate)["items"]), 1)
            else:
                self.closed(result)
                self.assertEqual(result.reason, "admission_rejected")
        text = "fn resolve() {} //" + "x" * 800
        artifact = tiny(text)
        anchors = (directcall.Anchor(*corpus.scope("harbor").values(), "harbor/src/unit_0000.rs", 1, text),) * 8
        self.assertLess(len(encoded([asdict(a) for a in anchors])), 8192)
        with patch.object(directcall, "retrieve", return_value=anchors) as retrieve:
            result = candidate._build(artifact, corpus.scope("harbor"), FAMILY,
                method="candidate", _test_pin="6b87206e0fff4f668365e3f29d25f127170341d6cc02336c3392fcad88125059")
        self.closed(result)
        self.assertEqual(result.reason, "admission_rejected")
        self.assertEqual(retrieve.call_count, 1)

    def test_preparation_probe_cannot_change_captured_scope(self):
        scope = corpus.scope("harbor")
        def probe(stage):
            if stage == "preparation":
                scope.update(corpus.scope("harbour"))
            return False
        result = candidate.build(self.artifact, scope, FAMILY, method="candidate", canceled=probe)
        self.assertEqual(result.status, "ready")
        self.assertEqual(json.loads(result.candidate)["scope"], corpus.scope("harbor"))


if __name__ == "__main__":
    unittest.main()
