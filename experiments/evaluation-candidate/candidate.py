"""Small frozen-artifact conformance integration; not a host send API or worker."""
from dataclasses import asdict, dataclass
from importlib import import_module
import json


@dataclass(frozen=True)
class Result:
    status: str
    reason: str
    original_input: bytes | None = None
    candidate: bytes | None = None


class _Closed(Exception):
    pass


def _dependencies(method):
    # Fixed repository-owned authored modules only. Never load fixture source,
    # caller paths, plugins or modules named by artifact metadata.
    return (import_module("experiments.evaluation-corpus.corpus"),
            import_module("experiments.evaluation-adapter.adapter"),
            (import_module("experiments.evaluation-lexical.lexical") if method == "lexical"
             else import_module("experiments.evaluation-symbol.symbol")),
            import_module("experiments.evaluation-scoring.scoring"))


def _envelope(scoring, fixture, items):
    return {"schema": scoring.VERSION,
            "scope": dict(zip(scoring.SCOPE_KEYS, fixture.scope)),
            "coverage": {"status": "complete", "envelope": list(fixture.coverage)},
            "items": items}


def build(artifact, selected_scope, family, *, method="lexical", canceled=None):
    """Return immutable ephemeral bytes or a closed result, never host effects.

    Only the reviewed SMALL recipe is approved here. Its pin comes from authored
    repository policy, not artifact/candidate fields. Scope labels are consistency
    values, NOT authentication. method is exactly lexical (default) or symbol;
    invalid methods block after the preparation probe, before dependencies.
    canceled(stage) is an optional synchronous probe
    at preparation, retrieval, admission and final_return; it cannot abort work.
    No public split prepare/normalize or trusted-fixture constructor is exposed.
    """
    return _build(artifact, selected_scope, family, method=method, canceled=canceled)


def _build(artifact, selected_scope, family, *, method="lexical", canceled=None, _test_pin=None):
    """_test_pin is INTERNAL trusted test policy for tiny boundary artifacts only.

    Never route caller/artifact pins here. Like unittest mocks, this private seam
    is not a security boundary against arbitrary Python execution in this process.
    Public build always validates the actual frozen corpus recipe as well.
    """
    original = None
    stage = "preparation"

    def checkpoint(name):
        if canceled is not None:
            answer = canceled(name)
            if type(answer) is not bool:
                raise RuntimeError("invalid cancellation probe")
            if answer:
                raise _Closed("canceled")

    try:
        # Freeze the sole mutable caller input before any probe/dependency call.
        selected = dict(selected_scope) if type(selected_scope) is dict else selected_scope
        checkpoint(stage)
        if type(method) is not str or method not in ("lexical", "symbol"):
            raise _Closed("invalid_method")
        corpus, adapter, retriever, scoring = _dependencies(method)
        try:
            adapter.scope(selected)
            if type(family) is not str or family not in adapter.FAMILIES:
                raise ValueError("unsupported family")
            if type(artifact) is not corpus.Corpus:
                raise ValueError("artifact type")
            if _test_pin is None:
                if adapter.decode(artifact.manifest)["tier"] != "small":
                    raise ValueError("unapproved tier")
                pin = corpus.FROZEN_DIGESTS["small"]
                if corpus.validate(artifact) != pin:
                    raise ValueError("corpus pin")
            else:
                pin = _test_pin
            cases = adapter.prepare(artifact.sources, artifact.manifest,
                                    artifact.oracle, artifact.inputs, selected,
                                    expected_digest=pin)
            case = cases[adapter.FAMILIES.index(family)]
            original = case.arm_input.declared_task
            if family not in scoring.RELEVANCE or case.arm_input.method_task is None:
                raise _Closed("unsupported_family")
            # Only adapter-produced immutable lineage enters the trusted fixture.
            # Its complete map includes irrelevant lines and all rejected anchors.
            data = json.loads(case.fixture)
            fixture = scoring.Fixture(
                tuple(data["scope"][k] for k in scoring.SCOPE_KEYS),
                tuple(data["coverage"]),
                tuple(scoring.Anchor(**a) for a in data["anchors"]),
                frozenset(scoring.Anchor(**a) for a in data["gold"]),
                frozenset(scoring.Anchor(**a) for a in data["rejected"]),
                data["family"])
            method_task = case.arm_input.method_task
            task = json.loads(method_task)
            scoring.build_manifest(task)  # Actual task/schema/original-budget API.
        except (ValueError, TypeError, KeyError, IndexError, UnicodeError):
            raise _Closed("preparation_rejected") from None

        stage = "retrieval"
        checkpoint(stage)
        # No fixture, oracle, coverage, hashes or private sidecar crosses this call.
        anchors = retriever.retrieve(case.arm_input.sources, task)
        if scoring.canonical(task) != method_task:
            raise _Closed("task_changed")

        stage = "admission"
        checkpoint(stage)
        if type(anchors) is not tuple or any(type(a) is not retriever.Anchor for a in anchors):
            raise _Closed("malformed_retrieval")
        candidate = _envelope(scoring, fixture, [asdict(a) for a in anchors])
        # Check the WHOLE envelope without selecting cheaper anchors or truncating.
        payload = scoring.canonical(candidate)
        verdict = scoring.score(fixture, candidate)
        if (verdict.get("status") != "valid"
                or len(payload) > scoring.MAX_BYTES
                or scoring.canonical(candidate) != payload):
            raise _Closed("admission_rejected")
        # Scorer metrics are internal plumbing, never returned/logged as results.
        stage = "final_return"
        checkpoint(stage)
        return Result("ready", "admitted_limited_envelope", original, payload)
    except _Closed as error:
        reason = error.args[0]
        return Result("canceled" if reason == "canceled" else "blocked", reason, original)
    except Exception:
        # Dependency/probe failures cannot expose content, exception text or a
        # provisional/last-good candidate. A fresh deliberate call can recover.
        return Result("unavailable", stage + "_unavailable", original)
