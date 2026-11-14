# Native human-context search — Lane E

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6,
P3-A3/A4/A5/A6. This is a concrete SwiftUI view bound to the existing
`CompanionModel` and actual core CLI, not a separate sample application.
No phase closure or app GUI acceptance is claimed.

## Integration and ownership

Started in the assigned T3 isolated worktree at coordinator `661bdb3`.
Fetched and merged reviewed `origin/main` containing
`530fe81c396d6984637fd00bb980bfa034e02478`, then cherry-picked the required
Lane C implementation `1c49e1ab41f75d8a72c35639bd437f74f6ef9e0d` as
`3df4dfe` and evidence `5d5b36bbc80c98e5cccf1ceee5ae3b83ca1cead4` as
`b09e67e`. Those prerequisite commits are separate from Lane E changes.
No branch switch, manual worktree, reset, discard, or subdelegate.

Primary's exact one-line mount inside the existing Context tab's VStack,
alongside the existing context list/history/editor (for example immediately
after `ContextPreparationView(model: model)` and its divider):

```swift
HumanContextSearchView(model: model)
```

Public API: `HumanContextSearchView.init(model: CompanionModel)`,
`CompanionModel.searchHumanContext(_:)`, `canSearchHumanContext`,
read-only `humanSearch`, `humanSearchQueryChanged()`, and
`inspectHumanSearchEntry(_:)`. Inspection loads the existing history pane,
without setting or replacing view-local unsaved editor fields. Existing
explicit Edit/Retire/Forget remain the only mutation controls.

Owned runtime changes are only minimal additions to `Contract.swift`,
`ProcessService.swift`, `CompanionModel.swift`, and the new
`HumanContextSearchView.swift`. New tests are `HumanSearchTests.swift` and
`LiveHumanSearchTests.swift`; the existing fake in `CompanionTests.swift`
adds one unavailable case for the new exhaustive Operation enum.
Native `main.swift`, provider settings/persistence, Rust/CLI/daemon,
generated locks/schemas/dependencies and inherited progress docs are untouched
by Lane E (the explicitly required C prerequisite commits are separate).

## Contract, safety and lifecycle

`Operation.searchHumanContext(project, query)` maps to the actual
`context search PROJECT QUERY` command, with empty stdin. Query is necessarily
an argv positional per this CLI contract; no claim that query text uses stdin.
The existing runner uses the exact configured executable/private store,
no shell/PATH lookup or ambient credential environment, bounded output/time,
and joins/reaps its owned child before returning cancellation or timeout.
Query validation matches core: at most 256 UTF-8 bytes before trim, nonempty
after Rust Unicode-whitespace trimming, no Unicode control characters.

The typed human receipt has a closed top-level/entry field set, exact human
producer/status/authority/coverage/selection labels, valid IDs/kinds/revisions,
complete nonempty text up to 4096 UTF-8 bytes with no NUL, at most eight unique
entry IDs, matched count up to 4096, exact omitted/matched/result consistency,
and a whole 8192-byte JSON envelope including newline. Raw output and typed
re-encoding are bounded; no text is sliced to fit. Legacy null incarnation can
decode at the transport boundary, but native cached adoption requires a valid
current non-null incarnation, matching project/root identity/incarnation.

Search reuses the private service, namespace helper and owned serialized
`start` path. Project/root/root-identity/incarnation are checked before and
after the read, and receipt identity is checked before publication. Replacement,
cancellation, supersession, configuration/project/policy switches, and relevant
write/retire/human Forget/source Forget invalidate search state. Query edits
invalidate displayed results and cancel any owned search. A replacement joins
even cancellation-ignoring prior work before dispatch. Search cancellation says
“requested” until the owned operation has joined; late callbacks cannot publish
or overwrite newer status. Existing namespace-loss behavior deliberately clears
old-scope drafts rather than adopting them into a new registration. Same-scope
search/error/inspection and source-only policy staging preserve original and
view-local human drafts (no editor-revision increment).

The view labels human-authored context separately from observed source evidence,
shows project scope, latest-active-at-read limitations, whole-entry omission
counts and both selection bounds, and offers explicit history inspection.
No rule is auto-approved, executed or treated as permission. No source-content
read, inference, hidden Send/provider action, host delivery, file export,
credential reuse, startup registration, notification or content log is added.
Core performs lexical matching; the UI does not duplicate Unicode ranking.

## Acceptance evidence

All fixtures are synthetic, local and disposable; no Docker was needed.

- P2-A1 / P3-A3: strict project/receipt namespace checks; null-incarnation native
  refusal; fake post-read replacement and actual second-process same-root
  re-registration reject adoption, preserving the replacement's own history.
  Actual similarly named other project retains its distinct note.
- P2-A2 / P3-A4: actual CLI add/search/edit changes kind/revision/text; matching
  superseded history disappears; retirement excludes the entry. Human Forget
  excludes every target revision after reopen, without affecting other notes.
- P2-A3 / P3-A5: cancellation-ignoring worker joined before replacement;
  late results suppressed after cancel/project/config/source/quit changes;
  typed errors/unknown responses fail closed, and explicit retry recovers.
  Actual subprocess timeout and cancellation return only after child reap
  (synthetic child PID no longer exists). No claim that canceled writes roll back.
- P2-A4: exact human provenance/status/authority and coverage; source labels,
  unknown fields, bad kinds/revisions, duplicate IDs and inconsistent counts
  rejected. Actual source snapshot/policy and source file bytes remain unchanged
  across human search/edit/retire/Forget; no source-fact label is introduced.
- P2-A5 / P3-A4: actual native bound Forget excludes target from later searches
  and reopened transport. Other-project context and source bytes are preserved.
- P2-A6: Unicode byte/control/whitespace query boundaries, exact process argv,
  empty stdin, no inherited credential environment, malformed/unknown/overlimit
  output, entry/text/count bounds and valid whole-entry omission tested.
  The Apple Python fixture shim adds only its known toolchain metadata to the
  runner's two-variable environment; arbitrary inherited variable names fail.
- P3-A6: native view compiles with accessible labels, keyboard submit, text-only
  status and selectable plain text. Actual VoiceOver/AX/keyboard walkthrough
  remains unverified. Known real AX failure `-1728` was not retried; no permissions,
  desktop capture or host launch changes were made.

## Verification and remaining gates

Local checks and full tested SHA are recorded in the appended verification
record after the implementation commit. Initial checks caught the installed
SDK's unshipped same-named State macro (fixed using the existing application's
typed property-wrapper alias), the synthetic Python shim's added environment
metadata (fixture allowlist corrected), and an invalid duplicate-root fixture
(fixed to use separate project roots). The secret gate initially flagged a
synthetic registration constant named like a credential; renamed it to describe
its actual non-secret incarnation role without relaxing scanner rules. These
were test/setup failures, not waived.

Main-tab mount is **not done** by this lane. Independent native review,
integrated-head CI, real mounted app/AX walkthrough, representative retrieval
quality/scale evaluation and complete Phase 2/3 acceptance remain **not run**.
There is no Lane E PR/CI run/head: no push, PR, watch, merge, schedule, install,
deploy or release was requested or performed. Prior main/PR checks do not certify
this lane. Plum coordination was unavailable (linked environment unreachable).

## Local verification record

Tested implementation SHA: `136429b26abf06893b41924c97b18570a22e45dd`.
The subsequent Lane E evidence-only commit appends this record; its full tested
SHA is supplied in the final handoff after rechecking that evidence head.

- `python3 scripts/check.py`: **PASS**. Locked build, format, warnings-denied
  Clippy, all Rust workspace tests/doctests/docs, CLI/daemon diagnostics,
  documentation links and intentional-failure gate passed. This includes the
  prerequisite's six human-search core tests and three real-process CLI tests.
- `cargo deny --locked check`: **PASS** (advisories, bans, licenses, sources).
- `python3 scripts/secrets.py`: **PASS**, after staging only the eight explicitly
  owned native/test/evidence paths. Tracked-file/history scan and negative probe
  both passed. No scanner rule/configuration was changed.
- `cargo build --locked -p threadmark-cli`: **PASS**, followed by the full strict
  documented Swift wrapper with the absolute rebuilt CLI explicitly supplied:

  ```sh
  THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
    sh apps/companion/scripts/swift.sh test \
    --disable-xctest --enable-swift-testing -Xswiftc -warnings-as-errors
  ```

  **PASS: 114 tests in 11 suites**, including all opt-in real-core tests (none
  skipped), eight new native test functions plus one new live-core journey.
  The new journey also succeeds while the approved synthetic source is
  unreadable; source bytes and the recorded source snapshot remain unchanged.
  Swift source warnings are errors; the inherited wrapper still emits the
  SwiftPM native-build-system deprecation notice, and a clean link emits the
  existing macOS 13 target / Testing.framework macOS 14 linker warning. Neither
  warning was hidden, changed or treated as GUI/runtime acceptance.
- `git diff --check`, `git diff --cached --check`: **PASS**.
- Independent Lane E review: **NOT RUN**; primary owns review/integration.
- Lane E exact-head remote CI: **NOT RUN**; no run ID/URL/head exists.
- Mounted app GUI/AX and retrieval-quality evaluation: **NOT RUN**.

No Docker resources, real user store/content, credential, global configuration,
network inference, desktop capture, host launch or external publication was used.
The completed assigned worktree remains intact for primary integration.
