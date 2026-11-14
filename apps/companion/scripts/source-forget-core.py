#!/usr/bin/env python3
"""Explicit synthetic CLI acceptance: suppression/export and unbound-repeat limits.

TM-01–04/07/10; bounded P2-A1/A3/A5 and P3-A4 evidence, not GUI acceptance.
No discovery, user stores, network, credentials, schema upgrade or source cleanup.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    binary = parser.parse_args().binary.resolve(strict=True)
    scratch = Path(tempfile.gettempdir()).resolve() / "opencode"
    with tempfile.TemporaryDirectory(prefix="threadmark-source-cli-", dir=scratch) as directory:
        base = Path(directory)
        alpha, beta = base / "alpha", base / "beta"
        alpha.mkdir(); beta.mkdir()
        forgotten = b"fn synthetic_forgotten_export_unique() {}\n"
        remaining = b"fn synthetic_remaining_export_unique() {}\n"
        other = b"fn synthetic_other_export_unique() {}\n"
        (alpha / "a.rs").write_bytes(forgotten)
        (alpha / "b.rs").write_bytes(remaining)
        (beta / "a.rs").write_bytes(other)

        def call(*args, input=None, fail=False):
            result = subprocess.run(
                [str(binary), "--data-dir", str(base / "store"), *args],
                input=input, capture_output=True, timeout=30,
                env={"LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"},
            )
            # Do not echo private diagnostic/body data, even on failure.
            if fail:
                assert result.returncode != 0, "expected scope rejection"
                return None
            assert result.returncode == 0, "synthetic core operation failed"
            assert len(result.stdout) <= 1_048_576, "unbounded response"
            return json.loads(result.stdout)

        def binding(project):
            return ["--expected-root", project["root"], "--expected-root-identity", project["root_identity"],
                    "--expected-incarnation", project["incarnation"], "--expected-sources", *project["sources"]]

        call("project", "add", "alpha", str(alpha), "a.rs", "b.rs")
        call("project", "add", "beta", str(beta), "a.rs")
        call("index", "alpha"); call("index", "beta")
        call("context", "add", "alpha", "memo", "note", input=b"Synthetic original human note")
        call("context", "update", "alpha", "memo", "decision", input=b"Synthetic retained human revision")
        human = call("context", "show", "alpha", "memo")
        beta_before = call("project", "export", "beta", "--confirm-export-local-content")
        captured = call("project", "show", "alpha")
        receipt = call("source", "forget", "alpha", "a.rs", "--confirm-forget-source", *binding(captured))
        assert set(receipt) == {"project", "path", "forgotten", "source_authorization", "snapshot", "human_context", "retention_limits"}
        assert receipt["snapshot"] == "invalidated" and receipt["source_authorization"] == "revoked"
        current = call("project", "show", "alpha")
        assert current["sources"] == ["b.rs"] and current["snapshot"] is None
        assert call("source", "forgotten", "alpha") == {"project": "alpha", "forgotten": [{"path": "a.rs"}]}
        call("index", "alpha")
        rebuilt = call("project", "show", "alpha")
        assert rebuilt["snapshot"] is not None
        call("source", "forget", "alpha", "a.rs", "--confirm-forget-source", *binding(captured), fail=True)
        assert call("project", "show", "alpha") == rebuilt
        # This is operator-only CLI behavior, deliberately NOT exposed by native API.
        repeat = call("source", "forget", "alpha", "a.rs", "--confirm-forget-source")
        assert repeat["snapshot"] == "unchanged"
        assert call("project", "show", "alpha") == rebuilt
        assert call("query", "alpha", "synthetic_forgotten_export_unique")["results"] == []
        assert call("query", "alpha", "synthetic_remaining_export_unique")["results"]
        preview = call("context", "prepare", "alpha", "synthetic_forgotten_export_unique", input=b"Synthetic unrelated request")
        assert "fn synthetic_forgotten_export_unique()" not in preview["proposed"]
        exported = call("project", "export", "alpha", "--confirm-export-local-content")
        assert "fn synthetic_forgotten_export_unique()" not in json.dumps(exported)
        call("project", "sources", "alpha", "a.rs", "b.rs", fail=True)
        assert call("context", "show", "alpha", "memo") == human
        assert call("project", "export", "beta", "--confirm-export-local-content") == beta_before
        assert (alpha / "a.rs").read_bytes() == forgotten
        assert (alpha / "b.rs").read_bytes() == remaining
        assert (beta / "a.rs").read_bytes() == other
    print("synthetic source Forget CLI acceptance passed; export suppression, preserved rebuild on operator repeat, files/human history/other project intact; fixture removed")


if __name__ == "__main__":
    main()
