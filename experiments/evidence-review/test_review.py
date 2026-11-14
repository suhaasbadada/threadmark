"""Offline tests: recorded artifact reads and isolated stdlib fixture seams only."""
import copy
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import cli
import review as r


class RecordedTests(unittest.TestCase):
    def test_retained_hash(self):
        self.assertEqual(hashlib.sha256(r.REPORT.read_bytes()).hexdigest(), r.EXPECTED_SHA)

    def test_actual_rows_and_confidence(self):
        evidence = r.load_recorded("orbit")
        rows = evidence["rows"]
        self.assertEqual(len(rows["where_is_normalize"]), 2)
        self.assertEqual(len(rows["what_directly_calls_normalize"]), 2)
        draft = r.candidate(evidence)
        self.assertIn("value.trim()", draft)
        self.assertIn("confidence=not supplied", draft)
        self.assertIn("confidence=EXTRACTED", draft)
        self.assertIn("service.py:L9-L9", draft)
        self.assertIn("LIMITED_STATIC", draft)
        self.assertLessEqual(len(draft.encode()), r.DRAFT_LIMIT)

    def test_actual_second_project(self):
        draft = r.candidate(r.load_recorded("orbit-next"))
        self.assertIn("value.to_lowercase()", draft)
        self.assertNotIn("value.trim()", draft)
        self.assertIn("orbit-next / synthetic-worktree / synthetic-snapshot-1", draft)

    def test_wrong_project_no_reads(self):
        with patch.object(r, "bounded_read", side_effect=AssertionError):
            self.assertIsNone(r.load_recorded("private/path"))

    def test_manifest_matches_actual_sources(self):
        for project in r.PROJECTS:
            evidence = r.load_recorded(project)
            sources = {name: (r.FIXTURES / project / name).read_bytes() for name in r.SOURCE_NAMES}
            manifest = r.norm.source_manifest(sources)
            for rows in evidence["rows"].values():
                for row in rows:
                    a = row["anchor"]
                    self.assertEqual(a["sha256"], manifest[a["path"]]["sha256"])
                    self.assertEqual(a["excerpt"], "\n".join(
                        r.norm.source_lines(sources[a["path"]])[a["start"] - 1:a["end"]]))

    def test_missing_report(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "REPORT", Path(d) / "missing"):
            self.assertIsNone(r.load_recorded("orbit"))

    def test_tampered_report(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "report.json"
            path.write_bytes(r.REPORT.read_bytes() + b" ")
            with patch.object(r, "REPORT", path):
                self.assertIsNone(r.load_recorded("orbit"))

    def test_report_budget(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "large"
            path.write_bytes(b"x" * (r.REPORT_LIMIT + 1))
            with patch.object(r, "REPORT", path):
                self.assertIsNone(r.load_recorded("orbit"))

    def test_report_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "link"
            path.symlink_to(r.REPORT)
            with patch.object(r, "REPORT", path):
                self.assertIsNone(r.load_recorded("orbit"))

    def source_failure(self, kind):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "orbit").mkdir()
            for name in r.SOURCE_NAMES:
                (root / "orbit" / name).write_bytes((r.FIXTURES / "orbit" / name).read_bytes())
            target = root / "orbit/service.py"
            if kind == "tamper":
                target.write_bytes(target.read_bytes() + b"# changed\n")
            elif kind == "budget":
                target.write_bytes(b"x" * (r.SOURCE_LIMIT + 1))
            else:
                target.unlink()
                if kind == "symlink":
                    target.symlink_to(r.FIXTURES / "orbit/service.py")
            with patch.object(r, "FIXTURES", root):
                self.assertIsNone(r.load_recorded("orbit"))

    def test_source_tamper(self):
        self.source_failure("tamper")

    def test_source_missing(self):
        self.source_failure("missing")

    def test_source_symlink(self):
        self.source_failure("symlink")

    def test_source_budget(self):
        self.source_failure("budget")

    def test_combined_source_budget(self):
        with patch.object(r, "bounded_read", side_effect=[r.REPORT.read_bytes(),
                                                         b"x" * 40000, b"y" * 40000]):
            self.assertIsNone(r.load_recorded("orbit"))

    def test_draft_utf8_budget(self):
        evidence = copy.deepcopy(r.load_recorded("orbit"))
        evidence["limitations"] = ["語" * 3000]
        with self.assertRaises(ValueError):
            r.candidate(evidence)


class ControllerTests(unittest.TestCase):
    def test_review_exact_draft(self):
        c = r.Controller("orbit")
        original_draft = c.draft
        c.command("review")
        self.assertTrue(c.reviewed)
        self.assertEqual(c.draft, original_draft)
        self.assertTrue(c.draft.startswith(r.ORIGINAL + "\n"))
        c.draft += "tamper"
        c.command("review")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")

    def test_project_invalidates(self):
        c = r.Controller("orbit")
        c.command("review")
        c.command("project orbit-next")
        self.assertFalse(c.reviewed)
        self.assertIn("to_lowercase", c.draft)
        c.command("review")
        self.assertTrue(c.reviewed)

    def test_stale_restore_no_approval(self):
        c = r.Controller("orbit")
        c.command("review")
        c.command("stale")
        c.command("review")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")
        c.command("restore")
        self.assertTrue(c.draft)
        self.assertFalse(c.reviewed)

    def test_outage_persists_switch_recover_no_approval(self):
        c = r.Controller("orbit")
        c.command("review")
        c.command("unavailable")
        c.command("project orbit-next")
        c.command("review")
        self.assertTrue(c.outage)
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")
        c.command("recover")
        self.assertFalse(c.reviewed)
        c.command("review")
        self.assertTrue(c.reviewed)

    def test_cancel_original_only(self):
        c = r.Controller("orbit")
        c.command("review")
        c.command("cancel")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")
        self.assertTrue(c.display().endswith(r.ORIGINAL + "\n"))
        self.assertNotIn("source sha256", c.display())
        c.command("review")
        self.assertFalse(c.reviewed)

    def test_artifact_drift_before_review(self):
        c = r.Controller("orbit")
        with patch.object(r, "REPORT", r.REPORT.parent / "absent.json"):
            c.command("review")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")
        c.command("review")  # no automatic last-good candidate
        self.assertFalse(c.reviewed)
        c.command("show")
        self.assertFalse(c.reviewed)
        c.command("review")
        self.assertTrue(c.reviewed)

    def test_changed_evidence_on_show_invalidates(self):
        evidence = r.load_recorded("orbit")
        c = r.Controller("orbit", loader=lambda _: evidence)
        c.command("review")
        evidence["limitations"].append("Changed synthetic context")
        c.command("show")
        self.assertFalse(c.reviewed)

    def test_source_drift_before_review(self):
        c = r.Controller("orbit")
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "orbit").mkdir()
            for name in r.SOURCE_NAMES:
                data = (r.FIXTURES / "orbit" / name).read_bytes()
                (root / "orbit" / name).write_bytes(data + b"\n")
            with patch.object(r, "FIXTURES", root):
                c.command("review")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")

    def test_unavailable_no_fallback(self):
        c = r.Controller("orbit", loader=lambda _: None)
        c.command("review")
        self.assertFalse(c.reviewed)
        self.assertEqual(c.draft, "")


class CliTests(unittest.TestCase):
    def run_cli(self, text):
        output = io.StringIO()
        cli.main(["--synthetic", "orbit"], io.StringIO(text), output)
        return output.getvalue()

    def test_no_args_help_no_evidence_or_input(self):
        class NoRead:
            def readline(self, *_):
                raise AssertionError("stdin accessed")
        with patch.object(r, "bounded_read", side_effect=AssertionError("evidence accessed")):
            output = io.StringIO()
            cli.main([], NoRead(), output)
            self.assertIn("--synthetic", output.getvalue())
            with self.assertRaises(SystemExit) as caught:
                cli.main(["--help"], NoRead(), output)
            self.assertEqual(caught.exception.code, 0)

    def test_eof_quit_original_only(self):
        for text in ("review\n", "review\nquit\n"):
            output = self.run_cli(text)
            tail = output.rsplit("Canceled;", 1)[1]
            self.assertIn("Locally reviewed: False", tail)
            self.assertTrue(output.endswith(r.ORIGINAL + "\n"))
            self.assertNotIn("source sha256", tail)

    def test_unknown_no_echo_or_approval(self):
        output = self.run_cli("review\nsecret-unrecognized-input\n")
        self.assertNotIn("secret-unrecognized-input", output)
        self.assertIn("Unknown command rejected", output)
        self.assertIn("zero evidence", output)

    def test_input_limits_cancel(self):
        for text in ("review\n" + "x" * 1025, "help\n" * 33):
            output = self.run_cli(text)
            self.assertTrue(output.endswith(r.ORIGINAL + "\n"))
            self.assertIn("no approved draft", output)
        self.assertIn("Input command limit reached", self.run_cli("help\n" * 32))

    def test_capability_surface(self):
        # Regression guard, not a security/containment proof.
        for name in ("review.py", "cli.py"):
            source = (Path(__file__).parent / name).read_text()
            for forbidden in ("subprocess", "socket", "urllib", "eval(", "exec(",
                              "clipboard", "scoped_run", "graphify.extract import"):
                if forbidden == "scoped_run" and name == "review.py":
                    continue  # comment explicitly disclaims this dependency
                self.assertNotIn(forbidden, source)


if __name__ == "__main__":
    unittest.main()
