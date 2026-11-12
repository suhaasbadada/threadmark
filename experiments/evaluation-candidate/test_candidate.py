"""Observable offline conformance, not a retrieval/quality/performance study."""
from dataclasses import FrozenInstanceError, asdict, replace
from importlib import import_module
import copy
import hashlib
import json
import unittest
from unittest.mock import patch

import candidate


corpus = import_module("experiments.evaluation-corpus.corpus")
adapter = import_module("experiments.evaluation-adapter.adapter")
lexical = import_module("experiments.evaluation-lexical.lexical")
scoring = import_module("experiments.evaluation-scoring.scoring")
symbol = import_module("experiments.evaluation-symbol.symbol")
FAMILY = "definition_directcall"
# Reviewed test policy, fixed before boundary assertions. Never derive an
# expected pin from a candidate at execution/admission time.
PINS = {
    "exact": "644213bf4cd916468ee0b761d13b568c7df793d305dcf1ada9a52a6ce6821583",
    "one_over": "516c449f08a703c726c74533d8ee78a9e47a7e8181cd8bf6976dd35c503eee0d",
    "multi_over": "3f0b7f911894b6d583448d87a8fab3680724fd5a04984552fa2a8121296be404",
    "duplicates": "884af07a66673742327a8515a5e3798f6e3f5f9bca3a4073e7613e31951b1fe5",
    "originals": "fe0ab0afe705facc397f09795950df03ba3d793c145b87f6c55d35a9b2477031",
}


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def boundary(text, *, originals=False):
    """Two inert lines, separately pinned test policy; NOT a frozen corpus tier.

    Reuse authored metadata, not copied module implementations. No fixture source
    is executed. These deliberately refrozen artifacts cannot enter public build.
    """
    base = corpus.build("small")
    sources = (("harbor/src/unit_0000.rs", (text + "\n").encode("utf-8")),
               ("harbour/src/unit_0000.rs", b"resolve foreign\n"))
    m, o, i = map(json.loads, (base.manifest, base.oracle, base.inputs))
    if originals:
        i["tasks"][0]["instructions"] = "Do NOT rename resolve. Preserve café.\nPermission is NOT granted."
        i["tasks"][0]["families"][0]["query"] = "  resolve café?\nDo not rewrite this.  "
        i["tasks"][0]["families"][2]["original"] = "  Do NOT send café.\n"
        i["tasks"][0]["families"][2]["constraints"] = ["no send", "no deploy", "café stays café", "permission unknown"]
    o["facts"] = [{**corpus.scope(p.split("/")[0]), "path": p,
                   "line": 1, "text": b.decode().removesuffix("\n"),
                   "kind": "definition"} for p, b in sources]
    o["cross_root_conflicts"] = [{"paths": [p for p, _ in sources], "line": 1,
                                  "kind": "same_local_symbol_different_scope"}]
    # Keep the original four tasks and every declared instruction unchanged.
    oracle, inputs = corpus.canonical(o), corpus.canonical(i)
    m["source_count"] = 2
    m["source_bytes"] = sum(len(b) for _, b in sources)
    m["files"] = [{**corpus.scope(p.split("/")[0]), "path": p,
                    "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
                   for p, b in sources]
    for project, (_, data) in zip(m["projects"], sources):
        project["source_count"], project["source_bytes"] = 1, len(data)
    m["oracle_sha256"] = hashlib.sha256(oracle).hexdigest()
    m["inputs_sha256"] = hashlib.sha256(inputs).hexdigest()
    m.pop("digest")
    m["digest"] = hashlib.sha256(corpus.canonical(m)).hexdigest()
    return corpus.Corpus(sources, corpus.canonical(m), oracle, inputs)


class CandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact = corpus.build("small")

    def run_build(self, **kwargs):
        return candidate.build(self.artifact, corpus.scope("harbor"), FAMILY, **kwargs)

    def assert_closed(self, result, status=None):
        self.assertIn(result.status, ("blocked", "canceled", "unavailable"))
        if status:
            self.assertEqual(result.status, status)
        self.assertIsNone(result.candidate)
        self.assertEqual(set(vars(result)), {"status", "reason", "original_input", "candidate"})

    def test_actual_small_end_to_end_ranking_and_originals(self):
        for project in ("harbor", "harbour"):
            with self.subTest(project=project):
                scope = corpus.scope(project)
                result = candidate.build(self.artifact, scope, FAMILY)
                self.assertEqual(result.status, "ready")
                self.assertIs(type(result.candidate), bytes)
                payload = json.loads(result.candidate)
                self.assertEqual(result.candidate, encoded(payload))
                self.assertLessEqual(len(result.candidate), 8192)
                self.assertEqual(set(payload), {"schema", "scope", "coverage", "items"})
                self.assertEqual(payload["scope"], scope)
                self.assertEqual(payload["schema"], "evaluation-scoring/1")
                # Independent explicit expected coordinates, not a second call to
                # retrieve or gold-based expected output. Macro text stays ranked.
                expected = [("unit_0000.rs", 2), ("unit_0000.rs", 3),
                            ("unit_0001.py", 2), ("unit_0001.py", 5),
                            ("unit_0003.rs", 2), ("unit_0004.rs", 2),
                            ("unit_0004.rs", 3), ("unit_0005.py", 2)]
                self.assertEqual([(a["path"].split("/")[-1], a["line"])
                                  for a in payload["items"]], expected)
                source_map = dict(self.artifact.sources)
                for item in payload["items"]:
                    self.assertEqual({k: item[k] for k in scope}, scope)
                    self.assertEqual(item["text"], source_map[item["path"]].decode().split("\n")[item["line"] - 1])
                coverage = payload["coverage"]
                self.assertEqual(coverage["status"], "complete")
                self.assertIn("limited authored fixture map, not extractor completeness or syntax certification", coverage["envelope"])
                self.assertIn("corpus digest=" + corpus.FROZEN_DIGESTS["small"], coverage["envelope"])
                selected_files = [entry for entry in json.loads(self.artifact.manifest)["files"]
                                  if entry["project"] == project]
                self.assertIn("selected source manifest sha256=" + hashlib.sha256(
                    encoded(selected_files)).hexdigest(), coverage["envelope"])
                self.assertIn("Rust macro expansion unavailable; Python dynamic calls unresolved",
                              coverage["envelope"])
                task = next(t for t in json.loads(self.artifact.inputs)["tasks"] if t["project"] == project)
                original = json.loads(result.original_input)
                self.assertEqual(original, {"schema": "1", "scope": scope,
                    "original_input": task["families"][0], "instructions": task["instructions"]})
                self.assertEqual(result.original_input, adapter.canonical(original))
                self.assertNotIn("metrics", vars(result))
                self.assertNotIn("metrics", payload)

    def test_private_data_never_reaches_retriever(self):
        actual = lexical.retrieve
        observed = []

        def spy(sources, task):
            observed.append((sources, copy.deepcopy(task)))
            return actual(sources, task)

        with patch.object(lexical, "retrieve", side_effect=spy):
            self.assertEqual(self.run_build().status, "ready")
        self.assertEqual(len(observed), 1)
        sources, task = observed[0]
        self.assertEqual(sources, tuple((p, b) for p, b in self.artifact.sources if p.startswith("harbor/")))
        original = json.loads(self.artifact.inputs)["tasks"][0]
        self.assertEqual(task, {"schema": "evaluation-scoring/1", "scope": corpus.scope("harbor"),
                               "family": FAMILY, "query": original["families"][0]["query"],
                               "instructions": original["instructions"]})

    def test_decision_stale_counterexample_blocks_whole_candidate(self):
        actual = lexical.retrieve
        seen = []

        def spy(*args):
            anchors = actual(*args)
            seen.extend(anchors)
            return anchors

        with patch.object(lexical, "retrieve", side_effect=spy):
            result = candidate.build(self.artifact, corpus.scope("harbor"), adapter.FAMILIES[1])
        self.assertTrue(any(a.text == "Historical rule (retired): export audit records." for a in seen))
        self.assertEqual(len(seen), 8)
        self.assert_closed(result, "blocked")
        self.assertEqual(result.reason, "admission_rejected")

    def test_conformance_families_unsupported_preserve_original(self):
        task = json.loads(self.artifact.inputs)["tasks"][0]
        for family in adapter.FAMILIES[2:]:
            with patch.object(lexical, "retrieve", side_effect=AssertionError("must not retrieve")) as retrieve:
                result = candidate.build(self.artifact, corpus.scope("harbor"), family)
            retrieve.assert_not_called()
            self.assert_closed(result, "blocked")
            self.assertEqual(result.reason, "unsupported_family")
            self.assertEqual(json.loads(result.original_input), {"schema": "1", "scope": corpus.scope("harbor"),
                "original_input": next(f for f in task["families"] if f["id"] == family),
                "instructions": task["instructions"]})

    def test_artifact_scope_pin_and_type_rejection_fresh_recovery(self):
        bad_manifest = json.loads(self.artifact.manifest)
        bad_manifest["digest"] = "0" * 64
        bad_artifacts = [replace(self.artifact, manifest=corpus.canonical(bad_manifest)),
                         replace(self.artifact, sources=self.artifact.sources[:-1]),
                         replace(self.artifact, inputs=self.artifact.inputs + b" "),
                         boundary("resolve tiny"), object()]
        for artifact in bad_artifacts:
            with self.subTest(artifact_type=type(artifact).__name__):
                self.assert_closed(candidate.build(artifact, corpus.scope("harbor"), FAMILY), "blocked")
        for key, value in (("project", "foreign"), ("revision", "wrong"), ("worktree", "other")):
            scope = {**corpus.scope("harbor"), key: value}
            self.assert_closed(candidate.build(self.artifact, scope, FAMILY), "blocked")
        self.assertEqual(self.run_build().status, "ready")

    def test_retrieval_anchor_mutations_use_actual_scorer(self):
        good = lexical.retrieve(tuple((p, b) for p, b in self.artifact.sources if p.startswith("harbor/")),
            json.loads(adapter.prepare(self.artifact.sources, self.artifact.manifest,
                self.artifact.oracle, self.artifact.inputs, corpus.scope("harbor"),
                expected_digest=corpus.FROZEN_DIGESTS["small"])[0].arm_input.method_task))
        first = good[0]
        mutations = [replace(first, **{k: v}) for k, v in (
            ("project", "harbour"), ("worktree", "foreign"), ("revision", "old"),
            ("path", "harbor/src/unknown.rs"), ("path", "../escape.rs"),
            ("line", 999), ("line", True), ("text", first.text + " "), ("text", "bad\nline"))]
        mutations += [asdict(first), None]
        for anchor in mutations:
            with self.subTest(anchor_type=type(anchor).__name__), patch.object(lexical, "retrieve", return_value=(anchor,)):
                self.assert_closed(self.run_build(), "blocked")
        for output in ([first], {"items": good}, None, (first,) * 9):
            with patch.object(lexical, "retrieve", return_value=output):
                self.assert_closed(self.run_build(), "blocked")

    def test_candidate_header_mutations_checked_by_real_admission(self):
        actual = candidate._envelope

        def change_schema(c):
            c["schema"] = "foreign/1"

        def change_scope(c):
            c["scope"]["revision"] = "old"

        def incomplete(c):
            c["coverage"]["status"] = "partial"

        def tampered(c):
            c["coverage"]["envelope"].append("invented coverage")

        def missing(c):
            del c["coverage"]

        def malformed(c):
            c["coverage"]["envelope"] = "not a list"

        def empty(c):
            c["coverage"]["envelope"] = []

        def extra(c):
            c["permission"] = "approved"

        for mutation in (change_schema, change_scope, incomplete, tampered, missing, malformed, empty, extra):
            def altered(*args):
                c = actual(*args)
                mutation(c)
                return c
            with self.subTest(mutation=mutation.__name__), patch.object(candidate, "_envelope", side_effect=altered):
                self.assert_closed(self.run_build(), "blocked")

    def test_duplicate_slots_consumed_without_dedup(self):
        actual = lexical.retrieve
        def duplicates(*args):
            return (actual(*args)[0],) * 8
        with patch.object(lexical, "retrieve", side_effect=duplicates):
            result = self.run_build()
        self.assertEqual(result.status, "ready")
        self.assertEqual(len(json.loads(result.candidate)["items"]), 8)

    def test_full_envelope_exact_inclusive_and_utf8_overflow(self):
        exact = "resolve " + "x" * 7125 + "😀"
        for name, text, expected_bytes in (("exact", exact, 8192),
                                           ("one_over", exact + "x", 8193),
                                           ("multi_over", exact + "é", 8194)):
            artifact = boundary(text)
            self.assertEqual(json.loads(artifact.manifest)["digest"], PINS[name])
            # Independent serialization oracle: the list fits in ALL cases,
            # while the full envelope has the exact declared boundary length.
            case = adapter.prepare(artifact.sources, artifact.manifest, artifact.oracle,
                artifact.inputs, corpus.scope("harbor"), expected_digest=PINS[name])[0]
            f = json.loads(case.fixture)
            items = [{**corpus.scope("harbor"), "path": "harbor/src/unit_0000.rs",
                      "line": 1, "text": text}]
            full = {"schema": "evaluation-scoring/1", "scope": corpus.scope("harbor"),
                    "coverage": {"status": "complete", "envelope": f["coverage"]}, "items": items}
            self.assertLess(len(encoded(items)), 8192)
            self.assertEqual(len(encoded(full)), expected_bytes)
            self.assertEqual([asdict(a) for a in lexical.retrieve(case.arm_input.sources,
                json.loads(case.arm_input.method_task))], items)
            result = candidate._build(artifact, corpus.scope("harbor"), FAMILY, _test_pin=PINS[name])
            if name == "exact":
                self.assertEqual(result.status, "ready")
                self.assertEqual(result.candidate, encoded(full))
                self.assertEqual(len(result.candidate), 8192)
            else:
                self.assert_closed(result, "blocked")
                self.assertEqual(result.reason, "admission_rejected")

    def test_duplicate_byte_budget_is_not_unique_item_budget(self):
        artifact = boundary("resolve " + "x" * 1000)
        self.assertEqual(json.loads(artifact.manifest)["digest"], PINS["duplicates"])
        actual = lexical.retrieve
        def duplicate(*args):
            return (actual(*args)[0],) * 8
        with patch.object(lexical, "retrieve", side_effect=duplicate):
            result = candidate._build(artifact, corpus.scope("harbor"), FAMILY,
                                      _test_pin=PINS["duplicates"])
        self.assert_closed(result, "blocked")
        self.assertEqual(result.reason, "admission_rejected")

    def test_unicode_whitespace_original_and_constraints_preserved(self):
        artifact = boundary("resolve tiny", originals=True)
        self.assertEqual(json.loads(artifact.manifest)["digest"], PINS["originals"])
        task = json.loads(artifact.inputs)["tasks"][0]
        for index in (0, 2):
            result = candidate._build(artifact, corpus.scope("harbor"), adapter.FAMILIES[index],
                                      _test_pin=PINS["originals"])
            if index == 0:
                self.assertEqual(result.status, "ready")
            else:
                self.assert_closed(result, "blocked")
            self.assertEqual(json.loads(result.original_input), {"schema": "1", "scope": corpus.scope("harbor"),
                "instructions": task["instructions"], "original_input": task["families"][index]})

    def test_cancellation_at_all_declared_boundaries(self):
        stages = ["preparation", "retrieval", "admission", "final_return"]
        for index, stage in enumerate(stages):
            calls = []
            def canceled(name):
                calls.append(name)
                return name == stage
            result = self.run_build(canceled=canceled)
            self.assert_closed(result, "canceled")
            self.assertEqual(calls, stages[:index + 1])
        calls = []
        self.assertEqual(self.run_build(canceled=lambda s: calls.append(s) or False).status, "ready")
        self.assertEqual(calls, stages)

    def test_dependency_failures_and_fresh_invocation_recovery(self):
        for module, name in ((candidate, "_dependencies"), (corpus, "validate"), (adapter, "prepare"),
                             (lexical, "retrieve"), (scoring, "score"), (scoring, "canonical")):
            with self.subTest(name=name), patch.object(module, name, side_effect=RuntimeError("CONTENT MUST NOT ESCAPE")):
                result = self.run_build()
            self.assert_closed(result, "unavailable")
            self.assertNotIn("CONTENT", result.reason)
            self.assertEqual(self.run_build().status, "ready")
        for verdict in ({"status": "invalid"}, {"status": None}, {}, None):
            with patch.object(scoring, "score", return_value=verdict):
                self.assert_closed(self.run_build())
        self.assert_closed(self.run_build(canceled=lambda _: None), "unavailable")
        self.assertEqual(self.run_build().status, "ready")

    def test_retriever_cannot_replace_task_bindings(self):
        actual = lexical.retrieve
        for key, value in (("query", "different query"), ("instructions", "different instructions"),
                           ("scope", corpus.scope("harbour"))):
            def mutated(sources, task):
                result = actual(sources, task)
                task[key] = value
                return result
            with patch.object(lexical, "retrieve", side_effect=mutated):
                result = self.run_build()
            self.assert_closed(result, "blocked")
            self.assertEqual(result.reason, "task_changed")

    def test_immutable_results_aliases_late_scope_change_no_lastgood(self):
        scope = corpus.scope("harbor")
        before = self.artifact
        good = candidate.build(self.artifact, scope, FAMILY)
        saved = good.candidate
        with self.assertRaises(FrozenInstanceError):
            good.candidate = None
        decoded = json.loads(good.candidate)
        decoded["coverage"]["envelope"].clear()
        decoded["items"].clear()
        def change_scope(stage):
            scope["revision"] = "late-change"
            return False
        # Scope capture precedes every probe, including preparation.
        scope = corpus.scope("harbor")
        result = candidate.build(self.artifact, scope, FAMILY, canceled=change_scope)
        self.assertEqual(result, good)
        with patch.object(lexical, "retrieve", side_effect=RuntimeError("failed")):
            self.assert_closed(self.run_build(), "unavailable")
        self.assertEqual(good.candidate, saved)
        self.assertEqual(self.artifact, before)
        self.assertEqual(self.run_build(), good)

    def test_preparation_probe_cannot_switch_the_invocation_project(self):
        selected = corpus.scope("harbor")
        expected = candidate.build(self.artifact, dict(selected), FAMILY)

        def probe(stage):
            if stage == "preparation":
                selected.update(corpus.scope("harbour"))
            return False

        actual = candidate.build(self.artifact, selected, FAMILY, canceled=probe)
        self.assertEqual(actual, expected)
        self.assertEqual(json.loads(actual.candidate)["scope"], corpus.scope("harbor"))
        self.assertEqual(selected, corpus.scope("harbour"))


class SelectedMethodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact = corpus.build("small")

    def build(self, method, **kwargs):
        return candidate.build(self.artifact, corpus.scope("harbor"), FAMILY,
                               method=method, **kwargs)

    def closed(self, result, status, reason=None):
        self.assertEqual(result.status, status)
        self.assertIsNone(result.candidate)
        if reason:
            self.assertEqual(result.reason, reason)

    def anchor(self, module, *, project="harbor", index=0, line=2):
        # Authored coordinates, never a retrieval-derived expected oracle.
        path = f"{project}/src/unit_{index:04d}.rs"
        text = dict(self.artifact.sources)[path].decode().split("\n")[line - 1]
        return module.Anchor(**corpus.scope(project), path=path, line=line, text=text)

    def test_actual_symbol_declarations_both_roots_and_lexical_default(self):
        for project in corpus.PROJECTS:
            with self.subTest(project=project):
                scope = corpus.scope(project)
                result = candidate.build(self.artifact, scope, FAMILY, method="symbol")
                self.assertEqual(result.status, "ready")
                payload = json.loads(result.candidate)
                expected = [(f"unit_{i:04d}.{ext}", 2)
                            for i, ext in ((0, "rs"), (1, "py"), (4, "rs"), (5, "py"),
                                           (8, "rs"), (9, "py"), (12, "rs"), (13, "py"))]
                self.assertEqual([(a["path"].split("/")[-1], a["line"])
                                  for a in payload["items"]], expected)
                for a in payload["items"]:
                    self.assertEqual({k: a[k] for k in scope}, scope)
                    self.assertEqual(a["text"], dict(self.artifact.sources)[a["path"]].decode().split("\n")[1])
                default = candidate.build(self.artifact, scope, FAMILY)
                self.assertEqual(default, candidate.build(self.artifact, scope, FAMILY, method="lexical"))
                self.assertEqual(result.original_input, default.original_input)
                self.assertEqual(payload["coverage"], json.loads(default.candidate)["coverage"])
                self.assertEqual(set(vars(result)), set(vars(default)))

    def test_only_bound_public_inputs_and_selected_arm_called(self):
        for name, module, other in (("lexical", lexical, symbol), ("symbol", symbol, lexical)):
            seen = []
            actual = module.retrieve
            def spy(sources, task):
                seen.append((sources, copy.deepcopy(task)))
                self.assertIs(type(sources), tuple)
                self.assertTrue(all(type(p) is tuple and type(p[1]) is bytes for p in sources))
                return actual(sources, task)
            with self.subTest(method=name), patch.object(module, "retrieve", side_effect=spy), patch.object(other, "retrieve") as unused:
                self.assertEqual(self.build(name).status, "ready")
                unused.assert_not_called()
            self.assertEqual(len(seen), 1)
            sources, task = seen[0]
            self.assertEqual(sources, tuple((p, b) for p, b in self.artifact.sources if p.startswith("harbor/")))
            declared = json.loads(self.artifact.inputs)["tasks"][0]
            self.assertEqual(task, {"schema": scoring.VERSION, "scope": corpus.scope("harbor"),
                "family": FAMILY, "query": declared["families"][0]["query"],
                "instructions": declared["instructions"]})

    def test_invalid_methods_reject_before_dependencies_without_coercion(self):
        class String(str):
            pass
        class Hostile:
            def __eq__(self, other):
                raise AssertionError("must not compare")
            def __str__(self):
                raise AssertionError("must not coerce")
        for method in (None, True, 1, b"symbol", [], {}, "", "Symbol", "directcall",
                       "experiments.evaluation-symbol.symbol", String("symbol"), Hostile()):
            calls = []
            with patch.object(candidate, "_dependencies") as dependencies:
                result = self.build(method, canceled=lambda s: calls.append(s) or False)
            self.closed(result, "blocked", "invalid_method")
            self.assertIsNone(result.original_input)
            self.assertEqual(calls, ["preparation"])
            dependencies.assert_not_called()
        with patch.object(candidate, "_dependencies") as dependencies:
            self.closed(self.build(None, canceled=lambda _: True), "canceled")
            dependencies.assert_not_called()

    def test_scope_and_task_binding_mutations_and_fresh_recovery(self):
        for name, module in (("lexical", lexical), ("symbol", symbol)):
            good = self.build(name)
            selected = corpus.scope("harbor")
            def probe(stage):
                selected.update(corpus.scope("harbour"))
                return False
            self.assertEqual(candidate.build(self.artifact, selected, FAMILY, method=name, canceled=probe), good)
            for key in scoring.SCOPE_KEYS:
                with patch.object(module, "retrieve") as retrieve:
                    scope = {**corpus.scope("harbor"), key: "wrong"}
                    self.closed(candidate.build(self.artifact, scope, FAMILY, method=name), "blocked", "preparation_rejected")
                    retrieve.assert_not_called()
            actual = module.retrieve
            for key, value in (("scope", corpus.scope("harbour")), ("query", "changed"),
                               ("instructions", "permission invented")):
                def mutate(sources, task):
                    anchors = actual(sources, task)
                    task[key] = value
                    return anchors
                with self.subTest(method=name, key=key), patch.object(module, "retrieve", side_effect=mutate):
                    self.closed(self.build(name), "blocked", "task_changed")
            self.assertEqual(self.build(name), good)

    def test_wrong_arm_malformed_unknown_stale_and_duplicate_budgets(self):
        for name, module, other in (("lexical", lexical, symbol), ("symbol", symbol, lexical)):
            first = self.anchor(module)
            stale = module.Anchor(**corpus.scope("harbor"), path="harbor/src/unit_0002.md",
                line=3, text="Historical rule (retired): export audit records.")
            bad = [(self.anchor(other),), (asdict(first),), [first], None,
                   (replace(first, path="harbor/src/unknown.rs"),),
                   (replace(first, line=True),), (replace(first, text="unknown"),),
                   (replace(first, project="harbour"),), (replace(first, worktree="wrong"),),
                   (replace(first, revision="old"),), (first,) * 9, (first, stale)]
            for anchors in bad:
                with self.subTest(method=name, output=type(anchors).__name__), patch.object(module, "retrieve", return_value=anchors) as retrieve, patch.object(other, "retrieve") as fallback:
                    self.closed(self.build(name), "blocked")
                    retrieve.assert_called_once()
                    fallback.assert_not_called()
            with patch.object(module, "retrieve", return_value=(first,) * 8):
                result = self.build(name)
            self.assertEqual(result.status, "ready")
            self.assertEqual(json.loads(result.candidate)["items"], [asdict(first)] * 8)
            self.assertEqual(self.build(name).status, "ready")

    def test_both_full_envelope_boundaries_no_cheaper_fallback(self):
        exact = "resolve " + "x" * 7125 + "😀"
        for name, module, other in (("lexical", lexical, symbol), ("symbol", symbol, lexical)):
            for pin_name, text, size in (("exact", exact, 8192), ("one_over", exact + "x", 8193),
                                         ("multi_over", exact + "é", 8194),
                                         ("duplicates", "resolve " + "x" * 1000, None)):
                artifact = boundary(text)
                self.assertEqual(json.loads(artifact.manifest)["digest"], PINS[pin_name])
                anchor = module.Anchor(**corpus.scope("harbor"), path="harbor/src/unit_0000.rs", line=1, text=text)
                anchors = (anchor,) * (8 if pin_name == "duplicates" else 1)
                case = adapter.prepare(artifact.sources, artifact.manifest, artifact.oracle,
                    artifact.inputs, corpus.scope("harbor"), expected_digest=PINS[pin_name])[0]
                payload = {"schema": scoring.VERSION, "scope": corpus.scope("harbor"),
                    "coverage": {"status": "complete", "envelope": json.loads(case.fixture)["coverage"]},
                    "items": [asdict(a) for a in anchors]}
                if size:
                    self.assertLess(len(encoded(payload["items"])), 8192)
                    self.assertEqual(len(encoded(payload)), size)
                # Boundary source is inert text, not a symbol declaration. Inject
                # authored anchors to isolate the SAME whole-envelope admission.
                with self.subTest(method=name, boundary=pin_name), patch.object(module, "retrieve", return_value=anchors) as retrieve, patch.object(other, "retrieve") as fallback:
                    result = candidate._build(artifact, corpus.scope("harbor"), FAMILY,
                        method=name, _test_pin=PINS[pin_name])
                    retrieve.assert_called_once()
                    fallback.assert_not_called()
                if pin_name == "exact":
                    self.assertEqual(result.candidate, encoded(payload))
                else:
                    self.closed(result, "blocked", "admission_rejected")

    def test_cancel_stops_unnecessary_calls_and_dependency_recovery(self):
        stages = ["preparation", "retrieval", "admission", "final_return"]
        for name, module in (("lexical", lexical), ("symbol", symbol)):
            for index, stage in enumerate(stages):
                calls = []
                def probe(s):
                    calls.append(s)
                    return s == stage
                with patch.object(adapter, "prepare", wraps=adapter.prepare) as prepare, patch.object(module, "retrieve", wraps=module.retrieve) as retrieve, patch.object(scoring, "score", wraps=scoring.score) as score:
                    self.closed(self.build(name, canceled=probe), "canceled")
                    self.assertEqual(calls, stages[:index + 1])
                    self.assertEqual(prepare.call_count, int(index > 0))
                    self.assertEqual(retrieve.call_count, int(index > 1))
                    self.assertEqual(score.call_count, int(index > 2))
            for dependency, function in ((candidate, "_dependencies"), (corpus, "validate"),
                    (adapter, "prepare"), (scoring, "Fixture"), (scoring, "build_manifest"),
                    (module, "retrieve"), (candidate, "_envelope"), (scoring, "score"), (scoring, "canonical")):
                with self.subTest(method=name, dependency=function), patch.object(dependency, function, side_effect=RuntimeError("PRIVATE")):
                    result = self.build(name)
                self.closed(result, "unavailable")
                self.assertNotIn("PRIVATE", result.reason)
                self.assertEqual(self.build(name).status, "ready")
            for stage in stages:
                def broken(s):
                    if s == stage:
                        raise RuntimeError("PRIVATE")
                    return False
                self.closed(self.build(name, canceled=broken), "unavailable", stage + "_unavailable")
                self.assertEqual(self.build(name).status, "ready")

    def test_symbol_decision_empty_not_quality_and_unsupported_originals(self):
        result = candidate.build(self.artifact, corpus.scope("harbor"), adapter.FAMILIES[1], method="symbol")
        self.assertEqual(result.status, "ready")
        self.assertEqual(json.loads(result.candidate)["items"], [])
        for name, module in (("lexical", lexical), ("symbol", symbol)):
            for family in adapter.FAMILIES[2:]:
                with patch.object(module, "retrieve") as retrieve:
                    result = candidate.build(self.artifact, corpus.scope("harbor"), family, method=name)
                    self.closed(result, "blocked", "unsupported_family")
                    retrieve.assert_not_called()
                declared = json.loads(self.artifact.inputs)["tasks"][0]
                self.assertEqual(json.loads(result.original_input)["original_input"],
                                 next(f for f in declared["families"] if f["id"] == family))
            artifact = boundary("resolve tiny", originals=True)
            result = candidate._build(artifact, corpus.scope("harbor"), FAMILY,
                                      method=name, _test_pin=PINS["originals"])
            self.assertEqual(result.status, "ready")
            declared = json.loads(artifact.inputs)["tasks"][0]
            self.assertEqual(json.loads(result.original_input), {"schema": "1", "scope": corpus.scope("harbor"),
                "instructions": declared["instructions"], "original_input": declared["families"][0]})


if __name__ == "__main__":
    unittest.main()
