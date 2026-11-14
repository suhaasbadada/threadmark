"""Pure protocol/scorer tests; never repeat the 18-case pilot in CI."""
from dataclasses import replace
import json
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import pilot as p

candidate = p.import_module("experiments.evaluation-candidate.candidate")


class PilotTests(unittest.TestCase):
    def result(self, arm="candidate", project="harbor"):
        value = candidate.build(p.corpus.build("small"), p.r.scope(project), p.r.FAMILY, method=arm)
        self.assertEqual(value.status, "ready")
        return p.r.Result("ready", "verified", 0, 0, value.candidate, value.original_input)

    def test_fixed_order_and_dry_manifest_no_worker_or_retrieval(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(p.r.Runner, "run") as launch, \
                patch.object(candidate, "build", side_effect=AssertionError("no retrieval")):
            output = Path(tmp) / "new"
            self.assertEqual(p.main(["--output", str(output), "--hardware-model", "synthetic-model", "--ram-bytes", "1024"]), 0)
            raw = (output / "manifest.json").read_bytes()
            value = json.loads(raw)
            self.assertEqual(p.scoring.canonical(value), raw)
            self.assertEqual(value["cases"], list(p.CASES))
            self.assertEqual(len(value["cases"]), 18)
            for arm in p.ARMS:
                for project in p.PROJECTS:
                    self.assertEqual(sum(c["arm"] == arm and c["project"] == project for c in value["cases"]), 3)
            self.assertEqual(value["budgets"]["memory_enforcement"], "unavailable")
            self.assertEqual(len(value["corpus_manifest"]["files"]), 32)
            self.assertNotIn("executable", value["environment"])
            self.assertFalse((output / "report.json").exists())
            launch.assert_not_called()

    def test_no_args_and_bad_options_never_launch(self):
        with patch.object(p.r.Runner, "run") as launch, patch("sys.stdout", io.StringIO()), \
                patch("sys.stderr", io.StringIO()):
            self.assertEqual(p.main([]), 0)
            for args in (["--run-small"], ["--recipe", "medium"], ["--arm", "symbol"],
                         ["--output", "unused"], ["--query", "resolve"]):
                with self.assertRaises(SystemExit):
                    p.main(args)
            launch.assert_not_called()

    def test_real_adapter_scorer_all_arms_both_roots_no_ranking_during_rescore(self):
        directcall = p.import_module("experiments.evaluation-directcall.directcall")
        for arm in p.ARMS:
            for project in p.PROJECTS:
                result = self.result(arm, project)
                with patch.object(candidate, "build", side_effect=AssertionError("no build")), \
                        patch.object(directcall, "retrieve", side_effect=AssertionError("no ranking")):
                    measured = p.rescore(result, arm, project)
                score = measured["score"]
                self.assertEqual(score["status"], "valid")
                self.assertEqual(score["payload_bytes"], len(result.candidate))
                self.assertEqual(score["metrics"]["tp"] + score["metrics"]["fn"], score["metrics"]["gold_count"])
                coverage = measured["candidate"]["coverage"]["envelope"]
                if arm == "candidate":
                    self.assertTrue(coverage[-2].startswith("candidate policy sha256="))
                    self.assertTrue(coverage[-1].startswith("candidate observation sha256="))

    def test_protocol_and_score_mutations_reject_whole_result(self):
        result = self.result()
        bad = json.loads(result.candidate)
        bad["items"][0]["project"] = "harbour"
        coverage = json.loads(result.candidate)
        coverage["coverage"]["envelope"].pop()
        for value in (replace(result, status="protocol_rejected"), replace(result, cleanup="unverified"),
                      replace(result, target_exit=1), replace(result, original_input=b"{}"),
                      replace(result, candidate=result.candidate + b"\n"),
                      replace(result, candidate=p.scoring.canonical(bad)),
                      replace(result, candidate=p.scoring.canonical(coverage))):
            with self.assertRaises(ValueError):
                p.rescore(value, "candidate", "harbor")
        with self.assertRaises(ValueError):
            p.rescore(result, "unknown", "harbor")

    def test_retained_manifest_before_launch_and_failure_stops_no_retry(self):
        for status, cleanup in (("protocol_rejected", "verified"), ("timeout", "verified"),
                                ("cleanup_unverified", "unverified"), ("dependency_failure", "not_launched")):
            with tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp)
                frozen = p.manifest("synthetic-model", 1024)
                p._write(directory / "manifest.json", frozen, exclusive=True)
                def launch(arm, project):
                    self.assertEqual((directory / "manifest.json").read_bytes(), p.scoring.canonical(frozen))
                    self.assertEqual(json.loads((directory / "report.json").read_bytes())["results"], [])
                    return p.r.Result(status, cleanup)
                with patch.object(p.r.Runner, "run", side_effect=launch) as run:
                    self.assertEqual(p._run(frozen, directory), 1)
                    run.assert_called_once_with("lexical", "harbor")
                report = json.loads((directory / "report.json").read_bytes())
                self.assertEqual(report["state"], "stopped")
                self.assertEqual(report["results"][0]["status"], status)
                self.assertNotIn("score", report["results"][0])

    def test_manifest_change_trial_budget_and_existing_output_never_launch(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(p.r.Runner, "run") as launch:
            directory = Path(tmp)
            frozen = p.manifest("synthetic-model", 1024)
            p._write(directory / "manifest.json", {**frozen, "cases": []}, exclusive=True)
            self.assertEqual(p._run(frozen, directory), 1)
            launch.assert_not_called()
            with self.assertRaises(FileExistsError):
                p.main(["--run-small", "--output", str(directory), "--hardware-model", "synthetic-model", "--ram-bytes", "1024"])
        with tempfile.TemporaryDirectory() as tmp, patch.object(p.r.Runner, "run") as launch:
            directory = Path(tmp)
            p._write(directory / "manifest.json", frozen, exclusive=True)
            with patch.object(p.time, "monotonic", side_effect=(0, 1790, 1790)):
                self.assertEqual(p._run(frozen, directory), 1)
            launch.assert_not_called()
            report = json.loads((directory / "report.json").read_bytes())
            self.assertEqual(report["results"][0]["status"], "trial_budget_stop")

    def test_three_repetitions_summary_not_independence(self):
        rows = [{"arm": "lexical", "project": "harbor", "runner_elapsed_seconds": n,
                 "candidate_sha256": "synthetic"} for n in (3, 1, 2)]
        summary = p.summaries(rows)[0]
        self.assertEqual(summary["runner_seconds_median"], 2)
        self.assertEqual(summary["runner_seconds_range"], [1, 3])
        self.assertTrue(summary["identical_candidate_bytes"])

    def test_success_retains_every_case_with_actual_scorer_no_worker(self):
        receipts = {(arm, project): self.result(arm, project)
                    for arm in p.ARMS for project in p.PROJECTS}
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            frozen = p.manifest("synthetic-model", 1024)
            p._write(directory / "manifest.json", frozen, exclusive=True)
            with patch.object(p.r.Runner, "run", side_effect=lambda a, b: receipts[a, b]) as run:
                self.assertEqual(p._run(frozen, directory), 0)
                self.assertEqual(run.call_count, 18)
            report = json.loads((directory / "report.json").read_bytes())
            self.assertEqual(report["state"], "complete")
            self.assertEqual([row["case"] for row in report["results"]], list(range(1, 19)))
            self.assertTrue(all(row["score"]["status"] == "valid" for row in report["results"]))


if __name__ == "__main__":
    unittest.main()
