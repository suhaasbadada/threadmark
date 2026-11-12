"""Only the authored generator is imported; generated source is inert bytes."""
import ast
from dataclasses import FrozenInstanceError, replace
import hashlib
import json
from pathlib import Path
import unittest

import corpus as c


class CorpusTests(unittest.TestCase):
    def setUp(self):
        self.good = c.build("small")

    def reject(self, candidate):
        before = self.good
        with self.assertRaises(ValueError):
            c.validate(candidate)
        self.assertEqual(self.good, before)
        # Recovery is a fresh pure validation, not persisted last-good state.
        self.assertEqual(c.validate(c.build("small")), c.FROZEN_DIGESTS["small"])

    def alter(self, section, edit):
        value = json.loads(getattr(self.good, section))
        edit(value)
        return replace(self.good, **{section: c.canonical(value)})

    def test_all_tiers_repeated_builds_hashes_budgets_and_anchors(self):
        for tier, count, cap, size in [("small", 32, 1 << 20, 4164),
                                       ("medium", 256, 8 << 20, 33620),
                                       ("large", 2048, 32 << 20, 271356)]:
            with self.subTest(tier=tier):
                first = c.build(tier)
                self.assertEqual(first, c.build(tier))
                self.assertEqual(c.validate(first), c.FROZEN_DIGESTS[tier])
                manifest = json.loads(first.manifest)
                self.assertEqual(manifest["source_count"], count)
                self.assertEqual(len(first.sources), count)
                self.assertEqual(manifest["source_bytes"], size)
                self.assertEqual(sum(len(b) for _, b in first.sources), size)
                self.assertLessEqual(size, cap)
                self.assertEqual(first.sources, tuple(sorted(first.sources)))
                sources = dict(first.sources)
                self.assertEqual(len(sources), count)
                for item in manifest["files"]:
                    data = sources[item["path"]]
                    self.assertEqual(item["bytes"], len(data))
                    self.assertEqual(item["sha256"], hashlib.sha256(data).hexdigest())
                    self.assertLessEqual(len(data), 65536)
                    self.assertEqual(item["project"], item["path"].split("/")[0])
                for project in manifest["projects"]:
                    selected = [b for p, b in first.sources if p.startswith(project["project"] + "/")]
                    self.assertEqual(len(selected), count // 2)
                    self.assertEqual(sum(map(len, selected)), project["source_bytes"])
                self.assertEqual(manifest["oracle_sha256"], c.sha(first.oracle))
                self.assertEqual(manifest["inputs_sha256"], c.sha(first.inputs))
                digest = manifest.pop("digest")
                self.assertEqual(digest, c.sha(c.canonical(manifest)))
                oracle = json.loads(first.oracle)
                for fact in oracle["facts"]:
                    self.assertEqual(sources[fact["path"]].decode().splitlines()[fact["line"] - 1], fact["text"])
                    for key, value in c.scope(fact["project"]).items():
                        self.assertEqual(fact[key], value)
                for conflict in oracle["cross_root_conflicts"]:
                    self.assertEqual({p.split("/")[0] for p in conflict["paths"]}, set(c.PROJECTS))
                    lines = [sources[p].decode().splitlines()[conflict["line"] - 1] for p in conflict["paths"]]
                    if conflict["kind"] == "conflicting_decisions":
                        self.assertNotEqual(*lines)
                    else:
                        self.assertEqual(*lines)
                inputs = json.loads(first.inputs)
                self.assertEqual(len(inputs["tasks"]), 2)
                for task in inputs["tasks"]:
                    self.assertEqual(len(task["families"]), 4)
                self.assertNotIn("facts", inputs)
                self.assertNotIn("expected", first.inputs.decode())
                self.assertTrue(all("/src/" in p for p in sources))
                self.assertEqual(manifest["retrieval"], "not_run")
                self.assertEqual(manifest["scoring_contract"], "not_available")

    def test_immutable_and_validation_does_not_mutate(self):
        before = c.Corpus(tuple(self.good.sources), bytes(self.good.manifest),
                          bytes(self.good.oracle), bytes(self.good.inputs))
        c.validate(self.good)
        self.assertEqual(before, self.good)
        with self.assertRaises(FrozenInstanceError):
            self.good.oracle = b"{}"
        decoded = c.decode(self.good.manifest)
        decoded["schema"] = "changed"
        self.assertEqual(before, self.good)

    def test_one_byte_tamper_missing_duplicate_unsorted_and_mismatch(self):
        path, data = self.good.sources[0]
        for sources in [((path, b"!" + data[1:]),) + self.good.sources[1:],
                        self.good.sources[1:],
                        (self.good.sources[1],) + self.good.sources[1:],
                        tuple(reversed(self.good.sources))]:
            self.reject(replace(self.good, sources=sources))
        self.reject(replace(self.good, oracle=c.build("medium").oracle))

    def test_paths_reject_absolute_traversal_controls_symlinklike_foreign(self):
        for path in ["/harbor/src/unit_0000.rs", "harbor/../src/unit_0000.rs",
                     "harbor//src/unit_0000.rs", "harbor/src/./unit_0000.rs",
                     "harbor\\src\\unit_0000.rs", "harbor/src/unit_0000.rs\n",
                     "harbor/src/link->unit_0000.rs", "other/src/unit_0000.rs",
                     "harbor/src/unit_0000.rs\x00", "harbor/src/%2e%2e/unit_0000.rs"]:
            with self.subTest(path=repr(path)):
                self.reject(replace(self.good, sources=((path, self.good.sources[0][1]),) + self.good.sources[1:]))

    def test_schema_manifest_and_scope_errors(self):
        for section in ("manifest", "oracle", "inputs"):
            self.reject(self.alter(section, lambda value: value.update(schema="unknown")))
            self.reject(replace(self.good, **{section: b'{"schema":1,"schema":1}'}))
            self.reject(replace(self.good, **{section: b'not json'}))
            self.reject(replace(self.good, **{section: b'[]'}))
        for key, value in [("source_count", 0), ("source_bytes", 0), ("aggregate_cap", 1),
                           ("tier", "unknown"), ("extra", True)]:
            self.reject(self.alter("manifest", lambda m: m.update({key: value})))
        self.reject(self.alter("manifest", lambda m: m["files"].append(m["files"][0])))
        self.reject(self.alter("manifest", lambda m: m["files"][0].update(sha256="0" * 64)))
        for key in ("project", "revision", "worktree"):
            self.reject(self.alter("oracle", lambda o: o["facts"][0].update({key: "foreign"})))
        self.reject(self.alter("inputs", lambda i: i["tasks"][0].update(revision="stale")))

    def test_oracle_foreign_out_of_range_wrong_text_and_duplicate(self):
        for changes in [{"path": "foreign/src/unit_0000.rs"}, {"line": 0},
                        {"line": -1}, {"line": 9999}, {"line": True}, {"text": "wrong"}]:
            self.reject(self.alter("oracle", lambda o: o["facts"][0].update(changes)))
        self.reject(self.alter("oracle", lambda o: o["facts"].append(o["facts"][0])))
        self.reject(self.alter("oracle", lambda o: o["cross_root_conflicts"][0].update(paths=["foreign/file.md"])))

    def test_file_and_aggregate_caps(self):
        self.reject(replace(self.good, sources=((self.good.sources[0][0], b"x" * 65537),) + self.good.sources[1:]))
        # Every individual source is legal-sized; sum exceeds the small cap.
        self.reject(replace(self.good, sources=tuple((p, b"x" * 65536) for p, _ in self.good.sources)))

    def test_self_consistent_refreeze_still_rejected(self):
        altered = self.alter("oracle", lambda o: o.update(expected_unknowns=[]))
        manifest = c.decode(altered.manifest)
        manifest["oracle_sha256"] = c.sha(altered.oracle)
        del manifest["digest"]
        manifest["digest"] = c.sha(c.canonical(manifest))
        self.reject(replace(altered, manifest=c.canonical(manifest)))

    def test_fixed_failure_recipes_are_not_observed_results(self):
        oracle = c.decode(self.good.oracle)
        self.assertIn("not observed", oracle["rejection_recipe_status"])
        self.assertEqual(len(oracle["rejection_recipes"]), 10)
        self.assertNotIn("scores", oracle)
        self.assertIn("material permission", oracle["expected_unknowns"])

    def test_generator_has_no_execution_network_or_filesystem_api(self):
        # Inspect authored module only, never parse/import/execute synthetic source.
        tree = ast.parse(Path(c.__file__).read_text())
        allowed = {"dataclasses", "hashlib", "json", "re", "argparse"}
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                self.assertTrue({a.name for a in node.names} <= allowed)
            if isinstance(node, ast.ImportFrom):
                self.assertIn(node.module, allowed)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                self.assertNotIn(node.func.id, {"open", "exec", "eval", "compile", "__import__"})


if __name__ == "__main__":
    unittest.main()
