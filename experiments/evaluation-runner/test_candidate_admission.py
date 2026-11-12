"""Candidate parity via pure bytes only; new actual worker launch is parent-gated."""
import base64
from importlib import import_module
import json
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

import runner as r

candidate = import_module("experiments.evaluation-candidate.candidate")
corpus = import_module("experiments.evaluation-corpus.corpus")
directcall = import_module("experiments.evaluation-directcall.directcall")
trusted = import_module("experiments.evaluation-candidate._trusted")
scoring = import_module("experiments.evaluation-scoring.scoring")


class CandidateReadmissionTests(unittest.TestCase):
    def protocol(self, project="harbor"):
        result = candidate.build(corpus.build("small"), r.scope(project), r.FAMILY, method="candidate")
        self.assertEqual(result.status, "ready")
        return r.envelope("candidate", project, r.bindings(), {
            "status": result.status, "reason": result.reason,
            "original": base64.b64encode(result.original_input).decode("ascii"),
            "candidate": base64.b64encode(result.candidate).decode("ascii")})

    def admit(self, value, project="harbor"):
        return r._admit(r.canonical(value), "candidate", project, r.bindings())

    def test_both_roots_actual_build_readmitted_without_retrieval(self):
        for project in ("harbor", "harbour"):
            value = self.protocol(project)
            with patch.object(directcall, "retrieve", side_effect=AssertionError("no ranking")), \
                    patch.object(candidate, "build", side_effect=AssertionError("no worker fixture")):
                status, original, payload = self.admit(value, project)
            self.assertEqual(status, "ready")
            self.assertEqual(payload, base64.b64decode(value["result"]["candidate"]))
            self.assertEqual(original, base64.b64decode(value["result"]["original"]))

    def test_exact_protocol_mutations_closed(self):
        for field, wrong in (("schema", "evaluation-runner/99"), ("arm", "symbol"),
                ("recipe", "medium"), ("corpus_pin", "0" * 64), ("bindings", {}),
                ("scope", r.scope("harbour")), ("family", "unknown")):
            value = self.protocol()
            value[field] = wrong
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.admit(value)

    def test_exact_policy_observation_original_and_anchor_mutations_closed(self):
        for mutation in ("policy", "observation", "omit", "extra", "order", "partial", "scope", "endpoint", "original"):
            value = self.protocol()
            payload = json.loads(base64.b64decode(value["result"]["candidate"]))
            coverage = payload["coverage"]["envelope"]
            if mutation == "policy":
                coverage[-2] = "candidate policy sha256=" + "0" * 64
            elif mutation == "observation":
                coverage[-1] = "candidate observation sha256=" + "0" * 64
            elif mutation == "omit":
                coverage.pop()
            elif mutation == "extra":
                coverage.append(coverage[-1])
            elif mutation == "order":
                coverage.reverse()
            elif mutation == "partial":
                payload["coverage"]["status"] = "partial"
            elif mutation == "scope":
                payload["scope"]["revision"] = "wrong"
            elif mutation == "endpoint":
                payload["items"][0]["path"] = "harbor/src/unknown.rs"
            else:
                value["result"]["original"] = base64.b64encode(b"{}").decode("ascii")
            value["result"]["candidate"] = base64.b64encode(scoring.canonical(payload)).decode("ascii")
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.admit(value)

    def test_fixed_bindings_cover_helper_and_directcall_stale_fail_closed(self):
        value = self.protocol()
        self.assertIn("evaluation-directcall/directcall.py", value["bindings"])
        self.assertIn("evaluation-candidate/_trusted.py", value["bindings"])
        pins = r.bindings()
        with patch.object(r, "bindings", return_value={**pins, "evaluation-directcall/directcall.py": "0" * 64}):
            with self.assertRaises(ValueError):
                r._admit(r.canonical(value), "candidate", "harbor", pins)
        with patch.object(directcall, "policy_manifest", return_value=b"{}"):
            with self.assertRaises((ValueError, KeyError)):
                self.admit(value)
        with patch.object(directcall, "_dependency_sha", "0" * 64):
            with self.assertRaises(ValueError):
                self.admit(value)

    def test_candidate_prelaunch_policy_gate_without_any_spawn(self):
        with patch.object(subprocess, "Popen") as spawn, \
                patch.object(trusted, "_policy", side_effect=ValueError("unreviewed")):
            result = r.Runner().run("candidate", "harbor")
        self.assertEqual((result.status, result.cleanup), ("dependency_failure", "not_launched"))
        self.assertIsNone(result.candidate)
        spawn.assert_not_called()

    def test_candidate_scaling_and_unknown_arm_preflight_no_spawn(self):
        with patch.object(subprocess, "Popen") as spawn:
            for arm, recipe in (("candidate", "medium"), ("candidate", "large"), ("directcall", "small")):
                self.assertEqual(r.Runner().run(arm, "harbor", recipe=recipe).status, "preflight_rejected")
        spawn.assert_not_called()

    def test_cancel_during_final_binding_reads_supersedes_constructed_receipt(self):
        cleanup, bindings = tempfile.TemporaryDirectory.cleanup, r.bindings
        removed = False
        cancel = threading.Event()
        def remove(state):
            nonlocal removed
            cleanup(state)
            removed = True
        def check():
            value = bindings()
            if removed:
                cancel.set()
            return value
        # Actual authored lifecycle fixture ONLY. Mocked admission receipt tests
        # the return boundary without launching the unreviewed candidate worker.
        with patch.object(tempfile.TemporaryDirectory, "cleanup", remove), \
                patch.object(r, "bindings", check), \
                patch.object(r, "_admit", return_value=("ready", b"synthetic-original", b"synthetic-candidate")):
            result = r.Runner()._fixture("complete", cancel=cancel)
        self.assertTrue(cancel.is_set())
        self.assertEqual((result.status, result.cleanup), ("canceled", "verified"))
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.original_input)


if __name__ == "__main__":
    unittest.main()
