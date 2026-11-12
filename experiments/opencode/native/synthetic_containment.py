#!/usr/bin/env python3
"""Fixed C-only experiment. NOT compiler/Node/native-host certification.

First execution requires independent parent policy/code review. Import is inert.
No descriptor, executable, profile or budget inputs are accepted by the CLI.
"""
from contextlib import contextmanager, ExitStack
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import socket
import sys
import tempfile
import time

_HELPER = Path(__file__).resolve().parents[2] / "host-isolation" / "_bounded_process.py"
_spec = importlib.util.spec_from_file_location("_threadmark_bounded_process", _HELPER)
if _spec.name not in sys.modules:
    _module = importlib.util.module_from_spec(_spec)
    sys.modules[_spec.name] = _module
    _spec.loader.exec_module(_module)
owner = sys.modules[_spec.name]
SOURCE = Path(__file__).with_name("containment_probe.c")
SANDBOX = Path("/usr/bin/sandbox-exec")
CLANG = Path("/usr/bin/clang")
SDK = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
STATE = ("home", "tmp", "config", "cache", "data", "state")
_MODES = {"filesystem": {"approved-read", *('write-' + n for n in STATE),
                        "deny-sibling", "deny-home", "deny-repo", "deny-config",
                        "deny-symlink-read", "deny-symlink-write", "deny-workspace-write",
                        "deny-probe-write", "deny-policy-write", "deny-inventory-write"},
          "fork": {"deny-fork"}, "spawn": {"deny-spawn"}, "exec": {"deny-exec"}}
_NETWORK = {label: {label + "-" + n for n in ("connect", "udp", "bind", "listen")}
            for label in ("v4", "v6")}
_REQUIRED = (set().union(*_MODES.values(), *_NETWORK.values()) |
             {"parser-0", "parser-1", "no-receiver-traffic", "quoted-injection-shaped-root"})
_QUARANTINED = False
_RETAINED_ARTIFACTS = []


class Blocked(ValueError):
    """Content-free failure. Captured output and private paths never leave here."""


class Canceled(Exception):
    pass


def quoted(value):
    text = str(value)
    if not text or any(not 32 <= ord(c) <= 126 for c in text):
        raise Blocked("unsupported policy path")
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


@dataclass(frozen=True)
class Rule:
    operations: tuple
    kind: str
    path: Path

    def allows(self, operation, path):
        return operation in self.operations and (
            path == self.path or self.kind == "subpath" and self.path in path.parents)


@dataclass(frozen=True)
class Policy:
    """Synthetic dyld baseline ONLY; not Node's reviewed system inventory."""
    rules: tuple

    def allows(self, operation, path):
        return any(rule.allows(operation, path) for rule in self.rules)

    def serialize(self):
        lines = ["(version 1)", "(deny default)",
                 "; SYNTHETIC C baseline only; no Node/runtime inventory claim."]
        for rule in self.rules:
            if (not rule.path.is_absolute() or ".." in rule.path.parts
                    or rule.kind not in ("literal", "subpath")
                    or not rule.operations
                    or any(op not in ("file-read*", "file-read-metadata", "file-write*",
                                      "file-map-executable", "process-exec")
                           for op in rule.operations)):
                raise Blocked("invalid fixed policy model")
            lines.append(f'(allow {" ".join(rule.operations)} ({rule.kind} {quoted(rule.path)}))')
        return "\n".join(lines) + "\n"


def policy(root):
    if not root.is_absolute() or ".." in root.parts:
        raise Blocked("invalid owned root")
    executable = root / "probe"
    rules = [Rule(("process-exec",), "literal", executable),
             Rule(("file-read*", "file-map-executable"), "literal", executable),
             Rule(("file-read*",), "literal", root / "read-canary")]
    for name in STATE:
        rules.append(Rule(("file-read*", "file-write*"), "subpath", root / "state" / name))
    for path in (Path("/usr/lib"), Path("/System/Library/dyld")):
        rules.append(Rule(("file-read*", "file-map-executable"), "subpath", path))
    # Metadata traversal only: never byte reads of private/root ancestors.
    metadata = {root, root / "state", root / "guard.sb", root / "read-canary", executable}
    metadata.update(root.parents)
    metadata.update(root / "state" / name for name in STATE)
    metadata.update((Path("/usr"), Path("/System"), Path("/System/Library")))
    rules.extend(Rule(("file-read-metadata",), "literal", p) for p in sorted(metadata))
    return Policy(tuple(rules))


def clean_env(root):
    paths = dict(zip(("HOME", "TMPDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                      "XDG_DATA_HOME", "XDG_STATE_HOME"), STATE))
    return {**{key: str(root / "state" / name) for key, name in paths.items()},
            "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"}


def require_platform():
    if platform.system() != "Darwin":
        raise Blocked("requires macOS; portable tests are not containment")
    for tool in (SANDBOX, CLANG):
        if not tool.is_file() or not os.access(tool, os.X_OK):
            raise Blocked("required installed Apple tool unavailable")


@contextmanager
def artifacts():
    """Delete only this fresh owned directory, and only after verified cleanup.

    No TemporaryDirectory finalizer: unknown cleanup retains state for inspection.
    Quarantine deliberately has no reset/retry API.
    """
    global _QUARANTINED
    if _QUARANTINED or owner._QUARANTINED:
        raise Blocked("cleanup unverified; experiment quarantined")
    root = Path(tempfile.mkdtemp(prefix='threadmark-c-"\\(allow default)-')).resolve()
    try:
        yield root
    except owner.CleanupUnverified:
        _QUARANTINED = True
        raise
    finally:
        if _QUARANTINED or owner._QUARANTINED:
            _RETAINED_ARTIFACTS.append(root)
        else:
            mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
            try:
                shutil.rmtree(root)
            except OSError:
                _QUARANTINED = True
                _RETAINED_ARTIFACTS.append(root)
                raise Blocked("owned artifact cleanup unverified") from None
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, mask)


@contextmanager
def cancellation():
    def stop(_number, _frame):
        raise Canceled()
    previous = {}
    try:
        for number in (signal.SIGTERM, signal.SIGINT):
            previous[number] = signal.signal(number, stop)
        yield
    finally:
        for number, handler in previous.items():
            signal.signal(number, handler)


def parse_checks(output, expected):
    try:
        lines = output.decode("ascii").split("\n")
    except UnicodeError:
        raise Blocked("invalid synthetic observations") from None
    if (not lines or lines.pop() != "" or len(lines) != len(expected)
            or set(lines) != {name + ":PASS" for name in expected}):
        raise Blocked("partial or failed synthetic observations")
    return {name: "observed-pass" for name in sorted(expected)}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_guard():
    """After review ONLY: build and run the fixed owned C negative controls."""
    evidence = {"result": "blocked", "synthetic_only": True, "platform": platform.system(),
                "kernel": platform.release(),
                "checks": {name: "NOT_RUN" for name in sorted(_REQUIRED)}, "identities_sha256": {},
                "host_launched": False, "typescript_launched": False, "c_fixture_built": False,
                "limitations": ["DNS/resolver IPC NOT PROVED",
                    "Node/plugins/config/type closure NOT RUN", "V8/total memory NOT RUN",
                    "escaped descendants NOT proved by group kill alone"]}
    try:
        return _run_guard(evidence)
    except (ValueError, OSError, Canceled, KeyboardInterrupt) as error:
        evidence["cleanup"] = ("unverified-retained" if _QUARANTINED or owner._QUARANTINED
                               else "verified-or-not-launched")
        error.evidence = evidence
        raise


def _run_guard(evidence):
    require_platform()  # Before artifact creation, sockets or target launch.
    evidence["identities_sha256"].update({"fixture": digest(SOURCE),
        "harness": digest(Path(__file__)), "owner": digest(_HELPER),
        "supervisor": digest(owner.SUPERVISOR)})
    deadline = time.monotonic() + 120
    checks = evidence["checks"]
    with artifacts() as root, cancellation(), ExitStack() as stack:
        for name in STATE:
            (root / "state" / name).mkdir(parents=True, mode=0o700)
        (root / "workspace").mkdir(mode=0o700)
        canaries = [root / name for name in
                    ("read-canary", "sibling", "outside/home/.config/opencode/config.json",
                     "outside/repository/AGENTS.md", "outside/config/settings.json",
                     "workspace/check", "config-inventory/settings.json", "exec-marker")]
        for path in canaries:
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            path.write_bytes(b"synthetic-unchanged\n")
            path.chmod(0o600)
        (root / "exec-marker").chmod(0o500)  # Invalid executable: ENOEXEC is NOT denial proof.
        (root / "state" / "home" / "outside-link").symlink_to(root / "sibling")
        env = clean_env(root)

        def run(arguments, seconds=5):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise Blocked("synthetic experiment timeout")
            return owner.bounded(arguments, root / "workspace", env,
                                 timeout=min(seconds, remaining), limit=256 * 1024)

        sdk = SDK
        if not sdk.is_dir():
            if not Path("/usr/bin/xcrun").is_file():
                raise Blocked("installed SDK inspection unavailable")
            code, output, _, _ = run(["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"])
            try:
                sdk = Path(output.decode("ascii").strip())
            except UnicodeError:
                raise Blocked("invalid installed SDK inspection") from None
            if (code or not sdk.is_absolute() or sdk.suffix != ".sdk" or not sdk.is_dir()
                    or not any(sdk.is_relative_to(base) for base in
                               (Path("/Applications"), Path("/Library/Developer")))):
                raise Blocked("installed SDK unavailable")
        code, _, _, _ = run([str(CLANG), "-isysroot", str(sdk), "-std=c11", "-Wall", "-Wextra",
                             "-Werror", str(SOURCE), "-o", str(root / "probe")], seconds=30)
        if code:
            raise Blocked("fixed C fixture compilation failed")
        evidence["c_fixture_built"] = True
        # Owner-writable controls: DAC must not masquerade as sandbox denial.
        (root / "probe").chmod(0o700)
        profile = root / "guard.sb"
        profile.write_text(policy(root).serialize(), encoding="ascii")
        profile.chmod(0o600)
        evidence["identities_sha256"].update({"binary": digest(root / "probe"),
                                              "policy": digest(profile)})
        protected = {path: digest(path) for path in [*canaries, profile, root / "probe"]}

        def unchanged():
            if any(digest(path) != value for path, value in protected.items()):
                raise Blocked("synthetic protected artifact changed")

        def launch(mode, arguments=(), profile_file=profile):
            try:
                code, output, _, _ = run([str(SANDBOX), "-f", str(profile_file),
                                          str(root / "probe"), mode, str(root), *arguments])
                return code, output
            finally:
                unchanged()

        for index, text in enumerate(("(version 1)\n(unknown-threadmark-operation)\n",
                                       "(version 1)\n(deny default\n")):
            invalid = root / "invalid.sb"
            invalid.write_text(text, encoding="ascii")
            checks[f"parser-{index}"] = "failed-or-unverified"
            code, output = launch("parser", profile_file=invalid)
            if code != 65 or output or (root / "workspace" / "parser-ran").exists():
                raise Blocked("invalid policy did not fail closed")
            checks[f"parser-{index}"] = "observed-pass"

        for mode, expected in _MODES.items():
            checks.update({name: "failed-or-unverified" for name in expected})
            code, output = launch(mode)
            if code:
                raise Blocked("synthetic filesystem/process control failed")
            checks.update(parse_checks(output, expected))

        # Owned local receivers only. No external internet or resolver operation.
        receivers = []
        for family, address, label in ((socket.AF_INET, "127.0.0.1", "v4"),
                                        (socket.AF_INET6, "::1", "v6")):
            ports = []
            for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
                endpoint = stack.enter_context(socket.socket(family, kind))
                if family == socket.AF_INET6:
                    endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                endpoint.bind((address, 0))
                if kind == socket.SOCK_STREAM:
                    endpoint.listen(1)
                endpoint.setblocking(False)
                ports.append(str(endpoint.getsockname()[1]))
                receivers.append((endpoint, kind))
            checks.update({name: "failed-or-unverified" for name in _NETWORK[label]})
            code, output = launch("network-" + label, ports)
            if code:
                raise Blocked("synthetic network control failed")
            checks.update(parse_checks(output, _NETWORK[label]))
        checks["no-receiver-traffic"] = "failed-or-unverified"
        for endpoint, kind in receivers:
            try:
                if kind == socket.SOCK_STREAM:
                    connection, _ = endpoint.accept()
                    connection.close()
                else:
                    endpoint.recvfrom(64)
            except BlockingIOError:
                continue
            raise Blocked("owned receiver observed forbidden traffic")
        checks["no-receiver-traffic"] = "observed-pass"
        checks["quoted-injection-shaped-root"] = "observed-pass"
        unchanged()
        if set(checks) != _REQUIRED or any(value != "observed-pass" for value in checks.values()):
            raise Blocked("incomplete synthetic control matrix")
    evidence.update(result="synthetic-only-pass", cleanup="verified-owned-artifacts-removed")
    return evidence


def main():
    if sys.argv[1:] != ["--synthetic-compiler-guard"]:
        print("usage: synthetic_containment.py --synthetic-compiler-guard", file=sys.stderr)
        return 2
    try:
        result = run_guard()
    except (ValueError, OSError, Canceled, KeyboardInterrupt) as error:
        print(json.dumps(getattr(error, "evidence", {"result": "blocked", "synthetic_only": True,
                          "cleanup": "unverified-retained" if
                          _QUARANTINED or owner._QUARANTINED else "verified-or-not-launched"})))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
