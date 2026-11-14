"""Fixed public-synthetic SMALL comparison. No default launch or arbitrary inputs."""
import argparse
from datetime import datetime, timezone
import hashlib
from importlib import import_module
import json
import os
from pathlib import Path
import platform
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
r = import_module("experiments.evaluation-runner.runner")
corpus = import_module("experiments.evaluation-corpus.corpus")
adapter = import_module("experiments.evaluation-adapter.adapter")
scoring = import_module("experiments.evaluation-scoring.scoring")
trusted = import_module("experiments.evaluation-candidate._trusted")
ARMS = ("lexical", "symbol", "candidate")
PROJECTS = ("harbor", "harbour")
CASES = tuple({"case": i + 1, "repetition": rep, "arm": arm, "project": project}
              for i, (rep, arm, project) in enumerate(
                  (rep, arm, project) for rep in (1, 2, 3)
                  for arm in ARMS for project in PROJECTS))
TRIAL_SECONDS = 1800


def sha(data):
    return hashlib.sha256(data).hexdigest()


def _case(artifact, project):
    cases = adapter.prepare(artifact.sources, artifact.manifest, artifact.oracle,
                            artifact.inputs, r.scope(project), expected_digest=r.PIN)
    return next(case for case in cases if json.loads(case.fixture)["family"] == r.FAMILY)


def manifest(hardware_model, ram_bytes):
    """Metadata only: no retrieval, scoring predictions or process launch."""
    if type(hardware_model) is not str or not hardware_model or type(ram_bytes) is not int or ram_bytes <= 0:
        raise ValueError("hardware declaration required")
    artifact = corpus.build("small")
    if corpus.validate(artifact) != r.PIN:
        raise ValueError("corpus pin")
    tasks = {}
    for project in PROJECTS:
        case = _case(artifact, project)
        tasks[project] = {
            "original": json.loads(case.arm_input.declared_task),
            "original_sha256": sha(case.arm_input.declared_task),
            "scoring_manifest": json.loads(scoring.build_manifest(json.loads(case.arm_input.method_task)))}
    value = {
        "schema": "evaluation-pilot/1", "run_id": datetime.now(timezone.utc).isoformat(),
        "recipe": "small", "family": r.FAMILY, "cases": list(CASES),
        "tasks": tasks, "corpus_manifest": json.loads(artifact.manifest),
        "bindings": r.bindings(), "pilot_sha256": sha(Path(__file__).read_bytes()),
        "candidate_policy": json.loads(trusted._policy()),
        "environment": {"python": sys.version, "implementation": platform.python_implementation(),
                        "python_binary_sha256": sha(Path(sys.executable).read_bytes()),
                        "system": platform.system(), "release": platform.release(),
                        "os_build": platform.version(), "macos": platform.mac_ver()[0],
                        "architecture": platform.machine(), "hardware_model_declared": hardware_model,
                        "ram_bytes_declared": ram_bytes, "tools": "Python stdlib; authored modules bound above; no external retriever"},
        "budgets": {"worker_seconds": r.WALL_SECONDS, "output_bytes": r.OUTPUT_BYTES,
                    "cleanup_seconds": r.CLEANUP_SECONDS, "trial_seconds": TRIAL_SECONDS,
                    "max_items": scoring.MAX_ITEMS, "candidate_bytes": scoring.MAX_BYTES,
                    "original_bytes": 4096, "memory_enforcement": "unavailable", "network_inference_spend": 0},
        "interpretation": {
            "cache_warm_measurement": "NOT_AVAILABLE: fresh process, no indexed cache; no OS-cold claim",
            "timing": "monotonic elapsed around Runner.run including startup, admission and cleanup; not retrieval-only or performance benchmark",
            "repetitions": "three fixed repetitions; repeated determinism, not independent samples; all outcomes retained; median/range only",
            "scoring": "actual frozen adapter and scorer after returned result; candidate uses actual trusted normalization; no oracle in retrieval",
            "historical_status": "embedded frozen corpus/scoring manifests retain historical prospective flags, not pilot execution status",
            "excluded": "other tiers/tasks, task correctness, human effort, inference, hosts, Graphify adoption, product improvement, p95, peak RSS"}}
    return value


def rescore(result, arm, project):
    """Reconstruct the actual complete adapter fixture AFTER a worker result."""
    if type(arm) is not str or arm not in ARMS or type(project) is not str or project not in PROJECTS:
        raise ValueError("fixed arm/project required")
    if (type(result) is not r.Result or result.status != "ready" or result.cleanup != "verified"
            or result.target_exit != 0 or result.memory_enforcement != "unavailable"
            or type(result.candidate) is not bytes or type(result.original_input) is not bytes):
        raise ValueError("closed runner result")
    artifact = corpus.build("small")
    if corpus.validate(artifact) != r.PIN:
        raise ValueError("corpus pin")
    case = _case(artifact, project)
    if result.original_input != case.arm_input.declared_task:
        raise ValueError("original mismatch")
    value = json.loads(result.candidate)
    if scoring.canonical(value) != result.candidate:
        raise ValueError("noncanonical candidate")
    expected = trusted._prepare(case, arm)
    score = scoring.score(expected.fixture, value)
    trusted._recheck(expected)
    if score["status"] != "valid":
        raise ValueError("score rejected")
    return {"candidate": value, "candidate_sha256": sha(result.candidate),
            "original_sha256": sha(result.original_input), "score": score}


def summaries(results):
    groups = []
    for arm in ARMS:
        for project in PROJECTS:
            rows = [row for row in results if row["arm"] == arm and row["project"] == project]
            times = [row["runner_elapsed_seconds"] for row in rows if "runner_elapsed_seconds" in row]
            admitted = [row for row in rows if "candidate_sha256" in row]
            groups.append({"arm": arm, "project": project, "outcomes": len(rows),
                           "admitted": len(admitted),
                           "identical_candidate_bytes": (len({row["candidate_sha256"] for row in admitted}) == 1
                                                         if len(admitted) == 3 else None),
                           "runner_seconds_median": statistics.median(times) if times else None,
                           "runner_seconds_range": [min(times), max(times)] if times else None})
    return groups


def _write(path, value, *, exclusive=False):
    # Normal generated evidence write, never a source/lockfile patch. No raw diagnostics.
    with path.open("xb" if exclusive else "wb") as handle:
        handle.write(scoring.canonical(value))
        handle.flush()
        os.fsync(handle.fileno())


def _unchanged(frozen):
    return (r.bindings() == frozen["bindings"]
            and sha(Path(__file__).read_bytes()) == frozen["pilot_sha256"]
            and sha(Path(sys.executable).read_bytes()) == frozen["environment"]["python_binary_sha256"])


def _run(frozen, directory):
    """Exactly the retained order, stop at first failure, never retry or widen."""
    report = {"schema": "evaluation-pilot-report/1", "manifest_sha256": sha(scoring.canonical(frozen)),
              "state": "running", "results": [], "summaries": []}
    path = directory / "report.json"
    _write(path, report, exclusive=True)  # Failure to retain closes BEFORE first launch.
    started = time.monotonic()
    runner = r.Runner()
    for case in CASES:
        row = dict(case)
        try:
            if (frozen["cases"] != list(CASES) or not _unchanged(frozen)
                    or (directory / "manifest.json").read_bytes() != scoring.canonical(frozen)):
                raise ValueError("manifest or code changed")
            # Reserve the full existing worker + cleanup allowance before any next launch.
            if time.monotonic() - started + r.WALL_SECONDS + r.CLEANUP_SECONDS >= TRIAL_SECONDS:
                row["status"] = "trial_budget_stop"
            else:
                before = time.monotonic()
                result = runner.run(case["arm"], case["project"])
                row.update(status=result.status, cleanup=result.cleanup, target_exit=result.target_exit,
                           output_bytes=result.output_bytes, memory_enforcement=result.memory_enforcement,
                           runner_elapsed_seconds=time.monotonic() - before)
                row.update(rescore(result, case["arm"], case["project"]))
                if not _unchanged(frozen):
                    raise ValueError("code changed")
                if time.monotonic() - started >= TRIAL_SECONDS:
                    row["status"] = "trial_budget_stop"
        except (Exception, KeyboardInterrupt) as error:
            # Keep the runner's status, but never publish raw exceptions/paths/source.
            row.setdefault("status", "pilot_rejected")
            row["pilot_failure"] = type(error).__name__
            for key in ("candidate", "candidate_sha256", "original_sha256", "score"):
                row.pop(key, None)
        report["results"].append(row)
        report["trial_elapsed_seconds"] = time.monotonic() - started
        report["summaries"] = summaries(report["results"])
        complete = row.get("status") == "ready" and "score" in row and "pilot_failure" not in row
        report["state"] = "running" if complete else "stopped"
        if complete and len(report["results"]) == len(CASES):
            report["state"] = "complete"
        _write(path, report)
        if not complete:
            return 1
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-small", action="store_true", help="explicitly launch exactly 18 fixed cases; requires prior lifecycle verification/authorization")
    parser.add_argument("--output", type=Path, help="NEW owned evidence directory (never reused)")
    parser.add_argument("--hardware-model", help="declared machine model, not a private hostname")
    parser.add_argument("--ram-bytes", type=int)
    args = parser.parse_args(argv)
    if args.output is None:
        if args.run_small:
            parser.error("--output and hardware declaration required")
        parser.print_help()
        return 0
    if not args.hardware_model or args.ram_bytes is None or args.ram_bytes <= 0:
        parser.error("--hardware-model and positive --ram-bytes required")
    frozen = manifest(args.hardware_model, args.ram_bytes)
    args.output.mkdir(mode=0o700, parents=False, exist_ok=False)
    _write(args.output / "manifest.json", frozen, exclusive=True)
    if not args.run_small:
        return 0
    return _run(frozen, args.output)


if __name__ == "__main__":
    raise SystemExit(main())
