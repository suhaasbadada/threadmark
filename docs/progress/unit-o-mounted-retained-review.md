# Unit O — model-owned retained native review

**TM-04–TM-07, TM-10; partial P4-A3/A4 and P3-A5.** Mounts the existing
actual-core retained adapter in the native model/view/app. This is not GUI/AX
acceptance, live-model quality certification, host integration or phase closure.
Read alongside [the adapter contract and mandatory hooks](native-retained-review-adapter.md),
[Phase 3](../spec/phase-3-background-experience.md) and
[Phase 4](../spec/phase-4-refinement.md).

## Base, ownership and handoff

- Prepared head: `661bdb3e11118efe979cc7adf06c39db723bf133`, initially clean.
- Normal `git merge --no-edit` of required integrated base
  `029025ea4abe35897381b99bba49e8fe9b301dee` produced merge-only head
  **`236c184040e8e3c70f86185369bcb9ac56828dfc`**. Its two parents are exactly
  the prepared head and required integrated base above. All history, including
  the prepared checkout's separate contract/site history, is preserved.
- Implementation is deliberately **uncommitted** on that merge head. There is no
  tested implementation commit SHA. Tested identity is the full merge SHA plus
  the owned working diff. SHA-256 of `git diff HEAD --` over the five runtime/test
  files below (excluding this evidence document):
  `5b08fc542068a2dfa2b716c1cc7fb489c9fc9c934b142ace55d3084485712838`.
- Coordinator takes only the owned implementation/evidence diff, not base/site
  merges or unrelated history. No reset, switch, new worktree, implementation
  commit, delegate, push, PR, watch, deployment or release was performed.
- Coordinator owns independent review, integration, exact integrated-head CI and
  any authorized publication/merge. **CI run/head: not run for this working diff;
  independent review: not run by this implementation lane.** Earlier green heads
  do not certify this diff.

Owned inventory (repository-relative):

| File | Change |
| --- | --- |
| `apps/companion/Sources/CompanionKit/CompanionModel.swift` | Retained confirmation/actions; model-owned preparation and idle worker owner; serialized revocation/join; current bindings; settings/configuration lifecycle; shutdown. |
| `apps/companion/Sources/CompanionKit/RefinementPreviewView.swift` | Mount retained review, challenge-bound Edit/Use prepared/Use original/Cancel, questions and truthful in-memory value/delivery states. |
| `apps/companion/Sources/ThreadmarkCompanion/main.swift` | Route every provider-session invalidation to model settings; update Connections/Privacy disclosures. Existing close/Quit entry points use the model lifetime. |
| `apps/companion/Sources/CompanionKit/RefinementConsent.swift` | Disclosure-string-only correction: inference consent is not approval; retained engine value is not delivery. Immutable DTO/validation behavior unchanged. |
| `apps/companion/Tests/CompanionKitTests/RetainedModelTests.swift` | Eight new actual-model tests plus owned synthetic numeric-loopback peer. |
| `docs/progress/unit-o-mounted-retained-review.md` | This evidence and exclusions. |

No `RetainedReview*.swift` adapter, old test/fixture, Rust, schema, dependency,
lockfile, site or global configuration changes.

## Lifecycle and authority

The model owns one controller, not the view. Confirmation validates the pending
immutable consent, byte-exact current original/query, project/root/identity/
incarnation/sources/snapshot, policy, settings, model generation and configuration
generation. It constructs the binding from current model values and uses only
the configured `ProcessService` executable/store URLs. Preflight is literal,
provider-free and joins stopped refresh-driver authorization before new reads.
The ranked Source Query/Context selector does not change retained Refine; unit N
is not an integration dependency.

Preparation and its idle lifetime owner enter the existing owned-operation
registry before any suspension. The owner awaits preparation, retains the
controller's actual `ownedLifetime`, and joins inside a cancellation handler
calling `lifetime.cancel()`. Cancellation during preparation cancels its owned
start task and reaches the adapter exchange handler. Task closures do not retain
the model across idle join; actual idle deinit is tested.

Synchronous setters first hide/revoke retained actions and advance the model
generation, cancel owned tasks and signal any captured lifetime. An owned teardown
boundary joins all predecessors and awaits `controller.synchronize(nil)`.
Every replacement operation awaits all prior registry entries before service/core
work; a new review synchronizes its captured current binding before spawning.
No unowned cancellation task is launched. Refresh consent cannot be enabled
while a retained operation, pending inference consent or predecessor registry
work exists. Actions additionally recheck the complete current model binding.

Edit/Use prepared/Use original each capture the displayed challenge and enqueue
one owned action. Actions disable synchronously while pending. Unsaved prose
disables prepared use until explicit Edit issues a new review challenge. Material
questions remain visible and cannot be removed by Edit. Failure never calls the
finite preview path, retries inference, or implicitly chooses original.
`.approvedValue` displays only the actual Rust value and `DeliveryNotAttempted`;
there is no clipboard write, host draft, admission, Send, execution or learning.
The existing finite `confirmRefinement` remains a separate compatibility API.

Closing Manage retains the bounded idle session in the model; pause affects
automatic lexical scheduling, not explicit review. Quit revokes immediately;
shutdown snapshots the post-revocation registry, joins it and refresh-driver
shutdown, and awaits controller cancellation/join. Neither window close nor
inference preparation is represented as delivery success.

## Acceptance evidence

All data are synthetic. Tests use the rebuilt actual CLI, new private SQLite
stores and a task-owned numeric-loopback HTTP peer only. The peer accepts/counts
all connections, uses bounded nonblocking I/O and joins before closing its
listener. No real provider, secret, private egress, host launch, capture,
permission change, deployment or Docker resource is used.

| Stable acceptance | Actual model evidence |
| --- | --- |
| P4-A3 | Preview, Edit and actual exact Rust prepared value; questions survive Edit and block prepared use; provider failure retains the original until explicit original choice; cancellation during provider I/O rejects late adoption. No hidden retry/double provider call. |
| P4-A4 | Stale challenge cannot approve edited prose; draft/query/policy/settings/profile/configuration/selection/cancel/quit revoke idle actions synchronously. Source bytes, snapshot, policy and replaced registration invalidate both actual core choices; source changes after provider failure invalidate explicit original too. |
| P4-A3/A4 | Default/changed settings, unissued consent ID, byte-different canonically equivalent original, stale consent and changing back cannot start a call. Literal retained consent is checked while the native selector is ranked. |
| P3-A5 | Close retains idle owner; pause is distinct; Quit and deinit cancel/join/reap the real child. Replacement preflight and the next session observe the old child already reaped; queued old actions cannot survive invalidation. |
| Privacy/preservation | Original bytes, saved human history and source file are preserved on review actions/failure/cancel. Actual persisted human history stays one revision; store files contain neither synthetic original nor edited objective. Child cleanup uses actual `waitpid`/ECHILD evidence. |

Project selection/reconfiguration retain their existing project-display/draft
clearing semantics; this unit does not add draft restoration or history archival.

## Local verification

SDK/toolchain isolation is command-local. CLI and hostile C fixtures were rebuilt
from this checkout using the commands in the adapter progress document. Every
Swift command used `sh apps/companion/scripts/swift.sh`, never plain Swift, with
`THREADMARK_CORE_TEST_BINARY` and `THREADMARK_RETAINED_FIXTURES` pointing to the
task-owned rebuilt artifacts. Source warnings are errors; SwiftPM still emits
its existing native-backend deprecation and Testing deployment-target linker
warnings. No global SDK/header setting changed.

| Gate | Result on merge head + owned diff |
| --- | --- |
| `cargo build --offline --locked -p threadmark-cli` | PASS; actual CLI rebuilt. |
| SDK-isolated C11 `-Wall -Wextra -Werror` hostile fixtures | PASS; all ten mode copies rebuilt. |
| Strict complete-concurrency debug, `--filter RetainedModelTests` | PASS: 8 tests / 1 suite. |
| Strict complete-concurrency release, `--no-parallel --filter RetainedModelTests` | PASS: 8 tests / 1 suite. |
| Strict full Swift debug | PASS: 157 tests / 20 suites, actual CLI/C fixtures enabled. |
| Strict full Swift release, `--no-parallel` | PASS: 157 tests / 20 suites, actual CLI/C fixtures enabled. |
| `CARGO_NET_OFFLINE=true python3 scripts/check.py` | PASS: workspace format/build/Clippy/rustdoc/tests, diagnostics, doc links and intentional failing-test rejection. |
| `cargo deny --offline --locked check` | PASS: advisories/bans/licenses/sources. |
| `python3 scripts/secrets.py` after staging owned new files | PASS: tracked files/history and synthetic secret rejection. |
| `git diff --check`, staged whitespace | PASS. |
| GUI/AX, keyboard/assistive-technology runtime, live-model quality, host delivery, independent review, integrated remote CI | NOT RUN; remain coordinator/external gates. |

Ignored local logs: `target/unit-o-{scope-debug,scope-release,full-debug,full-release,check,deny,secrets}.log`.
No public content-bearing artifact is produced. Temporary test roots/stores are
removed by fixtures; loopback peers are stopped/joined; test children are reaped.
Ignored built artifacts and this task worktree remain intact for the coordinator.

Plum coordination lookup returned `thread_not_found`; no coordination message,
watch, polling, reminder or scheduled follow-up exists. No external dependency
or promised update is being awaited by this unit. All phase/privacy/host/quality
gates remain open; local passes do not close a phase.
