# Unit P — Immutable native ranked inference boundary

**TM-04–TM-07, TM-10; partial P4-A1–A4, inherited P2-A1/A2/A6.**
Adapter/consent support only, not mounted selection or GUI acceptance. All fixtures
are synthetic; provider tests contact only a test-owned ephemeral numeric-loopback
peer. No semantic-retrieval, inference-quality, host-delivery or phase-close claim.

## Baseline and owned inventory

- Assigned clean HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required local base: `770b3bd68a055dfce2e2206972c34081ed7609bb`.
- Authorized normal `git merge --no-edit` produced merge-only tested HEAD
  `21dcb7b594bdc8dccd77ed9ed8dde7a325250a5d`, with those two parents in that
  order. Independent assigned contract/site history is preserved. No reset,
  branch switch, new worktree or implementation commit.
- Implementation is **staged, uncommitted** at that HEAD. Coordinator must take
  only the owned diff, not replay this prerequisite merge or unrelated history.
- Runtime/test fingerprint: SHA-256 of `git diff --cached -- apps/companion`:
  `225f397ec26bbd4a1880f877b8e8b0059176bb55fe5d2fbd76c3a93842a8674e`.
  Six files, 357 additions / 8 deletions; this evidence document is excluded from
  that fingerprint.

Owned files:

1. `apps/companion/Sources/CompanionKit/RefinementConsent.swift`
2. `apps/companion/Sources/CompanionKit/RetainedReviewController.swift`
3. `apps/companion/Sources/CompanionKit/RetainedReviewProcess.swift`
4. `apps/companion/Sources/CompanionKit/RetainedReviewProtocol.swift`
5. `apps/companion/Sources/CompanionKit/ProcessService.swift` (one argv line only)
6. `apps/companion/Tests/CompanionKitTests/RankedRefinementTests.swift` (new)
7. This progress document (new).

## Implementation contract

- Consent and full retained binding expose immutable `retrievalMode`, using the
  existing `SourceRetrievalMode`; both old initializer shapes default to literal.
  No Query/Context mode implicitly selects Refine mode. No common model, view,
  app, existing test or source-mode enum change; concurrent Unit O remains owner
  of literal mounting and coordinator owns later explicit selection capture.
- Ranked consent validates query byte/control/whitespace/term bounds, per-scalar
  Unicode lowercase and byte-exact deduplication before store access/spawn. It
  requires exact ordered terms, ranked selection/coverage and truncation metadata.
  Literal rejects a ranked selection. Existing provider/settings/root/identity/
  incarnation/snapshot/source/currentness/producer/evidence count/8192-byte gates
  remain, with explicit source policy and 1024-byte evidence-text checks.
- Full binding equality now compares original/query UTF-8 exactly, along with
  mode, project, settings and all generations. Changing a synchronized binding
  retires its consent ID even before a child starts; changing mode back cannot
  restore the same permission. Previously consumed IDs cannot restart inference.
- `--terms` is appended only after consent validation, for retained review and
  finite preview. No fallback/retry. Original remains private stdin data. Retained
  DTO validates Rust's ranked coverage disclosure; no new retained wire fields.
- Finite preview also validates the existing CLI's explicit ranked mode and
  closed, exact selected-evidence envelope, including IDs/anchors/text/hash/
  producer/kind/currentness/coverage. Missing mode/evidence or unknown fields fail
  closed. Existing literal wire and preview DTO initializer shape are unchanged.
- Preserved the CI repair's internal `didSpawn` observer and sole POSIX I/O
  worker/reaper. No lifecycle, provider transport, Rust, schema, dependency or
  generated lockfile changes. Existing core bound-query/currentness/edit/approval
  checks remain authoritative; native IDs are equality guards, not credentials.

## Acceptance evidence

Three dedicated Swift tests (multiple cases each) plus the full inherited suite:

| Partial gate | Executed evidence |
| --- | --- |
| P4-A1/A2 | Actual rebuilt CLI/SQLite: literal phrase `synthetic blue` selects nothing; explicit ranked consent selects the inspected anchor. Owned HTTP receives byte-exact negation/Unicode/action-looking original and exact evidence path/text/hash/producer. No input or edit plaintext appears in store files. |
| P4-A3/A4 | Ranked edit advances revision/digest; stale action rejects, fresh action returns byte-exact edited Rust value. Questions survive edit and block prepared use. Actual cancellation joins/reaps; stale evidence before inference contacts no provider and after edit blocks explicit original. All spawned test PIDs are checked reaped. |
| P4-A3/A4 | Ranked/literal selection mismatch, invalid terms, stale snapshot/currentness, missing/wrong selection metadata reject. Full binding checks mode, byte-different canonically equivalent original, query, settings and generations. Mode change-back, invalidation-before-start and consumed consent replay cannot start a child. |
| P4-A2/A3 | Actual finite preview with ranked consent returns ready (not literal empty evidence) and validates ranked coverage/evidence. Tampered/missing mode, wrong evidence and unknown keys reject. Legacy literal constructors and full inherited literal tests pass. |
| Inherited boundaries | Actual-CLI retained literal/root/namespace/provider-failure checks, hostile C framing/EOF/deadline/queue/deinit/reaping, bounded query/context/currentness, and Rust ranked consent/challenge replay tests pass in the full gates. No duplicate implementation of those core contracts. |

## Actual local checks

- `cargo build --offline --locked -p threadmark-cli`: **PASS**, actual rebuilt CLI.
- Rebuilt hostile C fixtures using documented command-local SDK isolation:
  `-nostdinc`, Clang resource includes, SDK system includes and `-isysroot`.
  No system header/configuration changes.
- Documented `apps/companion/scripts/swift.sh` wrapper with actual CLI and hostile
  fixtures enabled, strict complete-concurrency and warnings-as-errors:
  **debug `--no-parallel` PASS, 152 tests / 20 suites**;
  **release `--no-parallel` PASS, 152 tests / 20 suites**.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, 224 Rust tests and
  two doctests, format/locked build/strict Clippy/rustdoc, finite diagnostics,
  local documentation links and intentional failing-test rejection.
- `cargo deny --offline --locked check`: **PASS**, cached policy/advisory data;
  no online advisory refresh.
- `python3 scripts/secrets.py` after staging all owned new files: **PASS**,
  tracked file/history scan and synthetic secret rejection.
- `git diff --check` and `git diff --cached --check`: **PASS**.

The initial new test compile caught a fixture initialization capture; corrected.
Its first HTTP response omitted required Content-Type; corrected the fixture.
The next finite-preview case exposed ranked-only CLI response fields; implemented
closed validation rather than discarding them or downgrading. Final suites pass.
The first combined debug/release shell hit its 120-second tool deadline during
release compilation (debug had passed); verified no surviving build/test child,
then reran release with a sufficient bounded allowance and it passed. SwiftPM's
existing native-build-system/deployment-target warnings remain tooling warnings;
Swift source warnings are errors. No plain Swift command was used.

Ignored task-owned logs: `target/unit-p-swift-targeted.log`,
`target/unit-p-swift-debug.log`, `target/unit-p-swift-release.log`,
`target/unit-p-check.log`, `target/unit-p-deny.log`, `target/unit-p-secrets.log`.
Fixtures stop/join and remove their synthetic stores; no test process or socket
is retained. Ignored compiled binaries remain in the worktree.

## Exclusions and remaining gates

Exact remote CI run/head, independent review, integration and common-model/UI
selection mounting: **NOT RUN / coordinator-owned**. No push, PR, commit of
implementation, host launch, GUI/permissions, real provider, credentials, private
egress, listener, deployment, subagent, Docker or worktree cleanup. Two inherited
production-duration Rust timeout tests (300-second idle and 30-second provider)
remain intentionally ignored; their paths/budgets are unchanged, and short native
deadline/cancellation/hostile-child coverage passes. No inferred quality or
phase closure. Plum thread lookup returned `thread_not_found`; no coordination
message, watcher, scheduled follow-up or automatic title-change claim.
