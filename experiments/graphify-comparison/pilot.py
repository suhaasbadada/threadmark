"""Opt-in fixed twelve-worker SMALL comparison. No default worker launch."""
import argparse
from datetime import datetime, timezone
from importlib import import_module
import json
import os
from pathlib import Path
import platform
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
a = import_module("experiments.graphify-comparison.adapter")
old = import_module("experiments.evaluation-pilot.pilot")
s = import_module("experiments.extraction.scoped_run")
sha = old.sha
CASES = tuple({"case": i + 1, "repetition": rep, "project": project, "arm": arm}
              for i, (rep, project, arm) in enumerate(
                  (rep, project, arm) for rep in (1, 2, 3)
                  for project in old.PROJECTS for arm in a.ARMS))
FILES = tuple(dict.fromkeys((*old.r.FILES, "evaluation-pilot/pilot.py", "evidence-selection/selection.py",
    "extraction/scoped_run.py", "extraction/normalized.py", "extraction/run.py",
    "host-isolation/_bounded_process.py", "graphify-comparison/adapter.py",
    "graphify-comparison/worker.py", "graphify-comparison/pilot.py")))
REFERENCES = {"report.json": "5970f8d28c1cccaf7184fa17997d9a0a3b0bb3f732750392b703ad559541b1f2",
              "manifest.json": "a816fab893d9e8010eb1f06ccf38910f0578fd5af200ddff7641e2109cd8e455"}
TRIAL_SECONDS = 1800


def bindings():
    return {name: sha((ROOT / "experiments" / name).read_bytes()) for name in FILES}


def fixed(project):
    artifact = old.corpus.build("small")
    a.norm.require(old.corpus.validate(artifact) == old.r.PIN, "corpus_pin")
    case = old._case(artifact, project)
    a.norm.require(len(case.arm_input.sources) == 16, "all_sources")
    return case


def manifest(hardware_model, ram_bytes):
    a.norm.require(type(hardware_model) is str and bool(hardware_model)
                   and type(ram_bytes) is int and ram_bytes > 0, "hardware")
    reference = {}
    for name, digest in REFERENCES.items():
        data = (ROOT / "experiments/evaluation-pilot/evidence" / name).read_bytes()
        a.norm.require(sha(data) == digest, "frozen_reference_changed")
        reference[name] = digest
    old_manifest = json.loads((ROOT / "experiments/evaluation-pilot/evidence/manifest.json").read_bytes())
    old_report = json.loads((ROOT / "experiments/evaluation-pilot/evidence/report.json").read_bytes())
    a.norm.require(old_manifest["bindings"] == old.r.bindings(), "historical_algorithms_changed")
    tasks = {}
    for project in old.PROJECTS:
        case = fixed(project)
        base = json.loads(case.fixture)
        task = json.loads(case.arm_input.method_task)
        a.norm.require(old_manifest["tasks"][project]["original"] == json.loads(case.arm_input.declared_task)
                       and old_manifest["tasks"][project]["original_sha256"] == sha(case.arm_input.declared_task)
                       and old_manifest["tasks"][project]["scoring_manifest"] == json.loads(a.scoring.build_manifest(task))
                       and old_manifest["corpus_manifest"] == json.loads(old.corpus.build("small").manifest),
                       "historical_inputs_changed")
        tasks[project] = {"original": json.loads(case.arm_input.declared_task),
            "original_sha256": sha(case.arm_input.declared_task), "method_task": task,
            "sources": {p: {"bytes": len(b), "sha256": sha(b)} for p, b in case.arm_input.sources},
            "gold_count": len(base["gold"]), "fixture_sha256": sha(case.fixture),
            "scoring_manifest": json.loads(a.scoring.build_manifest(task))}
    return {"schema": "graphify-comparison/1", "registered_at": datetime.now(timezone.utc).isoformat(),
        "cases": list(CASES), "tasks": tasks, "bindings": bindings(),
        "corpus_manifest": json.loads(old.corpus.build("small").manifest),
        "old_reference_hashes": reference,
        "old_recorded_quality_not_rescored": [{k: row[k] for k in ("arm", "project", "repetition", "score")}
                                             for row in old_report["results"]],
        "installed_versions": s.installed_versions(),
        "environment": {"python": sys.version, "python_binary_sha256": sha(Path(sys.executable).read_bytes()),
            "os": platform.system(), "release": platform.release(), "build": platform.version(),
            "architecture": platform.machine(), "hardware_model_declared": hardware_model,
            "ram_bytes_declared": ram_bytes},
        "selection": {"policy": a.selection.POLICY,
            "rank": "original query identifier order, UTF-8 path, numeric line; dedup coordinates; alternate definition/call, definition first; spill; eight",
            "authored": "existing directcall.extract via selection.select",
            "graphify": "pinned AST extract all 16 including Markdown; bare ASCII callable name(); nonclass; one-hop calls targeting matched IDs; preserve origin/confidence",
            "oracle": "only parent scorer; never passed to worker",
            "scorer": "existing exact six-field anchors, full gold 16 per scope; category/confidence counts auxiliary not semantic scoring"},
        "budgets": {"seconds": 15, "aggregate_stdout_stderr_bytes": 262144,
            "cleanup_seconds": 2, "files": 16, "source_bytes": 65536, "nodes": 2000,
            "edges": 4000, "candidate_bytes_including_coverage": 8192, "items": 8,
            "trial_seconds": TRIAL_SECONDS, "memory_enforcement": "unavailable"},
        "interpretation": {"coverage": a.LIMITS,
            "failure": "invalid/unavailable/null metrics; stop first failure, no retry/fallback/widening",
            "counts": "available/selected unique source lines per definition/call; same line may count both; report declared confidence separately",
            "quality": "all outcomes valuable; no query/rank tuning; old quality recorded reference only, no rescore",
            "timing": "different trial; no old timing comparison, OS-cold or performance claim; scaling beyond SMALL blocked",
            "cache": "fresh owned source/cache/HOME/all XDG per condition; warm NOT_AVAILABLE",
            "repetitions": "three repetitions are determinism checks, not independent samples",
            "excluded": "engine adoption, native host, inference, RSS, task success, Phase 1 closure"}}


def unchanged(frozen):
    return (bindings() == frozen["bindings"]
            and sha(Path(sys.executable).read_bytes()) == frozen["environment"]["python_binary_sha256"]
            and s.installed_versions() == frozen["installed_versions"]
            and all(sha((ROOT / "experiments/evaluation-pilot/evidence" / n).read_bytes()) == h
                    for n, h in REFERENCES.items()))


def condition(case, private):
    """Reuse retained owner, never the old Runner arm universe."""
    expected = fixed(case["project"])
    task = json.loads(expected.arm_input.method_task)
    with tempfile.TemporaryDirectory(prefix="threadmark-comparison-") as directory:
        work = Path(directory)
        for p, data in expected.arm_input.sources:
            destination = work / "source" / p
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        for name in ("cache", "home", "xdg-cache", "xdg-config", "xdg-data", "xdg-state", "xdg-runtime"):
            (work / name).mkdir(mode=0o700)
        old._write(work / "request.json", {"arm": case["arm"], "task": task,
            "sources": {p: sha(b) for p, b in expected.arm_input.sources}}, exclusive=True)
        env = {"HOME": str(work / "home"), "TMPDIR": str(work), "PATH": os.defpath, "LANG": "C.UTF-8",
            **{"XDG_" + key + "_HOME": str(work / ("xdg-" + key.lower()))
               for key in ("CACHE", "CONFIG", "DATA", "STATE")}, "XDG_RUNTIME_DIR": str(work / "xdg-runtime")}
        command = [sys.executable, "-I", "-B", str(Path(__file__).with_name("worker.py"))]
        code, output, diagnostics, elapsed = s.legacy._process.bounded(command, work, env, 15, 262144)
        # Diagnostics are private, bounded, and never echoed in the public report.
        with (private / (str(case["case"]) + ".stderr")).open("xb") as handle:
            handle.write(diagnostics)
        with (private / (str(case["case"]) + ".stdout")).open("xb") as handle:
            handle.write(output)
        a.norm.require(code == 0, "worker_unavailable")
        reply = s.parse_reply(output)
        if type(reply) is dict and reply.get("status") == "unavailable":
            failure = reply.get("failure")
            raise ValueError(failure if failure == "unsupported_coverage" else "invalid_output_or_dependency")
        a.norm.require(type(reply) is dict and set(reply) == {
            "schema", "status", "arm", "task", "versions", "result"}
            and reply["schema"] == "graphify-comparison-worker/1" and reply["status"] == "ready"
            and reply["arm"] == case["arm"] and reply["task"] == task
            and reply["versions"] == s.PINS, "worker_mismatch")
        value, score = a.candidate(reply["result"], json.loads(expected.fixture), case["arm"])
        selected = reply["result"]["metadata"]["selected"]
        return {"status": "ready", "cleanup": "verified", "target_exit": code,
            "elapsed_seconds": elapsed, "candidate": value, "candidate_sha256": sha(a.scoring.canonical(value)),
            "metadata": reply["result"]["metadata"], "score": score,
            "selected_categories": {kind: sum(any(f["kind"] == kind for f in item["facts"])
                                               for item in selected) for kind in a.selection.CATEGORIES},
            "declared_confidence_fact_counts": {label: sum(f.get("confidence", "UNDECLARED") == label
                for item in selected for f in item["facts"])
                for label in ("EXTRACTED", "INFERRED", "AMBIGUOUS", "UNDECLARED")},
            "original_sha256": sha(expected.arm_input.declared_task)}


def run(frozen, output, private):
    report = {"schema": "graphify-comparison-report/1", "state": "running",
              "manifest_sha256": sha(a.scoring.canonical(frozen)), "results": []}
    old._write(output / "report.json", report, exclusive=True)
    started = time.monotonic()
    for case in CASES:
        row = {**case, "status": "unavailable", "score": {"status": "invalid", "metrics": None}}
        try:
            a.norm.require(frozen["cases"] == list(CASES) and unchanged(frozen)
                and (output / "manifest.json").read_bytes() == a.scoring.canonical(frozen), "binding_changed")
            a.norm.require(time.monotonic() - started + 17 < TRIAL_SECONDS, "trial_budget")
            row.update(condition(case, private))
            a.norm.require(unchanged(frozen) and time.monotonic() - started < TRIAL_SECONDS, "postcheck")
        except (Exception, KeyboardInterrupt) as error:
            row = {**case, "status": "invalid_or_unavailable", "score": {"status": "invalid", "metrics": None}}
            if type(error) is ValueError and error.args in (("unsupported_coverage",), ("invalid_output_or_dependency",)):
                row["failure"] = error.args[0]
        report["results"].append(row)
        report["determinism"] = []
        for project in old.PROJECTS:
            for arm in a.ARMS:
                rows = [r for r in report["results"] if r["project"] == project and r["arm"] == arm]
                admitted = [r for r in rows if r["status"] == "ready"]
                report["determinism"].append({"project": project, "arm": arm,
                    "outcomes": len(rows), "admitted": len(admitted),
                    "identical_candidate_bytes": len({r["candidate_sha256"] for r in admitted}) == 1
                    if len(admitted) == 3 else None})
        complete = row["status"] == "ready"
        report["state"] = ("complete" if len(report["results"]) == 12 else "running") if complete else "stopped"
        report["elapsed_seconds"] = time.monotonic() - started
        old._write(output / "report.json", report)
        if not complete:
            return 1
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-small", action="store_true", help="only after primary independent review and lifecycle gate")
    parser.add_argument("--output", type=Path, help="new owned public evidence directory")
    parser.add_argument("--private-diagnostics", type=Path, help="new private directory outside repository")
    parser.add_argument("--hardware-model")
    parser.add_argument("--ram-bytes", type=int)
    args = parser.parse_args(argv)
    if not args.run_small:
        parser.print_help()
        return 0
    if (args.output is None or args.private_diagnostics is None
            or not args.hardware_model or args.ram_bytes is None):
        parser.error("new output/private diagnostics and hardware declaration required")
    private = args.private_diagnostics.resolve()
    a.norm.require(not private.is_relative_to(ROOT)
                   and not private.is_relative_to(args.output.resolve())
                   and not args.output.resolve().is_relative_to(private), "private_destination")
    frozen = manifest(args.hardware_model, args.ram_bytes)
    private.mkdir(mode=0o700, parents=False, exist_ok=False)
    args.output.mkdir(mode=0o700, parents=False, exist_ok=False)
    old._write(args.output / "manifest.json", frozen, exclusive=True)
    return run(frozen, args.output, private)


if __name__ == "__main__":
    s.legacy.install_cancellation_handler()
    try:
        raise SystemExit(main())
    except (Exception, KeyboardInterrupt):
        raise SystemExit("Comparison stopped; inspect owned report/private diagnostics.") from None
