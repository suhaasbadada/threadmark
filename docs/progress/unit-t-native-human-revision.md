# Unit T — native human expected-revision editing and retirement

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5/P3-A4.
Contract: [human expected revision v1](../contracts/human-context-revision-v1.md).
Specs: [Phase 2](../spec/phase-2-knowledge-core.md),
[Phase 3](../spec/phase-3-background-experience.md). Both phases remain open.

## Baseline and ownership

- Assigned task worktree reused; no reset, branch switch, or new worktree.
- Clean initial HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133` (prepared
  contract history, retaining site history).
- Required backend base: `a44df02e2a60c67dfb5e6d6be70c99a374a54617`.
- Authorized normal `git merge --no-edit` produced merge-only baseline/tested
  HEAD `be788e7de7407317246ecdce717de8c014c4d6c6` with those two parents.
  Implementation remains uncommitted; that SHA alone does not identify the
  implementation. No implementation commit, push, PR, review, remote CI, merge
  to a target branch, release or deployment was performed.
- Implementation fingerprint: SHA-256 of
  `git diff --no-ext-diff HEAD -- apps/companion` (includes staged new test file):
  `29bdcc28d55365529d1a1443d60f3ed77347f298c3e9ed5066cfe4406f1483f9`.
  This progress record is deliberately outside that fingerprint's path scope.

Owned inventory:

- `apps/companion/Sources/CompanionKit/Contract.swift`: validated immutable
  `HumanContextRevisionBinding`, strict loaded-history validation, two separate
  CAS operations, actionable `contextConflict` error.
- `apps/companion/Sources/CompanionKit/ProcessService.swift`: exact four-flag
  Update/Retire argv, bounded stdin-only update text, validation before spawn,
  bounded and checked existing receipt shapes. Legacy trusted forms unchanged.
- `apps/companion/Sources/CompanionKit/CompanionModel.swift`: only human-history
  capture/open and write/retire/mutate methods. No refinement/preparation edits.
- `apps/companion/Sources/ThreadmarkCompanion/main.swift`: only `ContextView`
  human-pane state/actions; no provider/refinement UI changes.
- `apps/companion/Sources/CompanionTestProcess/main.swift`: narrow exact-argv CAS
  fixture modes; no production discovery path.
- `apps/companion/Tests/CompanionKitTests/HumanRevisionTests.swift` (new):
  malformed/legacy metadata, cancellation/late-commit/successor fencing,
  post-commit read uncertainty, actual CLI peer races, restart and history limit.
- `CompanionTests.swift`: CAS-aware fake checks, loaded-base/no-I/O guards,
  preservation and exact transport tests; existing replacement/history assertions
  retained, existing update calls now explicitly capture a revision.
- `HumanSearchTests.swift`: replace an impossible empty-history fake response
  with a valid synthetic revision, preserving the existing assertions.
- `LiveHumanSearchTests.swift`: capture update base and explicitly inspect
  history before retirement after a search.
- `LiveSourceForgetTests.swift`: existing replacement test now dispatches the
  native CAS update using its old loaded base; assertions unchanged.
- `apps/companion/README.md` and this progress record: behavior/evidence only.

Test-file paths above are under `apps/companion/Tests/CompanionKitTests/`.
Rust/backend, schema, dependencies, lockfiles, provider/Consent, retained adapters,
diff implementation, refinement files/methods, and site are unchanged relative
to the merge baseline. Primary owns same-file integration with concurrent R work.

## Behavior and acceptance evidence

- P2-A1/P3-A4: Update requires the editor's exact captured binding to match loaded
  history for the current note/namespace. Retire requires matching loaded history.
  Missing incarnation, empty/non-contiguous/out-of-budget history, malformed kind,
  NUL/oversized text and mismatched editor bases fail closed, with no legacy-write
  fallback. Add still uses namespace-bound creation, never revision zero.
- Core performs the comparison/append atomically; native does not precheck and
  then send an old unbound write. Actual separate CLI processes compete for one
  captured revision: exactly one Update/Retire succeeds, yielding two revisions.
- Actual CLI peer Update, Retire and Forget after capture reject both stale native
  Update and Retire. Peer content/status stays intact; Forget suppression prevents
  recreation. Loaded history, original request and editor revision remain intact.
  Existing real-CLI same-ID registration-replacement tests retain their clearing
  assertions and now exercise CAS for native Update/Retire.
- P2-A3: owned cancellation joins late writes before successor I/O. A canceled
  writer cannot adopt late history. The explicit successor reload can adopt actual
  history only after namespace checks. Same-namespace failures preserve history;
  namespace replacement retains existing clearing policy.
- Receipt, cancellation, timeout and post-commit read failures remain uncertain,
  never proof that a write had no effect. Generic CLI failures are classified as
  a history conflict only with corroborating later revision/suppression metadata
  and namespace validation. That status still makes no rollback guarantee.
- A success receipt without advanced, validated actual history is not confirmed
  success; it remains uncertain and retains the captured history.
- P2-A5/P3-A4 partial: fresh Update and Retire append once; replay fails. Restart,
  rebuild and a source-policy-only change preserve human history. All 32 revisions
  are exercised through actual guarded writes; Update and Retire at the limit
  fail without appending. Existing real source-Forget preservation tests also run.
- Human-pane Inspect/Reload no longer replaces the unsaved editor or advances its
  edit base. Edit explicitly labels replacement of the editor. Failed retirement
  does not exit editing or discard text. Success does not silently rebase an editor.

## Local verification (2026-11-13)

All fixtures synthetic; no GUI/app/host launch, external egress, credentials,
Docker, host permissions/global configuration changes, source modifications
outside owned fixtures, or subagents. Existing tests' fixture-local permission
and local mock-provider exercises remain enabled.

- `python3 scripts/check.py`: PASS (format, clippy, workspace tests/doc tests,
  documentation, smoke and intentional-negative gates; 239 passing Rust/doc-test
  results in the log, including the existing CAS backend tests). CLI rebuilt.
- `cargo deny --locked check`: PASS, advisories/bans/licenses/sources.
- Rebuilt retained C fixtures using the documented SDK-isolated `xcrun clang`
  command with `-std=c11 -Wall -Wextra -Werror`; all ten fixture mode copies made
  under ignored `target/retained-fixtures`.
- Full serial Debug Swift: PASS, **179 tests / 25 suites**, no skipped suites;
  real CLI and C fixture environment variables explicitly set. Command:
  `sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`.
- `sh apps/companion/scripts/check-retained-api.sh`: PASS, positive public API
  compilation and negative direct-controller compilation gate.
- Relevant serial Release Swift: PASS, **85 tests / 8 suites**, same explicit
  CLI/C-fixture environment and strict flags, adding `--configuration release`
  and `--filter 'HumanRevisionTests|LiveHumanRevisionTests|ModelTests|AdapterTests|LiveHumanSearchTests|LiveSourceForgetTests'`.
- Strict wrapper `build --product ThreadmarkCompanion` with the same compiler
  flags: PASS; built only, never launched. The wrapper's existing native-backend
  deprecation warning remains; no compiler warnings were relaxed.
- `python3 scripts/secrets.py`: PASS after staging the two new files, including
  tracked working-tree/history scans and the synthetic-negative scanner gate.
- `git diff --check` and `git diff --cached --check`: PASS.
- Tested CLI `target/debug/threadmark` SHA-256:
  `d0ced208ef17e73a3ed9dab283a16a0c86c98429919a33c2b370f9175fd3a6c5`.
- Retained C fixture SHA-256:
  `b8e6de85b292c4ae8a0132a76fec5d26c20514f9d93baa51aed9d03d96ba99ed`.

Local harness logs: `unit-t-check-final.log`, `unit-t-deny.log`,
`unit-t-swift-debug-final.log`, `unit-t-swift-release.log`,
`unit-t-app-build.log` in the session's approved temporary directory. These are
local evidence, not a CI run. Remote CI URL/head and independent review: not run;
primary integration gates remain outstanding.

Initial development runs exposed an impossible empty-history fake, callers that
needed explicit edit-base capture, and a cancellation event-count expectation
(one canceled writer's namespace probe plus two successor probes). Fixtures and
expectations were corrected without removing or weakening existing assertions.
Final full Debug above passed after those corrections.

## Exclusions and handoff gates

No semantic conflict resolution, conflict links, newest-rule arbitration,
background companion completion, inference, host delivery, certified host/OS
support, forensic erasure, phase closure, or GUI/assistive-technology verification
is claimed. GUI/AX remains unverified. Editor preservation is covered at the
model/state boundary plus source-isolated human-pane action changes, not a GUI
walkthrough. Primary owns independent review, integration, exact final commit/CI
head recording, and any authorized later publication or merge.
