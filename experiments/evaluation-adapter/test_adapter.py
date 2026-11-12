"""Tiny authored objects only; no imports/reads/runs of corpus or scorer code."""
from dataclasses import FrozenInstanceError
import copy
import hashlib
import json
import unittest

import adapter


def encoded(value):
    # Independently authored test recipe, not the corpus generator.
    return json.dumps(value, ensure_ascii=True, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("ascii")


def hashed(value):
    return hashlib.sha256(value).hexdigest()


def scoped(project):
    return {"project": project, "worktree": project + "-fixture-worktree-1",
            "revision": project + "-fixture-revision-1"}


def mini():
    """A miniature declared artifact, NOT a generated corpus size tier."""
    local = ["// irrelevant current line", *[f"fn resolve_{n}() {{}}" for n in range(10)],
             "resolve_0();", "Current rule: retain.", "Retired rule: export.",
             "Do not send. Permission unresolved.", "macro_gap!();", "dynamic(name)"]
    sources = (("harbor/src/unit_0000.rs", ("\n".join(local) + "\n").encode()),
               ("harbour/src/unit_0000.md", b"Current rule: delete.\n"))
    fact_lines = [(n, "definition") for n in range(2, 12)] + [
        (12, "direct_call"), (13, "current_decision"), (14, "stale_decision"),
        (15, "negation_permission"), (16, "macro_gap"), (17, "dynamic_gap")]
    oracle = {"schema": "1", "facts": [
        {**scoped("harbor"), "path": sources[0][0], "line": n,
         "text": local[n - 1], "kind": kind} for n, kind in fact_lines] + [
        {**scoped("harbour"), "path": sources[1][0], "line": 1,
         "text": "Current rule: delete.", "kind": "current_decision"}],
        "cross_root_conflicts": [{"paths": [p for p, _ in sources], "line": 1,
                                  "kind": "conflicting_decisions"}],
        "expected_unknowns": ["macro-generated definitions", "dynamic call targets",
                              "material permission", "task correctness"],
        "rejection_recipe_status": "fixed expectations only; not observed extractor results",
        "rejection_recipes": [
            {"mutation": name, "expected": result} for name, result in [
                ("interrupt extraction", "no_partial_admission"),
                ("dependency unavailable", "no_complete_result"),
                ("fresh rebuild after failure", "validate_fresh_candidate_only")]],
        "family_expectations": {
            "definition_directcall": ["definition", "direct_call"],
            "conflictingrules_stale_wrongrevision": ["current_decision", "reject_stale"],
            "negations_permission": ["preserve_all_constraints", "permission_unknown"],
            "rename_delete_malformed_interruption_recovery": ["no_partial_admission"]}}
    inputs = {"schema": "1", "tier": "small", "tasks": [
        {**scoped(p), "instructions": "Do not execute. Preserve café and every negation.\nAsk about permission.",
         "families": [
             {"id": "definition_directcall", "query": "Locate ALL resolve definitions and direct callers."},
             {"id": "conflictingrules_stale_wrongrevision", "query": "Find current rule, not retired or foreign."},
             {"id": "negations_permission", "original": "Do not send or deploy. Permission unresolved.\n",
              "constraints": ["local only", "no send", "no deploy", "permission unresolved"]},
             {"id": "rename_delete_malformed_interruption_recovery", "query": "Describe uncertainty; do not invent recovery."}]}
        for p in ("harbor", "harbour")]}
    manifest = {"schema": "1", "generator": "1", "templates": "1", "tier": "small",
                "source_count": 2, "aggregate_cap": 1 << 20, "file_cap": 65536,
                "source_bytes": sum(len(b) for _, b in sources),
                "projects": [{**scoped(p), "source_count": 1, "source_bytes": len(b)}
                             for p, (_, b) in zip(("harbor", "harbour"), sources)],
                "files": [{**scoped(p.split("/")[0]), "path": p,
                           "bytes": len(b), "sha256": hashed(b)} for p, b in sources],
                "excluded_sources": ["oracle", "instructions", "private source"],
                "known_parser_limits": ["No parser or extractor run"],
                "oracle_sha256": hashed(encoded(oracle)), "inputs_sha256": hashed(encoded(inputs)),
                "retrieval": "not_run", "scoring_contract": "not_available",
                "inference": "not_run", "host": "not_run", "executor": "not_run"}
    manifest["digest"] = hashed(encoded(manifest))
    return [sources, manifest, oracle, inputs]


# Frozen separately from candidates; test setup never derives the expected pin.
PIN = "783168de23907f1158c9594495f8f74d7d473606f200a0522bd21fedb00f139f"


def refreeze(candidate):
    """Test-only adversary: recalculating metadata cannot replace trusted PIN."""
    m = candidate[1]
    m["oracle_sha256"] = hashed(encoded(candidate[2]))
    m["inputs_sha256"] = hashed(encoded(candidate[3]))
    m.pop("digest", None)
    m["digest"] = hashed(encoded(m))
    return m["digest"]


def multi_file_mini():
    c = mini()
    path = "harbor/src/unit_0001.py"
    raw = b"def resolve():\n    return 1\n# another irrelevant line\n"
    c[0] = tuple(sorted((*c[0], (path, raw))))
    c[1]["source_count"] += 1
    c[1]["source_bytes"] += len(raw)
    c[1]["projects"][0]["source_count"] += 1
    c[1]["projects"][0]["source_bytes"] += len(raw)
    c[1]["files"].insert(1, {**scoped("harbor"), "path": path,
                             "bytes": len(raw), "sha256": hashed(raw)})
    c[2]["facts"].append({**scoped("harbor"), "path": path, "line": 1,
                            "text": "def resolve():", "kind": "definition"})
    refreeze(c)
    return c


def call(candidate, pin=PIN, selected=None):
    sources, manifest, oracle, inputs = candidate
    return adapter.prepare(sources, encoded(manifest), encoded(oracle), encoded(inputs),
                           scoped("harbor") if selected is None else selected,
                           expected_digest=pin)


class AdapterTests(unittest.TestCase):
    def test_frozen_digest_and_all_families(self):
        c = mini()
        self.assertEqual(c[1]["digest"], PIN)
        cases = call(c)
        self.assertEqual(len(cases), 4)
        self.assertEqual(cases, call(c))
        for case, family in zip(cases, adapter.FAMILIES):
            fixture, sidecar = map(json.loads, (case.fixture, case.private_sidecar))
            self.assertEqual(fixture["family"], family)
            self.assertEqual(len(fixture["anchors"]), 17)
            self.assertEqual(set(fixture["anchors"][0]), set(adapter.ANCHOR))
            self.assertTrue(all(a["project"] == "harbor" for a in fixture["anchors"]))
            self.assertNotIn("complete", fixture)
            self.assertEqual(sidecar["oracle"], c[2])
            self.assertEqual(sidecar["inputs"], c[3])
            self.assertEqual(sidecar["manifest"], c[1])
            self.assertEqual(sidecar["budgets"], {"max_items": 8,
                "max_candidate_bytes": 8192, "max_original_bytes": 4096})

    def test_all_gold_over_eight_and_irrelevant_anchor(self):
        definition, decision, negation, recovery = call(mini())
        f = json.loads(definition.fixture)
        self.assertEqual([a["line"] for a in f["gold"]], list(range(2, 13)))
        self.assertEqual(f["anchors"][0]["text"], "// irrelevant current line")
        self.assertNotIn(f["anchors"][0], f["gold"])
        self.assertEqual([a["line"] for a in f["rejected"]], [14])
        self.assertTrue(all(a not in f["gold"] for a in f["rejected"]))
        self.assertEqual([a["line"] for a in json.loads(decision.fixture)["gold"]], [13])
        for case in (negation, recovery):
            self.assertEqual(json.loads(case.fixture)["gold"], [])
            self.assertEqual(json.loads(case.private_sidecar)["classification"], "conformance_only")

    def test_all_selected_files_not_oracle_narrowed(self):
        c = multi_file_mini()
        # Independently predeclared pin for this second miniature artifact.
        pin = "dcf98ee6b0a67d0e060342302c313cd59556420c635f226fce364a49b78872d2"
        self.assertEqual(c[1]["digest"], pin)
        case = call(c, pin=pin)[0]
        f = json.loads(case.fixture)
        self.assertEqual(len(case.arm_input.sources), 2)
        self.assertEqual(len(f["anchors"]), 20)
        self.assertEqual(len(f["gold"]), 12)
        self.assertEqual(f["gold"][-1]["path"], "harbor/src/unit_0001.py")
        self.assertEqual(f["anchors"][-1]["text"], "# another irrelevant line")
        self.assertNotIn(f["anchors"][-1], f["gold"])
        self.assertTrue(all(a["line"] not in (16, 17) for a in f["gold"]
                            if a["path"] == "harbor/src/unit_0000.rs"))

    def test_originals_byte_exact_and_no_manufactured_query(self):
        c = mini()
        for case, family in zip(call(c), c[3]["tasks"][0]["families"]):
            public = json.loads(case.arm_input.declared_task)
            self.assertEqual(public["original_input"], family)
            self.assertEqual(public["instructions"].encode(), c[3]["tasks"][0]["instructions"].encode())
            if "query" in family:
                method = json.loads(case.arm_input.method_task)
                self.assertEqual(method["query"].encode(), family["query"].encode())
                self.assertEqual(method["instructions"], public["instructions"])
                self.assertEqual(set(method), {"schema", "scope", "family", "query", "instructions"})
            else:
                self.assertIsNone(case.arm_input.method_task)
                self.assertEqual(json.loads(case.private_sidecar)["score_manifest_mapping"], "NOT_AVAILABLE")

    def test_arm_answer_separation(self):
        c = mini()
        for case in call(c):
            self.assertEqual(case.arm_input.sources, c[0][:1])
            public = json.loads(case.arm_input.declared_task)
            self.assertEqual(set(public), {"schema", "scope", "original_input", "instructions"})
            for secret in (c[1]["digest"], c[1]["oracle_sha256"], c[1]["inputs_sha256"],
                           "expected_unknowns", "rejection_recipes", '"gold"', '"kind"'):
                self.assertNotIn(secret.encode(), case.arm_input.declared_task)
                self.assertNotIn(secret.encode(), case.arm_input.method_task or b"")
            with self.assertRaises(FrozenInstanceError):
                case.fixture = b"changed"

    def test_coverage_hashes_and_no_result_claim(self):
        c = mini()
        f = json.loads(call(c)[0].fixture)
        coverage = "\n".join(f["coverage"])
        selected_files = [entry for entry in c[1]["files"]
                          if entry["project"] == "harbor"]
        for value in (PIN, c[1]["oracle_sha256"], c[1]["inputs_sha256"],
                      hashed(encoded(selected_files)), "LF-only", "macro", "dynamic", "not extractor"):
            self.assertIn(value, coverage)
        self.assertNotIn("status", f)
        self.assertNotIn("metrics", f)
        self.assertNotIn("items", f)

    def test_large_selected_manifest_does_not_overflow_empty_score_envelope(self):
        c = mini()
        c[1]["tier"] = c[3]["tier"] = "medium"
        c[1]["aggregate_cap"] = 8 << 20
        extra = tuple((f"harbor/src/unit_{n:04d}.rs", b"// irrelevant\n")
                      for n in range(1, 129))
        c[0] = tuple(sorted((*c[0], *extra)))
        c[1]["files"] = [{**scoped(p.split("/")[0]), "path": p,
                          "bytes": len(b), "sha256": hashed(b)} for p, b in c[0]]
        c[1]["source_count"] = len(c[0])
        c[1]["source_bytes"] = sum(len(b) for _, b in c[0])
        for project in c[1]["projects"]:
            own = [f for f in c[1]["files"] if f["project"] == project["project"]]
            project["source_count"] = len(own)
            project["source_bytes"] = sum(f["bytes"] for f in own)
        # Explicitly trusted alternate test artifact, not a production pin.
        case = call(c, pin=refreeze(c))[0]
        f = json.loads(case.fixture)
        envelope = {"schema": "evaluation-scoring/1", "scope": f["scope"],
                    "coverage": {"status": "complete", "envelope": f["coverage"]},
                    "items": []}
        self.assertLessEqual(len(adapter.canonical(envelope, ascii_only=False)), 8192)
        self.assertEqual(len(case.arm_input.sources), 129)
        self.assertEqual(json.loads(case.private_sidecar)["manifest"], c[1])
        self.assertEqual(len(f["gold"]), 11)

    def test_selected_other_root_and_wrong_scope(self):
        cases = call(mini(), selected=scoped("harbour"))
        f = json.loads(cases[1].fixture)
        self.assertEqual([a["text"] for a in f["gold"]], ["Current rule: delete."])
        self.assertTrue(all(a["project"] == "harbour" for a in f["anchors"]))
        for key in adapter.SCOPE:
            s = scoped("harbor")
            s[key] = "other"
            with self.subTest(key=key), self.assertRaises(ValueError):
                call(mini(), selected=s)

    def test_tamper_and_forged_self_refreeze(self):
        for section, key, value in [(1, "templates", "2"), (2, "schema", "2"),
                                     (3, "schema", "2"), (1, "source_bytes", 0)]:
            c = mini()
            c[section][key] = value
            refreeze(c)
            with self.subTest(key=key), self.assertRaises(ValueError):
                call(c)  # Never accept the adversary's newly self-supplied digest.
        c = mini()
        c[0] = ((c[0][0][0], b"tampered\n"), c[0][1])
        with self.assertRaises(ValueError):
            call(c)
        for pin in ("0" * 64, "", None, True, PIN.upper()):
            with self.subTest(pin=pin), self.assertRaises(ValueError):
                call(mini(), pin=pin)

    def assert_structural_rejection(self, mutate):
        c = mini()
        mutate(c)
        # Explicitly trust an alternate test artifact to reach independent checks;
        # production callers must NEVER get their trusted pin from a candidate.
        pin = refreeze(c)
        with self.assertRaises(ValueError):
            call(c, pin=pin)

    def test_schema_fields_empty_unknown_and_strict_types(self):
        changes = [lambda c: c[1].update(schema="2"),
                   lambda c: c[1].update(generator=1),
                   lambda c: c[1].update(templates="2"),
                   lambda c: c[2].update(schema="2"),
                   lambda c: c[3].update(schema="2"),
                   lambda c: c[1].update(tier="unknown"),
                   lambda c: c[1].update(unknown="field"),
                   lambda c: c[2].update(unknown="field"),
                   lambda c: c[3].update(unknown="field"),
                   lambda c: c[2].update(facts=[]),
                   lambda c: c[2].update(expected_unknowns=[]),
                   lambda c: c[2].update(rejection_recipes=[]),
                   lambda c: c[3].update(tasks=[]),
                   lambda c: c[3]["tasks"][0].update(instructions=""),
                   lambda c: c[3]["tasks"][0]["families"][0].update(query=""),
                   lambda c: c[3]["tasks"][0]["families"][2].update(constraints=[]),
                   lambda c: c[3]["tasks"][0]["families"].reverse(),
                   lambda c: c[3]["tasks"][0]["families"][0].update(extra=True),
                   lambda c: c[2]["family_expectations"].update(unknown=["x"]),
                   lambda c: c[1]["files"][0].update(bytes=True),
                   lambda c: c[1].update(source_count=True),
                   lambda c: c[1].update(file_cap=True)]
        for n, mutate in enumerate(changes):
            with self.subTest(change=n):
                self.assert_structural_rejection(mutate)

    def test_missing_duplicate_foreign_unordered_sources(self):
        for sources in (mini()[0][:1], mini()[0] * 2, (mini()[0][0], mini()[0][0]),
                        tuple(reversed(mini()[0])), list(mini()[0])):
            c = mini()
            c[0] = sources
            with self.subTest(sources_type=type(sources)), self.assertRaises(ValueError):
                call(c)
        for path in ("foreign/src/unit_0000.rs", "harbor/../src/unit_0000.rs",
                     "/harbor/src/unit_0000.rs", "harbor\\src\\unit_0000.rs",
                     "harbor/src/unit_0000.rs\x00", "harbor//src/unit_0000.rs"):
            c = mini()
            c[0] = ((path, c[0][0][1]), c[0][1])
            c[1]["files"][0]["path"] = path
            with self.subTest(path=path), self.assertRaises(ValueError):
                call(c, pin=refreeze(c))

    def test_bad_oracle_anchors_and_conflicts(self):
        changes = [lambda c: c[2]["facts"][0].update(line=True),
                   lambda c: c[2]["facts"][0].update(line=0),
                   lambda c: c[2]["facts"][0].update(line=100),
                   lambda c: c[2]["facts"][0].update(text="wrong"),
                   lambda c: c[2]["facts"][0].update(text="fn resolve_0() {}\r"),
                   lambda c: c[2]["facts"][0].update(revision="old"),
                   lambda c: c[2]["facts"][0].update(worktree="other"),
                   lambda c: c[2]["facts"][0].update(project="harbour"),
                   lambda c: c[2]["facts"][0].update(path="foreign/src/unit_0000.rs"),
                   lambda c: c[2]["facts"][0].update(kind="forbidden"),
                   lambda c: c[2]["facts"].append(copy.deepcopy(c[2]["facts"][0])),
                   lambda c: c[2]["cross_root_conflicts"][0].update(line=999),
                   lambda c: c[2]["cross_root_conflicts"][0].update(paths=["missing", "missing"])]
        for n, mutate in enumerate(changes):
            with self.subTest(change=n):
                self.assert_structural_rejection(mutate)

    def test_hashes_counts_caps_and_order_independently(self):
        changes = [lambda c: c[1].update(source_count=3),
                   lambda c: c[1].update(source_count=33),
                   lambda c: c[1].update(source_bytes=0),
                   lambda c: c[1].update(source_bytes=(1 << 20) + 1),
                   lambda c: c[1].update(aggregate_cap=999),
                   lambda c: c[1].update(file_cap=999),
                   lambda c: c[1]["files"][0].update(bytes=0),
                   lambda c: c[1]["files"][0].update(sha256="0" * 64),
                   lambda c: c[1]["files"].reverse(),
                   lambda c: c[1]["projects"].reverse(),
                   lambda c: c[1]["projects"][0].update(source_count=2),
                   lambda c: c[1]["projects"][0].update(source_bytes=0),
                   lambda c: c[1]["files"][0].update(revision="old"),
                   lambda c: c[3]["tasks"][0].update(revision="old")]
        for n, mutate in enumerate(changes):
            with self.subTest(change=n):
                self.assert_structural_rejection(mutate)
        c = mini()
        c[1]["oracle_sha256"] = "0" * 64
        c[1].pop("digest")
        c[1]["digest"] = hashed(encoded(c[1]))
        with self.assertRaises(ValueError):
            call(c, pin=c[1]["digest"])
        c = mini()
        c[1]["inputs_sha256"] = "0" * 64
        c[1].pop("digest")
        c[1]["digest"] = hashed(encoded(c[1]))
        with self.assertRaises(ValueError):
            call(c, pin=c[1]["digest"])

    def test_metadata_transport_canonical_duplicates_types(self):
        c = mini()
        for raw in (b"", b"{}", b"null", b"[]", b'{"schema":"1","schema":"1"}',
                    encoded(c[1]) + b"\n", b"NaN", b"\xff", bytearray(encoded(c[1])),
                    b" " * (adapter.META_CAP + 1)):
            with self.subTest(raw_type=type(raw)), self.assertRaises(ValueError):
                adapter.prepare(c[0], raw, encoded(c[2]), encoded(c[3]),
                                scoped("harbor"), expected_digest=PIN)

    def test_line_conventions_source_types_and_file_cap(self):
        for raw in (b"line\r\n", b"line\r", b"line\vnext\n", b"line\x00\n",
                    "line\u2028next\n".encode(), "line\x85next\n".encode(),
                    b"\xff", b"a" * 65537, bytearray(b"line\n"), "line\n"):
            c = mini()
            c[0] = ((c[0][0][0], raw), c[0][1])
            with self.subTest(raw_type=type(raw)), self.assertRaises(ValueError):
                call(c)
        self.assertEqual(adapter.source_lines(b"a\n\nb\n"), ["a", "", "b"])
        self.assertEqual(adapter.source_lines(b"a\n\nb"), ["a", "", "b"])
        self.assertEqual(adapter.source_lines(b""), [])

    def test_request_overflow_not_truncated(self):
        for family, field in ((0, "query"), (2, "original")):
            self.assert_structural_rejection(lambda c: c[3]["tasks"][0]["families"][family].update(
                {field: "é" * 4096}))
        self.assert_structural_rejection(lambda c: c[3]["tasks"][0].update(instructions="x" * 4097))

    def test_original_budget_inclusive_at_4096(self):
        c = mini()
        task = c[3]["tasks"][0]
        original = {"query": "x", "instructions": task["instructions"]}
        used = len(json.dumps(original, ensure_ascii=False, sort_keys=True,
                              separators=(",", ":")).encode("utf-8"))
        task["families"][0]["query"] = "x" * (4096 - used + 1)
        # This test deliberately trusts an alternate authored boundary fixture.
        pin = refreeze(c)
        method = json.loads(call(c, pin=pin)[0].arm_input.method_task)
        self.assertEqual(method["query"], task["families"][0]["query"])
        task["families"][0]["query"] += "x"
        with self.assertRaises(ValueError):
            call(c, pin=refreeze(c))

    def test_nonmutation_failure_and_fresh_recovery(self):
        good = mini()
        before = copy.deepcopy(good)
        trusted = call(good)
        bad = copy.deepcopy(good)
        bad[2]["facts"][0]["text"] = "bad candidate"
        with self.assertRaises(ValueError):
            call(bad)
        self.assertEqual(good, before)
        self.assertEqual(trusted, call(mini()))
        self.assertEqual(trusted, call(good))
        good[2]["facts"][0]["text"] = "changed original input after preparing"
        self.assertEqual(trusted, call(mini()))


if __name__ == "__main__":
    unittest.main()
