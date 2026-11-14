#!/usr/bin/env python3
"""Test the actual app's content-free validation mode; never opens a window."""
import pathlib
import subprocess
import sys
import tempfile

binary = pathlib.Path(sys.argv[1]).resolve(strict=True)
with tempfile.TemporaryDirectory(prefix="threadmark-launch-") as directory:
    store = pathlib.Path(directory) / "store"
    valid = ["--core-binary", str(binary), "--data-dir", str(store)]
    cases = [([], 0), (valid, 0), (["--core-binary", str(binary)], 2),
             (["--data-dir", "relative"], 2), (["--unknown"], 2),
             (valid + valid, 2),
             (["--core-binary", directory, "--data-dir", str(store)], 2)]
    for args, expected in cases:
        result = subprocess.run([str(binary), "--validate-launch-config", *args],
                                capture_output=True, timeout=10, check=False)
        assert result.returncode == expected, (expected, result.returncode)
        assert directory.encode() not in result.stdout + result.stderr
        assert not store.exists(), "Validation must not create storage"
print("PASS: 7 launch validation cases; no core invocation or store creation")
