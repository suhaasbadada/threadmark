"""Offline tests only: historical raw replies / mocked worker, not actual extraction."""
import ast
import contextlib
import copy
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import normalized as norm
import scoped_run as runner

SCOPE = {"project": "orbit", "worktree": "synthetic-worktree", "revision": "synthetic-snapshot-1"}


def fixture():
    raw = json.loads(Path(__file__).with_name("results.json").read_text())["runs"][0]["envelope"]["graph"]
    sources = {p.name: p.read_bytes() for p in (runner.legacy.FIXTURES / "orbit").iterdir()}
    return raw, sources


class NormalizationTests(unittest.TestCase):
    def test_unicode_separators_do_not_shift_parser_line_anchors(self):
        for separator in ("\u2028", "\u2029", "\u0085"):
            with self.subTest(separator=repr(separator)):
                content = ('s = "one' + separator + 'two"\ndef normalize():\n    pass\n').encode()
                node = ast.parse(content.decode()).body[1]
                self.assertEqual(node.lineno, 2)
                sources = {"service.py": content}
                manifest = norm.source_manifest(sources)
                self.assertEqual(manifest["service.py"]["lines"], 3)
                anchor = norm.anchor({"source_file": "service.py", "source_location": "L2"}, sources, manifest)
                self.assertEqual(anchor["excerpt"], "def normalize():")

    def test_lf_rows_crlf_and_terminal_newline_are_shared(self):
        for content, expected in ((b"", ()), (b"a", ("a",)), (b"a\n", ("a",)),
                                  (b"a\n\n", ("a", "")), (b"a\r\nb\r\n", ("a", "b")),
                                  (b"a\rb", ("a\rb",)), (b"a\r", ("a\r",))):
            with self.subTest(content=content):
                self.assertEqual(norm.source_lines(content), expected)
                sources = {"service.py": content}
                manifest = norm.source_manifest(sources)
                self.assertEqual(manifest["service.py"]["lines"], len(expected))
                if expected:
                    anchor = norm.anchor({"source_file": "service.py", "source_location": f"L1-L{len(expected)}"}, sources, manifest)
                    self.assertEqual(anchor["excerpt"], "\n".join(expected))

    def test_historical_reply_produces_anchored_user_visible_rows(self):
        raw, sources = fixture()
        result = norm.normalize(raw, sources, SCOPE)
        rows = norm.query_rows(result, SCOPE)
        self.assertEqual(len(rows["where_is_normalize"]), 2)
        self.assertEqual(len(rows["what_directly_calls_normalize"]), 2)
        for row in rows["what_directly_calls_normalize"]:
            self.assertEqual(row["confidence"], "EXTRACTED")
            self.assertIn("normalize(value)", row["anchor"]["excerpt"])
        self.assertEqual(result["coverage"], "LIMITED_STATIC")
        self.assertNotIn("complete", result)
        self.assertEqual(raw, fixture()[0])

    def test_stable_reordered_and_distinct_scopes_and_source_bytes(self):
        raw, sources = fixture()
        first = norm.normalize(raw, sources, SCOPE)
        raw["nodes"].reverse()
        raw["edges"].reverse()
        self.assertEqual(first, norm.normalize(raw, dict(reversed(list(sources.items()))), SCOPE))
        original = {n["id"] for n in first["nodes"]}
        for key in SCOPE:
            scope = {**SCOPE, key: "changed"}
            self.assertTrue(original.isdisjoint(n["id"] for n in norm.normalize(raw, sources, scope)["nodes"]))
        changed = {p: b"# changed snapshot\n" + b for p, b in sources.items()}
        self.assertTrue(original.isdisjoint(n["id"] for n in norm.normalize(raw, changed, SCOPE)["nodes"]))

    def test_rejection_matrix_and_fresh_recovery(self):
        raw, sources = fixture()
        expected = norm.normalize(raw, sources, SCOPE)
        changes = [
            lambda g: g.update(schema=1),
            lambda g: g.update(failed_sources=["lib.rs"]),
            lambda g: g.update(skipped_sources=["lib.rs"]),
            lambda g: g.update(extracted_sources=["lib.rs"]),
            lambda g: g.update(extracted_sources=["lib.rs", "service.py", "lib.rs"]),
            lambda g: g.update(extracted_sources=[{}]),
            lambda g: g.update(nodes=[]),
            lambda g: g.update(nodes=[{}] * 2001),
            lambda g: g.update(edges=[{}] * 4001),
            lambda g: g["nodes"].append(copy.deepcopy(g["nodes"][0])),
            lambda g: g["nodes"][0].update(source_file="../other/lib.rs"),
            lambda g: g["nodes"][0].update(source_file="/private/lib.rs"),
            lambda g: g["nodes"][0].update(source_location="L999"),
            lambda g: g["nodes"][0].update(source_location="L3-L2"),
            lambda g: g["nodes"][0].update(source_location="L0"),
            lambda g: g["nodes"][0].update(label="/private/diagnostic"),
            lambda g: g["nodes"][0].update(private_diagnostic="hidden"),
            lambda g: g["nodes"][0].update(_origin="semantic"),
            lambda g: g["nodes"][0].update(file_type="invented-kind"),
            lambda g: g["nodes"][0].update(_callable=1),
            lambda g: g["edges"][0].update(target="missing"),
            lambda g: g["edges"][0].update(source=[]),
            lambda g: g["edges"][0].update(source_location="L999"),
            lambda g: g["edges"][0].update(confidence="certain"),
            lambda g: g["edges"][0].update(confidence=[]),
            lambda g: g["edges"][0].update(weight=float("nan")),
            lambda g: g["edges"].append(copy.deepcopy(g["edges"][0])),
            lambda g: g.update(input_tokens=True),
        ]
        for index, change in enumerate(changes):
            with self.subTest(index=index):
                bad = copy.deepcopy(raw)
                change(bad)
                with self.assertRaises(ValueError):
                    norm.normalize(bad, sources, SCOPE)
                self.assertEqual(norm.normalize(raw, sources, SCOPE), expected)

    def test_confidence_preserved_not_upgraded_by_ast(self):
        for label in norm.LABELS:
            raw, sources = fixture()
            raw["edges"][0]["confidence"] = label
            raw["nodes"][0]["confidence"] = label
            snapshot = norm.normalize(raw, sources, SCOPE)
            self.assertIn(label, {e["confidence"] for e in snapshot["edges"]})
            self.assertEqual(next(n for n in snapshot["nodes"] if n["upstream_id"] == "lib")["confidence"], label)

    def test_source_manifest_bounds_and_paths(self):
        for sources in ({"../a.py": b"pass"}, {"/a.py": b"pass"}, {"a//b.py": b"pass"},
                        {"a.py": b"\xff"}, {"a.py": b"x" * 65537}, {},
                        {f"{i}.py": b"pass" for i in range(17)}, {"a.txt": b"pass"}):
            with self.subTest(paths=list(sources)), self.assertRaises(ValueError):
                norm.source_manifest(sources)

    def test_queries_reject_scope_mismatch(self):
        raw, sources = fixture()
        with self.assertRaisesRegex(ValueError, "scope"):
            norm.query_rows(norm.normalize(raw, sources, SCOPE), {**SCOPE, "project": "orbit-next"})

    def test_new_contract_does_not_accept_old_envelope(self):
        raw, sources = fixture()
        with self.assertRaises(ValueError):
            norm.normalize({"schema": 1, "complete": True, "graph": raw}, sources, SCOPE)

    def test_duplicate_json_and_nonfinite_rejected(self):
        for value in (b'{"a":1,"a":2}', b'{"a":NaN}', b'{"a":'):
            with self.assertRaises(ValueError):
                runner.parse_reply(value)


class WorkerBoundaryTests(unittest.TestCase):
    def test_actual_stdlib_python_parse_rejects_malformed_without_execution(self):
        runner.python_preflight({"ok.py": b"raise RuntimeError('must not execute')\n"})
        with self.assertRaisesRegex(ValueError, "python_syntax"):
            runner.python_preflight({"broken.py": b"def broken(\n"})

    def test_mocked_native_rust_parser_error_and_recovery(self):
        parser = mock.Mock()
        parser.parse.return_value.root_node.has_error = True
        modules = {"tree_sitter": SimpleNamespace(Language=lambda value: value, Parser=lambda _: parser),
                   "tree_sitter_rust": SimpleNamespace(language=lambda: "mock-language")}
        with mock.patch.dict(sys.modules, modules):
            with self.assertRaisesRegex(ValueError, "rust_syntax"):
                runner.rust_preflight({"lib.rs": b"invalid synthetic rust"})
            parser.parse.return_value.root_node.has_error = False
            runner.rust_preflight({"lib.rs": b"pub fn fine() {}"})
        self.assertEqual(parser.parse.call_count, 2)

    def test_dependencies_absent_or_wrong_fail_closed(self):
        for effect in (metadata_missing(), lambda _: "wrong"):
            with mock.patch.object(runner.metadata, "version", side_effect=effect):
                with self.assertRaises((ValueError, runner.metadata.PackageNotFoundError)):
                    runner.installed_versions()

    def test_api_arguments_without_importing_graphify(self):
        extract = mock.Mock(return_value={"mock": True})
        with mock.patch.dict(sys.modules, {"graphify.extract": SimpleNamespace(extract=extract)}):
            self.assertEqual(runner.extract_graph([Path("a.py")], Path("root"), Path("cache")), {"mock": True})
        extract.assert_called_once_with([Path("a.py")], root=Path("root"), cache_root=Path("cache"),
                                        parallel=False, max_workers=1)

    def worker_mock(self, sources, raw, *, rust_error=False, extract_error=False):
        stack = contextlib.ExitStack()
        stack.enter_context(mock.patch.object(runner, "read_sources", return_value=sources))
        stack.enter_context(mock.patch.object(runner, "installed_versions", return_value=runner.PINS))
        rust = stack.enter_context(mock.patch.object(runner, "rust_preflight",
            side_effect=ValueError("mock-rust") if rust_error else None))
        extract = stack.enter_context(mock.patch.object(runner, "extract_graph",
            side_effect=ImportError("mock-missing") if extract_error else None, return_value=raw))
        stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
        return stack, rust, extract

    def test_python_rejection_before_native_parser_or_graphify(self):
        raw, sources = fixture()
        sources["broken.py"] = b"def broken(\n"
        stack, rust, extract = self.worker_mock(sources, raw)
        with stack:
            reply = runner.worker(Path("/synthetic"), Path("cache"), SCOPE)
        self.assertEqual(reply["graphify"], "NOT_RUN")
        self.assertEqual(reply["failure"], "syntax")
        self.assertEqual(reply["accepted_nodes"], 0)
        rust.assert_not_called()
        extract.assert_not_called()

    def test_mocked_rust_rejection_and_dependency_failure(self):
        raw, sources = fixture()
        for rust_error, extract_error, state in ((True, False, "NOT_RUN"), (False, True, "FAILED")):
            stack, _, _ = self.worker_mock(sources, raw, rust_error=rust_error, extract_error=extract_error)
            with stack:
                reply = runner.worker(Path("/synthetic"), Path("cache"), SCOPE)
            self.assertEqual(reply["status"], "rejected")
            self.assertEqual(reply["graphify"], state)
            self.assertNotIn("snapshot", reply)

    def test_mocked_valid_worker_and_failed_coverage_private_only(self):
        raw, sources = fixture()
        root = Path("/synthetic")
        raw["extracted_sources"] = [str(root / p) for p in sources]
        stack, _, _ = self.worker_mock(sources, raw)
        with stack:
            accepted = runner.worker(root, Path("cache"), SCOPE)
        self.assertEqual(accepted["status"], "accepted")
        self.assertEqual(accepted["snapshot"]["coverage"], "LIMITED_STATIC")
        raw["nodes"][0]["private_diagnostic"] = "/private/never-public"
        stack, _, _ = self.worker_mock(sources, raw)
        with stack:
            rejected = runner.worker(root, Path("cache"), SCOPE)
        self.assertEqual(rejected["failure"], "snapshot")
        self.assertNotIn("private", json.dumps(rejected))
        self.assertEqual(rejected["accepted_nodes"], 0)

    def test_source_changed_during_mocked_api_rejected(self):
        raw, sources = fixture()
        stack, _, _ = self.worker_mock(sources, raw)
        with stack, mock.patch.object(runner, "read_sources", side_effect=[sources, {"a.py": b"pass"}]):
            self.assertEqual(runner.worker(Path("/synthetic"), Path("cache"), SCOPE)["status"], "rejected")

    def test_cancellation_is_not_worker_reply(self):
        raw, sources = fixture()
        stack, _, _ = self.worker_mock(sources, raw)
        with stack, mock.patch.object(runner, "extract_graph", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                runner.worker(Path("/synthetic"), Path("cache"), SCOPE)

    def test_case_reuses_owner_budgets_and_cleans_after_mocked_cancel(self):
        paths = []
        def cancel(command, cwd, env, timeout, limit):
            paths.append(cwd)
            self.assertEqual((timeout, limit), (15, 262144))
            self.assertEqual(command[1:3], ["-I", "-B"])
            self.assertNotIn("OPENAI_API_KEY", env)
            self.assertEqual(env["HOME"], str(cwd / "home"))
            raise runner.legacy.Canceled("synthetic cancellation")
        with tempfile.TemporaryDirectory() as private:
            with mock.patch.object(runner.legacy._process, "bounded", side_effect=cancel):
                with self.assertRaises(runner.legacy.Canceled):
                    runner.case("orbit", "baseline", Path(private))
        self.assertTrue(paths)
        self.assertTrue(all(not p.exists() for p in paths))

    def test_no_actual_package_import_when_modules_loaded(self):
        self.assertNotIn("graphify", sys.modules)
        self.assertNotIn("tree_sitter", sys.modules)
        self.assertNotIn("tree_sitter_rust", sys.modules)


def metadata_missing():
    def missing(_):
        raise runner.metadata.PackageNotFoundError("synthetic")
    return missing


if __name__ == "__main__":
    unittest.main()
