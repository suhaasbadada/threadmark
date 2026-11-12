#!/usr/bin/env python3
"""Optional local AST experiment; no Graphify import unless --worker is invoked."""
import ast
import contextlib
import importlib.metadata as metadata
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import resource
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

VERSION = "0.9.101"
TIMEOUT = 15
OUTPUT_LIMIT = 256 * 1024
FIXTURES = Path(__file__).resolve().parent / "fixtures"
SUPERVISOR = FIXTURES.parent.parent / "host-isolation" / "process_supervisor.py"
CLEANUP_SECONDS = 2
_QUARANTINED = False
_UNVERIFIED_OWNERS = []


class CleanupUnverified(ValueError):
    """Missing ownership/termination proof blocks subsequent invocations."""


def _target_status(ready, status):
    """Only canonical private helper records count as target wait evidence."""
    try:
        pid = int(ready)
        if pid < 0 or ready != f"{pid}\n".encode("ascii"):
            raise ValueError
        if pid == 0 and status == b"launch-error\n":
            return None
        code = int(status)
        if pid == 0 or status != f"{code}\n".encode("ascii"):
            raise ValueError
        return code
    except (ValueError, UnicodeError):
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked") from None


def _finish(process, read_fd, ready_fd, status, ready):
    """Signal the still-owned group, then reap; never infer target exit from EOF."""
    end = time.monotonic() + CLEANUP_SECONDS
    failed = False
    def drain(fd, record):
        try:
            record.extend(os.read(fd, 33))
        except BlockingIOError:
            pass
        if len(record) > 32:
            raise ValueError("invalid private worker record")

    try:
        os.set_blocking(read_fd, False)
        os.set_blocking(ready_fd, False)
        until = min(end - 1, time.monotonic() + 0.7)
        while not ready.endswith(b"\n") and time.monotonic() < until:
            drain(ready_fd, ready)
            time.sleep(0.005)
        os.killpg(process.pid, signal.SIGTERM)
        until = min(end - 0.5, time.monotonic() + 0.5)
        while time.monotonic() < until:
            drain(read_fd, status)
            time.sleep(0.005)
    except (OSError, ValueError):
        failed = True
    finally:
        try:
            # The supervisor remains alive and unreaped through this final signal.
            os.killpg(process.pid, signal.SIGKILL)
        except OSError:
            failed = True
        finally:
            # EOF is also the helper's parent-death fallback, not proof of cleanup.
            try:
                process.stdin.close()
            except OSError:
                failed = True
            try:
                process.wait(timeout=max(0.001, end - time.monotonic()))
            except (OSError, subprocess.TimeoutExpired):
                _UNVERIFIED_OWNERS.append(process)
                failed = True
    if failed or time.monotonic() > end or process.returncode != -signal.SIGKILL:
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked")
    return _target_status(ready, status)


class Canceled(Exception):
    """Cancellation that cannot be swallowed as an interrupted selector syscall."""


def install_cancellation_handler():
    """Unwind owned workers/temp directories on ordinary POSIX termination."""
    def terminate(_signum, _frame):
        raise Canceled("experiment terminated")
    signal.signal(signal.SIGTERM, terminate)


def bounded(command, cwd, env, timeout=TIMEOUT, limit=OUTPUT_LIMIT):
    """Private POSIX harness primitive; aggregate live output, retained group owner."""
    global _QUARANTINED
    if _QUARANTINED:
        raise CleanupUnverified("worker cleanup unverified; further invocations blocked")
    if not 0 < timeout <= TIMEOUT or not 0 < limit <= OUTPUT_LIMIT:
        raise ValueError("invalid worker budget")
    start = time.monotonic()
    process = None
    chunks = {}
    descriptors = []
    status, ready = bytearray(), bytearray()
    code = None
    try:
        read_fd, write_fd = os.pipe()
        descriptors.extend((read_fd, write_fd))
        ready_fd, ready_write = os.pipe()
        descriptors.extend((ready_fd, ready_write))
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        try:
            process = subprocess.Popen(
                [sys.executable, "-I", "-S", str(SUPERVISOR), str(write_fd),
                 "--ready-fd", str(ready_write), *command],
                cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, close_fds=True, pass_fds=(write_fd, ready_write),
                start_new_session=True)
            for fd in (write_fd, ready_write):
                os.close(fd)
                descriptors.remove(fd)
        finally:
            # Pending cancellation can run only after the owner has been recorded.
            signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        chunks = {process.stdout: bytearray(), process.stderr: bytearray()}
        with selectors.DefaultSelector() as selector:
            for stream in chunks:
                selector.register(stream, selectors.EVENT_READ, chunks[stream])
            selector.register(read_fd, selectors.EVENT_READ, status)
            selector.register(ready_fd, selectors.EVENT_READ, ready)
            total = 0
            while selector.get_map():
                remaining = timeout - (time.monotonic() - start)
                if remaining <= 0:
                    raise ValueError("worker timeout")
                for key, _ in selector.select(min(remaining, 0.1)):
                    data = os.read(key.fd, 8192 if key.fileobj in chunks else 33)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    if key.fileobj in chunks:
                        total += len(data)
                        if total > limit:
                            raise ValueError("worker output budget exceeded")
                    elif len(key.data) + len(data) > 32:
                        raise ValueError("invalid private worker record")
                    key.data.extend(data)
    except OSError:
        raise ValueError("worker launch or I/O failed") from None
    finally:
        # Defer asynchronous cancellation through signals, reaping and FD restoration.
        mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        cleanup_error = None
        try:
            if process is not None:
                try:
                    code = _finish(process, read_fd, ready_fd, status, ready)
                except (OSError, ValueError, subprocess.TimeoutExpired):
                    _QUARANTINED = True
                    cleanup_error = CleanupUnverified(
                        "worker cleanup unverified; further invocations blocked")
        finally:
            try:
                if process is not None:
                    for stream in (process.stdin, process.stdout, process.stderr):
                        if stream is not None:
                            try:
                                stream.close()
                            except OSError:
                                _QUARANTINED = True
                                cleanup_error = CleanupUnverified(
                                    "worker cleanup unverified; further invocations blocked")
                for fd in descriptors:
                    try:
                        os.close(fd)
                    except OSError:
                        _QUARANTINED = True
                        cleanup_error = CleanupUnverified(
                            "worker cleanup unverified; further invocations blocked")
            finally:
                try:
                    signal.pthread_sigmask(signal.SIG_SETMASK, mask)
                finally:
                    if cleanup_error is not None:
                        raise cleanup_error
    if code != 0:
        # Never echo third-party diagnostics or source paths on failure.
        raise ValueError("worker failed; dependency/API prerequisite unavailable")
    return bytes(chunks[process.stdout]), round(time.monotonic() - start, 4)


def validate(reply, scope, manifest):
    """Deliberately narrow structural-only admission probe, no persistence."""
    if not isinstance(reply, dict) or reply.get("schema") != 1:
        raise ValueError("schema")
    if reply.get("scope") != scope or reply.get("complete") is not True:
        raise ValueError("scope/completion")
    if reply.get("manifest") != manifest:
        raise ValueError("manifest")
    graph = reply.get("graph")
    if not isinstance(graph, dict):
        raise ValueError("graph")
    nodes, edges = graph.get("nodes"), graph.get("edges")
    if graph.get("failed_sources") != [] or graph.get("skipped_sources") != []:
        raise ValueError("partial extraction")
    if sorted(graph.get("extracted_sources", [])) != manifest:
        raise ValueError("source coverage")
    if not isinstance(nodes, list) or not isinstance(edges, list):
        raise ValueError("collections")
    if not nodes or len(nodes) > 2000 or len(edges) > 4000:
        raise ValueError("item budget/empty snapshot")
    ids = set()
    for node in nodes:
        if not isinstance(node, dict) or not isinstance(node.get("id"), str):
            raise ValueError("node")
        if not node["id"] or node["id"] in ids:
            raise ValueError("duplicate/empty id")
        ids.add(node["id"])
    for item in nodes + edges:
        if not isinstance(item, dict):
            raise ValueError("item")
        source = item.get("source_file")
        if not isinstance(source, str) or source not in manifest:
            raise ValueError("foreign source")
        if PurePosixPath(source).is_absolute() or ".." in PurePosixPath(source).parts:
            raise ValueError("source escape")
        if item.get("_origin") != "ast":
            raise ValueError("origin")
        if not re.fullmatch(r"L[1-9][0-9]*(?:-L?[1-9][0-9]*)?", item.get("source_location", "")):
            raise ValueError("source anchor")
    for edge in edges:
        if edge.get("source") not in ids or edge.get("target") not in ids:
            raise ValueError("dangling edge")
        if edge.get("confidence") not in ("EXTRACTED", "INFERRED", "AMBIGUOUS"):
            raise ValueError("claim label")
    return reply


def worker(root, cache):
    distribution = metadata.distribution("graphifyy")
    if distribution.version != VERSION or distribution.metadata.get("License-Expression") != "Apache-2.0":
        raise ValueError("unexpected installed release metadata")
    licenses = {}
    import hashlib
    for name in ("LICENSE", "LICENSE-MIT", "NOTICE"):
        matches = [f for f in distribution.files if str(f).endswith("/licenses/" + name)]
        if len(matches) != 1:
            raise ValueError("missing installed license evidence")
        licenses[name] = hashlib.sha256(distribution.locate_file(matches[0]).read_bytes()).hexdigest()
    paths = sorted(p for p in root.iterdir() if p.suffix in (".py", ".rs"))
    if not paths or len(paths) > 16 or sum(p.stat().st_size for p in paths) > 65536:
        raise ValueError("input budget")
    with contextlib.redirect_stdout(sys.stderr):
        from graphify.extract import extract
        graph = extract(paths, root=root, cache_root=cache, parallel=False, max_workers=1)
    # The installed API returns absolute paths in coverage arrays. Never export
    # those private temporary locations; fail on any out-of-root coverage entry.
    for key in ("failed_sources", "skipped_sources", "extracted_sources"):
        graph[key] = [Path(source).relative_to(root).as_posix() for source in graph[key]]
    dependencies = {}
    for name in ("tree-sitter", "tree-sitter-python", "tree-sitter-rust", "networkx", "numpy", "rapidfuzz", "pyyaml"):
        dependencies[name] = metadata.version(name)
    print(json.dumps({"graph": graph, "licenses_sha256": licenses,
                      "dependencies": dependencies, "python": platform.python_version(),
                      "maxrss_native": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}))


def baseline(root):
    lexical, symbols, errors = [], [], []
    for path in sorted(root.iterdir()):
        text = path.read_text()
        lexical.extend(f"{path.name}:{i}" for i, line in enumerate(text.splitlines(), 1) if "normalize" in line)
        if path.suffix == ".py":
            try:
                tree = ast.parse(text)
            except SyntaxError:
                errors.append(path.name + ": SyntaxError")
            else:
                symbols.extend(f"{path.name}:{n.lineno}:{n.name}" for n in ast.walk(tree) if isinstance(n, ast.FunctionDef))
        else:
            symbols.extend(f"{path.name}:{i}:{name}" for i, line in enumerate(text.splitlines(), 1) for name in re.findall(r"\bfn\s+(\w+)", line))
    return {"lexical_normalize": lexical, "symbols": symbols, "errors": errors}


def experiment():
    results = {"platform": platform.system(), "machine": platform.machine(), "runs": []}
    with tempfile.TemporaryDirectory(prefix="threadmark-extraction-") as directory:
        work = Path(directory)
        env = {"HOME": str(work), "TMPDIR": str(work), "XDG_CACHE_HOME": str(work / "cache"),
               "PATH": os.defpath, "LANG": "C.UTF-8"}
        for project in ("orbit", "orbit-next"):
            root = work / project
            shutil.copytree(FIXTURES / project, root)
            cache = work / (project + "-cache")
            for stage in ("cold", "warm", "renamed", "deleted", "damaged"):
                if stage == "renamed":
                    (root / "service.py").rename(root / "renamed.py")
                if stage == "deleted":
                    (root / "renamed.py").unlink()
                if stage == "damaged":
                    (root / "broken.py").write_text("def broken(\n")
                manifest = sorted(p.name for p in root.iterdir())
                output, elapsed = bounded([sys.executable, "-I", "-B", str(Path(__file__).resolve()),
                                           "--worker", str(root), str(cache)], work, env)
                data = json.loads(output)
                envelope = {"schema": 1, "scope": [project, "synthetic-worktree", stage],
                            "complete": True, "manifest": manifest, "graph": data.pop("graph")}
                try:
                    validate(envelope, envelope["scope"], manifest)
                    admission = "accepted"
                except ValueError as error:
                    admission = "rejected: " + str(error)
                results["runs"].append({"project": project, "stage": stage, "seconds": elapsed,
                                        "admission": admission, "envelope": envelope,
                                        "baseline": baseline(root), **data})
    results["cleanup"] = "experiment temporary directory removed"
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    install_cancellation_handler()
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "--worker":
            worker(Path(sys.argv[2]), Path(sys.argv[3]))
        elif sys.argv[1:] == ["--run"]:
            experiment()
        else:
            raise ValueError("usage: python3 experiments/extraction/run.py --run")
    except (ValueError, ImportError, metadata.PackageNotFoundError, subprocess.TimeoutExpired,
            Canceled, KeyboardInterrupt):
        raise SystemExit("Extraction experiment failed: prerequisites, validation, or bounded worker failure; no installation attempted.")
