"""Fixed offline SMALL launcher. No study loop, arbitrary command or host API."""
from dataclasses import dataclass
import base64
import hashlib
from importlib import import_module
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SUPERVISOR = ROOT / "experiments/host-isolation/process_supervisor.py"
WALL_SECONDS = 30
OUTPUT_BYTES = 16 * 1024 * 1024
CLEANUP_SECONDS = 2
FAMILY = "definition_directcall"
PIN = "c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8"
FILES = ("evaluation-runner/runner.py", "evaluation-runner/worker.py",
         "host-isolation/process_supervisor.py", "evaluation-corpus/corpus.py",
         "evaluation-adapter/adapter.py", "evaluation-candidate/candidate.py",
         "evaluation-scoring/scoring.py", "evaluation-lexical/lexical.py",
         "evaluation-symbol/symbol.py")
_QUARANTINED = False
_ACTIVE = False
_FIXTURES = frozenset(("complete", "sleep", "descendant", "closed_output",
                       "overflow", "descendant_overflow", "malformed", "partial",
                       "trailing", "nonutf8", "arm", "scope", "pin", "bindings",
                       "unknown", "nonzero", "unverified", "dependency", "foreign_scope",
                       "incomplete", "stderr", "duplicate", "closed_candidate"))


@dataclass(frozen=True)
class Result:
    status: str
    cleanup: str = "not_launched"
    output_bytes: int = 0
    target_exit: int | None = None
    candidate: bytes | None = None
    original_input: bytes | None = None
    memory_enforcement: str = "unavailable"


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("ascii")


def bindings():
    # Fixed authored source files only; no discovery and no generated-source IO.
    return {name: hashlib.sha256((ROOT / "experiments" / name).read_bytes()).hexdigest()
            for name in FILES}


def scope(project):
    return {"project": project, "worktree": project + "-fixture-worktree-1",
            "revision": project + "-fixture-revision-1"}


def envelope(arm, project, pins, result):
    return {"schema": "evaluation-runner/1", "state": "complete", "arm": arm,
            "recipe": "small", "scope": scope(project), "corpus_pin": PIN,
            "bindings": pins, "family": FAMILY, "result": result}


def _admit(data, arm, project, pins):
    value = json.loads(data.decode("utf-8"))
    if canonical(value) != data:
        raise ValueError("noncanonical protocol")
    expected = envelope(arm, project, pins, value.get("result"))
    if value != expected:
        raise ValueError("protocol binding")
    result = value["result"]
    if type(result) is not dict or set(result) != {"status", "reason", "original", "candidate"}:
        raise ValueError("result schema")
    pair = (result["status"], result["reason"])
    allowed = {("ready", "admitted_limited_envelope"),
               ("blocked", "preparation_rejected"), ("blocked", "admission_rejected"),
               ("unavailable", "preparation_unavailable"),
               ("unavailable", "retrieval_unavailable"),
               ("unavailable", "admission_unavailable"),
               ("unavailable", "final_return_unavailable")}
    if pair not in allowed:
        raise ValueError("result state")
    def decode(field, limit):
        text = result[field]
        if text is None:
            return None
        if type(text) is not str or len(text) > 4 * ((limit + 2) // 3):
            raise ValueError("result bytes")
        raw = base64.b64decode(text, validate=True)
        if len(raw) > limit or base64.b64encode(raw).decode("ascii") != text:
            raise ValueError("result bytes")
        return raw
    original, candidate = decode("original", 4096), decode("candidate", 8192)
    if pair[0] != "ready":
        if candidate is not None:
            raise ValueError("closed candidate")
        if original is None:
            return pair[0], None, None
    if pair[0] == "ready" and (candidate is None or original is None):
        raise ValueError("missing admitted bytes")
    # Recheck actual merged admission and original bindings, never run retrieval
    # here. The authored worker alone invokes candidate.build; fixtures never do.
    corpus = import_module("experiments.evaluation-corpus.corpus")
    adapter = import_module("experiments.evaluation-adapter.adapter")
    scoring = import_module("experiments.evaluation-scoring.scoring")
    artifact = corpus.build("small")
    if corpus.validate(artifact) != PIN:
        raise ValueError("recipe pin")
    case = adapter.prepare(artifact.sources, artifact.manifest, artifact.oracle,
                           artifact.inputs, scope(project), expected_digest=PIN)[0]
    if original != case.arm_input.declared_task:
        raise ValueError("original binding")
    if pair[0] != "ready":
        return pair[0], original, None
    item = json.loads(case.fixture)
    fixture = scoring.Fixture(tuple(item["scope"][k] for k in scoring.SCOPE_KEYS),
        tuple(item["coverage"]), tuple(scoring.Anchor(**a) for a in item["anchors"]),
        frozenset(scoring.Anchor(**a) for a in item["gold"]),
        frozenset(scoring.Anchor(**a) for a in item["rejected"]), item["family"])
    decoded = json.loads(candidate.decode("utf-8"))
    if scoring.canonical(decoded) != candidate or scoring.score(fixture, decoded)["status"] != "valid":
        raise ValueError("candidate admission")
    return "ready", original, candidate


class Runner:
    """Main-thread, single-invocation owner; quarantine is process-session-wide."""

    def run(self, arm, project, *, recipe="small", cancel=None):
        """Exact lexical/symbol, harbor/harbour and small only; optional Event."""
        if (type(arm) is not str or arm not in ("lexical", "symbol")
                or type(project) is not str or project not in ("harbor", "harbour")
                or type(recipe) is not str or recipe != "small"
                or (cancel is not None and type(cancel) is not threading.Event)):
            return Result("preflight_rejected")
        return self._launch(arm, project, cancel=cancel)

    def _fixture(self, mode, *, cancel=None):
        # Unit seam selects ONLY an authored fixed fixture and stricter limits.
        # Not a public caller budget, executable/path or production fixture pin.
        if type(mode) is not str or mode not in _FIXTURES:
            return Result("preflight_rejected")
        return self._launch("lexical", "harbor", cancel=cancel, fixture=mode)

    def _launch(self, arm, project, *, cancel, fixture=None):
        global _ACTIVE, _QUARANTINED
        if threading.current_thread() is not threading.main_thread() or _ACTIVE:
            return Result("owner_unavailable")
        if _QUARANTINED:
            return Result("quarantined")
        _ACTIVE = True
        process = None
        read_fd = write_fd = ready_read = ready_write = None
        handlers = {}
        stopped = False
        count = 0
        output, errors, status, ready = bytearray(), bytearray(), bytearray(), bytearray()
        code = None
        outcome = "dependency_failure"
        cleanup = "not_launched"
        self._evidence = None
        def stop(_number, _frame):
            nonlocal stopped
            stopped = True
        def canceled():
            return stopped or (cancel is not None and cancel.is_set())
        try:
            for number in (signal.SIGTERM, signal.SIGINT):
                handlers[number] = signal.signal(number, stop)
            if canceled():
                return Result("canceled")
            pins = bindings()
            with tempfile.TemporaryDirectory(prefix="threadmark-runner-") as directory:
                state = Path(directory)
                for name in ("home", "config", "cache", "data", "tmp"):
                    (state / name).mkdir(mode=0o700)
                env = {"HOME": str(state / "home"), "XDG_CONFIG_HOME": str(state / "config"),
                       "XDG_CACHE_HOME": str(state / "cache"), "XDG_DATA_HOME": str(state / "data"),
                       "XDG_STATE_HOME": str(state / "data"), "TMPDIR": str(state / "tmp"),
                       "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"}
                target = HERE / ("lifecycle_fixture.py" if fixture else "worker.py")
                args = [sys.executable, "-I", "-S", str(target), arm, project]
                if fixture:
                    args.append(fixture)
                wall, cap = (1.0, 16384) if fixture else (WALL_SECONDS, OUTPUT_BYTES)
                deadline = time.monotonic() + wall
                read_fd, write_fd = os.pipe()
                ready_read, ready_write = os.pipe()
                try:
                    mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
                    try:
                        process = subprocess.Popen(
                            [sys.executable, "-I", "-S", str(SUPERVISOR), str(write_fd),
                             "--ready-fd", str(ready_write), *args],
                            cwd=state, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, close_fds=True, pass_fds=(write_fd, ready_write),
                            start_new_session=True)
                        os.close(write_fd)
                        write_fd = None
                        os.close(ready_write)
                        ready_write = None
                    finally:
                        signal.pthread_sigmask(signal.SIG_SETMASK, mask)
                    outcome = "timeout"
                    with selectors.DefaultSelector() as selector:
                        for stream, name in ((process.stdout, "stdout"), (process.stderr, "stderr"),
                                             (read_fd, "status"), (ready_read, "ready")):
                            selector.register(stream, selectors.EVENT_READ, name)
                        while selector.get_map():
                            if canceled():
                                outcome = "canceled"
                                break
                            remaining = deadline - time.monotonic()
                            if remaining <= 0:
                                break
                            overflow = False
                            for key, _ in selector.select(min(remaining, 0.02)):
                                chunk = os.read(key.fd, 4096)
                                if not chunk:
                                    selector.unregister(key.fileobj)
                                elif key.data == "ready":
                                    ready.extend(chunk)
                                    if len(ready) > 32:
                                        raise ValueError("readiness bound")
                                elif key.data == "status":
                                    status.extend(chunk)
                                    if len(status) > 32:
                                        raise ValueError("status bound")
                                else:
                                    count += len(chunk)
                                    if count > cap:
                                        overflow = True
                                        break
                                    (output if key.data == "stdout" else errors).extend(chunk)
                            if overflow:
                                outcome = "output_overflow"
                                break
                        else:
                            outcome = "received"
                finally:
                    if process is not None:
                        # Readiness resolves launch-boundary cancellation without
                        # releasing the control pipe or reaping the group owner.
                        end = time.monotonic() + CLEANUP_SECONDS
                        try:
                            os.set_blocking(read_fd, False)
                            os.set_blocking(ready_read, False)
                            ready_until = min(end - 1, time.monotonic() + 0.7)
                            while not ready.endswith(b"\n") and time.monotonic() < ready_until:
                                try:
                                    ready.extend(os.read(ready_read, 33))
                                except BlockingIOError:
                                    pass
                                if len(ready) > 32:
                                    break
                                time.sleep(0.005)
                            os.killpg(process.pid, signal.SIGTERM)
                            # Reap evidence comes from helper.target.wait(), not EOF.
                            until = min(end - 0.5, time.monotonic() + 0.5)
                            while time.monotonic() < until:
                                try:
                                    chunk = os.read(read_fd, 33)
                                except BlockingIOError:
                                    chunk = b""
                                if chunk:
                                    status.extend(chunk)
                                    if len(status) > 32:
                                        break
                                time.sleep(0.01)
                        finally:
                            try:
                                os.killpg(process.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                            finally:
                                process.wait(timeout=max(0.001, end - time.monotonic()))
                        if (len(ready) > 32 or ready.count(b"\n") != 1
                                or not ready.endswith(b"\n") or not ready[:-1].isdigit()
                                or f"{int(ready)}\n".encode("ascii") != ready):
                            raise ValueError("missing target identity")
                        if status == b"launch-error\n" and ready == b"0\n":
                            outcome, cleanup = "dependency_failure", "verified"
                        elif (int(ready) > 0 and len(status) <= 32 and status.endswith(b"\n")
                              and status.count(b"\n") == 1):
                            code = int(status.decode("ascii"))
                            if f"{code}\n".encode("ascii") != status:
                                raise ValueError("noncanonical target status")
                            cleanup = "verified"
                        else:
                            cleanup = "unverified"
                        if fixture and fixture in ("descendant", "closed_output", "descendant_overflow", "unverified"):
                            evidence = state / "terminal.json"
                            if evidence.is_file() and evidence.stat().st_size <= 1024:
                                self._evidence = json.loads(evidence.read_bytes())
                            if (type(self._evidence) is not dict
                                    or set(self._evidence) != {"worker", "child", "exit", "reaped"}
                                    or self._evidence["reaped"] is not True
                                    or any(type(self._evidence[k]) is not int
                                           for k in ("worker", "child", "exit"))
                                    or self._evidence["child"] <= 0
                                    or self._evidence["worker"] <= 0):
                                cleanup = "unverified"
                            elif self._evidence["worker"] != int(ready):
                                cleanup = "unverified"
                            else:
                                try:
                                    os.kill(self._evidence["child"], 0)
                                except ProcessLookupError:
                                    pass
                                else:
                                    cleanup = "unverified"
                        if time.monotonic() > end:
                            cleanup = "unverified"
                if cleanup != "verified":
                    _QUARANTINED = True
                    return Result("cleanup_unverified", "unverified", count, code)
                if outcome == "received":
                    if code != 0:
                        outcome = "worker_failed"
                    elif errors:
                        outcome = "protocol_rejected"
                    else:
                        try:
                            if bindings() != pins:
                                raise ValueError("changed source bindings")
                            admitted, original, candidate = _admit(bytes(output), arm, project, pins)
                            if canceled():
                                return Result("canceled", cleanup, count, code)
                            return Result(admitted, cleanup, count, code, candidate, original)
                        except Exception:
                            outcome = "protocol_rejected"
                return Result(outcome, cleanup, count, code)
        except Exception:
            if process is not None:
                _QUARANTINED = True
                return Result("cleanup_unverified", "unverified", count, code)
            return Result("dependency_failure")
        finally:
            resource_failure = False
            if process is not None:
                for stream in (process.stdin, process.stdout, process.stderr):
                    if stream is not None:
                        try:
                            stream.close()
                        except Exception:
                            resource_failure = True
            for fd in (read_fd, write_fd, ready_read, ready_write):
                if fd is not None:
                    try:
                        os.close(fd)
                    except OSError:
                        resource_failure = True
            for number, handler in handlers.items():
                try:
                    signal.signal(number, handler)
                except Exception:
                    resource_failure = True
            _ACTIVE = False
            if resource_failure:
                # Deliberately supersede even a constructed ready receipt if
                # final resource restoration failed. Never leak it as success.
                _QUARANTINED = True
                return Result("cleanup_unverified", "unverified", count, code)
