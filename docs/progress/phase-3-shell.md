# Phase 3 native shell — independent implementation lane

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
