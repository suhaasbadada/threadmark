#!/usr/bin/env python3
"""Run Gitleaks on tracked files (including staged/uncommitted changes), redacted."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def scan(directory, config, report):
    return subprocess.run(
        ["gitleaks", "dir", str(directory), "--config", str(config),
         "--redact=100", "--no-banner", "--exit-code=1",
         "--report-format=json", "--report-path", str(report)],
        cwd=ROOT, capture_output=True, timeout=120,
    )


def main():
    config = ROOT / ".gitleaks.toml"
    history = subprocess.run(
        ["gitleaks", "git", str(ROOT), "--config", str(config), "--redact=100",
         "--no-banner", "--log-opts=--all"],
        capture_output=True, timeout=120,
    )
    if history.returncode:
        raise RuntimeError("history secret scan failed; inspect locally with redaction enabled")
    with tempfile.TemporaryDirectory(prefix="threadmark-secrets-") as directory:
        root = Path(directory)
        tree = root / "tracked"
        tree.mkdir()
        files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).split(b"\0")
        for raw in files:
            if not raw:
                continue
            relative = Path(raw.decode())
            source = ROOT / relative
            if source.is_symlink():
                raise RuntimeError("tracked symlinks require explicit scanner review")
            if source.is_file():
                target = tree / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
        result = scan(tree, config, root / "tracked-report.json")
        if result.returncode:
            # Scanner output is deliberately not echoed; even redaction bugs cannot leak values.
            raise RuntimeError("secret scan failed; inspect locally with redaction enabled")
        probe = root / "probe"
        probe.mkdir()
        # Deliberately nonfunctional sentinel, assembled to avoid self-detection.
        (probe / "synthetic.txt").write_text("THREADMARK_" + "SYNTHETIC_SECRET=" + "not-a-real-credential-1234567890\n")
        report = root / "probe-report.json"
        result = scan(probe, config, report)
        findings = json.loads(report.read_text()) if report.is_file() else []
        if result.returncode != 1 or not any(
            finding.get("RuleID") == "threadmark-synthetic" for finding in findings
        ):
            raise RuntimeError("synthetic secret did not trip the scanner gate")
    print("tracked-file secret scan passed; synthetic secret correctly rejected")


if __name__ == "__main__":
    main()
