# Native macOS companion shell

Independent Phase 3 shell for TM-01–TM-03, TM-07 and TM-10, adapting the frozen
[client-v1 contract](../../docs/contracts/client-v1.md). SwiftUI management views
and an AppKit `NSStatusItem`; no webview, third-party package or Rust workspace
change. Core remains responsible for storage, indexing, authorization, source
identity/currentness, human revision history and transactional cancellation.

## Build and test (no launch)

From the repository root, using the installed Swift/SDK only:

```sh
sh apps/companion/scripts/swift.sh build --product ThreadmarkCompanion
sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing
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

## Product boundary

- Launch creates a quiet status item, **not** a management window or core call.
- Projects require explicit root and exact relative file approval, then explicit
  Build. Omitted files are excluded. Editing policy cancels the current UI job
  and invalidates displayed evidence immediately; Apply replaces the core policy,
  including an empty list for complete source revocation. Core validates actual
  files/symlinks/size/readability. No recursive scan is performed by the shell.
- Build has a textual stage, indeterminate progress (no invented percentage),
  cancel and bounded duration. Snapshot and core coverage remain inspectable.
  A recorded snapshot is never itself labeled current or complete.
- Human context add/edit/retire routes to core, with content only on stdin and
  inspectable revision history. The shell never implements a second database.
- Source evidence is scoped to the selected registered project and its approved
  file list. Project/source-policy changes and cancel reject late UI results.
  A host-project mismatch stops rather than selecting another project's context.
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

The user selects an exact trusted executable and an existing private data
directory. `Process` receives an argument array, an explicit working directory,
and only `LANG`/`LC_ALL` in its environment. There is no shell, PATH discovery,
HOME credential lookup or listener. Until configured, production visibly fails
`unavailable`. Selecting a binary is not a version check or trust certification.

`CoreService.perform(Operation)` exposes exactly the contract's operations.
Command mapping follows the coordinator-provided CLI. Project list is a JSON
array; project show is a summary object. Mutation output must be valid JSON;
the model re-reads authoritative project/context state instead of guessing a
mutation's response shape. Opaque `coverage`, `root_identity`, `authority` and
snapshot values are preserved as JSON rather than assigned invented semantics.

Bounds: 64 source paths; 16 KiB context stdin; 4 KiB query text; 1 MiB stdout
(query: 8 KiB / eight results); 16 KiB stderr; 30 seconds wall time. Bounds reject,
never truncate input. Both output streams are drained without blocking; stderr
content is discarded. Timeout/cancel first terminates, then kills only the owned
child after 200 ms if needed, and reaps it. Nonzero exit is a content-free typed
failure; the shell does not parse or expose private CLI diagnostics. Refresh is
required to inspect core state after uncertain mutation outcomes; UI cancellation
does not claim that a previously committed core transaction was rolled back.

`CompanionTestProcess` is an explicitly selected synthetic fixture used only by
tests. The application has no dependency on it. Fake tests do not establish a
live Rust link, tray behavior or a background process.

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
open pending these observed journeys. Forget, conflict resolution, cleanup/export,
login startup, automatic scheduling, host certification and inference are visibly
unavailable or outside client-v1, not simulated by the shell.
