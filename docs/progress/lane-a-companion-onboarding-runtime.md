# Lane A — isolated companion launch and onboarding runtime

## Ownership and revision

- Owned branch: `t3/companion-onboarding-launch-ux`; assigned T3 worktree retained.
- Started at `661bdb3e11118efe979cc7adf06c39db723bf133` and fetched/merged reviewed
  `origin/main` at `86dba4cd1e442c5e704e55f38fef4e7c69b5683e` before editing.
- Tested implementation SHA: `8b9809ed3a62a164efd9e9e01867f5e30b93678c`.
  This evidence file is a subsequent documentation-only commit.
- No push, PR, merge-to-main, deployment, host launch, provider request or spend.
  Exact CI run/head: **not run / none**. Independent review: **not run**.
  Coordinator owns PR51, shared APIs/contracts and integration; Lane B owns
  provider configuration/transport/refinement. Neither was copied or edited.

## Delivered scope

TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A4,
P3-A1/P3-A4/P3-A6, P4-A1/P4-A2/P4-A3.

The actual native executable now accepts paired absolute `--core-binary` and
`--data-dir` choices, held only in process memory. It has no default store or
environment/credential discovery. Invalid launch input exits 2 without printing
private paths; `--validate-launch-config` exits without AppKit/core work. Core
still owns authorization, schema validation and store creation.

Manage now opens visibly at startup (Connections if unconfigured, Projects if
explicitly configured). Numbered navigation provides a short route through setup,
source approval/Build and human notes/Context. Root entry works with a standard
keyboard-accessible text field as well as a chooser; the canonical root used for
approval is displayed before the approval action. Unconfigured/missing-root
registration cannot be approved. Stable app-only accessibility identifiers cover
the principal journey controls. Source bounds and explicit approval stay intact.

An initial synthetic test used Foundation's shortened temporary-root spelling,
which did not match core's canonical returned root. The fixture now uses the
existing canonical-directory helper; the UI displays and uses that canonical
approval root too. No shared API/contract change was required. Initial test
expectations also incorrectly assumed `ready` rather than the existing
`ready-for-review` state, and an unavailable-root query failure rather than the
existing explicit `stale-or-unindexed` empty result. Those expectations were
corrected, not the production core semantics.

## Acceptance and command evidence

All fixtures synthetic. Paths/content-bearing raw runtime output were not put in
public evidence. No Docker or dependencies/lock changes were needed.

| Gate | Actual result |
| --- | --- |
| `cargo build --locked -p threadmark-cli` | Exit 0; real core rebuilt locally |
| `sh apps/companion/scripts/swift.sh build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` | Exit 0; native executable built |
| `python3 apps/companion/scripts/test-launch-configuration.py apps/companion/.build/debug/ThreadmarkCompanion` | Exit 0; 7 argument/selection cases; no store creation; content-free output |
| `THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" sh apps/companion/scripts/swift.sh test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` | Exit 0; 83 tests, 7 suites, real-core opt-in enabled |
| `python3 scripts/check.py` | Exit 0; workspace formatting/lint/tests/docs and intentional-failure gate passed |
| `cargo deny --locked check` | Exit 0; advisories/bans/licenses/sources passed |
| `python3 scripts/secrets.py`, after staging only new owned files | Exit 0; tracked-file scan passed, synthetic sentinel rejected |
| `git diff --check` and `git diff --cached --check` | Exit 0 |

The wrapper emits a native-build-system deprecation warning; the test linker
warns that its installed Testing framework targets macOS 14 while the package
declares macOS 13. These did not fail local checks; macOS 13 compatibility is not
established by this host's run.

`OnboardingJourneyTests.registerNoteBuildQueryPreviewCancelAndRecover` uses the
production model/ProcessService and actual CLI/SQLite, not a fake service:

- Configuration alone creates no store; invalid traversal registration is
  rejected before creation. Only the explicitly approved source is indexed.
- Human note save/history precedes a successful one-file lexical Build. Searching
  an omitted file's synthetic token returns no evidence (partial P2-A1/P2-A4).
- A core-produced Context preview is `ready-for-review` and keeps the exact
  original, including negations/identifiers. Dismiss and immediate cancellation
  discard preview without replacing the original (partial P4-A1/P4-A3).
- Removing an approved synthetic file makes Build visibly fail without a success
  report; restoring it permits recovery and the human history remains unchanged
  (partial P2-A3/P3-A4). An unavailable root returns stale/empty evidence, not
  previously current excerpts (partial P4-A2).
- Existing passing suites additionally exercise late-result cancellation,
  subprocess teardown, source-boundary rejection, pause/close/quit distinctions
  and exact native metadata watches. Model/fake lifecycle tests are not native
  window-interaction evidence.

## Native launch versus GUI acceptance

Two direct launches used only this worktree's built companion and explicit
isolated stores. An empty-store launch left the store absent. A separate bounded
launch used an isolated synthetic project/note/one-file lexical index prepared
through the real CLI (each preparation command exit 0). The companion remained
alive through a 3-second observation; the synthetic core note remained intact.
Only the owned companion process was terminated afterward (SIGTERM, exit -15),
and its temporary synthetic fixture was removed. This is launch evidence, **not**
graceful Quit acceptance, window readiness or proof of a core action from the GUI.

App-scoped accessibility inspection targeted only that owned PID. It failed:

```text
AX probe exit: 1
System Events got an error: osascript is not allowed assistive access. (-1728)
```

No native desktop/AX automation tool was exposed, and no existing `peekaboo` or
`cliclick` command was available. No permissions were toggled, app/desktop
screenshots captured, global settings changed or unrelated applications driven.
The paused OpenCode host was untouched. Therefore actual GUI registration,
button-driven save/Build/query/preview/cancel, window readiness, keyboard traversal,
VoiceOver, focus, light/dark and native close/reopen remain **unverified**.
P3-A6 and the GUI portion of P3-A1 are blocked, not passed.

## Remaining integration gates and exclusions

Coordinator must integrate app-local changes with PR51's independently owned
main-view edits and Lane B/shared API work, then rerun strict Swift/core checks
on the integrated head. Obtain independent review and exact-head CI before any
phase/PR acceptance. Repeat the app-only manual/AX journey with existing authorized
assistive access; do not bypass the permission boundary. The walkthrough and
commands are in `apps/companion/ONBOARDING-RUNTIME.md`.

No AI refinement, provider configuration, inference consent, delivery, host
admission, daemon listener, installer, login startup, credential storage, real-user
store migration, source Forget UI or whole-phase closure is claimed. Configuration
is deliberately session-only, and startup is not readiness. No new shared contract
change is requested by this lane.
