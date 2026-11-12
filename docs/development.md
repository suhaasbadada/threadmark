# Reproducible development

Traceability: Phase 0, TM-01–TM-10, P0-A1/P0-A2/P0-A3/P0-A4.

## Requirements and checks

Rustup, Git, Python 3.11+; Rust is pinned to 1.97.1 with rustfmt/Clippy.
Development targets: macOS (Apple Silicon) and Linux x86_64. CI declares
macos-15 and ubuntu-24.04 checks, not released end-user platform support.
No Docker, model download, provider login or private repository is needed.

```sh
rustup toolchain install 1.97.1 --profile minimal --component rustfmt --component clippy
cargo build --workspace --locked
python3 scripts/check.py
cargo install cargo-deny --version 0.20.2 --locked
cargo deny --locked check
# Install Gitleaks 8.30.1 from its upstream checksum-verified distribution.
# Stage new files first: the scanner covers tracked working files plus Git history.
python3 scripts/secrets.py
```

`check.py` bounds each subprocess (180 seconds; negative test 120), executes fmt,
Clippy with warnings denied, unit/integration/doc tests, rustdoc, four CLI/daemon
smokes, local Markdown links and a separate intentional failing assertion. It
does not rewrite the worktree. CI also has job-level timeouts and least-privilege
read-only repository access. Security tooling installation/advisory fetch requires
network; runtime diagnostics/tests do not. Scanner output is captured, not echoed.
The synthetic sentinel is nonfunctional and generated outside the repository.

## Contract and release rules

`CONTRACT_VERSION=1` covers the Rust metadata contract, not a stable public wire
API. No IPC or storage schema exists, so there is no migration to run. Future
incompatible formats must bump version, reject unknown versions and document
migration/recovery before use. Use SemVer for eventual releases; 0.x is unstable.

Diagnostics use fixed metadata only, never source, prompts, credential values or
caller-provided IDs. Do not add verbose content logging as a debugging shortcut.
No auto-start, host install, credentials, analytics or network defaults are enabled.

Use PRs, record tested full SHA and exact-head CI run, review risk proportionately,
and resolve failed jobs rather than waive/retry blindly. Merge requires fresh owner
authorization. Packaging, Pages publication, binaries and deployment each require
the appropriate separate approval; no workflow in foundation publishes anything.

Rollback foundation changes with a reviewed revert PR, not a reset of user work.
No application data currently exists. Future schema changes need backups,
forward/backward compatibility decisions, and a tested restore path before rollout.

## Requirement traceability

All requirements share P0-A1–P0-A5 engineering gates; behavior remains planned:

| Requirement | Primary planned acceptance |
| --- | --- |
| TM-01 project management | P2-A1, P3-A1 |
| TM-02 backed understanding | P1-A1, P2-A4 |
| TM-03 editable/forgettable context | P2-A3, P2-A5, P3-A4 |
| TM-04 bounded context | P2-A4, P2-A6, P4-A2 |
| TM-05 intent preservation | P4-A1 |
| TM-06 failure guidance | P4-A5 |
| TM-07 evidence distinctions | P2-A4, P4-A2, P4-A5 |
| TM-08 honest integrations | P1-A2, P5-A1 |
| TM-09 continuity | P6-A2, P6-A3 |
| TM-10 human control | P1-A3, P4-A4, P5-A2 |

See the [spec index](spec/README.md) for the authoritative acceptance wording;
mapping a requirement is not evidence that its acceptance passed.
