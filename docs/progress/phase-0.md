# Phase 0 — Foundation evidence

Owner: project maintainer. Scope: TM-01–TM-10, P0-A1–P0-A5.
Status: implementation under verification; phase remains **open**.
Base revision: `f4d05ee474d055fb8345c831a733ebd4f5dd1f64`.

## Implemented scope

Three safe-Rust crates, pinned toolchain/lockfile, finite offline diagnostics,
scope/worker metadata checks, dependency injection ports and synthetic contract
tests. No resident service, storage, retrieval, inference, shell, host integration,
installer or background processing. Landing page is a separate PR; not part of
this runtime foundation. No merge or production publication is authorized.

CI declares Linux/macOS format, lint, test, doctest, rustdoc, bounded smoke,
negative assertion probe, Markdown links, RustSec/license/source checks and
Gitleaks history/tracked-file scans with an intentional synthetic failure probe.

## Acceptance ledger

| ID | Evidence / current limit |
| --- | --- |
| P0-A1 | Pending exact-head remote CI. Local tests alone do not satisfy it. |
| P0-A2 | Cargo failing assertion and synthetic scanner sentinel probes implemented; results to be recorded after execution. |
| P0-A3 | Requirement mapping in development guide; synthetic scope/failure/recovery fixtures, no providers required. |
| P0-A4 | ADR 0001, risk register, MIT license, development and approval rules. Independent review pending. |
| P0-A5 | README and architecture distinguish implemented checks from planned product; no capability certification claimed. |

## Verification log

- Initial local Clippy correctly failed on missing integration-test crate docs.
  Fixed by documenting each test crate, without disabling the warning.
- Joffrey independently reviewed the staged foundation. Found versionless local
  dependencies blocked by cargo-deny and a Gitleaks probe incorrectly expecting
  the rule ID in console output. Fixed with explicit dependency versions and a
  temporary redacted JSON report checked for the sentinel RuleID. No policy waiver.
- Full tested revision, local final results, independent review and exact-head CI
  run will be recorded in a follow-up evidence entry. No gate is predeclared green.
- Local macOS Apple Silicon / Rust 1.97.1: format, Clippy, 2 unit tests,
  8 integration tests, 1 doctest, rustdoc, CLI/daemon finite smokes, local links and
  intentional assertion failure passed. cargo-deny 0.20.2 advisory/bans/licenses/
  sources checks and Gitleaks 8.30.1 history/tracked-file/negative probe passed
  after the above repairs.
- Committed code revision `07029c02edb81e9b5f1ccf52c5bf5f6176d7069f`:
  `python3 scripts/check.py`, `python3 scripts/secrets.py`, and
  `cargo deny --locked check` all rerun successfully on macOS Apple Silicon,
  Rust 1.97.1, Python 3.12.6. This includes 2 unit tests, 8 integration tests,
  1 doctest, warning-denied lint/docs, build, all diagnostics and both negative
  probes. Independent review: Joffrey; both actionable findings repaired and
  reproduced checks pass. No runtime or host certification follows from this.

## Exit decision

**No-go for Phase 1 execution until P0 checks and review evidence are accepted.**
Planning/foundation checks are not proof of usable product behavior, durable
recovery or supported hosts. Source, docs and runtime acceptance stay separate.
