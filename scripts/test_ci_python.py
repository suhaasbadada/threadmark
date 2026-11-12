"""Finite selector tests; synthetic cache paths, no installation or network."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import ci_python


class SelectorTests(unittest.TestCase):
    def test_cached_patch_order_and_no_unreviewed_default(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Python"
            for name in ("3.12.9", "3.12.10", "3.15.2", "3.12.beta"):
                (root / name).mkdir(parents=True)
            choices = ci_python.candidates(directory, "/default/python3", (3, 15), lambda _: None)
            self.assertEqual(choices[0], root / "3.12.10/arm64/bin/python3")
            self.assertFalse(any("3.15" in str(p) or "beta" in str(p) for p in choices))
            self.assertNotIn(Path("/default/python3"), choices)

    def test_actual_reviewed_interpreter_and_bounded_clean_probe(self):
        if sys.version_info[:2] != (3, 12):
            self.fail("selector tests require the selected Python 3.12")
        run = Mock(wraps=subprocess.run)
        self.assertEqual(ci_python.select((Path(sys.executable),), run), Path(sys.executable).resolve())
        self.assertEqual(run.call_args.kwargs["timeout"], 5)
        self.assertEqual(set(run.call_args.kwargs["env"]), {"PATH", "LANG"})

    def test_wrong_version_has_no_install_or_fallback(self):
        run = Mock(return_value=subprocess.CompletedProcess([], 0, "3.15\n", ""))
        with self.assertRaisesRegex(ValueError, "no download fallback"):
            ci_python.select((Path(sys.executable),), run)
        run.assert_called_once()

    def test_missing_and_failed_candidates_close(self):
        for failure in (OSError("missing"), subprocess.TimeoutExpired("probe", 5)):
            with self.subTest(failure=type(failure).__name__), self.assertRaises(ValueError):
                ci_python.select((Path(sys.executable),), Mock(side_effect=failure))
        with self.assertRaises(ValueError):
            ci_python.select((Path("/nonexistent-threadmark-python"),))

    def test_ci_output_uses_explicit_interpreter_not_path_override(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "environment"
            with patch.dict(ci_python.os.environ, {"GITHUB_ENV": str(output)}), \
                    patch.object(ci_python, "select", return_value=Path(sys.executable).resolve()):
                ci_python.main()
            self.assertEqual(output.read_text(), "THREADMARK_PYTHON=" + str(Path(sys.executable).resolve()) + "\n")


if __name__ == "__main__":
    unittest.main()
