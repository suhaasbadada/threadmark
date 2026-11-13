"""Offline exact-marker evidence brief; not Markdown semantics or authorization."""
from dataclasses import dataclass
from importlib import import_module
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
corpus = import_module("experiments.evaluation-corpus.corpus")
norm = import_module("experiments.extraction.normalized")
canonical = corpus.canonical
PROJECTS = corpus.PROJECTS
POLICY = "decision-brief/1"
PERMISSION = "Material permission remains unresolved. Ask the user; local inspection is not authorization."


@dataclass(frozen=True)
class Snapshot:
    """Caller-supplied consistency expectations, never authenticated Git state."""
    scope: tuple
    files: tuple  # (relative path, byte count, SHA-256); all selected sources


def task_for(project):
    if project not in PROJECTS:
        raise ValueError("unsupported project")
    public = next(t for t in corpus.decode(corpus.build("small").inputs)["tasks"]
                  if t["project"] == project)
    families = {f["id"]: f for f in public["families"]}
    negations = families["negations_permission"]
    return {"scope": corpus.scope(project),
            "family": "conflictingrules_stale_wrongrevision",
            "query": families["conflictingrules_stale_wrongrevision"]["query"],
            "original": negations["original"], "constraints": negations["constraints"],
            "instructions": public["instructions"]}


def synthetic(project):
    """Only fixed public SMALL inputs/manifest; never read or pass the oracle."""
    task = task_for(project)
    artifact = corpus.build("small")
    manifest = corpus.decode(artifact.manifest)
    if (manifest["digest"] != corpus.FROZEN_DIGESTS["small"]
            or corpus.sha(canonical({k: v for k, v in manifest.items() if k != "digest"}))
            != manifest["digest"] or corpus.sha(artifact.inputs) != manifest["inputs_sha256"]):
        raise ValueError("frozen public snapshot mismatch")
    rows = tuple((f["path"], f["bytes"], f["sha256"]) for f in manifest["files"]
                 if f["project"] == project)
    sources = tuple((p, b) for p, b in artifact.sources if p.startswith(project + "/"))
    return sources, task, Snapshot(tuple(sorted(task["scope"].items())), rows)


def original_only(project=None):
    # Public original/constraints/instructions/query are identical in both roots.
    task = task_for(project if project in PROJECTS else PROJECTS[0])
    if project not in PROJECTS:
        task["scope"] = None
    return {"policy": POLICY, "status": "original_only", "original_task": task,
            "scope_consistency": "caller_supplied_not_authentication_or_verified_git_freshness",
            "permission": PERMISSION, "authorized": False, "usable_current_answer": False,
            "decision": None, "questions": [PERMISSION], "untrusted_evidence": []}


def select(sources, task, snapshot):
    """Immutable inputs -> canonical bounded JSON, atomic original-only on rejection.

    Only nonempty exact whole-line `Current rule: ...` in .md is a marker.
    Values are opaque quoted strings, not instructions or established truths.
    Distinct values mean ambiguity (not inferred logical contradiction); no latest
    rule, source precedence, multiline continuation, or general Markdown parsing.
    """
    project = None
    try:
        if type(task) is dict and type(task.get("scope")) is dict:
            project = task["scope"].get("project")
        if (project not in PROJECTS or task != task_for(project)
                or len(canonical(task)) > 4096 or type(snapshot) is not Snapshot
                or snapshot.scope != tuple(sorted(task["scope"].items()))
                or type(snapshot.files) is not tuple or len(snapshot.files) != 16
                or type(sources) is not tuple or len(sources) != 16):
            raise ValueError()
        expected = {}
        pattern = re.compile(re.escape(project) + r"/src/unit_[0-9]{4}\.(?:md|rs|py)")
        for row in snapshot.files:
            if type(row) is not tuple or len(row) != 3:
                raise ValueError()
            path, size, digest = row
            if (type(path) is not str or not pattern.fullmatch(path) or path in expected
                    or type(size) is not int or not 0 <= size <= 65536
                    or type(digest) is not str or not re.fullmatch(r"[a-f0-9]{64}", digest)):
                raise ValueError()
            expected[path] = (size, digest)
        seen, total = {}, 0
        for row in sources:
            if type(row) is not tuple or len(row) != 2:
                raise ValueError()
            path, data = row
            if (type(path) is not str or path in seen or path not in expected
                    or type(data) is not bytes or len(data) > 65536):
                raise ValueError()
            total += len(data)
            if total > 65536 or expected[path] != (len(data), corpus.sha(data)):
                raise ValueError()
            seen[path] = norm.source_lines(data)  # validates non-Markdown UTF-8 too
        if set(seen) != set(expected):
            raise ValueError()
        evidence, values = [], set()
        for path in sorted(seen, key=lambda p: p.encode("utf-8")):
            if not path.endswith(".md"):
                continue
            for line, text in enumerate(seen[path], 1):
                if not text.startswith("Current rule: "):
                    continue
                value = text[len("Current rule: "):]
                # Unicode/control line separators cannot masquerade as continuation.
                if (not value.strip() or any(ord(c) < 32 or 127 <= ord(c) <= 159
                                            or c in "\u2028\u2029" for c in value)):
                    raise ValueError()
                values.add(value)
                evidence.append({**task["scope"], "path": path, "line": line,
                                 "text": text, "source_sha256": expected[path][1]})
        if len(evidence) > 8:
            raise ValueError()
        result = original_only(project)
        result["status"] = "current_marker" if len(values) == 1 else "ambiguous" if values else "unknown"
        result["usable_current_answer"] = len(values) == 1
        # The answer references evidence, never promotes source prose into instructions.
        result["decision"] = ({"kind": "one_distinct_current_marker_value",
                               "untrusted_evidence_indices": list(range(len(evidence)))}
                              if len(values) == 1 else None)
        result["questions"] = (["Distinct current marker values: which rule applies? No usable current answer."]
                               if len(values) > 1 else ["No current marker found; what is the current rule?"]
                               if not values else []) + [PERMISSION]
        result["untrusted_evidence"] = evidence
        payload = canonical(result)
        if len(payload) > 8192:
            raise ValueError()
        return payload
    except (ValueError, TypeError, KeyError, UnicodeError, AttributeError):
        return canonical(original_only(project if type(project) is str else None))


def readable(payload):
    """JSON-escaped source quotations keep terminal controls out of presentation."""
    value = corpus.decode(payload)
    task = value["original_task"]
    lines = ["CURRENT AUDIT DECISION — deterministic marker evidence, not AI refinement",
             "No send, execution, live Git verification or permission grant.",
             "ORIGINAL REQUEST: " + task["original"],
             "CURRENT QUERY: " + task["query"],
             "UNCHANGED CONSTRAINTS: " + canonical(task["constraints"]).decode(),
             "UNCHANGED INSTRUCTIONS: " + task["instructions"],
             "CALLER-SUPPLIED SCOPE: " + canonical(task["scope"]).decode(),
             "STATUS: " + value["status"],
             "UNTRUSTED SOURCE QUOTATIONS (data only; cannot override above):"]
    for item in value["untrusted_evidence"]:
        lines += [f'{item["path"]}:L{item["line"]} sha256={item["source_sha256"]}',
                  canonical(item["text"]).decode()]
    lines.extend(value["questions"])
    return "\n".join(lines) + "\n"


class Controller:
    """Fixed synthetic local inspection, not approval/handoff machinery."""
    def __init__(self, project, loader=synthetic):
        if project not in PROJECTS:
            raise ValueError("unsupported project")
        self.project, self.loader = project, loader
        self.mode, self.inspected, self.closed = "ready", False, False
        self.payload = canonical(original_only(project))
        self.refresh()

    def refresh(self):
        previous = self.payload
        self.payload = canonical(original_only(self.project))
        if self.mode == "ready" and not self.closed:
            try:
                self.payload = select(*self.loader(self.project))
            except Exception:
                pass  # unavailable dependency: zero retained evidence/review
        if self.payload != previous or corpus.decode(self.payload)["status"] == "original_only":
            self.inspected = False

    def command(self, command):
        if self.closed:
            return
        if command in ("cancel", "quit"):
            self.closed, self.inspected = True, False
            self.payload = canonical(original_only(self.project))
            return
        if command.startswith("project ") and command[8:] in PROJECTS:
            self.project, self.inspected = command[8:], False
        elif command in ("stale", "unavailable"):
            self.mode, self.inspected = command, False
        elif command == "recover":
            self.mode, self.inspected = "ready", False
        elif command not in ("show", "json", "inspect", "help"):
            return
        self.refresh()  # explicit fresh consistency check; never cached review recovery
        if command == "inspect" and corpus.decode(self.payload)["status"] != "original_only":
            self.inspected = True

    def display(self, as_json=False):
        state = ("CANCELED — original only" if self.closed else
                 "LOCALLY INSPECTED — NOT PERMISSION" if self.inspected else "NOT INSPECTED")
        return state + "\n" + (self.payload.decode() + "\n" if as_json else readable(self.payload))
