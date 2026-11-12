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


class Canceled(Exception):
    """Cancellation that cannot be swallowed as an interrupted selector syscall."""


def install_cancellation_handler():
    """Unwind owned workers/temp directories on ordinary POSIX termination."""
    def terminate(_signum, _frame):
        raise Canceled("experiment terminated")
    signal.signal(signal.SIGTERM, terminate)


def bounded(command, cwd, env, timeout=TIMEOUT, limit=OUTPUT_LIMIT):
    """Bound both pipes while running, not after communicate has allocated them."""
    start = time.monotonic()
    process = None
    chunks = {}
    try:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, start_new_session=True)
        chunks = {process.stdout: bytearray(), process.stderr: bytearray()}
        with selectors.DefaultSelector() as selector:
            for stream in chunks:
                selector.register(stream, selectors.EVENT_READ)
            total = 0
            while selector.get_map():
                remaining = timeout - (time.monotonic() - start)
                if remaining <= 0:
                    raise ValueError("worker timeout")
                for key, _ in selector.select(min(remaining, 0.1)):
                    data = os.read(key.fileobj.fileno(), 8192)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(data)
                    if total > limit:
                        raise ValueError("worker output budget exceeded")
                    chunks[key.fileobj].extend(data)
            process.wait(timeout=max(0.001, timeout - (time.monotonic() - start)))
        if process.returncode:
            # Never echo third-party diagnostics or source paths on failure.
            raise ValueError("worker failed; dependency/API prerequisite unavailable")
        return bytes(chunks[process.stdout]), round(time.monotonic() - start, 4)
    finally:
        # This experiment is POSIX-only. Reap the group even on cancellation.
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        for stream in chunks:
            stream.close()


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
