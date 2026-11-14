# Unit V — native registration-bound human reads

## Publication outcome

PR #72 passed all five required checks on
`40b2a8a89c71f06d4830291c8c648c7aa749d452` (CI `43577023963`, integrated
`43577024014`). Fresh exact-head/main/check/review/approval/discussion/rules
verification found no blocker; merge completed as
`73791de79e0a9c158091dac770a48018556faa31`. The watch was removed after merge.
Separate exact post-merge CI remains unverified. Private-file export and the
remaining marker-receipt binding are independently active; no GUI/AX, live-model
quality, host delivery or phase closure is inferred from merge.

## Primary integration and independent review

Primary committed only the eighteen owned files as `a22cb89` in the completed
lane and applied them without conflicts as
`f0f976c1a7ee126744605cab64aa6cd6ed18c36d`, the exact combined tested runtime.
No baseline/site merges or native export changes were replayed. Joffrey reviewed
the exact fingerprint **CLEAR** and independently passed full strict Debug
(194 tests/27 suites), targeted Debug (136 tests/15 suites), the API compiler
gate and six actual-CLI invented-root rejection checks without content stdout.
He did not rerun Release/full Rust/security gates or rebuild artifacts.

Primary combined full workspace gate (255 Rust/two doctests), strict serial
actual-CLI/C-fixture suite (194 tests/27 suites), ordinary-import model API gate,
dependency policy, staged secrets and whitespace **PASS**. Original lane Release
evidence remains separate from this primary exact integrated Debug pass. Bound
export backend semantics remain unchanged; human reads gain no source authority
and no provider call. Marker-only endpoints remain explicitly excluded below.

PR #71 passed all five checks at
`bbacab839171d144cba8cce4e66ea3d59de7d320` (CI `43575937765`, integrated
`43575937838`); fresh main/exact-head/check/review/approval/discussion/rules gates
preceded merge `914152042f23ec8948cf66306f07605b4229fd4c`. Separate exact post-
merge CI and this unit's publication CI remain later gates. Native explicit
private-file export is independently active. Nine inherited progress edits,
all worktrees and parent reminders remain preserved; GUI/AX/live-quality/host-
delivery/phase closure remain unverified.

Requirements: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/A3/A6, P3-A4**.
Specs: [Phase 2](../spec/phase-2-knowledge-core.md),
[Phase 3](../spec/phase-3-background-experience.md).
Contract: [human-context read binding v1](../contracts/human-context-read-binding-v1.md).
Backend admission evidence remains [Unit U](unit-u-bound-human-reads.md);
editor/CAS semantics remain [Unit T](unit-t-native-human-revision.md).
Neither phase is closed.

## Baseline and ownership

Assigned checkout was clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Authorized normal `git merge --no-edit d7253943fc4ebe1441c30cf7073a65cae327f37a`
created merge-only baseline `9038aefc8a3d1e99602a00fddcda2fdd36a3eb03`, preserving
the prepared product contract and site history. No reset, switch, new worktree,
implementation commit, push or PR. Primary must take **only the owned uncommitted
diff**, not the baseline/site merge history.

Owned inventory:

- `apps/companion/Sources/CompanionKit/Contract.swift`: immutable validated
  `HumanContextReadBinding`, exact UTF-8 equality, three separately named bound
  read operations, human-specific upgrade guidance, byte-exact search scope.
- `apps/companion/Sources/CompanionKit/ProcessService.swift`: closed three-flag
  LIST/HISTORY/SEARCH argv, empty stdin, existing decode/validation/budgets;
  search binding checked at adapter response boundary as well as model adoption.
- `apps/companion/Sources/CompanionKit/CompanionModel.swift`: checked human-read
  helper, exact human namespace checks, initial selection/list, cached refresh,
  open history/search, human mutation/Forget follow-ups and CAS corroboration.
  Existing source/Refine/preparation namespace classifiers remain unchanged.
- `apps/companion/Sources/CompanionTestProcess/main.swift`: exact bound
  list/history argv fixtures only.
- `apps/companion/Tests/CompanionKitTests/BoundHumanReadTests.swift`: new synthetic
  binding/legacy/preservation and real CLI dispatch-race tests.
- Narrow bound-operation fake migrations in `CompanionTests.swift`,
  `BoundSourceReadTests.swift`, `FileEventTests.swift`, `ForgetTests.swift`,
  `HumanRevisionTests.swift`, `HumanSearchTests.swift`, `LiveHumanSearchTests.swift`,
  `LiveSourceForgetTests.swift`, `RankedSourceTests.swift`,
  `RefinementModeModelTests.swift`, `RefinementTests.swift`, `SourceForgetTests.swift`
  under that test directory. Search preservation and exact argv/cancellation
  coverage extended. The queued-Refresh/Quit assertion now checks the exact
  retained pre-refresh project instead of eager `nil`; its no-successor-I/O
  assertion is unchanged. Replacement clearing is checked after authoritative
  mismatch, followed by explicit selection before asserting replacement metadata.
  The Refine Unicode-projection fixture supplies its own synthetic human list:
  its invented root cannot legitimately satisfy a real bound CLI human read.
  Refine's byte-rejection/no-selection assertions remain unchanged.
- This progress file.

## Behavior and evidence

- **P2-A1/A6:** model-targeted reads never dispatch the trusted unbound operations.
  Initial explicit selection may read registration metadata; the context command
  carries that very captured ID/root/identity/incarnation. Cached Refresh binds
  the caller's known namespace rather than clearing it and adopting an ID-only
  replacement. Same-ID/same-root/new-nonce and different-root registrations
  cannot become a new read target implicitly.
- **P2-A1/A6:** actual CLI peer tests replace registration at bound command
  dispatch, after native metadata prechecks. LIST, HISTORY, SEARCH and both CAS
  list/history success-follow-up boundaries reject in the real adapter with a
  generic CLI failure, deliver no B response and have zero unbound fallback
  calls. Native then classifies the current replacement and applies the existing
  namespace-clearing policy. U separately proves admission precedes human SQL
  even when human tables are unavailable; this native unit does not add Rust hooks.
- **P2-A3/P3-A4:** same-namespace read/refresh/search failure retains loaded
  history, the captured editor base, editor revision and unrelated original.
  No automatic history rebase or editor replacement. Existing owned-worker
  cancellation/join, successor fencing and late-adoption guards remain active.
  Existing CAS peer-conflict and post-commit uncertainty assertions remain enabled.
  Successful explicit Refresh retains its pre-existing editor/request reset,
  deferred until success rather than performed before a possibly failing read.
- **P2-A6:** malformed/missing nonce/identity cannot construct a read binding.
  Legacy explicit selection is metadata-only with no LIST/HISTORY/SEARCH spawn;
  targeted legacy reads dispatch no service I/O. Upgrade guidance is explicit,
  not an upgrade, permission repair or fallback. UTF-8 comparison distinguishes
  canonically equivalent Swift strings without filesystem normalization.
- **P3-A4:** real CLI valid creation, history, search, update, retirement and
  explicit refresh retain existing semantics. A peer source-policy-only change
  plus deletion of the synthetic source does not invalidate human history or
  bind it to source files. Existing uncertainty gates are not relaxed: dirty
  local source policy and unresolved mutation/Forget still gate UI actions.
  Binding has no source-policy/snapshot fields, file lookup or provider call.
- Existing response validation, limits, retired revisions, active-latest search,
  Forget suppression, search provenance and authority disclosures are retained.
  Adapter tests check exact three-flag argv and empty stdin, bounded search
  responses, timeout/cancellation teardown and clean child environment.

## Explicit remaining boundaries

`context forgotten` and `source forgotten` are non-content marker inspection
endpoints, not U targets. Their existing pre/post metadata checks and uncertainty
semantics remain; they do **not** gain pre-marker SQL registration admission.
Trusted unbound operator API/CLI forms remain available for explicit operator
tests and are not claimed migrated or secure as cached reads. Writes retain
their existing namespace/revision contracts. No blanket “all APIs bound” claim.

Current-at-read registration rechecking is not an external revocation lease;
native cancellation and late-adoption guards remain necessary. Human data is
untrusted context, not source truth or permission. No source evidence/refinement,
retained adapter, provider profile/Consent, diff, indexing, Rust, schema,
dependency, lockfile or site implementation changes are owned here. The ordinary
import negative API compiler gate and explicit Swift 6.1 picker closures remain.

## Verification and handoff

Final commands/results, artifact hashes and diff fingerprint are recorded below.
The tested revision is baseline plus the owned uncommitted diff, not the merge
SHA alone. Primary independent review/integration and exact integrated-head CI
are **not run**; there is no remote run URL/head for this unit. No GUI/AX/live
quality, host delivery, phase completion or deployment is claimed. No external
egress, live provider, credentials, GUI permissions, host launch, Docker,
subagents, implementation commit, push, PR, scheduling or polling was used.

### Final local verification record

Tested full baseline: `9038aefc8a3d1e99602a00fddcda2fdd36a3eb03`, **plus** the
owned uncommitted implementation above. SHA-256 of
`git diff --binary HEAD -- apps/companion`:
`94cc57fb2637ad6bd8f8d7e6a90379b410452d4d3b62b9f20dff877eaf702a7b`.
This evidence file is outside that fingerprint to avoid a self-reference.
Only the two owned new files were staged for secret scanning; all changes remain
uncommitted and the task worktree is left intact.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, final run after
  adding the progress document. Formatting, locked build, warnings-denied Clippy,
  workspace tests/doctests, documentation, smoke, links and intentional-negative
  gates pass: 247 Rust tests plus two doctests. Two inherited production-duration
  deadline tests remain ignored (300-second idle and 30-second provider deadline).
  No Rust implementation was changed. CLI was rebuilt by this gate.
- `CARGO_NET_OFFLINE=true cargo deny --offline --locked check`: **PASS**,
  advisories/bans/licenses/sources, using existing offline policy data, no refresh.
- Rebuilt C fixtures with CI's SDK-isolated `xcrun clang -std=c11 -Wall -Wextra
  -Werror -nostdinc` command and copied all ten fixture modes under ignored
  `target/retained-fixtures`.
- Full strict serial Debug: **PASS**, **194 tests / 27 suites**, no suites skipped.
  Explicit `THREADMARK_CORE_TEST_BINARY` and `THREADMARK_RETAINED_FIXTURES` point
  at this checkout's rebuilt CLI/C fixtures. Command:
  `sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`.
- `sh apps/companion/scripts/check-retained-api.sh`: **PASS**, public-model
  positive compilation and ordinary-import negative controller-access compilation.
- Relevant strict serial Release: **PASS**, **136 tests / 15 suites**, same
  explicit CLI/C-fixture environment and wrapper/strict flags, adding
  `--configuration release --filter 'BoundHumanReadTests|HumanRevisionTests|LiveHumanRevisionTests|ModelTests|AdapterTests|HumanSearchTests|LiveHumanSearchTests|ForgetTests|SourceForgetTests|LiveSourceForgetTests|LiveCoreTests'`.
- Strict wrapper `build --product ThreadmarkCompanion`: **PASS**, built only,
  never launched. The wrapper's existing native-build-backend deprecation warning
  remains; no compiler warnings or checks were relaxed.
- `python3 scripts/secrets.py` after staging owned new files: **PASS**, tracked
  scan and synthetic-negative probe. Whitespace gates `git diff --check` and
  `git diff --cached --check`: **PASS**.
- Tested CLI SHA-256:
  `9e48ab6ef12fabd0aeb000d885d62cdffc709dd8f65172a5f201b7d5cd60c37a`.
  C fixture SHA-256:
  `b8e6de85b292c4ae8a0132a76fec5d26c20514f9d93baa51aed9d03d96ba99ed`.

Earlier development runs exposed incomplete fake bound-operation routing, an
invented-root Refine fixture incompatible with real bound LIST, and assumptions
that Refresh eagerly discarded state. These were repaired before the passing
full Debug run. No failed development run is represented as passing. Synthetic
test-local filesystem fixtures and inherited mock-provider loopback checks are
not GUI permissions, real credentials, external egress or live-provider quality.

Local logs are in the session's approved temporary directory, named
`unit-v-check-final.log`, `unit-v-deny.log`, `unit-v-secrets-final.log`,
`unit-v-swift-debug-final-pass.log`, `unit-v-swift-release.log` and
`unit-v-app-build.log`. These are local
evidence, not CI. Primary owns independent review, owned-diff integration and
exact integrated commit/head/CI recording before any separately authorized
publication. Baseline/site merge commits must not be replayed as V's owned diff.
