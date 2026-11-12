"""Synthetic byte fixtures only: no source loading, extraction or execution."""
from dataclasses import dataclass
import hashlib
import json
import re


TIERS = {"small": (32, 1 << 20), "medium": (256, 8 << 20),
         "large": (2048, 32 << 20)}
PROJECTS = ("harbor", "harbour")
VERSION = "1"
LIMITS = ["Rust macro expansion unavailable", "Python dynamic calls unresolved",
          "Templates are not representative repositories", "No parser or extractor run"]
EXCLUDED = ["oracle", "instructions", "queries", "manifests", "private source",
            "binaries", "symlinks", "external repositories"]


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("ascii")


def sha(data):
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class Corpus:
    sources: tuple  # (relative POSIX path, immutable bytes), not filesystem entries
    manifest: bytes
    oracle: bytes
    inputs: bytes


def scope(project):
    return {"project": project, "worktree": project + "-fixture-worktree-1",
            "revision": project + "-fixture-revision-1"}


def template(project, index):
    """Return authored synthetic text and (kind, exact line) facts."""
    mode = index % 4
    if mode == 0:
        return "rs", (f"// synthetic {project} module {index}\n"
                      f"pub fn resolve() -> u32 {{ {index} }}\n"
                      "pub fn entry() -> u32 { resolve() }\n"), [
                          ("definition", 2), ("direct_call", 3)]
    if mode == 1:
        return "py", (f"# synthetic {project} module {index}\n"
                      f"def resolve():\n    return {index}\n"
                      "def entry():\n    return resolve()\n"
                      "def indirect(name):\n    return globals()[name]()\n"), [
                          ("definition", 2), ("direct_call", 5), ("dynamic_gap", 7)]
    if mode == 2:
        rule = "retain audit records" if project == "harbor" else "delete audit records"
        return "md", (f"# Synthetic decision {index}\n"
                      f"Current rule: {rule}.\n"
                      "Historical rule (retired): export audit records.\n"
                      "Do not send or deploy. Material permission remains unresolved.\n"), [
                          ("current_decision", 2), ("stale_decision", 3),
                          ("negation_permission", 4)]
    return "rs", (f"// synthetic {project} macro fixture {index}\n"
                  "macro_rules! create_symbol { () => { fn resolve() {} }; }\n"
                  "create_symbol!();\n"), [("macro_gap", 3)]


def build(tier):
    """Build deterministic immutable inputs and a separately held answer oracle."""
    count, cap = TIERS[tier]
    sources, facts, tasks = [], [], []
    for project in PROJECTS:
        for index in range(count // 2):
            extension, text, anchors = template(project, index)
            path = f"{project}/src/unit_{index:04d}.{extension}"
            sources.append((path, text.encode("utf-8")))
            for kind, line in anchors:
                facts.append({**scope(project), "path": path, "line": line,
                              "text": text.splitlines()[line - 1], "kind": kind})
        tasks.append({**scope(project), "families": [
            {"id": "definition_directcall", "query": "Locate resolve and its direct callers in this scope."},
            {"id": "conflictingrules_stale_wrongrevision", "query": "Find the current audit rule; exclude retired and foreign-scope evidence."},
            {"id": "negations_permission", "original": "Prepare a local audit change. Do not send or deploy. Do not invent permission.",
             "constraints": ["local only", "no send", "no deploy", "permission unresolved"]},
            {"id": "rename_delete_malformed_interruption_recovery", "query": "Describe uncertainty after a source change or interrupted extraction."}],
            "instructions": "Use selected scope only. Preserve original constraints; ask about unresolved material permission. No execution authorization."})
    sources = tuple(sorted(sources))
    oracle = canonical({"schema": VERSION, "facts": facts,
        "cross_root_conflicts": [{"paths": [f"{p}/src/unit_0002.md" for p in PROJECTS],
                                  "line": 2, "kind": "conflicting_decisions"},
                                 {"paths": [f"{p}/src/unit_0000.rs" for p in PROJECTS],
                                  "line": 2, "kind": "same_local_symbol_different_scope"}],
        "expected_unknowns": ["macro-generated definitions", "dynamic call targets",
                              "material permission", "task correctness"],
        "rejection_recipe_status": "fixed expectations only; not observed extractor results",
        "rejection_recipes": [
            {"mutation": name, "expected": outcome} for name, outcome in [
                ("foreign_project", "reject_wrong_scope"),
                ("different_worktree", "reject_wrong_scope"),
                ("different_revision", "reject_wrong_revision"),
                ("retired_decision", "reject_stale"),
                ("rename unit_0000.rs to renamed.rs", "reject_old_path"),
                ("delete unit_0000.rs", "reject_deleted_fact"),
                ("truncate unit_0000.rs to pub fn {", "incomplete_not_complete"),
                ("interrupt extraction", "no_partial_admission"),
                ("dependency unavailable", "no_complete_result"),
                ("fresh rebuild after failure", "validate_fresh_candidate_only")]],
        "family_expectations": {"definition_directcall": ["definition", "direct_call"],
            "conflictingrules_stale_wrongrevision": ["current_decision", "reject_stale", "reject_wrong_scope", "reject_wrong_revision"],
            "negations_permission": ["preserve_all_constraints", "permission_unknown", "no_authorization"],
            "rename_delete_malformed_interruption_recovery": ["reject_old_path", "reject_deleted_fact", "incomplete_not_complete", "no_partial_admission", "validate_fresh_candidate_only"]}})
    inputs = canonical({"schema": VERSION, "tier": tier, "tasks": tasks})
    manifest = {"schema": VERSION, "generator": VERSION, "templates": VERSION,
        "tier": tier, "source_count": count, "aggregate_cap": cap, "file_cap": 65536,
        "source_bytes": sum(len(data) for _, data in sources),
        "projects": [{**scope(p), "source_count": count // 2,
                      "source_bytes": sum(len(b) for n, b in sources if n.startswith(p + "/"))}
                     for p in PROJECTS],
        "files": [{"path": path, "bytes": len(data), "sha256": sha(data),
                   **scope(path.split("/")[0])} for path, data in sources],
        "excluded_sources": EXCLUDED, "known_parser_limits": LIMITS,
        "oracle_sha256": sha(oracle), "inputs_sha256": sha(inputs),
        "retrieval": "not_run", "scoring_contract": "not_available",
        "inference": "not_run", "host": "not_run", "executor": "not_run"}
    manifest["digest"] = sha(canonical(manifest))
    return Corpus(sources, canonical(manifest), oracle, inputs)


def decode(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate metadata key")
            result[key] = value
        return result
    try:
        value = json.loads(data, object_pairs_hook=unique)
        if canonical(value) != data:
            raise ValueError("noncanonical metadata")
        return value
    except (TypeError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("malformed metadata") from error


def validate(candidate):
    """Stateless, nonmutating validation against the fixed versioned recipe.

    Reject even self-consistent refrozen changes: a template change requires a
    reviewed new version and digest pins, not merely recalculated hashes.
    """
    try:
        manifest, oracle, inputs = map(decode, (candidate.manifest, candidate.oracle, candidate.inputs))
        tier = manifest["tier"]
        count, cap = TIERS[tier]
        if type(candidate.sources) is not tuple or len(candidate.sources) != count:
            raise ValueError("source count/type mismatch")
        seen, total = {}, 0
        for path, data in candidate.sources:
            if not isinstance(path, str) or not re.fullmatch(
                    r"(?:harbor|harbour)/src/unit_[0-9]{4}\.(?:rs|py|md)", path):
                raise ValueError("noncanonical or foreign source path")
            if path in seen or type(data) is not bytes or len(data) > 65536:
                raise ValueError("duplicate, non-byte or oversized source")
            data.decode("utf-8")
            seen[path] = data
            total += len(data)
        if total > cap:
            raise ValueError("aggregate cap exceeded")
        for fact in oracle["facts"]:
            lines = seen[fact["path"]].decode("utf-8").splitlines()
            line = fact["line"]
            if type(line) is not int or not 1 <= line <= len(lines) or lines[line - 1] != fact["text"]:
                raise ValueError("oracle anchor mismatch")
        expected = build(tier)
        if candidate != expected:
            raise ValueError("frozen corpus mismatch")
        if manifest["digest"] != FROZEN_DIGESTS[tier]:
            raise ValueError("version digest changed")
        return manifest["digest"]
    except (KeyError, TypeError, AttributeError, UnicodeError, IndexError) as error:
        raise ValueError("malformed corpus") from error


# Freeze pins for parent review; changes require a new corpus/template version.
FROZEN_DIGESTS = {
    "small": "c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8",
    "medium": "624273d696f2be78040bc04a7c8b999b87ad34e84c3cf43de8dcb0d66abf2847",
    "large": "7ca4207ef45dc63b7eb6a66cbf16869a29e00210d2a1b4f96b4ff8466b6058df",
}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", choices=tuple(TIERS), required=True)
    args = parser.parse_args()
    corpus = build(args.check)
    print(validate(corpus))
