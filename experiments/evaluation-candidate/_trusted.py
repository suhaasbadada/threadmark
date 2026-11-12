"""Private authored normalization shared by candidate and runner, never a plugin API.

Only the adapter supplies Case values. Policy pins are authored here; observations
come from ALL selected public sources, never the oracle or retriever's metadata.
"""
from dataclasses import asdict, dataclass
import hashlib
from importlib import import_module
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
VERSION = "evaluation-directcall-admission/1"
SOURCE_PINS = (
    ("evaluation-directcall/directcall.py", "b9210ec286093a257ca6e814dd0c31047f78b93ed554d09e6778b447b66e0221"),
    ("evaluation-symbol/symbol.py", "d09e22d3a7d3f077673d672920bbeeff983de778407684ec6dc5c9e53ba63a60"),
    ("evaluation-scoring/scoring.py", "78d023fcb47e3a85908f0cd87ca9d3ae0126b70b330eba465c887281b6919181"),
    ("evaluation-corpus/corpus.py", "87f884b5820060e6939e05612699fd86be193d4b36fa14ddf0cfd4f16cc09dff"),
    ("evaluation-adapter/adapter.py", "5e71fb9e5c63dc0794944d62b981c19be831df12cd635ac24e92609d5e66dab2"),
)
# Digests of the AUTHORED standalone manifest with exactly these grammar labels.
# These are protocol states, NOT certification that every interpreter was tested.
GRAMMARS = (
    ((3, 10), "b1edfcdbc4feee8f361805e08aa5082fd3ac2414da423c16fd3691ff34313c89"),
    ((3, 11), "fe8edca605f4512bb1c3599ef2bae86ce5dea01a3a4200e4bb03e8c0b938952e"),
    ((3, 12), "7e126aabcfca4db0b01568139cd711cd22391bcd2eb979c3b78083fc588ed622"),
    ((3, 13), "d74c5f2a3da57f0be52228fffa2543e3d4945c62b8f08a3fb5a62964ce123b07"),
    ((3, 14), "f20a75851f8531af7676b6f0bd9bf339eefbdd59490696eb5e9e156d9c16de7e"),
)


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _bindings():
    return tuple((name, _sha((ROOT / "experiments" / name).read_bytes()))
                 for name in (*dict(SOURCE_PINS), "evaluation-candidate/_trusted.py"))


def _policy():
    directcall = import_module("experiments.evaluation-directcall.directcall")
    scoring = import_module("experiments.evaluation-scoring.scoring")
    grammar = tuple(sys.version_info[:2])
    expected = dict(GRAMMARS).get(grammar)
    if expected is None or _bindings()[:-1] != SOURCE_PINS:
        raise ValueError("unreviewed code or grammar")
    raw = directcall.policy_manifest()
    policy = json.loads(raw)
    digest = policy.pop("digest")
    if (digest != expected or _sha(scoring.canonical(policy)) != expected
            or scoring.canonical({**policy, "digest": digest}) != raw):
        raise ValueError("unreviewed standalone policy")
    # Supplemental integration policy; the historical pending value is untouched.
    return scoring.canonical({
        "policy": VERSION, "arm": "candidate", "python_ast_grammar": list(grammar),
        "standalone_policy": expected, "sources": dict(SOURCE_PINS),
        "observation": "all selected sources and scope; exact full extraction canonical sha256",
        "admission": "limited adapter map plus policy and observation commitments; actual scorer; whole8192",
        "consistency": "same reviewed extractor, not independent semantic oracle or runtime certainty",
        "readiness": "integration review, committed pins and exact-head CI are parent gates"})


@dataclass(frozen=True)
class Expectation:
    fixture: object
    sources: tuple
    scope: tuple
    policy: bytes
    observation: bytes
    bindings: tuple


def _observation(sources, scope):
    directcall = import_module("experiments.evaluation-directcall.directcall")
    scoring = import_module("experiments.evaluation-scoring.scoring")
    # Scope ONLY; no task/query, fixture, oracle, answer hash or private fact kind.
    extraction = directcall.extract(sources, dict(zip(scoring.SCOPE_KEYS, scope)))
    if type(extraction) is not directcall.Extraction:
        raise ValueError("invalid observation")
    return scoring.canonical({
        "scope": scope,
        "snapshot": [(p, len(b), _sha(b)) for p, b in sources],
        "extraction": asdict(extraction)})


def _prepare(case, method):
    scoring = import_module("experiments.evaluation-scoring.scoring")
    data = json.loads(case.fixture)
    scope = tuple(data["scope"][k] for k in scoring.SCOPE_KEYS)
    coverage = tuple(data["coverage"])
    policy = observation = b""
    bindings = ()
    if method == "candidate":
        bindings = _bindings()
        policy = _policy()
        observation = _observation(case.arm_input.sources, scope)
        coverage += ("candidate policy sha256=" + _sha(policy),
                     "candidate observation sha256=" + _sha(observation))
    fixture = scoring.Fixture(scope, coverage,
        tuple(scoring.Anchor(**a) for a in data["anchors"]),
        frozenset(scoring.Anchor(**a) for a in data["gold"]),
        frozenset(scoring.Anchor(**a) for a in data["rejected"]), data["family"])
    expected = Expectation(fixture, case.arm_input.sources, scope, policy, observation, bindings)
    _recheck(expected)
    return expected


def _recheck(expected):
    if expected.policy:
        if (expected.bindings != _bindings() or expected.policy != _policy()
                or expected.observation != _observation(expected.sources, expected.scope)):
            raise ValueError("changed trusted normalization")
