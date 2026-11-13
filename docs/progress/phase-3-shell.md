# Phase 3 native shell — independent implementation lane

## Engineering revision — cancellation ownership and real-core integration

This revision supersedes the initial implementation evidence below where noted.
It remains the same isolated shell lane, based on
`eb9a5626eaa618782ef51fb630fd3245376db0a7`; no coordinator commits were cherry-picked
and no checkout, branch, delegate or worker lane was created.

**Full tested implementation SHA:** `7eb339d9015b6c95a56a58746650f416a7aebddf`.
This report update is a subsequent evidence-only commit. Changes remain limited
to `apps/companion/**` and this progress record. No Rust/workspace/CLI/contract/CI
files were changed, and no push, PR, watch, release or deployment was performed.
Joffrey's original two findings were real issues; both are addressed below.
Current verification is implementation tests plus local self-review, not a claim
of an independent re-review or remote checks passing at this shell revision.

### Review findings and changes

- **HIGH — recycled PID during escalation:** removed Foundation `Process` from
  production transport. `posix_spawn` uses explicit stdin/stdout/stderr dup2 file
  actions, `POSIX_SPAWN_CLOEXEC_DEFAULT`, exact executable/cwd and minimal locale
  environment. The single bounded I/O thread is the sole `waitpid(WNOHANG)`
  reaper. It signals only while the child remains unreaped: TERM once, KILL at
  most once after 200 ms. An exited unreaped child reserves its PID. Reap or
  `ECHILD` immediately and permanently stops signals. No global handlers,
  process-group kills, PID rediscovery or generalized supervisor were added.
- **MEDIUM — persistent effects overtaken after cancel:** replacement starts now
  capture and cancel prior owned tasks, then await **all** their teardown before
  performing any replacement service call. Generation/cancellation/Quit are
  checked again after the join. UI invalidation remains immediate. Explicit join
  and Quit also include tasks whose visible `job` was already cleared by cancel.
- **Integration limits:** adapter, model, UI and tests now enforce 4 KiB context
  stdin, 256-byte query text and 64 project summaries. The shared UI/service kind
  list is note/decision/constraint/correction/pitfall. Material input is rejected,
  never truncated. Core remains the authority for actual source/storage policy.
- **New vs existing store:** Connections explicitly distinguishes an existing
  known initialized core store from an existing parent plus an unused new name.
  Selection/configuration creates no state directory; the next explicit core
  operation creates it with mode 0700. A new store's child cwd is its existing
  parent. `realpath` resolves user-selected directories because Foundation can
  shorten private temporary paths back through a symlink, which core correctly
  rejects. New-name validation also rejects dangling symlinks. No global paths,
  permissions or configuration were changed.
- **Truthful status:** Build is labeled bounded local source-evidence work;
  current core is lexical source-line indexing, not certified structural/semantic
  understanding. The GUI remains unlaunched and uncertified.

### Revision verification

At the implementation SHA above:

| Command / check | Result |
| --- | --- |
| `THREADMARK_CORE_TEST_BINARY=<explicit supplied binary> sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing -Xswiftc -warnings-as-errors` | **27 tests / four suites passed**, including real core integration; repeated after implementation commit |
| Same strict tests with no live binary configured, filtered to `LiveCoreTests` | Live test explicitly skipped with a reason; no PATH discovery or fake fallback |
| Same filtered live test with an explicitly nonexistent binary | Deliberately failed with typed `unavailable`; rejection probe passed |
| `sh apps/companion/scripts/swift.sh build --product ThreadmarkCompanion -Xswiftc -warnings-as-errors` | Passed; no launch |
| `sh apps/companion/scripts/bundle.sh` | Release build/package passed; no install, launch or signing |
| `plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist` | Passed |
| `python3 scripts/check.py` | Passed on unchanged Rust foundation plus shell documentation links |
| `cargo deny --locked --offline check` | Passed; no network fetch |
| `python3 scripts/secrets.py` after staging new files | Passed, including redacted tracked/history scan and rejection probe |
| `git diff --cached --check` | Passed |

The exact supplied Rust binary tested has SHA-256
`929b7faa540a070ddb16f079f84c56db14a28791a02ff185aa8c8e9e6baa27d4`
(unchanged across the final implementation test/build run). Its private absolute
path is not baked into source or public evidence. The test-only environment
parameter must be explicitly supplied; production never reads it. The parent
owns that binary's source/CLI/CI integration, so no source SHA is inferred from a
separately rebuilt executable.

Regression evidence includes:

- Deterministic lifecycle tests force exit between wait and escalation, verify a
  single KILL maximum, and reject every signal after reap/`ECHILD`. Six owned
  real fixture processes exit during the TERM/KILL grace boundary; they are
  reaped and subsequent test-only `waitpid` confirms `ECHILD`. Another fixture
  ignores TERM to exercise actual KILL and reap. No unrelated PID is signaled.
- A controlled fake mutation ignores cancellation and commits only when released.
  A replacement source policy and a replacement refresh both remain blocked
  until that commit/teardown. Final fake persisted policy and displayed state are
  checked, not only late UI suppression. The original held-index/project-switch
  assertions remain, with the old job released before awaiting replacement ready.
- Joining after cancel waits for outstanding work; Quit suppresses an already
  queued refresh after prior mutation teardown. UTF-8 query/context boundaries,
  project-list over-limit rejection and new-store selection/no-write behavior
  are also tested.

### Actually observed live-core adapter acceptance

Only owned, generated synthetic roots/files/store under the approved temporary
area were used and cleaned up. The real adapter and supplied core binary passed:

1. Select a nonexistent store without creating it; first explicit project add
   creates it with mode 0700; inspect registered exact file policy.
2. Index, retrieve current source-backed evidence, edit the source, observe stale
   status, and explicitly rebuild.
3. Add a human note, update to a decision, update to a correction, inspect all
   revisions, retire, and inspect retained history.
4. Register/index a second project; verify source and human context isolation.
5. Revoke all sources; verify empty stale retrieval. Reopen the known store with
   a fresh adapter and verify projects and retired history persist.
6. Select an empty existing directory; verify core rejects it rather than treating
   it as an initialized private store.

This adds real CLI/storage evidence for portions of P3-A1, P3-A3 and P3-A4 and
adapter/model evidence for P3-A2/P3-A5. **It is not native UI acceptance.** No GUI,
coding host, inference/provider, credentials, login startup, network, Docker,
package installation or global configuration was used. No Refine UI was added.
Native tray/window behavior, accessibility/focus, light/dark/reduced motion and
operator walkthrough remain for separately authorized parent acceptance. Phase 1
host/inference gates and full P3-A1–P3-A6 closure remain OPEN. The installed SDK /
native-backend and older-OS caveats from the original evidence still apply.

## Initial implementation evidence (historical baseline)

## Revision and ownership

- Frozen base: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Full tested implementation SHA: `a6680de4476dd9c048a89f705475d88168600ae0`.
- This report is a subsequent evidence-only commit; implementation files were
  tested again after the implementation commit, before writing this report.
- Owned changes: `apps/companion/**` and this report only. No Rust/core storage,
  index, refinement, root workspace/lockfile, shared contract, site or root README
  changes. No delegates, extra threads, branch switches or new worktrees.
- No PR, push, remote CI run/head, review approval, deployment or release exists
  for this lane. Local self-review only; coordinator integration/review is pending.

The explicitly authorized parallel Phase 3 sequencing exception does not close
Phase 1 live-host/inference gates or reduce full-product requirements.

## Delivered source

Native Swift Package: `CompanionKit` model/port/Process adapter, executable
AppKit `NSStatusItem` + SwiftUI Projects/Context/Connections/Privacy window,
explicit synthetic subprocess fixture and Swift Testing tests. No third-party
dependency downloads. See the [shell README](../../apps/companion/README.md) for
build commands, exact transport assumptions, bounds and the pending walkthrough.

The production adapter is visibly unavailable until an exact binary and private
data directory are selected. It never falls back to samples. It invokes no shell,
inherits no credential environment, records no private diagnostics, and sends
context text only on stdin. Core retains all authorization/storage semantics.

The model guards late results by operation generation and invalidates displayed
evidence/history/selection on project or source-policy changes. Quit cancels and
waits for every outstanding owned operation, including already superseded ones.
Closing/reopening Manage retains the window/model and does not cancel jobs.
Pause/resume is scheduling state; no automatic scheduler is installed.

## Verification at the implementation SHA

All commands below passed locally. The GUI executable was **compiled and
packaged, never launched**. Native runtime, tray, window, accessibility and
background continuation were not observed.

| Command | Evidence |
| --- | --- |
| `sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing -Xswiftc -warnings-as-errors` | 17 tests, two suites passed; also compiles the application executable without launching it |
| `sh apps/companion/scripts/bundle.sh` | Optimized release executable packaged into ignored local app bundle; no install/sign/launch |
| `plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist` | Passed |
| `python3 scripts/check.py` | Existing Rust format/build/clippy/tests/docs, foundation smoke, local doc links and intentional-failure gate passed; not live-core transport acceptance |
| `cargo deny --locked check` | Passed; repeated at committed implementation with `cargo deny --locked --offline check`, passed |
| `python3 scripts/secrets.py` | Passed after staging all new source; redacted tracked/history scan and synthetic rejection probe |
| `git diff --cached --check` | Passed before implementation commit |

Environment: installed Apple Swift 6.4 and macOS 27 SDK, arm64. A plain initial
SwiftPM invocation failed on incompatible ambient `/usr/local/include` headers;
the owned wrapper supplies command-scoped SDK paths. No global configuration or
headers were modified. Installed SwiftUI's new State macro lacks its plugin, so
the implementation explicitly aliases the existing State property wrapper.
SwiftPM reports its native backend deprecated; the installed Testing framework
targets macOS 14 while the application declares macOS 13. Neither older OS
compatibility nor current native runtime operation is certified by this build.

## Stable acceptance mapping

TM-01–TM-03, TM-07 and TM-10 are the Phase 3 shell requirements. The following is
partial local evidence, **not a claim that P3 acceptance or a phase is closed**.

| Acceptance | Local evidence | Still open / excluded |
| --- | --- | --- |
| P3-A1 | Fake registration requires exact root/files before Build; Build returns snapshot/coverage; source revocation clears evidence; model close preserves held job | Authorized native first-run/tray/close journey and live core indexing |
| P3-A2 | No provider transport/credential UI; semantic work cannot start. Subprocess stdout/stderr/input/time/retrieval budgets and cancel/owned-PID exit tested. Failed source update stays unusable until explicit recovery | Provider/content/budget consent, restart and real core atomicity/permission enforcement |
| P3-A3 | Two-project fake mismatch, host-project mismatch, held late result after project switch, and source-policy invalidation tests | Actual host identity/admission and worktree integration remain Phase 1/core-owned |
| P3-A4 | Fake add/edit decision, inspectable revision history, retire, rebuild preservation; process fixture verifies context CLI mapping and stdin-only text | Real persistence/restart, conflicts, forget/retention/cleanup require core contracts beyond client-v1; visibly unavailable, not simulated |
| P3-A5 | Distinct pause/resume, close-with-job, cancel, Quit and shutdown-waits-for-previously-canceled-work model tests; AppKit source wires terminate-later to teardown | Actual tray lifecycle/background progress/worker teardown walkthrough; automatic scheduling/login startup not implemented |
| P3-A6 | Compiled native standard controls, keyboard labels/shortcuts, textual statuses, system appearance, no custom animation; no OS-notification API or content-log path; content-free failure tests | Screen reader, focus order, dark/light/reduced-motion walkthrough and runtime notification/privacy inspection |

The adapter fixture verifies project add/list/show/source replacement (including
empty revocation), index/query and context add/update/list/show/retire command
mapping, JSON decoding, mismatch rejection, malformed output, dependency failure,
fresh recovery, stdin isolation and clean child environment. A test-owned hanging
fixture ignores SIGTERM; cancellation must reap that exact PID (ESRCH asserted).
All fixture files/data are synthetic and removed by the tests.

## Handoff boundaries

- Core CLI was not available in this checkout. The coordinator must validate the
  concrete JSON schema/CLI against the real integrated binary; fake transport
  tests are not live integration evidence. Project list is expected as a JSON
  array, mutation replies as valid JSON followed by authoritative re-read.
- No native GUI, coding host, provider, credential store or login item was
  launched/accessed. No Docker resources were created. No network listener,
  inference client, notification transport or send operation was implemented.
- Forget/conflict resolution, source-derived cleanup, login startup, persistent
  shell configuration, automatic scheduling and host certification remain open.
  Relaunch requires reselecting the exact binary/data directory. Core history
  persistence is not claimed from fake-service tests.
- Cancellation invalidates UI results and tears down its child; it cannot promise
  rollback of a core transaction that committed before cancellation. Refresh
  persisted state after uncertain mutation outcomes. Core independently owns
  atomic cancellation/authority checks; no process group or unrelated process is
  terminated by this adapter.
- Parent owns GUI acceptance and all shared integration. This lane is ready for
  integration/review, not a claim of a released or working live companion.
