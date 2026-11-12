"""Portable supervisor/policy tests; passing these is NOT containment evidence."""
import json
import os
from pathlib import Path
import signal
import selectors
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import harness as h


class PolicyTests(unittest.TestCase):
    def test_policy_is_default_deny_and_fixed_allowlist(self):
        text = h.profile(Path("/fixture/state"), Path("/fixture/probe"), 12345)
        self.assertIn("(deny default)", text)
        self.assertNotIn("(allow default)", text)
        self.assertNotIn("(import", text)
        self.assertEqual(text.count("(allow network-"), 1)
        self.assertIn('(remote tcp "localhost:12345")', text)
        self.assertIn('(allow file-read* (literal "/"))', text)
        self.assertNotIn('(subpath "/")', text)
        self.assertNotIn("udp", text)
        self.assertNotIn("mach-", text)
        self.assertNotIn("with no-sandbox", text)
        self.assertIn('(allow process-exec (literal "/fixture/probe"))', text)
        self.assertIn('(subpath "/fixture/state")', text)

    def test_system_global_and_user_config_not_in_allowances(self):
        # Policy inspection only. Never open or stat actual config/credential paths.
        text = h.profile(Path("/fixture/state"), Path("/fixture/probe"), 12345)
        for forbidden in (
            "/Library/Application Support/opencode", "/Library/Managed Preferences",
            "/Library/Preferences", "/Users", "/private/etc", "/System/Library/Frameworks",
        ):
            self.assertNotIn(forbidden, text)
        subpaths = [line.strip() for line in text.splitlines() if '(subpath "/' in line]
        self.assertEqual(len(subpaths), 3)  # state, usr/lib, dyld only

    def test_filesystem_policy_has_no_network_allowance(self):
        self.assertNotIn("network", h.filesystem_profile(Path("/state"), Path("/probe")))

    def test_invalid_inputs_fail(self):
        for port in (0, 65536, -1, "123", True, None):
            with self.subTest(port=port), self.assertRaises(h.GuardError):
                h.profile(Path("/state"), Path("/probe"), port)
        with self.assertRaises(h.GuardError):
            h.profile(Path("relative"), Path("/probe"), 123)
        for value in ("/path\n(inject)", "/path\x00", "/non-ascii-\u00e9"):
            with self.assertRaises(h.GuardError):
                h._quoted(value)

    def test_profile_string_escaping(self):
        self.assertEqual(h._quoted('/a"b\\c'), '"/a\\"b\\\\c"')

    def test_clean_environment_does_not_inherit(self):
        with mock.patch.dict(os.environ, {"TEST_SECRET": "synthetic", "DYLD_INSERT_LIBRARIES": "bad"}):
            env = h.clean_env(Path("/fixture/state"))
        self.assertNotIn("TEST_SECRET", env)
        self.assertNotIn("DYLD_INSERT_LIBRARIES", env)
        self.assertEqual(set(env), {"HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME",
                                    "XDG_STATE_HOME", "TMPDIR", "LANG", "LC_ALL", "PATH"})

    def test_unsupported_os_never_launches(self):
        with mock.patch.object(h.platform, "system", return_value="Linux"), \
                mock.patch.object(h, "_run") as run:
            with self.assertRaisesRegex(h.GuardError, "requires macOS"):
                h.run_guard()
            run.assert_not_called()

    def test_missing_tool_never_launches(self):
        with mock.patch.object(h.platform, "system", return_value="Darwin"), \
                mock.patch.object(h, "SANDBOX", Path("/nonexistent-threadmark-sandbox")), \
                mock.patch.object(h, "_run") as run:
            with self.assertRaisesRegex(h.GuardError, "sandbox-exec unavailable"):
                h.run_guard()
            run.assert_not_called()

    def test_unknown_cli_never_launches(self):
        with mock.patch.object(sys, "argv", ["harness.py", "/bin/sh"]), \
                mock.patch.object(h, "run_guard") as run:
            self.assertEqual(h.main(), 2)
            run.assert_not_called()

    def test_fixture_cleanup_even_on_failure(self):
        root = None
        with self.assertRaises(h.GuardError):
            with h.fixtures() as (root, state, outside):
                self.assertEqual(root.stat().st_mode & 0o777, 0o700)
                self.assertEqual(outside.read_bytes(), b"synthetic-outside-unchanged")
                self.assertTrue((state / "database").is_dir())
                raise h.GuardError("synthetic failure")
        self.assertFalse(root.exists())

    def test_compiler_failure_cleans_up_and_no_sandbox_fallback(self):
        roots = []

        def failed_compile(args, **kwargs):
            roots.append(kwargs["cwd"].parent)
            self.assertEqual(args[0], str(h.COMPILER))
            return 1, b"synthetic compiler error"

        with mock.patch.object(h, "require_platform"), \
                mock.patch.object(h, "sdk_path", return_value=Path("/fixture/SDK.sdk")), \
                mock.patch.object(h, "_run", failed_compile):
            with self.assertRaisesRegex(h.GuardError, "compilation failed"):
                h.run_guard()
        self.assertEqual(len(roots), 1)
        self.assertFalse(roots[0].exists())

    def test_parser_accepting_invalid_profile_is_fatal(self):
        calls = []

        def fake_run(args, **kwargs):
            calls.append(args)
            return 0, b""

        with mock.patch.object(h, "require_platform"), \
                mock.patch.object(h, "sdk_path", return_value=Path("/fixture/SDK.sdk")), \
                mock.patch.object(h.Path, "chmod"), mock.patch.object(h, "_run", fake_run):
            with self.assertRaisesRegex(h.GuardError, "invalid policy did not fail closed"):
                h.run_guard()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[1][0:2], [str(h.SANDBOX), "-f"])

    def test_runtime_or_exact_network_rejection_never_falls_back(self):
        for failure in ("runtime", "network"):
            with self.subTest(failure=failure):
                calls = []

                def fake_run(args, **kwargs):
                    calls.append(args)
                    if args[0] == str(h.COMPILER):
                        Path(args[-1]).touch()  # simulated build artifact only
                        return 0, b""
                    name = Path(args[2]).name
                    if name == "invalid.sb":
                        return 65, b"synthetic parser rejection"
                    if name == "filesystem.sb":
                        return (-6, b"") if failure == "runtime" else (0, b"synthetic-guard-ok\n")
                    self.assertEqual(name, "guard.sb")
                    return 65, b"synthetic exact endpoint rejection"

                with mock.patch.object(h, "require_platform"), \
                        mock.patch.object(h, "sdk_path", return_value=Path("/fixture/SDK.sdk")), \
                        mock.patch.object(h, "_run", fake_run):
                    with self.assertRaisesRegex(h.GuardError, "no host may launch"):
                        h.run_guard()
                self.assertEqual(len(calls), 4 if failure == "runtime" else 5)
                for args in calls[1:]:
                    self.assertEqual(args[:2], [str(h.SANDBOX), "-f"])

    def test_missing_sdk_is_explicit(self):
        with mock.patch.object(h, "SDK", Path("/nonexistent-threadmark-sdk")), \
                mock.patch.object(h, "_run", return_value=(1, b"")):
            with self.assertRaisesRegex(h.GuardError, "SDK unavailable"):
                h.sdk_path(Path("/fixture/state"))

    def test_sdk_discovery_rejects_non_system_and_malformed_paths(self):
        for output in (b"/Users/fixture/MacOSX.sdk\n", b"relative.sdk", b"\xff"):
            with self.subTest(output=output), \
                    mock.patch.object(h, "SDK", Path("/nonexistent-threadmark-sdk")), \
                    mock.patch.object(h, "_run", return_value=(0, output)):
                with self.assertRaises(h.GuardError):
                    h.sdk_path(Path("/fixture/state"))

    def test_cancellation_exception_is_not_swallowed_interruption(self):
        with self.assertRaises(h.Cancelled):
            h._cancel(signal.SIGTERM, None)
        self.assertFalse(issubclass(h.Cancelled, InterruptedError))


class SupervisorTests(unittest.TestCase):
    def test_owner_pipe_eof_terminates_running_target_and_group(self):
        read_fd, write_fd = os.pipe()
        process = None
        try:
            process = subprocess.Popen(
                [sys.executable, "-I", "-S", str(h.SUPERVISOR), str(write_fd),
                 sys.executable, "-I", "-S", "-c",
                 "import os,time; print(os.getpid(), flush=True); time.sleep(60)"],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                close_fds=True, pass_fds=(write_fd,), start_new_session=True,
            )
            os.close(write_fd)
            write_fd = None
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(5), "target never became ready")
            target_pid = int(process.stdout.readline())
            process.stdin.close()  # Actual owner-channel EOF while target is alive.
            self.assertEqual(process.wait(timeout=2), -signal.SIGKILL)
            with self.assertRaises(ProcessLookupError):
                os.kill(target_pid, 0)
        finally:
            if process is not None:
                if process.returncode is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=2)
                process.stdin.close()
                process.stdout.close()
                process.stderr.close()
            os.close(read_fd)
            if write_fd is not None:
                os.close(write_fd)

    def test_group_identity_is_not_reaped_until_after_last_group_signal(self):
        events = []
        original_wait = subprocess.Popen.wait
        original_kill = os.killpg

        def wait(process, *args, **kwargs):
            events.append("reap")
            return original_wait(process, *args, **kwargs)

        def kill(group, number):
            events.append(number)
            return original_kill(group, number)

        with mock.patch.object(subprocess.Popen, "wait", wait), \
                mock.patch.object(os, "killpg", kill):
            self.assertEqual(self.run_python("print('done')"), (0, b"done\n"))
        self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL, "reap"])

    def test_real_launch_boundary_cancellation_records_owner_before_delivery(self):
        original = subprocess.Popen
        children = []
        events = []
        original_kill = os.killpg

        def spawn(*args, **kwargs):
            child = original(*args, **kwargs)
            children.append(child)
            os.kill(os.getpid(), signal.SIGTERM)  # Deferred while Popen ownership is recorded.
            return child

        def kill(group, number):
            self.assertIsNone(children[0].returncode, "group owner reaped too early")
            events.append(number)
            return original_kill(group, number)

        with h.fixtures() as (_, state, _), h.cancellation(), \
                mock.patch.object(subprocess, "Popen", spawn), \
                mock.patch.object(os, "killpg", kill):
            with self.assertRaises(h.Cancelled):
                h._run([sys.executable, "-I", "-S", "-c", "import time; time.sleep(60)"],
                       cwd=state, env=h.clean_env(state))
        self.assertEqual(events, [signal.SIGTERM, signal.SIGKILL])
        self.assertEqual(len(children), 1)
        self.assertIsNotNone(children[0].returncode)
        with self.assertRaises(ProcessLookupError):
            os.kill(children[0].pid, 0)

    def run_python(self, code, seconds=1):
        with h.fixtures() as (_, state, _):
            return h._run([sys.executable, "-I", "-S", "-c", code],
                          cwd=state, env=h.clean_env(state), seconds=seconds)

    def test_success_and_failure_status(self):
        self.assertEqual(self.run_python("print('synthetic')"), (0, b"synthetic\n"))
        self.assertEqual(self.run_python("raise SystemExit(7)")[0], 7)

    def test_timeout(self):
        start = time.monotonic()
        with self.assertRaisesRegex(h.GuardError, "process timeout"):
            self.run_python("import time; time.sleep(60)", seconds=0.2)
        self.assertLess(time.monotonic() - start, 3)

    def test_timeout_after_stdout_closed(self):
        with self.assertRaisesRegex(h.GuardError, "process timeout"):
            self.run_python("import os,time; os.close(1); os.close(2); time.sleep(60)", seconds=0.2)

    def test_output_budget(self):
        with self.assertRaisesRegex(h.GuardError, "output budget"):
            self.run_python("import os; os.write(1, b'x' * 100000)")

    def test_launch_error_and_invalid_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(h.GuardError, "launch or I/O failed"):
                h._run(["/nonexistent-threadmark-tool"], cwd=directory, env={})
            with self.assertRaisesRegex(h.GuardError, "invalid timeout"):
                h._run([], cwd=directory, env={}, seconds=0)

    def test_sigterm_and_timeout_reap_owned_child_group(self):
        for mode in ("sigterm", "timeout"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                driver = subprocess.Popen(
                    [sys.executable, "-I", "-S", str(Path(__file__).with_name("lifecycle_fixture.py")),
                     str(root), mode], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    close_fds=True,
                )
                try:
                    deadline = time.monotonic() + 5
                    ready = root / "ready.json"
                    while not ready.exists() and time.monotonic() < deadline and driver.poll() is None:
                        time.sleep(0.01)
                    self.assertTrue(ready.exists(), "lifecycle fixture never became ready")
                    pids = json.loads(ready.read_text())
                    if mode == "sigterm":
                        driver.send_signal(signal.SIGTERM)
                    stdout, stderr = driver.communicate(timeout=5)
                    self.assertEqual(driver.returncode, 0, stderr.decode())
                    self.assertIn(mode.encode(), stdout)
                    for pid in pids:
                        with self.assertRaises(ProcessLookupError):
                            os.kill(pid, 0)
                    self.assertFalse((root / "owned").exists())
                finally:
                    if driver.poll() is None:
                        driver.kill()
                        driver.wait(timeout=2)
                    driver.stdout.close()
                    driver.stderr.close()


if __name__ == "__main__":
    unittest.main()
