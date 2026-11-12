# Phase 0 — Foundation evidence

Owner: project maintainer. Scope: TM-01–TM-10, P0-A1–P0-A5.
Status: foundation engineering gates accepted for the tested revision below;
PR merge and any publication remain **unapproved**. No product release exists.
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
| P0-A1 | Passed on `9515e7f87af4710cdc5e2ef3f52ec5ad92e4796c`, run `43180767765`, all three declared CI jobs successful. |
| P0-A2 | Intentional Cargo assertion failed as expected on Linux/macOS; synthetic Gitleaks sentinel detected in security job. Normal checks also passed. |
| P0-A3 | Requirement mapping in development guide; synthetic scope/failure/recovery fixtures, no providers required. |
| P0-A4 | ADR 0001, risk register, MIT license, development and approval rules reviewed by Joffrey; both actionable findings repaired and reproduced checks pass. |
| P0-A5 | README and architecture distinguish implemented checks from planned product; no capability certification claimed. |

## Verification log

- Initial local Clippy correctly failed on missing integration-test crate docs.
  Fixed by documenting each test crate, without disabling the warning.
- Joffrey independently reviewed the staged foundation. Found versionless local
  dependencies blocked by cargo-deny and a Gitleaks probe incorrectly expecting
  the rule ID in console output. Fixed with explicit dependency versions and a
  temporary redacted JSON report checked for the sentinel RuleID. No policy waiver.
- Full tested revisions, local results, independent review and exact-head CI are
  recorded below; no product/runtime gate is inferred from engineering checks.
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

## First remote run — infrastructure blocker repaired

PR: <https://github.com/suhaasbadada/threadmark/pull/1>.
Head: `50ab9748de0f469a8bbaf550bd6fc98d4bb635b7`.
PR CI run: <https://github.com/suhaasbadada/threadmark/actions/runs/43180646494>.
macOS job `131055486101` was canceled before execution with the failure annotation
`The configuration 'macos-14-arm64-us-default' is not supported`. This is not a
passing macOS gate. Changed the declared runner to macos-15 and removed duplicate
feature-branch push runs (PR runs still required; main push checks remain).
Linux and security jobs were in progress when this blocker was diagnosed; this
run is superseded by the repair head, not acceptance evidence for it.

## Exit decision

PR <https://github.com/suhaasbadada/threadmark/pull/1> targets `main` and remained
open, with no GitHub approval or merge, at verification time.
Full tested head: `9515e7f87af4710cdc5e2ef3f52ec5ad92e4796c`.
Exact PR CI run: <https://github.com/suhaasbadada/threadmark/actions/runs/43180767765>.

| Declared job | Job ID | Outcome |
| --- | --- | --- |
| Rust (ubuntu-24.04) | 131056002031 | Success, completed 2026-11-12 08:10:54 UTC |
| Rust (macos-15) | 131056001901 | Success, completed 2026-11-12 08:11:04 UTC |
| Dependencies, licenses and secrets | 131056002224 | Success, completed 2026-11-12 08:13:08 UTC |

Implementation owner accepts P0-A1–P0-A5 engineering evidence for that exact
revision, including independent review and repaired negative gates. This permits
bounded Phase 1 feasibility work in a separately scoped change, not automatic
merge, distribution or host certification. Any later head must pass its own CI;
this historical run must not be cited as proof of a later head's checks.

Planning/foundation checks are not proof of usable product behavior, durable
recovery or supported hosts. Source, docs, runtime, merge and publication
acceptance stay separate. The independent landing-page unit does not depend on
claiming any planned product workflow is implemented.
