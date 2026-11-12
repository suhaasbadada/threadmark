"""Finite stdlib checks; no Graphify, model, provider or Docker access required."""
import copy
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import run


def good():
    return {"schema": 1, "scope": ["orbit", "worktree", "revision"],
            "complete": True, "manifest": ["service.py"], "graph": {
                "nodes": [{"id": "service", "source_file": "service.py",
                           "source_location": "L1", "_origin": "ast"}],
                "edges": [], "failed_sources": [], "skipped_sources": [],
                "extracted_sources": ["service.py"]}}


class AdmissionTests(unittest.TestCase):
    def test_reject_and_recover_without_replacing_last_good(self):
        previous = good()
        mutations = {
            "wrong schema": lambda r: r.update(schema=2),
            "foreign scope": lambda r: r.update(scope=["orbit-next", "worktree", "revision"]),
            "partial": lambda r: r.update(complete=False),
            "missing manifest": lambda r: r.pop("manifest"),
            "failed source": lambda r: r["graph"].update(failed_sources=["service.py"]),
            "missing coverage": lambda r: r["graph"].update(extracted_sources=[]),
            "empty snapshot": lambda r: r["graph"].update(nodes=[]),
            "duplicate id": lambda r: r["graph"]["nodes"].append(copy.deepcopy(r["graph"]["nodes"][0])),
            "foreign path": lambda r: r["graph"]["nodes"][0].update(source_file="../orbit-next/service.py"),
            "bad anchor": lambda r: r["graph"]["nodes"][0].update(source_location="L0"),
            "semantic origin": lambda r: r["graph"]["nodes"][0].update(_origin="semantic"),
            "dangling edge": lambda r: r["graph"]["edges"].append({
                "source": "service", "target": "missing", "source_file": "service.py",
                "source_location": "L1", "_origin": "ast", "confidence": "EXTRACTED"}),
            "node budget": lambda r: r["graph"].update(nodes=[{}] * 2001),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                candidate = copy.deepcopy(previous)
                mutate(candidate)
                with self.assertRaises(ValueError):
                    run.validate(candidate, previous["scope"], previous["manifest"])
                self.assertEqual(previous, good())
                self.assertEqual(run.validate(good(), previous["scope"], previous["manifest"]), previous)

    def test_truncated_json(self):
        with self.assertRaises(json.JSONDecodeError):
            json.loads('{"schema":1,"graph":')

    def test_labels_are_not_upgraded(self):
        for label in ("EXTRACTED", "INFERRED", "AMBIGUOUS", "unlabeled"):
            reply = good()
            reply["graph"]["edges"] = [{"source": "service", "target": "service",
                "source_file": "service.py", "source_location": "L1",
                "_origin": "ast", "confidence": label}]
            if label == "unlabeled":
                with self.assertRaises(ValueError):
                    run.validate(reply, reply["scope"], reply["manifest"])
            else:
                self.assertEqual(run.validate(reply, reply["scope"], reply["manifest"])
                                 ["graph"]["edges"][0]["confidence"], label)


class ProcessTests(unittest.TestCase):
    def test_sigterm_unwinds_worker_and_temporary_directory(self):
        # The selector emits readiness only after bounded() entered its cleanup
        # region. Actual SIGTERM, not a mocked exception, cancels this parent.
        code = '''
import json, selectors, subprocess, sys, tempfile
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import run
run.install_cancellation_handler()
children = []
original_spawn = run.subprocess.Popen
def spawn(*args, **kwargs):
    child = original_spawn(*args, **kwargs)
    children.append(child)
    return child
run.subprocess.Popen = spawn
class ReadySelector(selectors.DefaultSelector):
    announced = False
    def select(self, timeout=None):
        if not self.announced:
            print(json.dumps({"worker": children[0].pid, "temp": directory}), flush=True)
            self.announced = True
        return super().select(timeout)
run.selectors.DefaultSelector = ReadySelector
try:
    with tempfile.TemporaryDirectory(prefix="threadmark-sigterm-") as directory:
        run.bounded([sys.executable, "-I", "-B", "-c", "import time; time.sleep(30)"],
                    Path(directory), {"HOME": directory}, timeout=10)
except run.Canceled:
    raise SystemExit(130)
'''
        state = None
        process = subprocess.Popen(
            [sys.executable, "-I", "-B", "-c", code, str(Path(__file__).parent)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(5), "parent did not become ready")
            state = json.loads(process.stdout.readline())
            self.assertTrue(Path(state["temp"]).is_dir())
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 130)
            self.assertFalse(Path(state["temp"]).exists())
            with self.assertRaises(ProcessLookupError):
                os.kill(state["worker"], 0)
        finally:
            if state is not None:
                try:
                    os.killpg(state["worker"], signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)
            # Only this test's exact experiment-owned path, including on failure.
            if state is not None and Path(state["temp"]).exists():
                import shutil
                shutil.rmtree(state["temp"])

    def test_bounded_failures_and_recovery(self):
        with tempfile.TemporaryDirectory(prefix="threadmark-harness-test-") as directory:
            env = {"HOME": directory, "PATH": os.defpath}
            cases = [("import time; time.sleep(5)", 0.1, 1024),
                     ("import sys; sys.stderr.write('x'*10000)", 2, 1024),
                     ("print('x'*10000)", 2, 1024),
                     ("raise ImportError('synthetic missing dependency')", 2, 1024)]
            for code, timeout, limit in cases:
                with self.subTest(code=code), self.assertRaises(ValueError):
                    run.bounded([sys.executable, "-I", "-B", "-c", code],
                                Path(directory), env, timeout, limit)
            output, _ = run.bounded([sys.executable, "-I", "-B", "-c", "print('recovered')"],
                                    Path(directory), env)
            self.assertEqual(output, b"recovered\n")

    def test_parent_cancellation_reaps_worker(self):
        with tempfile.TemporaryDirectory(prefix="threadmark-cancel-test-") as directory:
            original = run.subprocess.Popen
            children = []

            def spawn(*args, **kwargs):
                child = original(*args, **kwargs)
                children.append(child)
                return child

            with mock.patch.object(run.subprocess, "Popen", side_effect=spawn), \
                    mock.patch.object(run.selectors, "DefaultSelector") as selector:
                selector.return_value.__enter__.return_value.get_map.return_value = True
                selector.return_value.__enter__.return_value.select.side_effect = KeyboardInterrupt
                with self.assertRaises(KeyboardInterrupt):
                    run.bounded([sys.executable, "-I", "-B", "-c", "import time; time.sleep(5)"],
                                Path(directory), {"HOME": directory, "PATH": os.defpath})
            self.assertEqual(len(children), 1)
            self.assertIsNotNone(children[0].poll())

    def test_release_mismatch_fails_before_import(self):
        distribution = mock.Mock(version="0.0.0")
        with mock.patch.object(run.metadata, "distribution", return_value=distribution):
            with self.assertRaisesRegex(ValueError, "unexpected installed release"):
                run.worker(Path("unused"), Path("unused"))


class RecordedEvidenceTests(unittest.TestCase):
    def test_recorded_observations_not_timing_thresholds(self):
        evidence = json.loads(Path(__file__).with_name("results.json").read_text())
        runs = {(r["project"], r["stage"]): r for r in evidence["runs"]}
        graphs = {key: r["envelope"]["graph"] for key, r in runs.items()}
        for project in ("orbit", "orbit-next"):
            cold = graphs[project, "cold"]
            self.assertEqual(cold, graphs[project, "warm"])
            calls = {(e["source"], e["target"]) for e in cold["edges"] if e["relation"] == "calls"}
            self.assertIn(("service_submit", "service_normalize"), calls)
            self.assertIn(("lib_submit", "lib_normalize"), calls)
            renamed = graphs[project, "renamed"]
            self.assertIn("renamed_normalize", {n["id"] for n in renamed["nodes"]})
            self.assertNotIn("service_normalize", {n["id"] for n in renamed["nodes"]})
            self.assertEqual({n["source_file"] for n in graphs[project, "deleted"]["nodes"]}, {"lib.rs"})
            damaged = runs[project, "damaged"]
            self.assertEqual(damaged["admission"], "accepted")
            self.assertEqual(damaged["baseline"]["errors"], ["broken.py: SyntaxError"])
            self.assertIn("broken.py", damaged["envelope"]["graph"]["extracted_sources"])
        self.assertIn("service_normalize", {n["id"] for n in graphs["orbit", "cold"]["nodes"]}
                      & {n["id"] for n in graphs["orbit-next", "cold"]["nodes"]})
        self.assertNotIn("lib_hidden", {n["id"] for n in graphs["orbit", "cold"]["nodes"]})


if __name__ == "__main__":
    unittest.main()
