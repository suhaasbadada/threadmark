#!/usr/bin/env python3
"""Bounded local checks, standard library only. Never requires providers or Docker."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent


def run(args, **kwargs):
    subprocess.run(args, cwd=ROOT, check=True, timeout=180, **kwargs)


def docs():
    for path in ROOT.rglob("*.md"):
        if "target" in path.relative_to(ROOT).parts:
            continue
        text = path.read_text()
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if link.startswith(("https://", "http://", "mailto:", "#")):
                continue
            target = unquote(link.split("#")[0])
            if target and not (path.parent / target).is_file():
                raise RuntimeError(f"broken local link: {path.relative_to(ROOT)}: {link}")
    print("local documentation links passed (remote links not fetched)")


def failure_probe():
    # A separate tiny crate proves the actual cargo test process returns failure.
    with tempfile.TemporaryDirectory(prefix="threadmark-test-gate-") as directory:
        root = Path(directory)
        (root / "src").mkdir()
        (root / "Cargo.toml").write_text(
            '[package]\nname="threadmark-gate-probe"\nversion="0.0.0"\nedition="2024"\n'
        )
        (root / "src/lib.rs").write_text('#[test]\nfn intentional_failure() { assert_eq!(1, 2); }\n')
        result = subprocess.run(
            ["cargo", "test", "--offline", "--manifest-path", str(root / "Cargo.toml")],
            cwd=ROOT, capture_output=True, timeout=120,
            env={**os.environ, "CARGO_TARGET_DIR": str(root / "target")},
        )
        output = result.stdout + result.stderr
        if result.returncode != 101 or b"intentional_failure ... FAILED" not in output:
            raise RuntimeError("test gate probe did not fail with the expected assertion")
    print("intentional failing assertion rejected by cargo test")


def main():
    if sys.argv[1:] == ["docs"]:
        docs()
        return
    if sys.argv[1:]:
        raise SystemExit("usage: python3 scripts/check.py [docs]")
    for command in [
        ["cargo", "fmt", "--all", "--check"],
        ["cargo", "build", "--workspace", "--locked"],
        ["cargo", "clippy", "--workspace", "--all-targets", "--locked", "--", "-D", "warnings"],
        ["cargo", "test", "--workspace", "--locked"],
        ["cargo", "doc", "--workspace", "--no-deps", "--locked"],
        ["cargo", "run", "--locked", "-q", "-p", "threadmark-cli", "--", "--version"],
        ["cargo", "run", "--locked", "-q", "-p", "threadmark-cli", "--", "status"],
        ["cargo", "run", "--locked", "-q", "-p", "threadmark-cli", "--", "smoke"],
        ["cargo", "run", "--locked", "-q", "-p", "threadmark-daemon", "--", "--smoke"],
    ]:
        run(command, env={**os.environ, "RUSTDOCFLAGS": "-D warnings"})
    docs()
    failure_probe()


if __name__ == "__main__":
    main()
