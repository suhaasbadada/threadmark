# Unit R — explicit mounted Refine retrieval mode

## PR #68 Swift 6.1.2 compiler repair

Required CI [43572609882](https://github.com/suhaasbadada/threadmark/actions/runs/43572609882),
macOS job [132380032306](https://github.com/suhaasbadada/threadmark/actions/runs/43572609882/job/132380032306),
failed at `20e0512f5abeffdd15d89809fb1f5f42c8c55a12` before tests ran. Swift
6.1.2 crashed during IR generation for `RefinementPreviewView.swift`, reporting
SmallVector capacity overflow. The named SIL function demangles to an isolated
Sendable `SourceRetrievalMode` callback reabstraction thunk, matching the new
picker's direct actor-isolated setter method reference.

Exact tested correction `491a83dc28458f80813536cb69b824bb5dad0bdd` replaces only
that method reference with an explicit closure, matching the existing working
Source Query/Context picker pattern. Selection still calls the same model setter;
generation invalidation, cancel/join, consent and default mode are unchanged.
No compiler flag, concurrency warning, test or validation gate is weakened.

Primary complete strict serial actual-CLI/C-fixture suite **PASS**, 177 tests/24
suites; ordinary-import model API gate, release app bundle build/plist lint, full
workspace gate, dependency policy, staged secrets and whitespace **PASS**. Local
Swift is 6.4, not CI's 6.1.2, so this is not a claimed local reproduction or proof
the older compiler is fixed. New exact-head remote macOS CI remains mandatory;
the failed run is not retried or waived. Native revision-protected editing Unit T
has separately completed and awaits review/integration; Unit U remains active.

## Primary integration and review

Primary committed only the five owned files as `fa13807` in the completed lane
and applied them without conflicts as
`ade43b54b0446b961521e4c932fa3e3447438a15`, the exact combined tested runtime.
No baseline/site merges or concurrent native context-edit changes were replayed.
Joffrey independently reviewed the fingerprint **CLEAR**, passed all nine new
tests plus the full 177-test/24-suite strict native debug and serial-release
suites and the ordinary-import API gate. He used existing lane CLI/C artifacts;
no independent Rust/artifact rebuild is inferred.

Primary full combined workspace gate (237 Rust/two doctests), strict serial
actual-CLI/C-fixture suite (177 tests/24 suites), model API compiler gate,
dependency policy, staged secrets and whitespace **PASS**. Original lane/reviewer
release evidence remains separate from the primary exact integrated debug pass.
Core expected-revision APIs remain unchanged; native human CAS integration is
separately owned by Unit T, not claimed by this feature.

PR #67 passed all five checks at
`a44df02e2a60c67dfb5e6d6be70c99a374a54617` (CI `43571746083`, integrated
`43571746040`); fresh clean main, exact head, required checks, review/approval,
discussion and rules gates preceded merge
`37f44a41b465b055ad5689bd7d268e3af42ec113`. Its separate exact post-merge CI and
this feature's publication CI remain later gates. Nine inherited progress edits,
all worktrees and parent reminders remain intact. No GUI/AX/live-quality/host-
delivery or phase closure follows from these local/runtime tests.

**TM-04–TM-07, TM-10; partial P4-A1–A4, inherited P2-A1/A6 and P3-A5.**
Mounts the immutable [Unit P](unit-p-native-ranked-inference-boundary.md) mode
through the [Unit O](unit-o-mounted-retained-review.md) model lifecycle and
[Unit Q](unit-q-bounded-textual-diff.md) review surface. Read alongside
[Phase 3](../spec/phase-3-background-experience.md) and
[Phase 4](../spec/phase-4-refinement.md). Lexical retrieval and textual review
only: no semantic-fidelity, GUI/AX, live-model quality or phase-close claim.

## Baseline, ownership and integration identity

- Initially clean assigned HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Authorized normal `git merge --no-edit` of required local base
  `77da1a886567c9ce432fb345a44e5089839c49bc` produced merge-only tested HEAD
  **`5e217412350401925e10e8505dfbe6d853ce402a`**. Its two parents are exactly
  those full SHAs in that order. Prepared contract/site history is preserved.
- Implementation is **staged and uncommitted**. There is no implementation SHA.
  Tested identity is that merge HEAD plus the owned runtime/test diff. SHA-256 of
  `git diff --cached -- apps/companion`:
  **`65a88db01630228a30167aa520e5d12ecde3488c91ceb399c7d9884d5ad6aba2`**.
  Four files, 523 additions / 41 deletions. This evidence document is excluded.
- Coordinator must integrate **only the five owned files below**, not replay the
  prerequisite merge or unrelated contract/site history. No reset, branch switch,
  new worktree, implementation commit, push, PR, merge to a target or cleanup.

| Owned path | Change |
| --- | --- |
| `apps/companion/Sources/CompanionKit/CompanionModel.swift` | Separate literal-default Refine mode, revocation, frozen preflight selection, full current binding and finite compatibility. |
| `apps/companion/Sources/CompanionKit/RefinementPreviewView.swift` | Explicit independent selector, mode/lexical bounds and consent/review coverage disclosure. |
| `apps/companion/Sources/CompanionKit/Contract.swift` | Two disclosure/comment lines only: shared source-mode text must no longer falsely claim Refine always remains literal. No enum/API/DTO behavior change. |
| `apps/companion/Tests/CompanionKitTests/RefinementModeModelTests.swift` | Nine new actual-model tests with synthetic CLI/SQLite/owned-loopback fixtures and controlled preflight races. |
| `docs/progress/unit-r-mounted-refine-retrieval-mode.md` | This evidence and exclusions. |

No consent/controller/adapter/ProcessService/Rust implementation, existing test,
transport, credential, dependency, lockfile, schema, site or global configuration
change. Concurrent Unit S expected-revision work is not duplicated or claimed.

## Product and authority contract

- Refine defaults to literal independently of Source Query/Context. Inspect freezes
  mode, exact original/query, settings, namespace/policy/snapshot and the exact
  bound literal or ranked query result **before** showing inference consent.
  Provider settings remain default-off; enabled configuration is not permission.
- Mode changes synchronously revoke pending consent/actions and advance the
  existing generation, cancel preparation or idle owners, and retain the existing
  owned join boundary. Every successor waits for predecessors. Changing back
  cannot restore consent or enqueue an old action. A no-op same-mode setter does
  not revoke a current review.
- Current model bindings reuse P's actual mode-aware, byte-exact project and
  original/query equality. Full settings and selected-evidence comparisons use
  stable byte-preserving encoding as an additional native check. Exact ordered
  source-draft bytes are checked; canonical Swift equality cannot approve a
  byte-distinct scope/settings/selection. Preflight brackets the existing bounded
  source-read helper with exact binding checks, preserving legacy rejection and
  namespace/recovery error classification.
- Mounted confirmation forwards the captured mode through the unchanged retained
  adapter. Actions check the current complete model binding. The finite
  `confirmRefinement` compatibility API keeps literal defaults but re-inspects
  the captured ranked operation when explicitly selected, then validates its
  unchanged finite ranked envelope. Neither route falls back or retries inference.
- Selector, consent and retained review disclose literal substring versus ranked
  any-term lexical selection, term/ranking limits, maximum eight source lines and
  8192 serialized selection bytes, coverage and truncation. No semantic retrieval,
  completeness or intent-fidelity guarantee. Local loopback is not a sandbox.
- Q's original/diff, unsaved-edit disable, questions and exact challenge semantics
  are unchanged. One explicit confirmation permits one provider call; Edit and
  review choices never reinfer. Default history remains off; values stay in
  memory with delivery not attempted, not copy/draft/send/host execution.

## Acceptance evidence

All fixtures are synthetic. Tests invoke public model mutation/confirmation/action
methods only, observe public action completion without polling, and read internal
controller state/PIDs solely for assertions. They never start/synchronize/edit the
controller directly. The existing ordinary-import negative compiler gate remains.

| Stable partial gate | New executed evidence |
| --- | --- |
| P4-A1/A2 | Actual rebuilt CLI/SQLite: literal `synthetic blue` is empty, explicit ranked capture selects one exact inspected line. Source selector changes never implicitly change Refine mode, in either direction. Owned HTTP receives exact Unicode/CRLF/negation/action-looking original and selected path/text/hash/producer; no provider call occurs during inspection. |
| P4-A3/A4 | Pending mode change/back rejects retained and finite stale consent; invalid ranked term count fails visibly without literal fallback. Disabled default settings cannot inspect/authorize inference. |
| P3-A5, P4-A3/A4 | Actual provider-I/O preparation, idle review and queued original choice are revoked on mode change/back. Successor preflight observes the previous child reaped; a fresh session starts only under new consent. All captured PIDs are checked with waitpid/ECHILD. |
| P4-A3/A4 | Controlled wrapper delays a real CLI query reply while ignoring task cancellation. Replacement cannot overtake its join, late result cannot restore old consent, and only the new generation becomes pending. |
| P4-A4 | Canonically equivalent changed original/query and change-back cannot authorize. Full settings byte changes (including unselected settings) revoke or reject confirmation. An unissued literal-mode variant cannot impersonate ranked consent. A controlled Unicode scope projection around actual CLI project reads proves byte-distinct canonical roots reject before source selection; this is not a macOS filesystem-normalization claim. |
| P4-A2–A4 | Latest actual core snapshot changes before confirmation contact no provider for either retained or finite paths. Source changes after Edit block both prepared and original engine choices; no silent fallback. |
| P4-A3 | Ranked Edit advances revision/digest. Stale challenge cannot approve; fresh challenge returns exact Rust proposal. Questions survive Edit and block prepared use; explicit original returns unchanged bytes and DeliveryNotAttempted. Exactly one provider connection, not reinference. |
| Compatibility/preservation | Actual finite model path: default literal empty-selection needs-input versus explicit ranked ready preview with correct coverage. Source bytes, original and one-revision human history survive review/cancel/mode changes. Store files contain neither original nor edited objective. |

## Verification

CLI and hostile C fixtures were rebuilt in this checkout using the command-local
SDK isolation documented in [adapter reproduction](native-retained-review-adapter.md).
All Swift tests used `sh apps/companion/scripts/swift.sh`, actual CLI/C fixture
environment variables, `--no-parallel`, complete strict concurrency and source
warnings-as-errors; never plain Swift. Existing SwiftPM native-backend/deployment
target warnings remain tool warnings, not waived source warnings.

| Local gate on merge HEAD plus owned diff | Result |
| --- | --- |
| `cargo build --offline --locked -p threadmark-cli` | PASS; actual CLI rebuilt. |
| SDK-isolated C11 `-Wall -Wextra -Werror` fixture build + ten mode copies | PASS. |
| New actual-model scope tests | PASS, nine tests. |
| Final strict serial full native debug | PASS: 177 tests / 24 suites. |
| Final strict serial full native release | PASS: 177 tests / 24 suites. |
| `sh apps/companion/scripts/check-retained-api.sh` | PASS: public model access compiles; internal controller access specifically rejects. |
| `CARGO_NET_OFFLINE=true python3 scripts/check.py` | PASS: workspace format/locked build/Clippy/tests/rustdoc, diagnostics, local doc links and intentional failing-test rejection. |
| `cargo deny --offline --locked check` | PASS using cached advisory/policy data; no online refresh. |
| `python3 scripts/secrets.py` after staging owned new files | PASS: tracked files/history and synthetic secret rejection; repeated with final evidence staged. |
| Unstaged/staged whitespace | PASS; repeated after evidence staging. |
| Independent review, integrated exact-head remote CI run/head, GUI/AX, semantic/live-model quality and host delivery | NOT RUN; coordinator/external gates. |

Initial test compilation caught awaited actor calls inside synchronous expectation
autoclosures; corrected. Two initial new fixtures made invalid assumptions about
selected ASCII provider model IDs and macOS Unicode source path handling; corrected
to valid selected profiles and an explicitly controlled scope projection. The
first full debug run exposed bypassed legacy/namespace error classification in
the new selection helper. Restored the existing checked-source-read boundary and
reran full strict debug and release successfully. No assertion/check was waived.

Ignored local evidence: `target/unit-r-{cli,targeted,debug,release,api,check,deny,secrets}.log`.
Loopback peers count all connections, use bounded nonblocking I/O, close accepted
sockets and stop/join before closing listeners. Synthetic stores/roots are removed
by fixture cleanup. No Docker resources. Ignored builds and the worktree remain
intact for coordinator inspection; no content-bearing public evidence is produced.

Plum lookup returned `thread_not_found`; no coordination, watcher, reminder or
external dependency is pending. No subagents, implicit network egress, live
provider, credential use, host launch/permissions, deployment or release. Two
inherited production-duration Rust timeout tests remain ignored as before. Local
passes do not certify an integrated revision, close a phase or authorize a merge.
