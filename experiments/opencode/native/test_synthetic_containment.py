"""Pure policy and portable owner tests. Never compile C or launch a sandbox."""
from contextlib import redirect_stdout
import io
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import synthetic_containment as c


def decoded_rules(text):
    """Independent small reader for the emitted SBPL subset, including escapes.

    Tests evaluate the serialized rules, not just substrings of the model.
    This is not Apple's parser or actual sandbox evidence.
    """
    result = []
    for line in text.splitlines():
        if line.startswith(";") or line in ("(version 1)", "(deny default)"):
            continue
        match = re.fullmatch(r'\(allow ([a-z* -]+) \((literal|subpath) ("(?:[^"\\]|\\["\\])*")\)\)', line)
        if not match:
            raise AssertionError("unexpected serialized policy syntax")
        result.append(c.Rule(tuple(match[1].split()), match[2], Path(json.loads(match[3]))))
    return c.Policy(tuple(result))


class PolicyTests(unittest.TestCase):
    def test_import_has_no_process_socket_or_filesystem_side_effects(self):
        spec = importlib.util.spec_from_file_location("_synthetic_inert_import", Path(c.__file__))
        module = importlib.util.module_from_spec(spec)
        with mock.patch.dict(sys.modules, {spec.name: module}), \
                mock.patch.object(subprocess, "Popen", side_effect=AssertionError("launch on import")), \
                mock.patch.object(c.socket, "socket", side_effect=AssertionError("socket on import")), \
                mock.patch.object(tempfile, "mkdtemp", side_effect=AssertionError("artifact on import")), \
                mock.patch.object(Path, "write_text", side_effect=AssertionError("write on import")):
            spec.loader.exec_module(module)

    def test_partial_failure_evidence_remains_content_free_and_not_success(self):
        def fail(evidence):
            evidence["checks"]["completed-control"] = "observed-pass"
            evidence["identities_sha256"]["fixture"] = "0" * 64
            raise c.Blocked("SYNTHETIC-PRIVATE-CONTENT")
        output = io.StringIO()
        with mock.patch.object(c, "_run_guard", fail), \
                mock.patch.object(sys, "argv", ["synthetic_containment.py", "--synthetic-compiler-guard"]), \
                redirect_stdout(output):
            self.assertEqual(c.main(), 1)
        result = json.loads(output.getvalue())
        self.assertEqual(result["result"], "blocked")
        self.assertEqual(result["checks"]["completed-control"], "observed-pass")
        self.assertTrue(all(result["checks"][name] == "NOT_RUN" for name in c._REQUIRED))
        self.assertNotIn("SYNTHETIC-PRIVATE-CONTENT", output.getvalue())

    def test_behavior_survives_quoted_injection_shaped_root_serialization(self):
        for root in (Path("/synthetic/root"), Path('/synthetic/"\\(allow default)/root')):
            model = c.policy(root)
            decoded = decoded_rules(model.serialize())
            self.assertEqual(model, decoded)
            for policy in (model, decoded):
                self.assertTrue(policy.allows("process-exec", root / "probe"))
                self.assertFalse(policy.allows("process-exec", root / "exec-marker"))
                self.assertTrue(policy.allows("file-read*", root / "read-canary"))
                for name in c.STATE:
                    self.assertTrue(policy.allows("file-write*", root / "state" / name / "positive"))
                    self.assertTrue(policy.allows("file-read*", root / "state" / name / "positive"))
                    self.assertFalse(policy.allows("file-write*", root / "state" / (name + "-sibling")))
                for operation in ("network-outbound", "network-inbound", "process-fork", "mach-lookup"):
                    self.assertFalse(any(operation in rule.operations for rule in policy.rules))

    def test_no_private_byte_reads_or_nonstate_writes(self):
        root = Path("/private/synthetic/owned")
        policy = decoded_rules(c.policy(root).serialize())
        for path in (Path("/"), Path("/Users"), Path("/private"), root, root / "state",
                     root / "sibling", root / "outside/home/.config/opencode/config.json",
                     root / "outside/repository/AGENTS.md", root / "outside/config/settings.json",
                     root / "config-inventory", root / "guard.sb"):
            self.assertFalse(policy.allows("file-read*", path), path)
            self.assertFalse(policy.allows("file-write*", path), path)
        self.assertTrue(policy.allows("file-read-metadata", Path("/")))
        self.assertFalse(policy.allows("file-read-metadata", Path("/private/unrelated")))
        for path in (root / "workspace" / "check", root / "probe", root / "guard.sb"):
            self.assertFalse(policy.allows("file-write*", path))
        system = [rule.path for rule in policy.rules if rule.kind == "subpath"
                  and "file-map-executable" in rule.operations]
        self.assertEqual(system, [Path("/usr/lib"), Path("/System/Library/dyld")])

    def test_invalid_paths_and_operations_fail_closed(self):
        for value in ("", "/a\n(allow default)", "/a\x00", "/a\t", "/nonascii-é", "/a\x7f"):
            with self.subTest(value=value), self.assertRaises(c.Blocked):
                c.quoted(value)
        for root in (Path("relative"), Path("/a/../b")):
            with self.assertRaises(c.Blocked):
                c.policy(root)
        for rule in (c.Rule(("process-fork",), "literal", Path("/probe")),
                     c.Rule(("network-outbound",), "literal", Path("/probe")),
                     c.Rule(("file-read*",), "regex", Path("/probe"))):
            with self.assertRaises(c.Blocked):
                c.Policy((rule,)).serialize()

    def test_clean_env(self):
        with mock.patch.dict(os.environ, {"NODE_OPTIONS": "bad", "TEST_SECRET": "synthetic"}):
            env = c.clean_env(Path("/owned"))
        self.assertEqual(set(env), {"HOME", "TMPDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                                    "XDG_DATA_HOME", "XDG_STATE_HOME", "LANG", "LC_ALL", "PATH"})
        self.assertEqual(len({env[key] for key in env if key not in ("LANG", "LC_ALL", "PATH")}), 6)

    def test_cli_rejects_all_inputs_except_fixed_action_before_launch(self):
        for args in ([], ["/bin/sh"], ["--synthetic-compiler-guard", "--profile", "/owned"],
                     ["--synthetic-compiler-guard", "--timeout", "1"]):
            with mock.patch.object(sys, "argv", ["synthetic_containment.py", *args]), \
                    mock.patch.object(c, "run_guard") as run, redirect_stdout(io.StringIO()):
                self.assertEqual(c.main(), 2)
                run.assert_not_called()

    def test_unsupported_os_and_missing_tools_before_artifacts_or_launch(self):
        with mock.patch.object(c.platform, "system", return_value="Linux"), \
                mock.patch.object(c, "artifacts") as artifacts, \
                mock.patch.object(c.owner, "bounded") as launch:
            with self.assertRaises(c.Blocked):
                c.run_guard()
            artifacts.assert_not_called()
            launch.assert_not_called()
        with mock.patch.object(c.platform, "system", return_value="Darwin"), \
                mock.patch.object(c, "SANDBOX", Path("/nonexistent-synthetic-tool")), \
                mock.patch.object(c.owner, "bounded") as launch:
            with self.assertRaises(c.Blocked):
                c.run_guard()
            launch.assert_not_called()

    def test_missing_partial_malformed_duplicate_and_extra_observations_reject(self):
        expected = {"first", "second"}
        self.assertEqual(c.parse_checks(b"second:PASS\nfirst:PASS\n", expected),
                         {"first": "observed-pass", "second": "observed-pass"})
        for output in (b"", b"first:PASS\n", b"first:PASS\nfirst:PASS\n", b"\xff",
                       b"first:PASS\nsecond:FAIL\n", b"first:PASS\nsecond:PASS\nextra:PASS\n",
                       b"first:PASS\r\nsecond:PASS\n", b"first:PASS\nsecond:PASS"):
            with self.assertRaises(c.Blocked):
                c.parse_checks(output, expected)

    def test_failure_cli_does_not_disclose_diagnostics(self):
        output = io.StringIO()
        with mock.patch.object(sys, "argv", ["synthetic_containment.py", "--synthetic-compiler-guard"]), \
                mock.patch.object(c, "run_guard", side_effect=ValueError("SYNTHETIC-PRIVATE-CONTENT")), \
                redirect_stdout(output):
            self.assertEqual(c.main(), 1)
        self.assertNotIn("SYNTHETIC-PRIVATE-CONTENT", output.getvalue())
        self.assertEqual(json.loads(output.getvalue())["result"], "blocked")


class OwnerTests(unittest.TestCase):
    def test_artifact_removal_failure_retains_state_and_blocks_reuse(self):
        root = None
        with mock.patch.object(c, "_QUARANTINED", False), \
                mock.patch.object(c, "_RETAINED_ARTIFACTS", []):
            try:
                with mock.patch.object(shutil, "rmtree", side_effect=OSError("synthetic")):
                    with self.assertRaises(c.Blocked):
                        with c.artifacts() as root:
                            (root / "owned").write_bytes(b"synthetic")
                self.assertTrue(root.exists())
                self.assertEqual(c._RETAINED_ARTIFACTS, [root])
                with self.assertRaises(c.Blocked):
                    with c.artifacts():
                        self.fail("quarantined artifacts reused")
            finally:
                # No process was created; only this exact synthetic test tree.
                if root is not None:
                    shutil.rmtree(root)

    # Existing extraction lifecycle tests cover timeout, aggregate floods, actual
    # cancellation, early output EOF, owner ordering and cooperative descendants
    # through this same helper. Existing host tests cover parent control EOF.
    def python(self, root, code, **kwargs):
        return c.owner.bounded([sys.executable, "-I", "-S", "-c", code], root, {}, **kwargs)

    def test_shared_helper_preserves_diagnostic_status_without_publishing_it(self):
        with c.artifacts() as root:
            code, stdout, stderr, elapsed = self.python(root,
                "import sys; print('synthetic'); print('diagnostic',file=sys.stderr); sys.exit(7)")
            self.assertEqual((code, stdout, stderr), (7, b"synthetic\n", b"diagnostic\n"))
            self.assertGreater(elapsed, 0)
        self.assertFalse(root.exists())

    def test_hard_caps_inclusive_and_invalid_rejected_before_launch(self):
        with mock.patch.object(c.owner.subprocess, "Popen", side_effect=OSError("synthetic")) as spawn:
            for timeout, limit in ((120, 16 * 1024 * 1024), (0.1, 1)):
                with self.assertRaisesRegex(ValueError, "launch or I/O"):
                    c.owner.bounded([], "/", {}, timeout, limit)
            self.assertEqual(spawn.call_count, 2)
            spawn.reset_mock()
            for timeout, limit in ((120.1, 1), (1, 16 * 1024 * 1024 + 1), (0, 1),
                                   (float("nan"), 1), (float("inf"), 1), (True, 1),
                                   (1, True), (1, 1.5), (1, 0)):
                with self.assertRaisesRegex(ValueError, "budget"):
                    c.owner.bounded([], "/", {}, timeout, limit)
            spawn.assert_not_called()

    def test_ordinary_failure_removes_only_owned_artifacts_and_allows_fresh_run(self):
        roots = []
        for _ in range(2):
            with self.assertRaisesRegex(ValueError, "timeout"):
                with c.artifacts() as root:
                    roots.append(root)
                    self.python(root, "import time; time.sleep(30)", timeout=0.2)
            self.assertFalse(root.exists())
        self.assertNotEqual(*roots)
        with c.artifacts() as root:
            self.assertEqual(self.python(root, "print('fresh')")[1], b"fresh\n")

    def fault(self, kind):
        root = None
        retained = []
        original_kill = os.killpg
        original_wait = subprocess.Popen.wait
        original_status = c.owner._target_status
        events = []

        def kill(group, number):
            events.append(number)
            result = original_kill(group, number)
            # Inject a reported permission failure AFTER real finite fixture
            # cleanup. Tests must not strand processes to test quarantine.
            if kind == "permission":
                raise PermissionError("synthetic")
            return result

        def wait(process, *args, **kwargs):
            result = original_wait(process, *args, **kwargs)
            retained.append(process)
            if kind == "reap":
                raise OSError("synthetic reaping failure")
            return result

        def status(ready, record):
            if kind == "missing":
                record = b""
            if kind == "malformed":
                record = b"0\n0\n"
            return original_status(ready, record)

        with mock.patch.object(c, "_QUARANTINED", False), \
                mock.patch.object(c, "_RETAINED_ARTIFACTS", []), \
                mock.patch.object(c.owner, "_QUARANTINED", False), \
                mock.patch.object(c.owner, "_UNVERIFIED_OWNERS", []):
            try:
                with mock.patch.object(os, "killpg", kill), \
                        mock.patch.object(subprocess.Popen, "wait", wait), \
                        mock.patch.object(c.owner, "_target_status", status):
                    with self.assertRaises(c.owner.CleanupUnverified):
                        with c.artifacts() as root:
                            self.python(root, "print('done')")
                self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL])
                self.assertTrue(root.is_dir())
                self.assertEqual(c._RETAINED_ARTIFACTS, [root])
                self.assertTrue(c.owner._QUARANTINED)
                self.assertEqual(c.owner._UNVERIFIED_OWNERS, retained)
                with mock.patch.object(subprocess, "Popen") as launch:
                    with self.assertRaises(c.Blocked):
                        with c.artifacts():
                            self.fail("quarantined run admitted")
                    with self.assertRaises(c.owner.CleanupUnverified):
                        self.python(root, "print('never')")
                    launch.assert_not_called()
            finally:
                # Independent test-only proof: the injected errors happened
                # after real kill/wait; no production quarantine reset exists.
                self.assertTrue(retained)
                self.assertTrue(all(p.returncode == -signal.SIGKILL for p in retained))
                if root is not None:
                    shutil.rmtree(root)

    def test_term_and_kill_permission_failures_quarantine_and_retain(self):
        self.fault("permission")

    def test_missing_status_quarantines_and_retains(self):
        self.fault("missing")

    def test_malformed_status_quarantines_and_retains(self):
        self.fault("malformed")

    def test_reaping_failure_quarantines_and_retains(self):
        self.fault("reap")


if __name__ == "__main__":
    unittest.main()
