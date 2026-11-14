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
# After explicitly rebuilding core (synthetic data only):
python3 apps/companion/scripts/source-forget-core.py --binary "$PWD/target/debug/threadmark"
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

- Existing human-note Save and Retire use the reviewed four-flag
  [expected-revision contract](../../docs/contracts/human-context-revision-v1.md),
  carrying the loaded registration root/identity/incarnation and exact revision
  into core's atomic compare-and-append. Save requires the editor's explicitly
  captured base and matching loaded history; Retire requires matching loaded
  history. Missing legacy metadata fails closed without a child write. Add remains
  namespace-bound creation, never revision zero or an update fallback.
  Inspect/reload keeps the unsaved editor and its old base; **Edit loaded revision
  (replace editor)** is an explicit replacement, not automatic conflict resolution.
  Same-namespace rejection/cancellation retains loaded history, the human editor
  and original request. A replaced registration still clears old drafts under the
  existing namespace policy. Generic CLI failures with corroborating changed
  history/suppression metadata explain the conflict; cancellation, timeout, invalid
  receipts and post-commit read failures remain uncertain (not proof of no write).
  Successful history is adopted only after namespace revalidation. This CAS
  protection is not semantic conflict resolution or Phase 2/3 completion.
- Source Query and Context-only preparation share an explicit, session-memory-only
  **Literal (default)** / **Ranked lexical terms (opt-in)** picker. Ranking matches
  any of 1–8 deduplicated Unicode-lowercase whitespace terms (64 UTF-8 bytes per
  term, 256 bytes/query), by distinct matched terms then occurrences, with
  path/line ties. It is not semantic completeness, stemming or normalization.
  Refine stays literal, independently of this picker; selecting ranking invokes
  no provider. Changing mode cancels owned work, invalidates cached source results,
  Context/refinement previews and consent, and rejects late output while retaining
  the original draft. Nothing is automatically copied, delivered or sent.
  Native `query-terms` and `context prepare ... --terms` carry the exact cached
  root/root-identity/incarnation/source-policy/snapshot into core before source
  traversal and through Context engine revalidation; no ID-only reload fallback.
  The mode flag precedes binding flags, and `--expected-sources` remains the final
  exact list. Matching metadata is stale-UI protection, not authentication.
  Ranked results disclose terms, coverage and omitted matches; Context discloses
  ranked coverage alongside quoted evidence. Literal response defaults are unchanged.
- Projects offers **Remove local project…** only after loading a root identity
  and a validated schema-v3 registration incarnation.
  An immutable, cancel-default confirmation displays the exact ID/root/identity
  and loss of all local notes, history, evidence and policy. Confirmation runs
  `project remove ID --confirm-remove-local-data --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN`
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
  Native Apply and human add/edit/retire bind the captured root, root identity and
  registration incarnation; Apply additionally compares the exact old source
  list inside the write transaction. There is no legacy/unbound native fallback.
  Schema v1/v2 requires an explicit CLI v3/v4 upgrade after stopping legacy workers.
  A replaced registration clears the human editor, original draft and context
  display without adopting the replacement; uncertain failures require Refresh.
  Source-only changes in the same registration retain unsaved human drafts.
- **Forget entry…** requires loaded human history and a valid schema-v3
  incarnation. Its cancel-default immutable prompt displays project/context,
  root/identity/incarnation, latest revision and total revisions to remove.
  Only confirmation clears the human editor/history and prepared previews;
  the unrelated original request draft is preserved. Edits, scope/configuration
  changes, rebuild, pause, cancel, removal and Quit invalidate approval.
  Native calls always bind all four expected values, including latest revision;
  core rechecks them inside the immediate deletion transaction. No note text or
  original request is passed in Forget argv or stdin. A strict 1 KiB receipt alone
  is insufficient: fresh context absence and marker presence must be bracketed
  by project inspections of the same root/identity/incarnation before UI use.
  Cancellation, malformed receipts and uncertain follow-up require Refresh, not
  a claim of rollback. An explicit action inspects only bounded non-content
  suppression IDs, never an archive. Active removal/same-scope suppression is not
  forensic erasure or recall of backups, earlier exports or displayed copies.
  Source Forget is separate in Projects as described below; restore and unforget remain unavailable. Synthetic model,
  subprocess and opt-in live SQLite tests cover partial P2-A3/P2-A5/P3-A4;
  native walkthrough/accessibility acceptance and full Phase 2/3 remain open.
- **Inspect source suppression markers** explicitly verifies schema-v4 metadata,
  bracketed by exact project/root/root-identity/incarnation/source-policy checks.
  An incarnation alone is only a v3 capability, not evidence of v4. Only a
  successful inspection in the current selected scope enables **Forget source…**
  for each currently registered approved file; plain allowlist editing is separate.
  Its immutable Cancel-default prompt captures the entire ordered source policy
  and warns that all project source snapshots are invalidated, remaining files
  need rebuilding as needed, and this path's read/reimport authority is revoked
  with a non-content suppression marker and no unforget. Source files, human
  revision history, unsaved human editor and original request draft are untouched.
  The native call always includes `--confirm-forget-source --expected-root ROOT
  --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-sources FILE ...`;
  no root-only fallback or unbound idempotent repeat is used.
  Confirmation immediately invalidates source evidence/index reports/previews and
  blocks Build/query/Prepare/policy Apply while outcome is uncertain. Success
  requires a strict content-free receipt (1 KiB, exact fields, initial snapshot
  invalidated), remaining policy equal to the captured policy minus that file,
  and marker presence bracketed by fresh matching project metadata. Replacement
  registrations/policies never become authority for an old prompt. Failure/cancel
  requires Refresh; no rollback or automatic retry is claimed. Automatic timer,
  watches and owned async metadata preflight stop and are joined before deletion.
  The marker list is at most 1 MiB/64 sorted unique validated paths (240 bytes
  each), not an archive/export/restore capability. Earlier displayed copies,
  exports, journals and backups are not erased or recalled.
  Failed inspection offers generic permissions/Refresh and explicit v4 guidance:
  `store upgrade --to-version 4 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped`.
  Stop old workers first; the confirmation is operator attestation, not machine
  proof. No implicit upgrade or native upgrade panel is provided. Human-editor
  reset is namespace/human-Forget-specific, not triggered by source-only policy
  revisions. Synthetic model/subprocess and opt-in rebuilt-core tests cover
  bounded P2-A1/P2-A3/P2-A5/P3-A3/P3-A4/P3-A5; GUI/accessibility remains OPEN.
- Source evidence is scoped to the selected registered project and its approved
  file list. Project/source-policy changes and cancel reject late UI results.
  A host-project mismatch stops rather than selecting another project's context.
- A replacement operation cancels/invalidates UI immediately, then joins all prior
  owned operations before calling the service. A canceled mutation cannot commit
  after a replacement policy or refresh overtakes it. Join and Quit also include
  outstanding work whose visible job was already canceled.
- Optional **approved-file events + periodic bounded full lexical reconciliation** is off by default and
  session-memory-only. Projects shows the selected ID, root, root identity, exact
  approved files, 60-second interval and bounds before explicit Enable consent.
  Explicit consent covers metadata watches and automatic approved-content reads.
  Enable resumes this scope and installs `DispatchSourceFileSystemObject` watches
  on only the exact approved files plus one owned 60-second Foundation Timer.
  Setup opens metadata-only `O_EVTONLY` descriptors, never reads source contents,
  enumerates directories or watches parent directories/the whole project.
  Absolute root and relative components are descriptor-walked with `O_NOFOLLOW`;
  the opened root must match the captured device/inode. Symlinks, hardlinks,
  nonregular files, nested repositories/submodules and cross-device sources are
  rejected, consistent with the core boundary. There are at most 64 watched file
  descriptors and a fixed few temporary descriptors during setup (directory
  walk plus one native registration-preflight kqueue). A successful `EV_RECEIPT`
  vnode registration is required for each file; DispatchSource itself has no
  registration-error callback. The preflight never watches a directory or reads
  contents, and is closed after setup.
  Failed setup closes the entire set; there is no partial-coverage fallback.
  There is no immediate content read. Resume alone never grants consent.
  A clean nonempty loaded policy, known root identity, validated registration
  incarnation and configured core are required. Automatic CLI calls include
  `--expected-incarnation` and revalidate transactionally before publication,
  even after identical-directory re-registration.
  File events coalesce into one pending 300-ms trigger, including a bounded
  dispatch-to-main-actor hop. Event hints never grant authority: every resulting
  full lexical reconciliation uses the existing scope-bound core operation.
  The timer reconciles all approved contents for missed/busy events; this is not
  platform overflow detection/certification. Before every event or periodic hint,
  watches are closed/joined and securely rebound to the current exact paths.
  Atomic replacement therefore watches the replacement inode for later edits.
  Deleted/unavailable paths stop monitoring with Needs attention; no automatic
  permission repair or silent incomplete watch coverage is claimed.
  Pause invalidates watches, debounce and timer and cancels automatic work; resume
  reuses only the same valid consent after validating setup again. Manual
  operations take priority; busy event hints/ticks are skipped with
  no queue, overlap or cancellation thrashing. Closing Manage leaves opted-in work
  active. Disable, selection/refresh, source-policy edits/revocation, configuration,
  removal, explicit Cancel and Quit immediately stop all producers and invalidate
  consent/late results. Generation checks reject already-queued old callbacks.
  Cancellation joins teardown before replacement work. Failure stops all producers and
  shows content-free Needs attention; repair and explicit re-enable are required.
  Successful reconciliation updates the snapshot report and invalidates prepared
  evidence, but never changes the original draft, query, human notes or editor scope.
  This is bounded full lexical work, not incremental AST/symbol extraction,
  debounced inference, broad source discovery or full phase acceptance.
- Legacy v1/v2 projects show explicit v3 upgrade guidance and disable native
  Forget/cached removal/automatic refresh; noncached manual actions remain available. Stop
  older companions/workers and let pending work terminate, then explicitly run
  `store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped`.
  This is operator attestation, not machine proof or fencing of old pending
  workers. No implicit migration or native upgrade panel is introduced.
  Explicit Build remains manual and available while paused.
- Closing Manage retains the window/model and owned job. A one-time close
  explanation distinguishes it from Quit. Quit cancels **all** outstanding owned
  operations (including previously superseded ones), waits for adapter teardown,
  then exits. No process names, process groups or unrelated tasks are killed.
- Connections separates the local subprocess transport, explicit default-off
  provider profiles and unavailable/not-certified host adapters. Profiles can be
  saved/loaded only through explicitly chosen private files; loading leaves them
  off. There are no credential fields, host send actions or silent sample fallback.
- Drafts/previews remain memory-only. Core/store selection is explicit on relaunch
  or through paired launch arguments; no global preferences are discovered.
  Nonsecret profile persistence never stores drafts, source excerpts or consent.
- Context and human-note search do not invoke inference. Local Refine preview
  requires a separate immutable Cancel-default confirmation of the exact original,
  selected source evidence, profile/model/endpoint and one-call budgets. It sends
  only that disclosed data to numeric-loopback HTTP; a local server may forward
  data elsewhere. Remote TLS/auth and protected credential entry are unavailable.
  The finite CLI returns a reviewable preview, not retained approval, clipboard,
  host draft, send or downstream success. Cancel/failure preserves original text.
- No notifications, telemetry, content archive, custom animation, login startup
  or automatic provider calls. Automatic source reads require the separate file-event/periodic
  refresh consent above. Standard native controls/system appearance
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

`CoreService.perform(Operation)` exposes the contract's operations plus an additive
scope-bound lexical index variant used for every automatic job:
`index ID --expected-root ROOT --expected-root-identity IDENTITY --expected-sources FILE ...`.
Core validates malformed bindings before opening/creating storage, compares the
entire approval before reading any source, and rechecks the same captured policy
transactionally before publication. A reused ID at a different root, replaced root
identity or changed file policy fails closed; model-only scope checks are not
authority. Bound reconciliation requires an existing recognized store and never
recreates a missing store on a tick. These bindings prevent stale approval, not
authenticate a caller.
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
open pending these observed journeys. Native conflict-resolution/export UX,
login startup, incremental structural indexing and host certification remain
unavailable. Confirmed local Refine has synthetic CLI/HTTP acceptance, not live-model
quality or GUI certification. Remote inference and actual host delivery remain open;
no phase is closed by a compiled control or passing fixture.

The deterministic model tests exercise injected ticks. Synthetic native tests
exercise actual DispatchSource approved-file events with bounded async delivery
expectations, burst collapse, atomic replacement/further edits, stop/scope-change
late-callback rejection, deletion failure, unsafe path rejection, the 64-handle
bound and exact close tracking on setup failure/stop. The real Foundation Timer
callback simulates missed events without waiting 60 seconds. No mount fixture is
created; cross-device rejection is implemented, not independently runtime-proven.
Opt-in live-core tests drive real native events and consent/ticks
through the actual adapter and built Rust CLI into SQLite, including source
modification, pause/revocation, human-note/draft preservation, omitted-file and
other-project isolation, and an external same-ID/root replacement. These cover
bounded parts of P2-A1–P2-A3/P2-A6 and P3-A1/P3-A3–P3-A5; observed GUI/accessibility,
structural/symbol extraction and complete phase acceptance stay open. Native
event tests are headless synthetic tests, not observed GUI/runtime certification
on all supported macOS versions. This unit covers bounded parts of P2-A2/P2-A3
and P3-A1/P3-A5; no platform-wide lost-event guarantee is claimed.

Every initial enable, resume, event rebind and periodic rebind first queries
`project show` through the configured core service and compares the exact approved
ID/root/root identity/incarnation/source list. Monitoring remains pending until
that query and native setup succeed. Reconciliation closes the previous watch set
before awaiting authority; a mismatch/failure stops monitoring with Needs attention.
One owned query is retained through cancellation and joined by shutdown; repeated
starts replace only the latest desired scope, and hints during a query coalesce.
Generation checks prevent late canceled results from opening descriptors or
reporting readiness. This preflight is not an atomic external-revocation lease:
changes after observation are caught at the next validation, and content indexing
still requires the core's transactional `indexBound` scope check.
