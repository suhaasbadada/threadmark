# Lane L — Native retained-review adapter (not app-wired)

**TM-04–TM-07, TM-10; partial P4-A3/A4, P2-A1/A2/A6 and P3-A5.**
Implements the existing [private stdio v1 contract](../contracts/local-review-stdio-v1.md)
and retains J's actual Rust engine across review. This is a protocol-specific
native process driver/controller, not a replacement composer, generic RPC layer,
listener, provider client, host launcher or mounted GUI. Phase/privacy/quality/
remote/host gates remain open. See [J's evidence](local-review-stdio.md).

## Scope and ancestry

The assigned isolated checkout started at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Fetched and merged reviewed `origin/main`
`2b9abb810d5661259badb5d751d6e30af7e584f0`, then exact local published primary
`20a82054366f48112bbfe1e3e2df8ccdd1cf91cd`, then J's owned commits
`bd8c84fbd6c865e435cbc5bdbab8d2653db93d43`,
`7e98e764969893064187dee6fe7abb368a3932fa` and
`8a50372d485161f63afa01f76d603336acc02947`, in place without conflicts.
The required `535b049fb95730ee25cf17e74d5d5c2eceaf9cf3` main base is an ancestor.
No branch switch/reset/discard, extra worktree, push, PR, merge-to-main or delegate.
Primary owns PR #57 CI, independent review and K/model integration; supplied
post-merge CI evidence is not evidence for this lane's exact integrated head.

Owned runtime files are only `CompanionKit/RetainedReview*.swift`; owned tests are
`RetainedReviewTests.swift` and the synthetic hostile child in
`Tests/RetainedReviewFixtures/retained.c`. The one explicitly permitted existing
file change makes `PreviewJSON` internal instead of private, without behavior
change, to reuse escaped-key duplicate detection. No changes to K-owned files,
the existing preview view/public consent DTO, app entry point, Rust, providers,
profiles, dependencies, lockfiles, core schemas or finite-preview behavior.

## Wire and authority

- Exact J `refine review` argv and confirmation/root/identity/incarnation/snapshot
  flags. Existing consent/selection/default-off/local-profile validation and store
  selection validation run before spawn. No shell, PATH search, inherited secrets,
  global registry, credential reuse or native HTTP client.
- Original exists only in memory and the escaped first `version/original` JSON
  frame, not argv. Evidence/query text cannot become actions. Only explicit typed
  edit/prepared/original commands can generate subsequent protocol frames.
- At most one outstanding command (queue overflow cancels), 8192 bytes including
  LF per frame, eight frames and 65536 bytes per direction. Whole frames reject,
  never truncate. Nonblocking pipe writes/read loops bound allocation and each
  drain pass. Parent deadline is at most 300 seconds including idle review; J owns
  its unchanged <=30-second, one-call provider deadline and token/output budgets.
- Closed event/key/nested-provider/editable validation reuses the duplicate gate;
  rejects unknown modes/fields, partial/trailing/invalid JSON, invalid challenge,
  provider identity/budget/coverage/changed/questions mismatch and oversized data.
  Original is the immutable consent value, not an untrusted output echo.
- New reviews must advance revision exactly once and change digest. J's digest
  includes private Rust state/process identity, so native **does not invent a
  second hash protocol**. It retains the issued equality challenge, rejects stale
  UI actions locally and requires exact matching challenge/choice/text on handoff.
  Rust alone performs actual-core approval/handoff revalidation for both choices.
- Questions/no evidence block prepared use. Recoverable ReviewRequired preserves
  the last preview. Provider failure permits only explicit original/cancel using
  its challenge; no automatic approval/fallback/retry/new call/session. A consumed
  consent ID cannot start another session on the controller.
- Result is the actual Rust handoff text and `DeliveryNotAttempted`. No clipboard,
  host draft, admission, Send, network request from Swift, or downstream-success
  claim exists.

## Ownership and lifecycle

One detached **owned** I/O task alone owns the three private pipes and POSIX child.
It uses the existing `OwnedChild.step` owner/reaper, monotonic clock, SIGTERM then
identity-safe SIGKILL escalation, and no Foundation Process or parallel reaper.
It continuously observes EOF/exit even while the UI is idle. Cancellation,
timeout, output failure, malformed input/output and deinit close all descriptors
and reap the actual child. Terminal output is accepted only after process exit,
descriptor teardown and worker join; a handoff additionally requires exit zero.
No absent/partial event becomes success. A terminal event followed by a hung child
has a bounded one-second graceful-exit allowance, then fails closed and joins.

The mailbox never publishes content after cancellation. Controller generation and
identity guards reject late completions; synchronization invalidates generation
before awaiting teardown. Concurrent synchronization joins the same previous
owner, and only the newest generation can bind the replacement. Destruction
signals the retained owner; its task completes reaping without needing UI life.

## Required common-model wiring (PRIMARY, not implemented here)

1. Own one `RetainedReviewController` in the common model, not a SwiftUI view.
   Keep current original/query/project/root/identity/incarnation/snapshot/source
   policy/settings and configuration generation authoritative in that model.
2. On explicit existing immutable refinement confirmation, build
   `RetainedReviewBinding(consent:configurationGeneration:)` from the **current**
   model generation/scope/settings, after checking the pending consent ID and
   byte-exact current original/query. Do not rebuild the current binding from a
   stale confirmation. Alternatively use the full binding initializer to compare
   current model values directly. `await controller.synchronize(currentBinding)`
   before `start(consent:executable:store:)`, using trusted configured URLs.
3. Register the start task in the existing model-owned operation registry before
   awaiting it. Keep that task owned while review is idle too: after `start`
   returns, obtain `ownedLifetime`, then await `lifetime.join()` inside a task
   cancellation handler whose `onCancel` calls synchronous `lifetime.cancel()`.
   Cancellation during start is already propagated through its exchange handler.
   These handles are native worker lifetimes, not independent/global registrations.
4. Route **every** original/query/project/source-policy/registration/snapshot/
   provider/settings/configuration change through invalidation. Advance the model
   generation first, immediately disable old review actions, then **await**
   `controller.synchronize(nil)` (or the newly captured current binding) **before**
   committing the new binding. Existing synchronous model setters need an owned
   serialized async boundary; merely launching an unowned cancel Task is unsafe.
   Source-only disk changes are also revalidated by Rust at approve/handoff.
5. Each human Edit/Use prepared/Use original action captures the displayed
   challenge and calls its corresponding method once. Disable actions while busy.
   Display original/proposed/questions/editable prose and truthful state. Never
   clear questions via edit. A failed retained session must not silently call the
   existing finite-preview path (double-inference risk).
6. On Quit, revoke UI bindings and await `cancelAndJoin()` **and** registry tasks.
   `ownedLifetime.cancel()` alone is not acknowledgment. Keep the lifetime handle
   while idle, not just the task waiting for the first preview. Only consume
   `.approvedValue` as a returned value, never as host admission/copy/send.

## Acceptance and verification

All fixtures are synthetic: actual rebuilt CLI + SQLite + owned numeric-loopback
HTTP only. Accepted macOS sockets are explicitly nonblocking with bounded loops;
stop joins the server and closes its listener. No fake production backend, model,
keys, user content, global configuration, install, spend, egress, Docker, desktop
capture, permission change or host launch. GUI AX remains blocked externally by
osascript `-1728`; no GUI acceptance claim.

Native actual-core fixtures cover confirmed capture → preview → edit → changed
revision/digest → stale UI approval ReviewRequired → fresh prepared exact Rust
handoff; material questions survive edit and block prepared; explicit original
after provider failure; changed source and replaced namespace invalidate original,
including after failure; cancel during provider I/O, short parent deadline,
binding invalidation and no late adoption. Source/original/human history remain
unchanged; actual persisted human history is checked and store files are scanned
for synthetic original/edit plaintext. Exactly one provider connection per call.

Hostile-child native fixtures cover EOF, malformed/escaped duplicate/oversized/
unknown/partial output, pipe closure, idle deadline, blocked reply, competing
commands and deinit. Marker PID is compared through actual `waitpid`/ECHILD after
join, including an ignoring-SIGTERM child. Strict DTO tests cover missing/unknown
fields, provider identity/budgets and stale model/consent/profile bindings.
J's already-recorded actual 300s/30s production deadlines are not rerun; this lane
uses short parent deadlines without changing J's CLI or adding environment knobs.

Reproduction (SDK isolation is command-local; do not use plain Swift here):

```sh
mkdir -p target/retained-fixtures
cargo build --offline --locked -p threadmark-cli
sdk=$(xcrun --sdk macosx --show-sdk-path)
resource=$(xcrun clang -print-resource-dir)
xcrun clang -std=c11 -Wall -Wextra -Werror -nostdinc \
  -isystem "$resource/include" -isystem "$sdk/usr/include" -isysroot "$sdk" \
  apps/companion/Tests/RetainedReviewFixtures/retained.c \
  -o target/retained-fixtures/retained
for mode in malformed duplicate oversize unknown partial eof pipeclose idle hold deinit; do
  cp target/retained-fixtures/retained "target/retained-fixtures/retained-$mode"
done
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
THREADMARK_RETAINED_FIXTURES="$PWD/target/retained-fixtures" \
  sh apps/companion/scripts/swift.sh test \
    -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Repeat the same wrapper/env with: test -c release ...
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
```

The initial direct C compiler attempt hit this machine's incompatible
`/usr/local/include` headers; the isolated SDK command above passes without
changing system headers. SwiftPM emits existing native-build-system deprecation
and macOS deployment-target/Testing linker warnings; source warnings remain errors.
Final tested runtime SHA and gate results are recorded below after committing.
Remote CI/review and app/GUI integration have **not** run in this lane. No phase
closes. Plum lookup returned `thread_not_found`; no coordination message, watcher
or scheduled follow-up exists.
