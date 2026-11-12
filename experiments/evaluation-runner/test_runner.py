"""Lifecycle negatives plus reviewed fixed SMALL worker transport conformance."""
from dataclasses import FrozenInstanceError
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

import runner as r


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.assertFalse(r._ACTIVE)
        # A private simulated quarantine test must not poison other unit cases.
        # Production has NO reset API; a new Runner cannot clear quarantine.
        self.latch = mock.patch.object(r, "_QUARANTINED", False)
        self.latch.start()
        self.addCleanup(self.latch.stop)
        self.runner = r.Runner()

    def test_complete_closed_protocol_and_clean_environment(self):
        with mock.patch.dict(os.environ, {"PYTHONPATH": "synthetic", "SYNTHETIC_SECRET": "synthetic"}):
            result = self.runner._fixture("complete")
        self.assertEqual((result.status, result.cleanup, result.target_exit), ("blocked", "verified", 0))
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.original_input)
        with self.assertRaises(FrozenInstanceError):
            result.status = "ready"

    def test_reviewed_actual_small_transport_admission_both_arms_and_roots(self):
        # Added by parent only AFTER independent review and lifecycle gates passed.
        # Source strings remain inert; this is not a quality/performance study.
        for arm in ("lexical", "symbol"):
            for project in ("harbor", "harbour"):
                with self.subTest(arm=arm, project=project):
                    result = self.runner.run(arm, project)
                    self.assertEqual((result.status, result.cleanup, result.target_exit),
                                     ("ready", "verified", 0))
                    self.assertIs(type(result.candidate), bytes)
                    self.assertIs(type(result.original_input), bytes)
                    payload = json.loads(result.candidate)
                    self.assertEqual(payload["scope"], r.scope(project))
                    self.assertEqual(len(payload["items"]), 8)
                    for item in payload["items"]:
                        self.assertEqual({k: item[k] for k in r.scope(project)}, r.scope(project))
                    self.assertFalse(r._QUARANTINED)
                    self.assertFalse(r._ACTIVE)

    def test_public_preflight_never_launches_or_accepts_private_overrides(self):
        with mock.patch.object(subprocess, "Popen") as spawn:
            for arm, project, recipe in (("graph", "harbor", "small"), (True, "harbor", "small"),
                    ("lexical", "foreign", "small"), ("symbol", "harbour", "medium"),
                    ("symbol", "harbour", "large")):
                self.assertEqual(self.runner.run(arm, project, recipe=recipe).status, "preflight_rejected")
            self.assertEqual(self.runner.run("lexical", "harbor", cancel=lambda: False).status,
                             "preflight_rejected")
            with self.assertRaises(TypeError):
                self.runner.run("lexical", "harbor", fixture="complete")
            spawn.assert_not_called()

    def test_prelaunch_cancel_never_launches(self):
        event = threading.Event()
        event.set()
        with mock.patch.object(subprocess, "Popen") as spawn:
            result = self.runner.run("symbol", "harbour", cancel=event)
            self.assertEqual(result.status, "canceled")
            self.assertEqual(result.cleanup, "not_launched")
            spawn.assert_not_called()

    def test_launch_boundary_signal_retains_owner_until_final_signal(self):
        original_spawn, original_kill, original_wait = subprocess.Popen, os.killpg, subprocess.Popen.wait
        owners, events = [], []
        def spawn(*args, **kwargs):
            self.assertEqual(args[0][0:3], [sys.executable, "-I", "-S"])
            owner = original_spawn(*args, **kwargs)
            owners.append(owner)
            os.kill(os.getpid(), signal.SIGTERM)
            return owner
        def kill(group, number):
            self.assertIsNone(owners[0].returncode)
            events.append(number)
            return original_kill(group, number)
        def wait(process, *args, **kwargs):
            events.append("reap")
            return original_wait(process, *args, **kwargs)
        before = {n: signal.getsignal(n) for n in (signal.SIGTERM, signal.SIGINT)}
        with mock.patch.object(subprocess, "Popen", spawn), mock.patch.object(os, "killpg", kill), \
                mock.patch.object(original_spawn, "wait", wait):
            started = time.monotonic()
            result = self.runner._fixture("sleep")
            self.assertLess(time.monotonic() - started, 2)
        self.assertEqual((result.status, result.cleanup), ("canceled", "verified"))
        self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL, "reap"])
        self.assertLess(owners[0].returncode, 0)
        with self.assertRaises(ProcessLookupError):
            os.kill(owners[0].pid, 0)
        self.assertEqual(before, {n: signal.getsignal(n) for n in before})

    def assert_reaped(self):
        evidence = self.runner._evidence
        self.assertTrue(evidence["reaped"])
        self.assertEqual(evidence["exit"], -signal.SIGTERM)
        for key in ("worker", "child"):
            with self.assertRaises(ProcessLookupError):
                os.kill(evidence[key], 0)

    def test_timeout_and_output_eof_do_not_imply_descendant_termination(self):
        for mode in ("descendant", "closed_output"):
            with self.subTest(mode=mode):
                start = time.monotonic()
                result = self.runner._fixture(mode)
                self.assertEqual((result.status, result.cleanup), ("timeout", "verified"))
                self.assertLess(time.monotonic() - start, 3)
                self.assert_reaped()

    def test_aggregate_output_bound_including_descendant_writers(self):
        for mode in ("overflow", "descendant_overflow"):
            with self.subTest(mode=mode):
                result = self.runner._fixture(mode)
                self.assertEqual((result.status, result.cleanup), ("output_overflow", "verified"))
                self.assertGreater(result.output_bytes, 16384)
                self.assertLessEqual(result.output_bytes, 16384 + 4096)
                self.assertIsNone(result.candidate)
                if mode == "descendant_overflow":
                    self.assert_reaped()

    def test_protocol_failures_are_closed_and_sourcefree(self):
        for mode in ("malformed", "partial", "trailing", "nonutf8", "arm", "scope", "pin", "bindings",
                     "unknown", "foreign_scope", "incomplete", "stderr", "duplicate", "closed_candidate"):
            with self.subTest(mode=mode):
                result = self.runner._fixture(mode)
                self.assertEqual((result.status, result.cleanup), ("protocol_rejected", "verified"))
                self.assertIsNone(result.candidate)
                self.assertIsNone(result.original_input)

    def test_nonzero_and_dependency_failure(self):
        result = self.runner._fixture("nonzero")
        self.assertEqual((result.status, result.cleanup, result.target_exit), ("worker_failed", "verified", 7))
        self.assertEqual(self.runner._fixture("dependency").status, "unavailable")
        # Real OS exec failure; not an arbitrary executable accepted by the API.
        with mock.patch.object(sys, "executable", "/nonexistent-threadmark-python"):
            result = self.runner._fixture("complete")
        self.assertEqual((result.status, result.cleanup), ("dependency_failure", "not_launched"))
        self.assertEqual(self.runner._fixture("complete").status, "blocked")

    def test_verified_cleanup_allows_fresh_process_recovery(self):
        first = self.runner._fixture("descendant")
        self.assertEqual(first.cleanup, "verified")
        self.assert_reaped()
        self.assertEqual(r.Runner()._fixture("complete").status, "blocked")

    def test_signal_handlers_fd_and_temp_resources_restored_on_closed_paths(self):
        before = {n: signal.getsignal(n) for n in (signal.SIGTERM, signal.SIGINT)}
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(tempfile, "tempdir", directory):
            descriptors = set(os.listdir("/dev/fd"))
            for mode in ("complete", "partial", "nonzero", "dependency", "unverified"):
                self.runner._fixture(mode)
                self.assertEqual(before, {n: signal.getsignal(n) for n in before})
                self.assertEqual(set(os.listdir("/dev/fd")), descriptors)
                self.assertEqual(list(Path(directory).iterdir()), [])

    def test_public_small_policy_and_fixed_launcher_selection_without_launch(self):
        # Interface-only selection; does NOT launch or mock a successful worker.
        with mock.patch.object(self.runner, "_launch", return_value=r.Result("not_run")) as launch:
            for arm in ("lexical", "symbol"):
                for project in ("harbor", "harbour"):
                    self.assertEqual(self.runner.run(arm, project).status, "not_run")
                    launch.assert_called_with(arm, project, cancel=None)

    def test_final_resource_error_supersedes_receipt_and_restores_handlers(self):
        pipe, close = os.pipe, os.close
        pipes = []
        cancel = threading.Event()
        before = {n: signal.getsignal(n) for n in (signal.SIGTERM, signal.SIGINT)}
        def owned_pipe():
            pair = pipe()
            pipes.append(pair)
            return pair
        def close_with_reported_failure(fd):
            close(fd)
            if pipes and fd == pipes[0][0]:
                # Already closed: simulate a resource-restoration error without
                # deliberately leaking any OS resource in the negative test.
                cancel.set()
                raise OSError("synthetic close failure")
        with mock.patch.object(os, "pipe", owned_pipe), mock.patch.object(os, "close", close_with_reported_failure):
            result = self.runner._fixture("complete", cancel=cancel)
        self.assertEqual((result.status, result.cleanup), ("cleanup_unverified", "unverified"))
        self.assertEqual(before, {n: signal.getsignal(n) for n in before})
        self.assertEqual(r.Runner()._fixture("complete").status, "quarantined")

    def test_unverified_cleanup_blocks_even_a_new_runner(self):
        result = self.runner._fixture("unverified")
        self.assertEqual((result.status, result.cleanup), ("cleanup_unverified", "unverified"))
        with mock.patch.object(subprocess, "Popen") as spawn:
            self.assertEqual(r.Runner()._fixture("complete").status, "quarantined")
            self.assertEqual(r.Runner().run("lexical", "harbor").status, "quarantined")
            spawn.assert_not_called()

    def test_finalization_cancellation_supersedes_constructed_receipt(self):
        cleanup = tempfile.TemporaryDirectory.cleanup
        for use_signal in (False, True):
            event = threading.Event()
            observed = []
            def finish(state):
                cleanup(state)
                observed.append(not Path(state.name).exists())
                if use_signal:
                    os.kill(os.getpid(), signal.SIGTERM)
                else:
                    event.set()
            # Fixture process only; a mocked admission receipt isolates final
            # ownership return without executing the actual candidate worker.
            with self.subTest(signal=use_signal), \
                    mock.patch.object(tempfile.TemporaryDirectory, "cleanup", finish), \
                    mock.patch.object(r, "_admit", return_value=("ready", b"synthetic-original", b"synthetic-candidate")):
                result = self.runner._fixture("complete", cancel=event)
            self.assertEqual(observed, [True])
            self.assertEqual((result.status, result.cleanup), ("canceled", "verified"))
            self.assertIsNone(result.candidate)
            self.assertIsNone(result.original_input)

    def test_active_cancellation_and_sigterm_have_real_reap_evidence(self):
        for use_signal in (False, True):
            with self.subTest(signal=use_signal), tempfile.TemporaryDirectory() as directory, \
                    mock.patch.object(tempfile, "tempdir", directory):
                event = threading.Event()
                observed = []
                def cancel():
                    deadline = time.monotonic() + 2
                    while time.monotonic() < deadline:
                        ready = list(Path(directory).glob("threadmark-runner-*/ready.json"))
                        if ready:
                            observed.append((json.loads(ready[0].read_bytes()), time.monotonic()))
                            if use_signal:
                                os.kill(os.getpid(), signal.SIGTERM)
                            else:
                                event.set()
                            return
                        time.sleep(0.005)
                thread = threading.Thread(target=cancel)
                thread.start()
                try:
                    result = self.runner._fixture("descendant", cancel=event)
                finally:
                    thread.join(timeout=3)
                self.assertFalse(thread.is_alive())
                self.assertTrue(observed)
                self.assertLess(time.monotonic() - observed[0][1], 2)
                self.assertEqual((result.status, result.cleanup), ("canceled", "verified"))
                self.assert_reaped()
                self.assertEqual(list(Path(directory).iterdir()), [])

    def test_owner_death_cooperative_worker_and_descendant_are_not_left_alive(self):
        with tempfile.TemporaryDirectory() as directory:
            owner = subprocess.Popen([sys.executable, "-I", "-S", str(r.HERE / "lifecycle_fixture.py"),
                                      "owner", directory], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     close_fds=True)
            ready = None
            try:
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    files = list(Path(directory).glob("threadmark-runner-*/ready.json"))
                    if files:
                        ready = json.loads(files[0].read_bytes())
                        state = files[0].parent
                        break
                    time.sleep(0.005)
                self.assertIsNotNone(ready, "owned fixture did not become ready")
                owner.kill()  # Real SIGKILL: no Python finally handlers run.
                owner.wait(timeout=2)
                deadline = time.monotonic() + 2
                terminal = state / "terminal.json"
                while time.monotonic() < deadline:
                    if terminal.exists():
                        terminal_data = json.loads(terminal.read_bytes())
                        try:
                            os.kill(ready["worker"], 0)
                        except ProcessLookupError:
                            break
                    time.sleep(0.005)
                self.assertTrue(terminal.exists())
                self.assertEqual(terminal_data["child"], ready["child"])
                self.assertTrue(terminal_data["reaped"])
                self.assertEqual(terminal_data["exit"], -signal.SIGTERM)
                for key in ("worker", "child"):
                    with self.assertRaises(ProcessLookupError):
                        os.kill(ready[key], 0)
            finally:
                if owner.poll() is None:
                    owner.kill()
                    owner.wait(timeout=2)
                owner.stdout.close()
                owner.stderr.close()
                # Only this test's observed owned group, never a broad process kill.
                # Retain identity until helper's owner-EOF final KILL has run.
                if ready is not None:
                    for key in ("worker", "child"):
                        try:
                            os.kill(ready[key], 0)
                        except ProcessLookupError:
                            continue
                        self.fail("owned fixture cleanup unverified; do not run trials")


if __name__ == "__main__":
    unittest.main()
