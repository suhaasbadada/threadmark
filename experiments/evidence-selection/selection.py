"""Prospective bounded evidence selection; supplied source is never executed."""
import argparse
from dataclasses import asdict
from importlib import import_module
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
directcall = import_module("experiments.evaluation-directcall.directcall")
POLICY = "evidence-selection/1"
CATEGORIES = ("definition", "direct_call")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def _choose(groups):
    """Best rank per coordinate, alternate unique declaration/call lines."""
    ordered = []
    for group in groups:
        seen = set()
        unique = []
        for _, path, line in sorted(group):
            coordinate = (path.decode("utf-8"), line)
            if coordinate not in seen:
                seen.add(coordinate)
                unique.append(coordinate)
        ordered.append(iter(unique))
    selected, seen = [], set()
    active = [True, True]
    while len(selected) < 8 and any(active):
        for category in range(2):
            if len(selected) == 8:
                break
            for coordinate in ordered[category]:
                if coordinate not in seen:
                    seen.add(coordinate)
                    selected.append(coordinate)
                    break
            else:
                active[category] = False
    return selected


def select(sources, task):
    """Return canonical envelope bytes or reject whole. No oracle/plugin inputs.

    sources uses the reviewed extractor's sorted immutable source boundary.
    Scope labels are supplied consistency assertions, not verified Git identity.
    """
    try:
        if (type(task) is not dict
                or set(task) != {"schema", "scope", "family", "query", "instructions"}
                or task["schema"] != "evaluation-scoring/1"
                or task["family"] != "definition_directcall"):
            raise ValueError()
        original = {key: task[key] for key in ("query", "instructions")}
        if (any(type(v) is not str or not v for v in original.values())
                or len(canonical(original)) > 4096):
            raise ValueError()
        # Public extractor validates ALL sources/scope and closes on partial failure.
        extracted = directcall.extract(sources, task["scope"])
        words = {word: i for i, word in enumerate(dict.fromkeys(IDENT.findall(task["query"])))}
        targets = {d.id: words[d.name] for d in extracted.declarations if d.name in words}
        groups = [[], []]
        facts = {}
        for category, records in enumerate((extracted.declarations, extracted.resolvedcalls)):
            for record in records:
                target = record.id if category == 0 else record.target
                if target in targets:
                    coordinate = (record.path, record.line)
                    groups[category].append((targets[target], record.path.encode("utf-8"), record.line))
                    facts.setdefault(coordinate, set()).add(CATEGORIES[category])
        selected = _choose(groups)
        # Same LF/one-trailing-CR normalization already validated by extract().
        lines = {path: tuple(line.removesuffix("\r") for line in data.decode("utf-8").split("\n"))
                 for path, data in sources}
        envelope = {
            "policy": POLICY, "extractor": extracted.policyversion,
            "status": "partial_evidence_selection_not_full_graph",
            "draft": "Deterministic evidence-assisted draft; not AI refinement, execution or send authorization.",
            "original_task": task,
            "source_scope": {"scope": task["scope"], "paths": [path for path, _ in sources],
                             "identity": "caller_supplied_labels_not_verified_git_or_authorization"},
            "requested_categories": list(CATEGORIES),
            "available_categories": {kind: sum(kind in kinds for kinds in facts.values()) for kind in CATEGORIES},
            "selected_categories": {kind: sum(kind in facts[c] for c in selected) for kind in CATEGORIES},
            "evidence": [{**task["scope"], "path": path, "line": line,
                          "text": lines[path][line - 1],
                          "categories": sorted(facts[(path, line)])} for path, line in selected],
            "observed_coverage": [asdict(c) for c in extracted.observedcoverage],
        }
        result = canonical(envelope)
        if len(result) > 8192:
            raise ValueError()
        return result
    except Exception:
        raise ValueError("invalid or unsupported evidence selection") from None


def synthetic(project):
    """Fixed SMALL public bytes and unchanged original task; never pass oracle."""
    corpus = import_module("experiments.evaluation-corpus.corpus")
    if project not in corpus.PROJECTS:
        raise ValueError("unsupported synthetic project")
    artifact = corpus.build("small")
    public_task = next(t for t in json.loads(artifact.inputs)["tasks"] if t["project"] == project)
    family = next(t for t in public_task["families"] if t["id"] == "definition_directcall")
    task = {"schema": "evaluation-scoring/1", "scope": corpus.scope(project),
            "family": family["id"], "query": family["query"],
            "instructions": public_task["instructions"]}
    sources = tuple((p, b) for p, b in artifact.sources if p.startswith(project + "/"))
    return select(sources, task)


def readable(payload):
    """Human review of our bounded envelope, not a rewrite or delivery receipt."""
    value = json.loads(payload)
    task = value["original_task"]
    parts = ["THREADMARK — synthetic evidence draft (no inference or send)",
             "Policy: " + value["policy"],
             "Scope (caller-supplied labels): " + canonical(task["scope"]).decode(),
             "", "ORIGINAL REQUEST", task["query"], "", "INSTRUCTIONS", task["instructions"],
             "", "EVIDENCE — partial selection, at most eight source lines"]
    for item in value["evidence"]:
        parts.extend([f'{item["path"]}:{item["line"]} [{", ".join(item["categories"])}]', item["text"]])
    parts.extend(["", "Available categories: " + canonical(value["available_categories"]).decode(),
                  "Selected categories: " + canonical(value["selected_categories"]).decode(),
                  "", "STATIC COVERAGE — not runtime truth or a complete graph"])
    for observation in value["observed_coverage"]:
        reasons = sorted({entry["reason"] for entry in observation["unresolved"]})
        parts.append(f'{observation["path"]}: {observation["parse"]}; '
                     + "gaps=" + ", ".join(observation["gaps"])
                     + "; unresolved=" + ", ".join(reasons))
    parts.extend(["", "Use --json for the complete envelope and per-file spans. No execution authorization."])
    result = "\n".join(parts).encode("utf-8")
    if len(result) > 8192:
        raise ValueError("readable draft exceeds the output budget")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description="Print a fixed synthetic evidence-assisted draft. No send, copy, inference or service.")
    parser.add_argument("--synthetic", choices=("harbor", "harbour"))
    parser.add_argument("--json", action="store_true", help="complete canonical envelope instead of human-readable review")
    args = parser.parse_args(argv)
    if args.synthetic is None:
        parser.print_help()
        return
    payload = synthetic(args.synthetic)
    sys.stdout.buffer.write((payload if args.json else readable(payload)) + b"\n")


if __name__ == "__main__":
    main()
