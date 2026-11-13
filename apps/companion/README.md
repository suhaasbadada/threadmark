# Native macOS companion shell

Independent Phase 3 shell for TM-01–TM-03, TM-07 and TM-10, adapting the frozen
[client-v1 contract](../../docs/contracts/client-v1.md). SwiftUI management views
and an AppKit `NSStatusItem`; no webview or third-party package.
Core remains responsible for storage, indexing, authorization, source
identity/currentness, human revision history and transactional cancellation.

## Build and test (no launch)

From the repository root, using the installed Swift/SDK only:

```sh
sh apps/companion/scripts/swift.sh build --product ThreadmarkCompanion
sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing -Xswiftc -warnings-as-errors
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
```

The bundle script only builds and copies to ignored `dist/Threadmark.app`; it
does not run, install, sign, notarize, register login items or modify preferences.
Do not launch without the coordinator's separate authorization. The declared
deployment target is macOS 13; compiled with the installed macOS 27 SDK. This
does not certify older OS compatibility. Swift Testing here requires macOS 14+.

The wrapper isolates incompatible ambient `/usr/local/include` headers with
command-local SDK include/framework paths, and locates the installed Testing
framework. It uses SwiftPM's native build backend (deprecated by this Swift
version, but supported). No SDK/toolchain/global config is changed. The SDK's
new same-named `State` macro has no installed plugin; a type alias explicitly
selects SwiftUI's existing State property wrapper. A plain `swift test` on this
host fails in SDK header lookup; use the wrapper.

For explicit live-core adapter acceptance, set `THREADMARK_CORE_TEST_BINARY` to
the absolute path of the coordinator-built `threadmark` executable, then run the
same test command. This **test-only** option has no production discovery path.
Unset means the live suite is visibly skipped; an explicitly invalid binary
fails. It uses only new, owned synthetic roots/store under the temporary folder,
tests project/index/query/currentness/context/isolation/revocation/reopen through
the real adapter, and removes its data. It does not launch an app GUI or host.

## Product boundary

- Projects offers **Remove local project…** only after loading a root identity.
  An immutable, cancel-default confirmation displays the exact ID/root/identity
  and loss of all local notes, history, evidence and policy. Confirmation runs
  `project remove ID --confirm-remove-local-data --expected-root ROOT --expected-root-identity IDENTITY`
  through the actual core, with exact stale-approval binding (not authentication).
  Project/source/configuration changes invalidate the prompt. Confirm clears
  drafts/evidence/selection immediately; success requires a validated, content-free
  receipt (1 KiB maximum) and a fresh project list, never selecting another project.
  Source files are untouched. This is not Forget/suppression or forensic erasure;
  SQLite free pages, sidecars, backups and exports may retain bytes. Re-registration
  may import source evidence, not old notes. Cancellation/failure can have an
  uncertain persisted outcome: Refresh before retrying; no rollback is promised.
- Context includes explicit **Prepare context** for the selected project: a bounded
  query plus an editable in-memory original (not a persisted human note). Actual
  `context prepare` output shows the unchanged original and quoted untrusted
  evidence as selectable plain text, snapshot and ready-for-review/needs-input.
  Context-only means no AI, approval, save/copy/send action or host handoff.
  Currentness is checked at preparation read, not guaranteed afterward. Editing
  query/original cancels and invalidates pending/displayed previews immediately;
  cancel/dismiss retains the draft. Project changes clear both draft fields.
  Source changes, rebuilds, context mutations, configuration, cancel and Quit
  also invalidate previews. Output is strictly checked and bounded to 8 KiB.
  This covers only parts of P4-A1–P4-A3 and the P3 project/privacy boundaries;
  refinement, approval, delivery and full native accessibility acceptance remain open.
- Launch creates a quiet status item, **not** a management window or core call.
- Projects require explicit root and exact relative file approval, then explicit
  Build. Omitted files are excluded. Editing policy cancels the current UI job
  and invalidates displayed evidence immediately; Apply replaces the core policy,
  including an empty list for complete source revocation. Core validates actual
  files/symlinks/size/readability. No recursive scan is performed by the shell.
- Build has a textual stage, indeterminate progress (no invented percentage),
  cancel and bounded duration. Snapshot and core coverage remain inspectable.
  A recorded snapshot is never itself labeled current or complete. Current core
  indexing is lexical source-line evidence, not AST/semantic understanding.
- Human context add/edit/retire routes to core, with content only on stdin and
  inspectable revision history. The shell never implements a second database.
- Source evidence is scoped to the selected registered project and its approved
  file list. Project/source-policy changes and cancel reject late UI results.
  A host-project mismatch stops rather than selecting another project's context.
- A replacement operation cancels/invalidates UI immediately, then joins all prior
  owned operations before calling the service. A canceled mutation cannot commit
  after a replacement policy or refresh overtakes it. Join and Quit also include
  outstanding work whose visible job was already canceled.
- Pause/resume changes scheduling state only; there is no automatic scheduler,
  watcher or unsolicited core operation in this lane. Explicit Build is labeled
  manual and can run while automatic scheduling is paused.
- Closing Manage retains the window/model and owned job. A one-time close
  explanation distinguishes it from Quit. Quit cancels **all** outstanding owned
  operations (including previously superseded ones), waits for adapter teardown,
  then exits. No process names, process groups or unrelated tasks are killed.
- Connections separates the local subprocess transport, unavailable inference
  profiles and unavailable/not-certified host adapters. There are no credential
  fields, network/send actions or silent sample fallback.
- Configuration and drafts/previews are memory-only. Relaunch requires selecting
  the executable/data directory again; core persistence is not shell persistence.
- No notifications, telemetry, content archive, custom animation, login startup
  or automatic source/provider calls. Standard native controls/system appearance
  provide the compiled accessibility starting point, not a runtime certification.

## Transport integration

The user selects an exact trusted executable, then deliberately chooses either
an existing **known initialized core store** (not an empty directory), or an
existing parent plus a new store name. Selection/configuration creates nothing;
the next explicit core operation creates the new store with mode 0700. Store
selection resolves the chosen parent/known store with POSIX `realpath` (Foundation
can shorten private temporary paths back through a symlink). Core still validates
store permissions/identity. For a new store, the child's working directory is its
existing parent, not the absent store. `posix_spawn` receives an argument array,
explicit cwd/file actions, `POSIX_SPAWN_CLOEXEC_DEFAULT`, and only `LANG`/`LC_ALL`
in its environment. There is no shell, PATH discovery,
HOME credential lookup or listener. Until configured, production visibly fails
`unavailable`. Selecting a binary is not a version check or trust certification.

`CoreService.perform(Operation)` exposes exactly the contract's operations.
Command mapping follows the coordinator-provided CLI. Project list is a JSON
array; project show is a summary object. Most mutation output must be valid JSON;
the model re-reads authoritative project/context state instead of guessing a
mutation's response shape. Opaque `coverage`, `root_identity`, `authority` and
snapshot values are preserved as JSON rather than assigned invented semantics.

Bounds: 64 projects; 64 source paths; 4 KiB context stdin; 256-byte query text; 1 MiB stdout
(query: 8 KiB / eight results); 16 KiB stderr; 30 seconds wall time. Bounds reject,
never truncate input. Both output streams are drained without blocking; stderr
content is discarded. A single bounded I/O thread is the child's **sole reaper**.
It checks `waitpid(WNOHANG)`, sends TERM only while the identity is unreaped,
then at most one KILL after 200 ms if needed. An exited unreaped child reserves
its PID; once reaped or `ECHILD` occurs, all signals stop immediately. There is
no Foundation Process auto-reaper/PID-reuse race, global signal handler, process
group kill or generalized worker supervisor. Nonzero exit is a content-free typed
failure; the shell does not parse or expose private CLI diagnostics. Refresh is
required to inspect core state after uncertain mutation outcomes; UI cancellation
does not claim that a previously committed core transaction was rolled back.

`CompanionTestProcess` is an explicitly selected synthetic fixture used only by
tests. The application has no dependency on it. Fake tests do not establish a
live Rust link, tray behavior or a background process.
The separate opt-in live suite establishes only the real CLI adapter operations
it actually exercises; native tray/window/accessibility acceptance remains open.

## Coordinator-owned native acceptance (not run here)

After separate authorization and core CLI integration:

1. Open the packaged app, verify the tray appears with no scan/provider call;
   open Manage using keyboard navigation and a screen reader.
2. Configure an exact core binary/private data directory; approve a synthetic
   root and exact files; Build; inspect snapshot, coverage and stale/current labels.
3. Close Manage during a job, verify tray status and background continuation;
   reopen without losing the job. Cancel/revoke sources while updating; verify
   core atomicity independently from the shell's late-result guard.
4. Switch between incompatible projects and exercise failures/recovery. Add/edit
   a decision, inspect history, retire, rebuild and restart; verify core durability.
5. Verify pause/resume vs explicit Build vs close vs Quit, including worker exit.
   Check light/dark, reduced motion, focus order, text labels and screen reader.

Phase 1 live host/inference gates stay OPEN. Full P3-A1–P3-A6 acceptance remains
open pending these observed journeys. Forget, conflict resolution, export,
login startup, automatic scheduling, host certification and inference are visibly
unavailable or outside client-v1, not simulated by the shell.
