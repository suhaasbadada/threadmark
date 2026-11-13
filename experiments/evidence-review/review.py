"""Fixed synthetic recorded-evidence review; no execution or host capabilities."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "experiments/extraction/scoped-results-v1.json"
FIXTURES = ROOT / "experiments/extraction/fixtures"
EXPECTED_SHA = "4e3d9e0ceda5352c2f109bd51532a6e9de2ce9af2e4f0ee9d1f53b8b2d5f8afe"
PROJECTS = ("orbit", "orbit-next")
SOURCE_NAMES = ("lib.rs", "service.py")
REPORT_LIMIT = 128 * 1024
SOURCE_LIMIT = 64 * 1024
DRAFT_LIMIT = 8 * 1024
ORIGINAL = ("Locate normalize and its direct callers in the selected project. "
            "Do not modify files, send messages or execute tools.")

# Fixed authored stdlib-only dependency; never import Graphify/scoped_run/workers.
_spec = importlib.util.spec_from_file_location(
    "review_normalized", ROOT / "experiments/extraction/normalized.py")
norm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(norm)


def bounded_read(path, limit):
    if path.is_symlink() or not path.is_file():
        raise ValueError("unavailable")
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    if len(data) > limit:
        raise ValueError("unavailable")
    return data


def load_recorded(project):
    """Fixed paths only. None means unavailable, with no retained evidence."""
    if project not in PROJECTS:
        return None
    try:
        raw = bounded_read(REPORT, REPORT_LIMIT)
        if hashlib.sha256(raw).hexdigest() != EXPECTED_SHA:
            return None
        report = json.loads(raw)
        matches = [r for r in report["results"]
                   if r["project"] == project and r["case"] == "baseline"]
        if len(matches) != 1 or matches[0]["status"] != "accepted":
            return None
        snapshot = matches[0]["snapshot"]
        scope = {"project": project, "worktree": "synthetic-worktree",
                 "revision": "synthetic-snapshot-1"}
        sources = {name: bounded_read(FIXTURES / project / name, SOURCE_LIMIT)
                   for name in SOURCE_NAMES}
        if norm.source_manifest(sources) != snapshot["manifest"]:
            return None
        rows = norm.query_rows(snapshot, scope)
        return {"scope": scope, "producer": snapshot["producer"],
                "coverage": snapshot["coverage"],
                "limitations": snapshot["limitations"], "rows": rows}
    except (OSError, ValueError, KeyError, TypeError):
        return None


def candidate(evidence):
    scope, producer = evidence["scope"], evidence["producer"]
    parts = [ORIGINAL, "", "Deterministic recorded source context (not AI refinement):",
             "Scope: " + " / ".join(scope[k] for k in ("project", "worktree", "revision")),
             "Recorded producer: " + " / ".join(producer[k] for k in ("name", "version", "api")),
             "Coverage: " + evidence["coverage"], *evidence["limitations"],
             "Current fixed fixture bytes match recorded snapshot; live/Git freshness unsupported."]
    for question, rows in evidence["rows"].items():
        parts.append(question + ":")
        for row in rows:
            a = row["anchor"]
            parts.extend([f'{a["path"]}:L{a["start"]}-L{a["end"]} '
                          f'confidence={row.get("confidence", "not supplied")} '
                          f'origin={row["origin"]}',
                          "source sha256=" + a["sha256"], a["excerpt"]])
    draft = "\n".join(parts)
    if len(draft.encode("utf-8")) > DRAFT_LIMIT:
        raise ValueError("unavailable")
    return draft


class Controller:
    def __init__(self, project, loader=load_recorded):
        if project not in PROJECTS:
            raise ValueError("invalid project")
        self.project = project
        self.loader = loader
        self.stale = False
        self.outage = False
        self.draft = ""
        self.reviewed = False
        self.closed = False
        self.status = "Unreviewed. Nothing copied, sent or executed."
        self.refresh()

    def invalidate(self):
        self.reviewed = False
        self.draft = ""

    def fresh_draft(self):
        if self.stale or self.outage:
            return ""
        evidence = self.loader(self.project)
        if evidence is None:
            return ""
        try:
            return candidate(evidence)
        except (ValueError, KeyError, TypeError):
            return ""

    def refresh(self):
        self.invalidate()
        self.draft = self.fresh_draft()
        self.status = ("Unreviewed." if self.draft else "Unavailable; zero evidence.")

    def cancel(self):
        self.invalidate()
        self.closed = True
        self.status = "Canceled; original only; no approved draft."

    def command(self, command):
        if self.closed:
            return
        if command in ("cancel", "quit"):
            self.cancel()
        elif command == "review":
            fresh = self.fresh_draft()
            if fresh and fresh == self.draft:
                self.reviewed = True
                self.status = "Locally reviewed. Not host consent or future approval authority."
            else:
                self.invalidate()
                self.status = "Review blocked; unavailable or changed; zero evidence."
        elif command == "show":
            fresh = self.fresh_draft()
            if fresh != self.draft:
                self.invalidate()
                self.draft = fresh
                self.status = "Context changed; unreviewed." if fresh else "Unavailable; zero evidence."
        elif command.startswith("project ") and command[8:] in PROJECTS:
            self.project = command[8:]
            self.refresh()
        elif command in ("stale", "restore", "unavailable", "recover"):
            if command in ("stale", "restore"):
                self.stale = command == "stale"
            else:
                self.outage = command == "unavailable"
            self.refresh()
        elif command != "help":
            self.invalidate()
            self.status = "Unknown command rejected; review invalidated."

    def display(self):
        common = (f"Project: {self.project}\nSIMULATED stale={self.stale} "
                  f"dependency_outage={self.outage}\nStatus: {self.status}\n"
                  f"Locally reviewed: {self.reviewed}\nNothing copied, sent or executed.\n")
        if self.closed:
            return common + "Original:\n" + ORIGINAL + "\n"
        return common + ("Draft for inspection:\n" + self.draft if self.draft
                         else "Original only; zero evidence:\n" + ORIGINAL) + "\n"
