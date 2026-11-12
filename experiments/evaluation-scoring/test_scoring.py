"""Tiny authored values only; no corpus, generated source or retrieval execution."""
import ast
from copy import deepcopy
from dataclasses import replace
import hashlib
import inspect
import json
import unittest

import scoring as s


SCOPE = ("harbor", "fixture-worktree-1", "fixture-revision-1")
COVERAGE = ("synthetic authored lines only", "no macro expansion or dynamic resolution")
GOOD = s.Anchor(*SCOPE, "harbor/src/a.rs", 2, "pub fn resolve() {}")
OTHER = s.Anchor(*SCOPE, "harbor/src/b.py", 1, "def unrelated():")
STALE = s.Anchor(*SCOPE, "harbor/rules.md", 3, "Retired: export records.")
FORBIDDEN = s.Anchor(*SCOPE, "harbor/excluded.md", 1, "Excluded source.")
FOREIGN = replace(GOOD, project="harbour", path="harbour/src/a.rs")
OLD = replace(GOOD, revision="fixture-revision-0")
FIXTURE = s.Fixture(SCOPE, COVERAGE, (GOOD, OTHER, STALE, FORBIDDEN, FOREIGN, OLD),
                    frozenset((GOOD,)), frozenset((STALE, FORBIDDEN, FOREIGN, OLD)))
TASK = {"schema": s.VERSION, "scope": dict(zip(s.SCOPE_KEYS, SCOPE)),
        "family": s.RELEVANCE[0],
        "query": "Locate resolve and its direct callers in this scope.",
        "instructions": "Use selected scope only. No execution authorization."}


def candidate(*anchors):
    return {"schema": s.VERSION, "scope": dict(zip(s.SCOPE_KEYS, SCOPE)),
            "coverage": {"status": "complete", "envelope": list(COVERAGE)},
            "items": [vars(anchor).copy() for anchor in anchors]}


class ScoringTests(unittest.TestCase):
    def invalid(self, value, fixture=FIXTURE):
        result = s.score(fixture, value)
        self.assertEqual(result["status"], "invalid", result)
        self.assertIsNone(result["metrics"])
        self.assertNotIn("tp", result)

    def test_exact_and_current_irrelevant(self):
        result = s.score(FIXTURE, candidate(GOOD, OTHER))
        self.assertEqual(result["status"], "valid")
        self.assertEqual(result["metrics"], {"tp": 1, "fp": 1, "fn": 0, "gold_count": 1,
                         "precision": .5, "recall": 1, "slot_budget_recall_ceiling": 1})

    def test_same_local_symbol_other_project(self):
        self.invalid(candidate(FOREIGN))
        self.invalid(candidate(replace(GOOD, project="harbour")))

    def test_envelope_scope_schema_mismatch(self):
        for field in s.SCOPE_KEYS:
            with self.subTest(field=field):
                value = candidate(GOOD)
                value["scope"][field] += "-other"
                self.invalid(value)
        for schema in ("1", "evaluation-scoring/2", None, True, 1, []):
            value = candidate(GOOD)
            value["schema"] = schema
            self.invalid(value)

    def test_anchor_worktree_revision_mismatch(self):
        self.invalid(candidate(replace(GOOD, worktree="other")))
        self.invalid(candidate(OLD))

    def test_stale_forbidden_not_false_positives(self):
        for anchor in (STALE, FORBIDDEN):
            self.invalid(candidate(GOOD, anchor))

    def test_unknown_line_path_text(self):
        for anchor in (replace(GOOD, line=3), replace(GOOD, path="harbor/src/missing.rs"),
                       replace(GOOD, text="pub fn resolve() { }")):
            self.invalid(candidate(anchor))

    def test_duplicate_correct_and_irrelevant(self):
        result = s.score(FIXTURE, candidate(GOOD, GOOD, OTHER, OTHER))
        self.assertEqual((result["submitted_count"], result["unique_count"], result["duplicate_count"]),
                         (4, 2, 2))
        self.assertEqual((result["metrics"]["tp"], result["metrics"]["fp"]), (1, 1))
        self.assertGreater(result["payload_bytes"], s.score(FIXTURE, candidate(GOOD, OTHER))["payload_bytes"])

    def test_valid_empty_is_not_rejection_or_perfect_precision(self):
        result = s.score(FIXTURE, candidate())
        self.assertEqual(result["status"], "valid")
        self.assertIsNone(result["metrics"]["precision"])
        self.assertEqual(result["metrics"]["recall"], 0)
        self.assertEqual(result["metrics"]["fn"], 1)

    def test_zero_gold_denominators(self):
        fixture = replace(FIXTURE, gold=frozenset())
        result = s.score(fixture, candidate())["metrics"]
        for key in ("precision", "recall", "slot_budget_recall_ceiling"):
            self.assertIsNone(result[key])
        result = s.score(fixture, candidate(OTHER))["metrics"]
        self.assertEqual(result["precision"], 0)
        self.assertIsNone(result["recall"])

    def test_eight_items_inclusive_no_truncation(self):
        self.assertEqual(s.score(FIXTURE, candidate(*([GOOD] * 8)))["status"], "valid")
        self.invalid(candidate(*([GOOD] * 9)))

    def test_duplicate_payload_overflow_rejects_not_deduplicates(self):
        anchor = replace(GOOD, text="x" * 4200)
        fixture = replace(FIXTURE, anchors=(anchor,), gold=frozenset((anchor,)), rejected=frozenset())
        self.assertEqual(s.score(fixture, candidate(anchor))["status"], "valid")
        self.invalid(candidate(anchor, anchor), fixture)

    def test_broad_task_ceiling_duplicates_do_not_rewrite_budget(self):
        anchors = tuple(replace(GOOD, line=i + 1) for i in range(10))
        fixture = replace(FIXTURE, anchors=anchors, gold=frozenset(anchors), rejected=frozenset())
        result = s.score(fixture, candidate(anchors[0], anchors[0]))
        self.assertEqual(result["metrics"]["slot_budget_recall_ceiling"], .8)
        self.assertEqual(result["metrics"]["recall"], .1)
        self.assertEqual(result["unique_count"], 1)

    def test_payload_utf8_astral_exact_boundary_and_overflow(self):
        empty = replace(GOOD, text="")
        overhead = len(s.canonical(candidate(empty)))
        remaining = s.MAX_BYTES - overhead
        text = "\U0001f680" * (remaining // 4) + "a" * (remaining % 4)
        exact = replace(GOOD, text=text)
        overflow = replace(exact, text=text + "a")
        # Distinct source-map coordinates: contradictory text at one line is not trusted.
        overflow = replace(overflow, line=3)
        fixture = replace(FIXTURE, anchors=(exact, overflow), gold=frozenset(), rejected=frozenset())
        value = candidate(exact)
        self.assertEqual(len(s.canonical(value)), 8192)
        self.assertLess(len(s.canonical(value).decode("utf-8")), 8192)
        self.assertEqual(s.score(fixture, value)["status"], "valid")
        self.assertEqual(len(s.canonical(candidate(overflow))), 8193)
        self.invalid(candidate(overflow), fixture)

    def test_incomplete_malformed_coverage(self):
        for coverage in (None, {}, {"status": "partial", "envelope": list(COVERAGE)},
                         {"status": "complete", "envelope": []},
                         {"status": "complete", "envelope": list(reversed(COVERAGE))},
                         {"status": "complete", "envelope": [1]},
                         {"status": "complete", "envelope": tuple(COVERAGE)},
                         {"status": "complete", "envelope": list(COVERAGE), "gaps": []}):
            value = candidate(GOOD)
            value["coverage"] = coverage
            self.invalid(value)

    def test_strict_fields_and_types_no_permission_or_state_claims(self):
        for field in ("permission", "approved", "state", "kind", "oracle"):
            value = candidate(GOOD)
            value[field] = "authorized"
            self.invalid(value)
            value = candidate(GOOD)
            value["items"][0][field] = "authorized"
            self.invalid(value)
        for field, invalids in (("line", (True, 0, -1, 2.0, "2")),
                                ("text", (None, "two\nlines", "two\rlines", "\ud800")),
                                ("path", ("/absolute", "../escape", "a//b", "a/./b", "a\\b", "a\x00b")),
                                ("project", (1, "", None))):
            for bad in invalids:
                value = candidate(GOOD)
                value["items"][0][field] = bad
                self.invalid(value)
        for value in (None, [], {}, {**candidate(), "items": ()}, {**candidate(), "items": [None]}):
            self.invalid(value)

    def test_missing_fields_rejected(self):
        for field in candidate(GOOD):
            value = candidate(GOOD)
            del value[field]
            self.invalid(value)
        for field in vars(GOOD):
            value = candidate(GOOD)
            del value["items"][0][field]
            self.invalid(value)

    def test_nonmutating_rejection_fresh_recovery(self):
        before = deepcopy(FIXTURE)
        value = candidate(GOOD, STALE)
        snapshot = deepcopy(value)
        self.invalid(value)
        self.assertEqual(value, snapshot)
        self.assertEqual(FIXTURE, before)
        self.assertEqual(s.score(FIXTURE, candidate(GOOD))["metrics"]["tp"], 1)
        self.assertEqual(FIXTURE, before)

    def test_conformance_only_families_never_relevance_metrics(self):
        for family in s.CONFORMANCE:
            fixture = replace(FIXTURE, family=family)
            for value in (candidate(), candidate(GOOD)):
                result = s.score(fixture, value)
                self.assertEqual(result["status"], "conformance_only_not_evaluated")
                self.assertIsNone(result["metrics"])
            self.invalid(candidate(STALE), fixture)

    def test_trusted_fixture_cannot_invent_gold_or_conflicting_source_text(self):
        for changes in ({"gold": frozenset((STALE,))}, {"gold": frozenset((FOREIGN,))},
                        {"anchors": (GOOD, replace(GOOD, text="contradictory"))},
                        {"gold": {GOOD}}, {"scope": list(SCOPE)}):
            with self.assertRaises(ValueError):
                replace(FIXTURE, **changes)


class ManifestTests(unittest.TestCase):
    def test_canonical_determinism_digest_and_frozen_contract(self):
        data = s.build_manifest(TASK)
        reordered = dict(reversed(list(TASK.items())))
        self.assertEqual(data, s.build_manifest(reordered))
        manifest = json.loads(data)
        digest = manifest.pop("digest")
        self.assertEqual(digest, hashlib.sha256(s.canonical(manifest)).hexdigest())
        self.assertEqual(hashlib.sha256(s.canonical(s.CONTRACT)).hexdigest(),
                         "2aea61ef91963863acbbe45bfe2cda1bfcf81960408bc6df219876946b2ae4ac")
        for arm in manifest["arms"].values():
            self.assertEqual(arm, {"implementation": "NOT_IMPLEMENTED", "execution": "NOT_RUN"})

    def test_no_oracle_input_and_no_posthoc_scope_narrowing(self):
        self.assertEqual(list(inspect.signature(s.build_manifest).parameters), ["task"])
        before = s.build_manifest(TASK)
        changed_oracle = replace(FIXTURE, gold=frozenset((OTHER,)))
        self.assertNotEqual(changed_oracle.gold, FIXTURE.gold)
        self.assertEqual(before, s.build_manifest(TASK))
        for field in ("oracle", "facts", "hash_labels", "files"):
            with self.assertRaises(ValueError):
                s.build_manifest({**TASK, field: ["answer"]})
        manifest = json.loads(before)
        self.assertEqual(manifest["task"], TASK)
        self.assertEqual(manifest["query_words"],
                         ["and", "callers", "direct", "in", "its", "locate", "resolve", "scope", "this"])
        self.assertNotIn(GOOD.text, before.decode())

    def test_family_classification(self):
        for family in s.RELEVANCE + s.CONFORMANCE:
            result = json.loads(s.build_manifest({**TASK, "family": family}))
            self.assertEqual(result["classification"],
                             "relevance" if family in s.RELEVANCE else "conformance_only")

    def test_request_budget_and_strict_task(self):
        for changes in ({"schema": "wrong"}, {"query": "x" * 4097},
                        {"family": "invented"}, {"instructions": ""},
                        {"scope": {**TASK["scope"], "files": []}}):
            with self.assertRaises(ValueError):
                s.build_manifest({**TASK, **changes})

    def test_scorer_source_has_no_io_execution_or_retriever(self):
        # Inspect only authored scorer source, never generated corpus source.
        tree = ast.parse(inspect.getsource(s))
        imports = {node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}
        imports |= {alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
                    for alias in node.names}
        self.assertEqual(imports, {"dataclasses", "hashlib", "json", "re"})
        forbidden = {"open", "exec", "eval", "compile", "__import__", "input", "print"}
        self.assertFalse({node.id for node in ast.walk(tree) if isinstance(node, ast.Name)} & forbidden)


if __name__ == "__main__":
    unittest.main()
