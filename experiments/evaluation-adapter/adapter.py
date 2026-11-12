"""Pure public-synthetic fixture preparation, not retrieval or corpus transport."""
from dataclasses import dataclass
import hashlib
import json
import re


SCOPE = ("project", "worktree", "revision")
ANCHOR = (*SCOPE, "path", "line", "text")
FAMILIES = ("definition_directcall", "conflictingrules_stale_wrongrevision",
            "negations_permission", "rename_delete_malformed_interruption_recovery")
KINDS = {"definition", "direct_call", "current_decision", "stale_decision",
         "negation_permission", "macro_gap", "dynamic_gap"}
TIERS = {"small": (32, 1 << 20), "medium": (256, 8 << 20),
         "large": (2048, 32 << 20)}
PROJECTS = ("harbor", "harbour")
META_CAP = 16 << 20


def canonical(value, *, ascii_only=True):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=ascii_only, allow_nan=False).encode(
                          "ascii" if ascii_only else "utf-8")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition):
    if not condition:
        raise ValueError("unsupported or inconsistent synthetic artifact")


def keys(value, fields):
    require(type(value) is dict and set(value) == set(fields))


def text(value):
    require(type(value) is str and bool(value))
    value.encode("utf-8")


def strings(value):
    require(type(value) is list and bool(value))
    for item in value:
        text(item)


def number(value, minimum, maximum):
    require(type(value) is int and minimum <= value <= maximum)


def digest(value):
    require(type(value) is str and re.fullmatch("[0-9a-f]{64}", value) is not None)


def decode(data):
    require(type(data) is bytes and 0 < len(data) <= META_CAP)

    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result)
            result[key] = value
        return result

    value = json.loads(data, object_pairs_hook=unique)
    require(canonical(value) == data)
    return value


def scope(value):
    keys(value, SCOPE)
    for item in value.values():
        text(item)
        require(re.fullmatch(r"[A-Za-z0-9_-]{1,128}", item) is not None)
    require(value["project"] in PROJECTS)


def source_lines(data):
    require(type(data) is bytes and len(data) <= 65536)
    value = data.decode("utf-8")
    # No CR normalization, splitlines(), truncation or syntax interpretation.
    require(not any(c in value for c in "\r\v\f\x1c\x1d\x1e\x85\u2028\u2029"))
    require(not any(ord(c) < 32 and c not in "\t\n" for c in value))
    lines = value.split("\n")
    if lines[-1] == "":
        lines.pop()
    return lines


@dataclass(frozen=True)
class ArmInput:
    """Only these source bytes and declared tasks may go to a future arm."""
    sources: tuple
    declared_task: bytes
    method_task: bytes | None


@dataclass(frozen=True)
class Case:
    arm_input: ArmInput
    fixture: bytes
    private_sidecar: bytes


def prepare(sources, manifest, oracle, inputs, selected_scope, *, expected_digest):
    """Validate then convert all four families, or raise ValueError with no result.

    expected_digest is a TRUSTED separately predeclared pin, never a candidate
    field. Caller must freeze it before execution. Integrity is not authentication.
    Only existing immutable bytes/tuples are accepted; no IO or mutable state.
    """
    try:
        return _prepare(sources, manifest, oracle, inputs, selected_scope,
                        expected_digest)
    except (TypeError, KeyError, IndexError, UnicodeError, RecursionError,
            OverflowError, ValueError) as error:
        raise ValueError("invalid or unsupported adapter input") from error


def _prepare(sources, manifest_bytes, oracle_bytes, inputs_bytes, selected, pin):
    digest(pin)
    scope(selected)
    m, o, i = map(decode, (manifest_bytes, oracle_bytes, inputs_bytes))
    keys(m, ("schema", "generator", "templates", "tier", "source_count",
             "aggregate_cap", "file_cap", "source_bytes", "projects", "files",
             "excluded_sources", "known_parser_limits", "oracle_sha256",
             "inputs_sha256", "retrieval", "scoring_contract", "inference",
             "host", "executor", "digest"))
    require(all(type(m[k]) is str and m[k] == "1"
                for k in ("schema", "generator", "templates")))
    require(type(m["tier"]) is str and m["tier"] in TIERS)
    count_cap, byte_cap = TIERS[m["tier"]]
    number(m["source_count"], 1, count_cap)
    number(m["source_bytes"], 0, byte_cap)
    require(type(m["aggregate_cap"]) is int and m["aggregate_cap"] == byte_cap)
    require(type(m["file_cap"]) is int and m["file_cap"] == 65536)
    for key in ("retrieval", "inference", "host", "executor"):
        require(m[key] == "not_run")
    require(m["scoring_contract"] == "not_available")
    for key in ("excluded_sources", "known_parser_limits"):
        strings(m[key])
    for key in ("digest", "oracle_sha256", "inputs_sha256"):
        digest(m[key])
    require(sha(canonical({k: v for k, v in m.items() if k != "digest"}))
            == m["digest"] == pin)
    require(sha(oracle_bytes) == m["oracle_sha256"]
            and sha(inputs_bytes) == m["inputs_sha256"])

    require(type(m["projects"]) is list and len(m["projects"]) == 2)
    scopes = {}
    for project, entry in zip(PROJECTS, m["projects"]):
        keys(entry, (*SCOPE, "source_count", "source_bytes"))
        s = {k: entry[k] for k in SCOPE}
        scope(s)
        require(s["project"] == project)
        number(entry["source_count"], 1, count_cap)
        number(entry["source_bytes"], 0, byte_cap)
        scopes[project] = s
    require(selected == scopes[selected["project"]])
    require(type(sources) is tuple and len(sources) == m["source_count"])
    require(type(m["files"]) is list and len(m["files"]) == len(sources))
    files, line_map, previous = {}, {}, ""
    for pair, entry in zip(sources, m["files"]):
        require(type(pair) is tuple and len(pair) == 2)
        path, data = pair
        require(type(path) is str and re.fullmatch(
            r"(?:harbor|harbour)/src/unit_[0-9]{4}\.(?:rs|py|md)", path) is not None)
        require(path > previous)
        previous = path
        keys(entry, (*SCOPE, "path", "bytes", "sha256"))
        require({k: entry[k] for k in SCOPE} == scopes[path.split("/")[0]])
        number(entry["bytes"], 0, 65536)
        digest(entry["sha256"])
        lines = source_lines(data)
        require(entry["path"] == path and entry["bytes"] == len(data)
                and entry["sha256"] == sha(data))
        files[path] = entry
        line_map[path] = lines
    require(sum(len(b) for _, b in sources) == m["source_bytes"] <= byte_cap)
    for entry in m["projects"]:
        own = [f for f in m["files"] if f["project"] == entry["project"]]
        require(len(own) == entry["source_count"]
                and sum(f["bytes"] for f in own) == entry["source_bytes"])

    keys(o, ("schema", "facts", "cross_root_conflicts", "expected_unknowns",
             "rejection_recipe_status", "rejection_recipes", "family_expectations"))
    keys(i, ("schema", "tier", "tasks"))
    require(type(o["schema"]) is str and o["schema"] == "1"
            and type(i["schema"]) is str and i["schema"] == "1"
            and i["tier"] == m["tier"])
    require(type(o["facts"]) is list and 0 < len(o["facts"]) <= 65536)
    fact_anchors, seen = [], set()
    for fact in o["facts"]:
        keys(fact, (*ANCHOR, "kind"))
        require(type(fact["kind"]) is str and fact["kind"] in KINDS)
        require(type(fact["path"]) is str and fact["path"] in files)
        entry = files[fact["path"]]
        require({k: fact[k] for k in SCOPE} == {k: entry[k] for k in SCOPE})
        lines = line_map[fact["path"]]
        number(fact["line"], 1, len(lines))
        require(type(fact["text"]) is str and fact["text"] == lines[fact["line"] - 1])
        identity = (fact["path"], fact["line"])
        require(identity not in seen)
        seen.add(identity)
        fact_anchors.append(({k: fact[k] for k in ANCHOR}, fact["kind"]))
    strings(o["expected_unknowns"])
    require(o["rejection_recipe_status"] == "fixed expectations only; not observed extractor results")
    require(type(o["rejection_recipes"]) is list and bool(o["rejection_recipes"]))
    mutations = set()
    for recipe in o["rejection_recipes"]:
        keys(recipe, ("mutation", "expected"))
        text(recipe["mutation"])
        text(recipe["expected"])
        require(recipe["mutation"] not in mutations)
        mutations.add(recipe["mutation"])
    keys(o["family_expectations"], FAMILIES)
    for value in o["family_expectations"].values():
        strings(value)
    require(type(o["cross_root_conflicts"]) is list and bool(o["cross_root_conflicts"]))
    for conflict in o["cross_root_conflicts"]:
        keys(conflict, ("paths", "line", "kind"))
        strings(conflict["paths"])
        require(len(conflict["paths"]) == 2 and len(set(conflict["paths"])) == 2)
        require({files[p]["project"] for p in conflict["paths"]} == set(PROJECTS))
        for path in conflict["paths"]:
            number(conflict["line"], 1, len(line_map[path]))
        require(conflict["kind"] in ("conflicting_decisions", "same_local_symbol_different_scope"))

    require(type(i["tasks"]) is list and len(i["tasks"]) == 2)
    chosen = None
    for project, task in zip(PROJECTS, i["tasks"]):
        keys(task, (*SCOPE, "families", "instructions"))
        require({k: task[k] for k in SCOPE} == scopes[project])
        text(task["instructions"])
        require(type(task["families"]) is list and len(task["families"]) == 4)
        for family_id, family in zip(FAMILIES, task["families"]):
            if family_id == "negations_permission":
                keys(family, ("id", "original", "constraints"))
                text(family["original"])
                strings(family["constraints"])
            else:
                keys(family, ("id", "query"))
                text(family["query"])
            require(family["id"] == family_id)
            request = {k: v for k, v in family.items() if k != "id"}
            request["instructions"] = task["instructions"]
            require(len(canonical(request, ascii_only=False)) <= 4096)
        if project == selected["project"]:
            chosen = task

    selected_sources = tuple((p, b) for p, b in sources
                             if files[p]["project"] == selected["project"])
    anchors = [{**selected, "path": p, "line": n, "text": line}
               for p, _ in selected_sources
               for n, line in enumerate(line_map[p], 1)]
    eligible = [(a, kind) for a, kind in fact_anchors
                if all(a[k] == selected[k] for k in SCOPE)]
    selected_files = [entry for entry in m["files"]
                      if entry["project"] == selected["project"]]
    coverage = ["evaluation-adapter/1; corpus schema/generator/templates 1; LF-only",
                "limited authored fixture map, not extractor completeness or syntax certification",
                "corpus digest=" + pin, "oracle sha256=" + m["oracle_sha256"],
                "inputs sha256=" + m["inputs_sha256"],
                "Rust macro expansion unavailable; Python dynamic calls unresolved",
                *m["known_parser_limits"],
                "selected source manifest sha256=" + sha(canonical(selected_files))]
    cases = []
    for family in chosen["families"]:
        name = family["id"]
        conformance = name in FAMILIES[2:]
        gold_kinds = ({"definition", "direct_call"} if name == FAMILIES[0]
                      else {"current_decision"} if name == FAMILIES[1] else set())
        gold = [a for a, kind in eligible if kind in gold_kinds]
        rejected = [a for a, kind in eligible if kind == "stale_decision"]
        declared = {"schema": "1", "scope": selected, "original_input": family,
                    "instructions": chosen["instructions"]}
        method = None if "query" not in family else canonical({
            "schema": "evaluation-scoring/1", "scope": selected, "family": name,
            "query": family["query"], "instructions": chosen["instructions"]},
            ascii_only=False)
        fixture = {"scope": selected, "family": name, "coverage": coverage,
                   "anchors": anchors, "gold": gold, "rejected": rejected}
        sidecar = {"status": "public_synthetic_only", "classification":
                   "conformance_only" if conformance else "relevance",
                   "score_manifest_mapping": "NOT_AVAILABLE" if method is None
                   else "task_fields_only_not_integrated",
                   "budgets": {"max_items": 8, "max_candidate_bytes": 8192,
                               "max_original_bytes": 4096},
                   "manifest": m, "oracle": o, "inputs": i,
                   "retrieval": "NOT_IMPLEMENTED/NOT_RUN",
                   "runner": "NOT_IMPLEMENTED/NOT_RUN"}
        cases.append(Case(ArmInput(selected_sources, canonical(declared), method),
                          canonical(fixture, ascii_only=False), canonical(sidecar)))
    return tuple(cases)
