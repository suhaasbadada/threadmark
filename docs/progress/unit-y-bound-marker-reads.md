# Unit Y — coherent registration-bound suppression marker reads

Requirements: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/A3/A5/A6, P3-A4**.
Specs: [Phase 2](../spec/phase-2-knowledge-core.md),
[Phase 3](../spec/phase-3-background-experience.md).
Contract/acceptance: [suppression-marker read binding v1](../contracts/suppression-marker-read-binding-v1.md),
stable **Y-01–Y-05**. This completes the two marker endpoints excluded from
[V](unit-v-native-bound-human-reads.md), not general project metadata binding.

## Baseline and owned inventory

Clean initial HEAD `661bdb3e11118efe979cc7adf06c39db723bf133`.
Authorized normal `git merge --no-edit 40b2a8a89c71f06d4830291c8c648c7aa749d452`
created merge-only baseline **`265319e5507b9f7cf382b7f6802e7a032104aabd`**,
preserving prepared product contract/site history. Primary must take **only the
owned uncommitted diff**, never replay the baseline/site merge. No reset, branch
switch, new worktree, implementation commit, push or PR.

Owned paths:

- `crates/core/src/knowledge/human_read.rs`: two bound marker APIs sharing the
  reviewed admission/snapshot/fresh-publication helper without new transactions.
- `crates/core/src/knowledge/{forget,source_forget}.rs`: minimal transaction-local
  marker-query factoring; trusted entry points retain signatures/behavior.
- `crates/core/src/knowledge/human_read/tests.rs` (module declaration) and new
  `human_read/tests/marker_tests.rs`: core synthetic boundary/WAL/compat fixtures.
- `crates/daemon/src/knowledge.rs`: typed variants/pre-open validation/existing-only.
- `crates/cli/src/main.rs`: optional closed three-flag marker grammar/help.
- `crates/cli/tests/bound_human_reads.rs` (module declaration) and new
  `bound_human_reads/marker_tests.rs`: actual CLI/daemon fixtures.
- `apps/companion/Sources/CompanionKit/{Contract,ProcessService}.swift`: two new
  immutable-binding operations, exact argv/empty stdin and shared strict decoding.
- `apps/companion/Sources/CompanionKit/CompanionModel.swift`: only marker
  inspections/Forget follow-ups/mutation suppression corroboration and minimal
  extension of the reviewed human-read helper's admitted operation whitelist.
  The marker/Forget-only `sameForgetScope` helper now delegates registration
  comparison to the existing exact-byte human binding, retaining policy equality;
  generic source/Refine/mutation namespace classifiers are unchanged.
  Standalone inspections now preserve human history on failure/cancellation;
  existing inspection replacement error/clearing and Forget uncertainty remain.
- `apps/companion/Sources/CompanionTestProcess/main.swift`: exact bound marker
  argv fixture modes, preserving old trusted modes.
- `apps/companion/Tests/CompanionKitTests/{CompanionTests,ForgetTests,SourceForgetTests}.swift`:
  narrow new-operation fake routing/exhaustiveness, no unbound fake fallback.
- New `apps/companion/Tests/CompanionKitTests/BoundMarkerReadTests.swift`:
  actual-core dispatch races, legacy/failure/cancel/draft and adapter fixtures.
- New versioned contract above, one cross-link in human-read binding v1, this file.

Concurrent X private export actions/state/registry/UI, provider/refine/retained/diff,
site, source LIST/HISTORY/SEARCH, dependencies/lockfiles/schema/envelopes are not
changed. Project inventory/show and trusted operator forms remain outside this
cached marker-read contract. No authentication, source authority, listener, external
revocation lease, forensic erasure, provider quality or phase closure claim.

## Acceptance evidence

- **Y-01:** both public core APIs return `ScopeMismatch` on same-root/new-nonce
  and different-root replacement by a real second SQLite connection, including
  after dropping both marker tables. Thus first marker SQL cannot precede binding.
- **Y-02:** both marker queries execute after peer B commits under WAL, still
  select exactly snapshot A, and the shared fresh-registration publication check
  rejects the result. Fresh trusted inspection proves B actually contains its
  distinct IDs/paths. No B metadata is returned by the bound read.
- **Y-03:** composed/decomposed Unicode root/identity bytes reject independently;
  unchanged output after source-policy/snapshot change and unavailable root proves
  no source binding/lookup (source-access counter zero). Pre-cancel and cancel at
  the post-read boundary return no value. Read-only total-change checks, missing
  dependencies, malformed markers and full 4096/64 counts/overflow reject rather
  than truncate; whole JSON remains within 1 MiB. V2 trusted human markers work;
  bound legacy fails, v3 bound human markers work, source markers still require
  v4. Real CLI legacy fixtures verify user_version remains unchanged on reopen.
- **Y-04:** five new real-process CLI/daemon cases pass: both replacement roots,
  trusted JSON equivalence, Unicode exact bytes, malformed selectors/bindings,
  closed grammar with held empty stdin, absent-store no-create, typed daemon
  preflight/cancel and legacy v2/v3 compatibility. Errors publish no B IDs/paths.
- **Y-05:** new native suite passes eight real-CLI replacement-at-dispatch cases
  after model prechecks (both inspections and both Forget follow-ups, each root
  variant). Peer counters prove one core rejection, zero delivered replacement
  marker replies and zero unbound fallbacks. Committed Forget failures remain
  `forgetUncertain`/`sourceForgetUncertain`; source human history/base/editor and
  unrelated originals remain, while human Forget retains its intentional target
  editor clearing. Two actual-CLI post-commit marker reads held through Cancel
  are never adopted and do not claim rollback. Same-namespace read failure/cancel
  and Unicode precheck rejection retain loaded history/base/editor/original.
  Legacy inspections dispatch no I/O, explain upgrade and have fallback count 0.
  Actual-CLI policy-only changes/missing sources still admit both receipt reads.
  Strict bound subprocess fixture modes verify ordered argv/empty stdin and
  existing malformed/duplicate/order/extra/content/over-count/over-byte rejection.
  Full inherited T/V/Forget suites remain passing, not replaced or disabled.

## Final local verification

Tested full baseline **`265319e5507b9f7cf382b7f6802e7a032104aabd` plus the
owned uncommitted diff**, not the merge SHA alone. SHA-256 of
`git diff --binary HEAD -- . ':!docs/progress/unit-y-bound-marker-reads.md'`:
**`d0ad7980a6f2d62ebd0369d516aa260d4835d7948c866b1f46819910007e8938`**.
This evidence document is excluded to avoid a self-reference. All twenty owned
paths are enumerated above; only the five new files are staged for secret scanning.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, formatting,
  locked build, warnings-denied Clippy, **265 Rust tests/two doctests**, docs,
  smoke, local links and intentional-negative assertion gate.
- `CARGO_NET_OFFLINE=true cargo deny --offline --locked check`: **PASS**,
  advisories/bans/licenses/sources using existing offline policy data, no refresh.
- Rebuilt actual `target/debug/threadmark` and CI's C fixture with SDK-isolated
  `xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc` and explicit resource/SDK
  includes; all ten fixture modes copied under ignored `target/retained-fixtures`.
- Full strict serial Debug: **PASS, 201 tests / 28 suites**, none skipped.
  Command: `sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest
  --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc
  -warnings-as-errors`, with explicit `THREADMARK_CORE_TEST_BINARY` and
  `THREADMARK_RETAINED_FIXTURES` pointing at this checkout's rebuilt artifacts.
- Relevant strict serial Release: **PASS, 143 tests / 16 suites**, same explicit
  environment/wrapper/strict flags plus `--configuration release --filter
  'BoundMarkerReadTests|BoundHumanReadTests|HumanRevisionTests|LiveHumanRevisionTests|ModelTests|AdapterTests|HumanSearchTests|LiveHumanSearchTests|ForgetTests|SourceForgetTests|LiveSourceForgetTests|LiveCoreTests'`.
- `sh apps/companion/scripts/check-retained-api.sh`: **PASS**, ordinary-import
  positive model and negative controller-access compiler gate.
- `python3 scripts/secrets.py` after staging all five owned new files: **PASS**,
  tracked scan and synthetic-negative probe. `git diff --check` and
  `git diff --cached --check`: **PASS**.
- CLI SHA-256: `cfd9ca8f7f96ec4ebc43fd30c46df1765666e57806489783526f6cd2fd963fa8`.
  C fixture SHA-256: `b8e6de85b292c4ae8a0132a76fec5d26c20514f9d93baa51aed9d03d96ba99ed`.

Early development checks found test-only module-path/Clone assumptions, Swift
actor assertion/equality issues and a fake assuming Add returns Project instead
of acknowledgment. These were corrected before final passing gates. The initial
Release build/test invocation exceeded a 120-second tool limit; its interrupted
run is not passing evidence. The complete final strict Release run passed with
a larger command bound. Existing wrapper backend-deprecation warning remains;
no warnings/checks were relaxed. Local logs in the session-approved temporary
directory: `unit-y-check-final.log`, `unit-y-deny-final.log`,
`unit-y-swift-debug-final.log`, `unit-y-swift-release-final.log`, `unit-y-api.log`
and `unit-y-secrets.log`. These are local evidence, not CI.

## Remaining gates and exclusions

Tests use only synthetic fixtures. Independent review and exact integrated-head CI/merge are **not run**;
there is no PR or remote CI run/head/URL for this uncommitted unit. Primary owns
independent review, owned-diff integration and exact CI/merge gates.

No credentials, external egress, live provider, GUI/host launch, deployment,
subagents, Docker, polling, reminders or scheduling. The unchanged production
300-second idle/30-second provider deadline fixtures are **not rerun**; normal
ignored results are separate from the primary's previously reported W evidence.
