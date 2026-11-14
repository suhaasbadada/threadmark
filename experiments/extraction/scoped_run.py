#!/usr/bin/env python3
"""Opt-in six-case experiment. Default help imports no Graphify/native parsers."""
import argparse
import ast
import contextlib
import importlib.metadata as metadata
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import traceback

# -I deliberately excludes the script directory. Only these authored siblings
# are made available; never add a fixture/source directory to the import path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import normalized as norm
import run as legacy

PINS = {"graphifyy": "0.9.101", "tree-sitter": "0.25.2",
        "tree-sitter-python": "0.25.0", "tree-sitter-rust": "0.24.2"}
REPORT_SCHEMA = "threadmark.scoped-static-experiment.v1"


def installed_versions():
    versions = {name: metadata.version(name) for name in PINS}
    norm.require(versions == PINS, "dependency_version")
    norm.require(metadata.distribution("graphifyy").metadata.get("License-Expression")
                 == "Apache-2.0", "dependency_metadata")
    return versions


def read_sources(root):
    norm.require(root.is_dir() and not root.is_symlink(), "input_root")
    paths = sorted(root.iterdir())
    norm.require(0 < len(paths) <= 16, "input_budget")
    norm.require(all(p.is_file() and not p.is_symlink() and p.suffix in (".py", ".rs")
                     for p in paths), "input_shape")
    norm.require(sum(p.stat().st_size for p in paths) <= 65536, "input_budget")
    sources = {p.name: p.read_bytes() for p in paths}
    norm.source_manifest(sources)
    return sources


def python_preflight(sources):
    for path, content in sources.items():
        if path.endswith(".py"):
            try:
                ast.parse(content.decode("utf-8"), filename=path)
            except (SyntaxError, ValueError, UnicodeError):
                raise ValueError("python_syntax") from None


def rust_preflight(sources):
    # Called ONLY by the explicit worker after version checks and Python parse.
    from tree_sitter import Language, Parser
    import tree_sitter_rust
    parser = Parser(Language(tree_sitter_rust.language()))
    for path, content in sources.items():
        if path.endswith(".rs"):
            norm.require(not parser.parse(content).root_node.has_error, "rust_syntax")


def extract_graph(paths, root, cache):
    # No graphify CLI/provider pipeline, detect, build, resolver copy or source exec.
    from graphify.extract import extract
    return extract(paths, root=root, cache_root=cache, parallel=False, max_workers=1)


def relative_coverage(graph, root):
    norm.require(isinstance(graph, dict), "graph_shape")
    result = dict(graph)
    for key in ("failed_sources", "skipped_sources", "extracted_sources"):
        entries = graph.get(key)
        norm.require(isinstance(entries, list) and all(isinstance(s, str) for s in entries), "coverage")
        converted = []
        for source in entries:
            # The pinned API returns absolute coverage paths; all other source
            # anchors must already be canonical relative paths (normalizer).
            path = Path(source)
            norm.require(path.is_absolute() and not path.is_symlink(), "coverage")
            try:
                relative = path.relative_to(root).as_posix()
            except ValueError:
                raise ValueError("coverage") from None
            norm.require(".." not in Path(relative).parts, "coverage")
            converted.append(relative)
        result[key] = converted
    return result


def worker(root, cache, scope):
    """Single actual API call or fail-closed preflight. Diagnostics stay stderr."""
    state, stage = "NOT_RUN", "input"
    try:
        scope = norm.scope_checked(scope)
        sources = read_sources(root)
        stage = "dependency"
        versions = installed_versions()
        stage = "syntax"
        python_preflight(sources)
        with contextlib.redirect_stdout(sys.stderr):
            rust_preflight(sources)
            stage, state = "extraction", "FAILED"
            graph = extract_graph([root / p for p in sorted(sources)], root, cache)
            state = "RETURNED"
        stage = "snapshot"
        norm.require(read_sources(root) == sources, "source_changed")
        snapshot = norm.normalize(relative_coverage(graph, root), sources, scope)
        return {"schema": REPORT_SCHEMA, "status": "accepted", "graphify": state,
                "versions": versions, "syntax": "Python ast.parse; Rust tree-sitter root.has_error=false",
                "snapshot": snapshot}
    except Exception:
        # Do not convert cancellation/BaseException into an accepted worker reply.
        # Private diagnostics may contain installed paths; never embed in report.
        traceback.print_exc(file=sys.stderr)
        if state == "RETURNED":
            print(json.dumps(graph), file=sys.stderr)  # private failed API payload
        return {"schema": REPORT_SCHEMA, "status": "rejected", "graphify": state,
                "failure": stage, "accepted_nodes": 0}


def parse_reply(output):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            norm.require(key not in result, "duplicate_json_key")
            result[key] = value
        return result
    return json.loads(output, object_pairs_hook=unique,
                      parse_constant=lambda _: norm.require(False, "json_constant"))


def case(project, stage, private_directory):
    scope = {"project": project, "worktree": "synthetic-worktree", "revision": "synthetic-snapshot-1"}
    with tempfile.TemporaryDirectory(prefix="threadmark-scoped-") as directory:
        work = Path(directory)
        root, cache, home = work / "source", work / "cache", work / "home"
        shutil.copytree(legacy.FIXTURES / project, root)
        home.mkdir()
        if stage == "malformed":
            (root / "broken.py").write_text("def broken(\n", encoding="utf-8")
        sources = read_sources(root)
        env = {"HOME": str(home), "TMPDIR": str(work), "XDG_CACHE_HOME": str(work / "xdg-cache"),
               "XDG_CONFIG_HOME": str(work / "xdg-config"), "XDG_DATA_HOME": str(work / "xdg-data"),
               "PATH": os.defpath, "LANG": "C.UTF-8"}
        command = [sys.executable, "-I", "-B", str(Path(__file__).resolve()), "--worker",
                   str(root), str(cache), project, scope["worktree"], scope["revision"]]
        # Reuse the same retained-owner implementation and exact legacy budgets.
        code, output, diagnostics, elapsed = legacy._process.bounded(
            command, work, env, legacy.TIMEOUT, legacy.OUTPUT_LIMIT)
        (private_directory / f"{project}-{stage}.stderr").write_bytes(diagnostics)
        (private_directory / f"{project}-{stage}.stdout").write_bytes(output)
        norm.require(code == 0, "worker_failure")
        reply = parse_reply(output)
        norm.require(isinstance(reply, dict) and reply.get("schema") == REPORT_SCHEMA, "worker_shape")
        if stage == "malformed":
            norm.require(reply == {"schema": REPORT_SCHEMA, "status": "rejected", "graphify": "NOT_RUN",
                                   "failure": "syntax", "accepted_nodes": 0}, "malformed_not_rejected")
        else:
            norm.require(reply.get("status") == "accepted" and reply.get("graphify") == "RETURNED"
                         and reply.get("versions") == PINS, "baseline_not_accepted")
            # Check declared snapshot against parent-owned exact bytes/scope.
            snapshot = reply["snapshot"]
            norm.require(snapshot["schema"] == norm.SCHEMA and snapshot["scope"] == scope
                         and snapshot["manifest"] == norm.source_manifest(sources)
                         and snapshot["coverage"] == "LIMITED_STATIC", "snapshot_mismatch")
            reply["queries"] = norm.query_rows(snapshot, scope)
            norm.require(len(reply["queries"]["where_is_normalize"]) == 2
                         and len(reply["queries"]["what_directly_calls_normalize"]) == 2, "fixture_facts")
        return {"project": project, "case": stage, "seconds": elapsed, **reply}


def experiment(private_directory):
    # Require a fresh explicit private destination; no overwrite or raw stdout.
    private_directory = private_directory.resolve()
    repository = Path(__file__).resolve().parents[2]
    norm.require(not private_directory.is_relative_to(repository), "private_destination")
    private_directory.mkdir(mode=0o700, parents=False, exist_ok=False)
    results = []
    for project in ("orbit", "orbit-next"):
        for stage in ("baseline", "malformed", "recovery"):
            results.append(case(project, stage, private_directory))
        baseline, _, recovery = results[-3:]
        norm.require(baseline["snapshot"] == recovery["snapshot"], "recovery_changed")
    left = {n["id"] for n in results[0]["snapshot"]["nodes"]}
    right = {n["id"] for n in results[3]["snapshot"]["nodes"]}
    norm.require(left.isdisjoint(right), "scope_collision")
    return {"schema": REPORT_SCHEMA, "evidence": "actual pinned Graphify API; not mocked CI",
            "limits": {"seconds": 15, "output_bytes": 262144, "files": 16, "input_bytes": 65536,
                       "nodes": 2000, "edges": 4000, "workers": 1},
            "results": results, "checks": {"cross_root_disjoint": True, "fresh_recovery_equal": True,
                                          "malformed_zero_nodes_graphify_not_run": True},
            "cleanup": "six owned source/cache/HOME trees removed; private diagnostics retained",
            "limitations": norm.LIMITATIONS}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-six", action="store_true", help="explicit actual worker gate (after primary review)")
    parser.add_argument("--private-diagnostics", type=Path, help="new private directory outside repository")
    parser.add_argument("--worker", nargs=5, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.worker:
        norm.require(not args.run_six and args.private_diagnostics is None, "arguments")
        root, cache, project, worktree, revision = args.worker
        print(json.dumps(worker(Path(root), Path(cache), dict(project=project, worktree=worktree, revision=revision))))
    elif args.run_six:
        norm.require(args.private_diagnostics is not None, "private_diagnostics_required")
        print(json.dumps(experiment(args.private_diagnostics), indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    legacy.install_cancellation_handler()
    try:
        main()
    except (Exception, KeyboardInterrupt):
        raise SystemExit("Scoped extraction failed; no snapshot admitted. Inspect owned private diagnostics.") from None
