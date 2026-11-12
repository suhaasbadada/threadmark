"""Pure synthetic source-line baseline; no candidate coverage or semantic claims."""
from dataclasses import asdict, dataclass
import json
import re


SCOPE = ("project", "worktree", "revision")
FAMILIES = ("definition_directcall", "conflictingrules_stale_wrongrevision")
TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass(frozen=True)
class Anchor:
    project: str
    worktree: str
    revision: str
    path: str
    line: int
    text: str


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def _require(condition):
    if not condition:
        raise ValueError("invalid or unsupported lexical input")


def _fields(value, names):
    _require(type(value) is dict and set(value) == set(names))


def _words(text):
    return {word.lower() for word in TOKEN.findall(text)}


def _lines(data):
    lines = data.decode("utf-8").split("\n")
    if lines[-1] == "":
        lines.pop()
    normalized = tuple(line[:-1] if line.endswith("\r") else line for line in lines)
    _require(all("\r" not in line for line in normalized))
    return normalized


def retrieve(sources, task):
    """Return selected anchors only, or raise ValueError without partial output.

    sources is a UTF-8-path-byte-sorted tuple of (project-relative path, bytes)
    pairs, including the project root component. task is the five-field declared
    scoring task. All source bytes must already be approved synthetic inputs.
    Labels constrain value consistency, not authorization or real Git identity.
    Budgets apply after allocation. No IO, oracle, cache or last-good state.
    """
    try:
        return _retrieve(sources, task)
    except (UnicodeError, TypeError, ValueError) as error:
        raise ValueError("invalid or unsupported lexical input") from error


def _retrieve(sources, task):
    _fields(task, ("schema", "scope", "family", "query", "instructions"))
    _require(type(task["schema"]) is str and task["schema"] == "evaluation-scoring/1")
    _require(type(task["family"]) is str and task["family"] in FAMILIES)
    _fields(task["scope"], SCOPE)
    scope = tuple(task["scope"][key] for key in SCOPE)
    for label in scope:
        _require(type(label) is str
                 and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", label) is not None)
    for key in ("query", "instructions"):
        _require(type(task[key]) is str and bool(task[key]))
        task[key].encode("utf-8")
    _require(len(_canonical({key: task[key] for key in ("query", "instructions")})) <= 4096)
    _require(type(sources) is tuple and len(sources) <= 2048)
    # Validate every source, even with no query tokens or no matches. Never
    # silently skip a foreign root, malformed file, or an over-budget source.
    validated = []
    previous = b""
    total = 0
    for pair in sources:
        _require(type(pair) is tuple and len(pair) == 2)
        path, data = pair
        _require(type(path) is str and bool(path))
        encoded = path.encode("utf-8")
        parts = path.split("/")
        _require(not path.startswith("/") and "\\" not in path
                 and not any(ord(c) < 32 or ord(c) == 127 for c in path)
                 and not any(part in ("", ".", "..") for part in parts)
                 and len(parts) >= 2 and parts[0] == scope[0]
                 and path.endswith((".rs", ".py", ".md")))
        _require(encoded > previous)
        previous = encoded
        _require(type(data) is bytes and len(data) <= 65536)
        total += len(data)
        _require(total <= 32 * 1024 * 1024)
        # Validate every file first, but do not retain all decoded source lines.
        _lines(data)
        validated.append((path, encoded, data))
    query_words = _words(task["query"])
    ranked = []
    for path, encoded, data in validated:
        for number, text in enumerate(_lines(data), 1):
            overlap = len(query_words & _words(text))
            if overlap:
                ranked.append((-overlap, encoded, number,
                               Anchor(*scope, path, number, text)))
                ranked.sort(key=lambda row: row[:3])
                del ranked[8:]
    # Unique paths and one visit per numeric line guarantee unique coordinates.
    anchors = tuple(row[3] for row in ranked)
    _require(len(_canonical([asdict(anchor) for anchor in anchors])) <= 8192)
    return anchors
