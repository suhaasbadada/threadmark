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
import time
from types import SimpleNamespace
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
            print(json.dumps({"group_owner": children[0].pid, "temp": directory}), flush=True)
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
                os.kill(state["group_owner"], 0)
        finally:
            # Killing the still-owned parent closes the helper control pipe.
            # Never signal a recorded group ID after its owner has been reaped.
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

    def python(self, code, **kwargs):
        with tempfile.TemporaryDirectory(prefix="threadmark-owned-test-") as directory:
            return run.bounded([sys.executable, "-I", "-S", "-c", code],
                               Path(directory), {"HOME": directory, "PATH": os.defpath},
                               **kwargs)

    def test_owner_alive_unreaped_until_final_signal_and_all_fds_closed(self):
        events, children, fds = [], [], []
        spawn, kill, wait, pipe = subprocess.Popen, os.killpg, subprocess.Popen.wait, os.pipe

        def record_pipe():
            pair = pipe()
            fds.extend(pair)
            return pair

        def record_spawn(*args, **kwargs):
            self.assertEqual(args[0][:4], [sys.executable, "-I", "-S", str(run.SUPERVISOR)])
            self.assertTrue(kwargs["close_fds"])
            self.assertEqual(len(kwargs["pass_fds"]), 2)
            child = spawn(*args, **kwargs)
            children.append(child)
            return child

        def record_kill(group, number):
            self.assertEqual(group, children[0].pid)
            self.assertIsNone(children[0].returncode)
            os.kill(group, 0)  # Retained helper alive, not just a stale cached PID.
            events.append(number)
            return kill(group, number)

        def record_wait(child, *args, **kwargs):
            events.append("reap")
            return wait(child, *args, **kwargs)

        with mock.patch.object(run.subprocess, "Popen", record_spawn), \
                mock.patch.object(spawn, "wait", record_wait), \
                mock.patch.object(spawn, "poll", side_effect=AssertionError("early owner poll")), \
                mock.patch.object(spawn, "communicate", side_effect=AssertionError("early owner reap")), \
                mock.patch.object(run.os, "killpg", record_kill), \
                mock.patch.object(run.os, "pipe", record_pipe):
            self.assertEqual(self.python("import sys; print('exact'); print('diagnostic', file=sys.stderr)")[0],
                             b"exact\n")
        self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL, "reap"])
        for stream in (children[0].stdin, children[0].stdout, children[0].stderr):
            self.assertTrue(stream.closed)
        for fd in set(fds):
            with self.assertRaises(OSError):
                os.fstat(fd)

    def test_aggregate_budget_and_fresh_recovery_each_time(self):
        for code in ("import os; os.write(2, b'x'*10000)",
                     "import os; os.write(1, b'x'*700); os.write(2, b'y'*700)"):
            with self.subTest(code=code), self.assertRaisesRegex(ValueError, "output budget"):
                self.python(code, limit=1024)
            self.assertEqual(self.python("print('fresh')")[0], b"fresh\n")

    def test_closed_output_does_not_mean_target_completed(self):
        with self.assertRaisesRegex(ValueError, "timeout"):
            self.python("import os,time; os.close(1); os.close(2); time.sleep(30)", timeout=0.2)
        self.assertEqual(self.python("print('fresh')")[0], b"fresh\n")

    def cooperative_descendant(self, mode, startup_delay=0):
        # Fixed synthetic process fixture, not execution of an extraction corpus.
        code = '''
import json, os, signal, sys, time
from pathlib import Path
time.sleep(float(sys.argv[2]))
ready_read, ready_write = os.pipe()
child = os.fork()
if child == 0:
    os.close(ready_read)
    if sys.argv[1] == 'closed':
        os.close(1)
        os.close(2)
    os.write(ready_write, b'1')
    os.close(ready_write)
    while not Path('release').exists():
        time.sleep(0.005)
    if sys.argv[1] == 'overflow':
        os.write(2, b'x' * 10000)
        os.close(1)
        os.close(2)
    time.sleep(30)
    os._exit(0)
def stop(_number, _frame):
    pid, status = os.waitpid(child, 0)
    Path('terminal.json').write_text(json.dumps(
        {'worker': os.getpid(), 'child': pid, 'status': status, 'reaped': True}))
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
os.close(ready_write)
assert os.read(ready_read, 1) == b'1'
os.close(ready_read)
if sys.argv[1] == 'closed':
    os.close(1)
    os.close(2)
Path('ready.tmp').write_text(json.dumps({'worker': os.getpid(), 'child': child}))
Path('ready.tmp').rename('ready.json')
while True:
    time.sleep(0.01)
'''
        # bounded() normally includes launch in its deadline. This private clock
        # seam excludes only the measured fixture setup interval; active work and
        # _finish() still advance with real monotonic time. It is not a latency
        # measurement or a change to production's launch-inclusive watchdog.
        clock = time.monotonic
        origin = clock()
        setup_seconds = 0
        selector_class = selectors.DefaultSelector
        active_budget = 0.3
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = None

            class FixtureReadySelector(selector_class):
                def __enter__(selector):
                    nonlocal setup_seconds, state
                    # Gate before bounded() first calculates remaining work time,
                    # not after its launch-inclusive deadline could already fire.
                    try:
                        end = clock() + 5
                        while not (root / 'ready.json').exists():
                            if clock() >= end:
                                raise AssertionError('fixture startup deadline; active work not tested')
                            time.sleep(0.005)
                        state = json.loads((root / 'ready.json').read_text())
                        for pid in state.values():
                            os.kill(pid, 0)
                        setup_seconds = clock() - origin
                        (root / 'release').touch()
                        return super().__enter__()
                    except BaseException:
                        selector.close()  # Failed __enter__ does not call __exit__.
                        raise

            try:
                with mock.patch.object(run, 'time', SimpleNamespace(
                        monotonic=lambda: clock() - setup_seconds, sleep=time.sleep)), \
                        mock.patch.object(run.selectors, 'DefaultSelector', FixtureReadySelector):
                    with self.assertRaisesRegex(ValueError, 'timeout' if mode == 'closed'
                                                else 'output budget'):
                        run.bounded([sys.executable, '-I', '-S', '-c', code, mode,
                                     str(startup_delay)], root, {'HOME': directory},
                                    timeout=active_budget, limit=1024)
                self.assertIsNotNone(state, 'fixture never activated')
                evidence = json.loads((root / 'terminal.json').read_text())
                self.assertEqual({key: evidence[key] for key in state}, state)
                self.assertTrue(evidence['reaped'])
                self.assertEqual(os.waitstatus_to_exitcode(evidence['status']), -signal.SIGTERM)
                for pid in state.values():
                    with self.assertRaises(ProcessLookupError):
                        os.kill(pid, 0)
                if startup_delay:
                    self.assertGreaterEqual(setup_seconds, startup_delay)
                    self.assertGreater(setup_seconds, active_budget)
            except BaseException:
                # Do not launch fresh trials after missing descendant/wait proof.
                # bounded() owns signaling; never kill a recorded/reaped PGID here.
                run._QUARANTINED = True
                raise
        self.assertEqual(self.python("print('fresh')")[0], b'fresh\n')

    def test_cooperative_descendant_timeout_and_overflow_reaped(self):
        for mode in ("closed", "overflow"):
            with self.subTest(mode=mode):
                self.cooperative_descendant(mode)

    def test_delayed_fixture_startup_is_not_active_worker_timeout(self):
        for mode in ('closed', 'overflow'):
            with self.subTest(mode=mode):
                self.cooperative_descendant(mode, startup_delay=0.45)

    def test_launch_failure_closes_private_fds_without_quarantine(self):
        pipe = os.pipe
        fds = []
        def record_pipe():
            pair = pipe()
            fds.extend(pair)
            return pair
        with mock.patch.object(run.os, "pipe", record_pipe), \
                mock.patch.object(run.subprocess, "Popen", side_effect=OSError("synthetic")):
            with self.assertRaisesRegex(ValueError, "launch or I/O"):
                self.python("print('unused')")
        for fd in fds:
            with self.assertRaises(OSError):
                os.fstat(fd)
        self.assertFalse(run._QUARANTINED)
        self.assertEqual(self.python("print('fresh')")[0], b"fresh\n")

    def test_actual_launch_boundary_cancel_and_cleanup_signal_deferral(self):
        spawn, kill = subprocess.Popen, os.killpg
        children, events = [], []
        old_handler = signal.getsignal(signal.SIGTERM)
        old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())

        def record_spawn(*args, **kwargs):
            child = spawn(*args, **kwargs)
            children.append(child)
            os.kill(os.getpid(), signal.SIGTERM)
            return child

        def record_kill(group, number):
            self.assertIsNone(children[0].returncode)
            events.append(number)
            os.kill(os.getpid(), signal.SIGTERM)  # Must not interrupt cleanup.
            return kill(group, number)

        try:
            run.install_cancellation_handler()
            with mock.patch.object(run.subprocess, "Popen", record_spawn), \
                    mock.patch.object(run.os, "killpg", record_kill):
                with self.assertRaises(run.Canceled):
                    self.python("import time; time.sleep(30)")
            self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL])
            self.assertEqual(children[0].returncode, -signal.SIGKILL)
            self.assertTrue(all(s.closed for s in
                                (children[0].stdin, children[0].stdout, children[0].stderr)))
            self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), old_mask)
            self.assertEqual(self.python("print('fresh')")[0], b"fresh\n")
        finally:
            signal.signal(signal.SIGTERM, old_handler)

    def test_unverified_cleanup_blocks_further_launches(self):
        # Real target/helper finish, but missing private wait proof cannot be success.
        with mock.patch.object(run, "_QUARANTINED", False):
            with mock.patch.object(run, "_target_status", side_effect=run.CleanupUnverified("missing proof")):
                with self.assertRaisesRegex(run.CleanupUnverified, "cleanup unverified"):
                    self.python("print('done')")
            with mock.patch.object(run.subprocess, "Popen") as spawn:
                with self.assertRaises(run.CleanupUnverified):
                    self.python("print('must not launch')")
                spawn.assert_not_called()

    def test_signaling_permission_failure_is_not_silent_cleanup(self):
        kill = os.killpg
        def denied(group, number):
            if number == signal.SIGTERM:
                raise PermissionError("synthetic permission failure")
            return kill(group, number)
        with mock.patch.object(run, "_QUARANTINED", False), \
                mock.patch.object(run.os, "killpg", denied):
            with self.assertRaisesRegex(run.CleanupUnverified, "cleanup unverified"):
                self.python("print('done')")
            self.assertTrue(run._QUARANTINED)

    def test_private_status_is_actual_target_status(self):
        self.assertEqual(run._target_status(b"123\n", b"7\n"), 7)
        for ready, status in ((b"", b"0\n"), (b"123\n", b""),
                              (b"0123\n", b"0\n"), (b"123\n", b"0\n0\n")):
            with self.subTest(ready=ready, status=status), self.assertRaises(run.CleanupUnverified):
                run._target_status(ready, status)
        with self.assertRaisesRegex(ValueError, "dependency/API"):
            self.python("raise SystemExit(7)")
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "dependency/API"):
                run.bounded(["/nonexistent-threadmark-extraction-fixture"], Path(directory), {})
        self.assertEqual(self.python("import sys; print(sys.stdin.read() == '')")[0], b"True\n")

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
