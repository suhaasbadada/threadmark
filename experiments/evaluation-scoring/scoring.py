"""Prospective contracts and synthetic in-process scoring, not retrieval or a runner."""
from dataclasses import dataclass
import hashlib
import json
import re


VERSION = "evaluation-scoring/1"
MAX_ITEMS = 8
MAX_BYTES = 8192
RELEVANCE = ("definition_directcall", "conflictingrules_stale_wrongrevision")
CONFORMANCE = ("negations_permission", "rename_delete_malformed_interruption_recovery")
SCOPE_KEYS = ("project", "worktree", "revision")
ANCHOR_KEYS = (*SCOPE_KEYS, "path", "line", "text")
CONTRACT = {
    "scope": "all selected-scope UTF-8 .rs/.py/.md sources; no oracle narrowing",
    "tokens": "unique sorted lowercase ASCII [A-Za-z_][A-Za-z0-9_]* from query only",
    "lines": "LF split; remove one trailing CR per line; 1-based; omit final empty line",
    "lexical": "all lines sharing a query token; rank distinct token overlap descending",
    "symbol": "exact case-sensitive query identifiers at declared Rust/Python declarations; rank query identifier position then path/line",
    "symbol_coverage": "Rust named fn/struct/enum/trait/type/const/static/mod declarations including modified/impl methods and textual cfg branches, static mut skips mut; Python def/async def/class including nested, async anchors async; keyword and ASCII name same physical line; exclude comments/strings/generic parameters; no calls, macros, aliases or dynamic resolution",
    "candidate": "planned declarations and resolved direct-call sites for query identifiers; declarations before calls then identifier position then path/line; unresolved omitted and coverage labeled",
    "candidate_blocker": "NOT_IMPLEMENTED: pinned extractor, resolution/coverage decision and reviewed runner required",
    "ties": "UTF-8 POSIX path bytes ascending, then numeric line; same line emitted once",
    "output": "top eight whole anchors, then complete envelope must fit 8192 canonical UTF-8 bytes or reject; no byte-driven truncation",
    "scoring": "exact full source anchor; admissible gold only; no partial credit; duplicates consume budget, unique TP/FP; invalid means no metrics",
    "denominators": "precision TP/(TP+FP); recall TP/gold; zero denominator null; recall ceiling min(8,gold)/gold or null",
    "admission": "exact schema/scope/complete coverage; normalized source anchors must be independently validated before comparisons",
    "instructions": "unchanged declared instructions, same across arms; no extra prompt, oracle, fact kinds or answer hashes",
}


def canonical(value):
    """Exact payload unit: full JSON, sorted keys, no whitespace/newline, raw UTF-8."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def keys(value, expected):
    if type(value) is not dict or set(value) != set(expected):
        raise ValueError("fields/type mismatch")


def strings(values):
    values = tuple(values)
    if any(type(value) is not str or not value for value in values):
        raise ValueError("expected nonempty strings")
    for value in values:
        value.encode("utf-8")


def build_manifest(task):
    """Accept only declared task inputs, never fixture/oracle metadata."""
    keys(task, ("schema", "scope", "family", "query", "instructions"))
    keys(task["scope"], SCOPE_KEYS)
    strings(task["scope"].values())
    strings((task["query"], task["instructions"]))
    if (type(task["schema"]) is not str or task["schema"] != VERSION
            or type(task["family"]) is not str or task["family"] not in RELEVANCE + CONFORMANCE):
        raise ValueError("unsupported task")
    if len(canonical({k: task[k] for k in ("query", "instructions")})) > 4096:
        raise ValueError("original request budget")
    manifest = {
        "schema": VERSION, "task": task, "contract": CONTRACT,
        "query_words": sorted({word.lower() for word in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", task["query"])}),
        "query_identifiers": list(dict.fromkeys(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", task["query"]))),
        "classification": "relevance" if task["family"] in RELEVANCE else "conformance_only",
        "max_items": MAX_ITEMS, "max_payload_bytes": MAX_BYTES,
        "arms": {name: {"implementation": "NOT_IMPLEMENTED", "execution": "NOT_RUN"}
                 for name in ("lexical", "symbol", "candidate")},
    }
    manifest["digest"] = hashlib.sha256(canonical(manifest)).hexdigest()
    return canonical(manifest)


@dataclass(frozen=True)
class Anchor:
    project: str
    worktree: str
    revision: str
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class Fixture:
    """Trusted frozen test metadata, not an input transport or discovered repository.

    anchors is the allowed source-anchor map represented as immutable entries;
    rejected marks stale/forbidden entries. Oracle facts outside gold cannot earn TP.
    """
    scope: tuple
    coverage: tuple
    anchors: tuple
    gold: frozenset
    rejected: frozenset
    family: str = RELEVANCE[0]

    def __post_init__(self):
        if (type(self.scope) is not tuple or len(self.scope) != 3
                or type(self.coverage) is not tuple or not self.coverage
                or type(self.anchors) is not tuple
                or type(self.gold) is not frozenset or type(self.rejected) is not frozenset
                or type(self.family) is not str or self.family not in RELEVANCE + CONFORMANCE):
            raise ValueError("invalid trusted fixture")
        strings(self.scope + self.coverage)
        if any(type(a) is not Anchor for a in self.anchors):
            raise ValueError("invalid trusted anchor")
        for anchor in self.anchors:
            validate_anchor(vars(anchor))
        if (len(set(self.anchors)) != len(self.anchors)
                or len({(a.project, a.worktree, a.revision, a.path, a.line)
                        for a in self.anchors}) != len(self.anchors)
                or not self.gold <= set(self.anchors) - self.rejected
                or not self.rejected <= set(self.anchors)
                or any((a.project, a.worktree, a.revision) != self.scope for a in self.gold)):
            raise ValueError("inconsistent trusted fixture")


def validate_anchor(item):
    keys(item, ANCHOR_KEYS)
    strings(item[k] for k in (*SCOPE_KEYS, "path"))
    path = item["path"]
    if (path.startswith("/") or "\\" in path
            or any(ord(char) < 32 or ord(char) == 127 for char in path)
            or any(part in ("", ".", "..") for part in path.split("/"))):
        raise ValueError("invalid relative POSIX path")
    if type(item["line"]) is not int or item["line"] < 1:
        raise ValueError("invalid line")
    if type(item["text"]) is not str or "\n" in item["text"] or "\r" in item["text"]:
        raise ValueError("invalid single-line text")
    item["text"].encode("utf-8")


def score(fixture, candidate):
    """Reject a whole invalid result. No mutation, persistence, IO or semantic claims."""
    try:
        keys(candidate, ("schema", "scope", "coverage", "items"))
        keys(candidate["scope"], SCOPE_KEYS)
        strings(candidate["scope"].values())
        if type(candidate["schema"]) is not str or candidate["schema"] != VERSION:
            raise ValueError("schema mismatch")
        if tuple(candidate["scope"][key] for key in SCOPE_KEYS) != fixture.scope:
            raise ValueError("scope mismatch")
        keys(candidate["coverage"], ("status", "envelope"))
        coverage = candidate["coverage"]
        if (type(coverage["status"]) is not str or coverage["status"] != "complete"
                or type(coverage["envelope"]) is not list):
            raise ValueError("incomplete/malformed coverage")
        strings(coverage["envelope"])
        if tuple(coverage["envelope"]) != fixture.coverage:
            raise ValueError("coverage mismatch")
        items = candidate["items"]
        if type(items) is not list or len(items) > MAX_ITEMS:
            raise ValueError("item budget/type")
        submitted = []
        for item in items:
            validate_anchor(item)
            anchor = Anchor(**item)
            if (anchor.project, anchor.worktree, anchor.revision) != fixture.scope:
                raise ValueError("anchor scope mismatch")
            if anchor not in fixture.anchors or anchor in fixture.rejected:
                raise ValueError("unknown, stale or forbidden anchor")
            submitted.append(anchor)
        payload_bytes = len(canonical(candidate))
        if payload_bytes > MAX_BYTES:
            raise ValueError("payload budget")
        unique = set(submitted)
        result = {"status": "valid", "submitted_count": len(items),
                  "unique_count": len(unique), "duplicate_count": len(items) - len(unique),
                  "payload_bytes": payload_bytes, "metrics": None}
        if fixture.family in CONFORMANCE:
            result["status"] = "conformance_only_not_evaluated"
            return result
        tp, fp = len(unique & fixture.gold), len(unique - fixture.gold)
        gold = len(fixture.gold)
        result["metrics"] = {"tp": tp, "fp": fp, "fn": gold - tp,
                             "gold_count": gold,
                             "precision": tp / (tp + fp) if tp + fp else None,
                             "recall": tp / gold if gold else None,
                             "slot_budget_recall_ceiling": min(MAX_ITEMS, gold) / gold if gold else None}
        return result
    except (ValueError, TypeError, UnicodeError) as error:
        return {"status": "invalid", "reason": str(error), "metrics": None}
