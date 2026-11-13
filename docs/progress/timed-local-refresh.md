# Opt-in timed local lexical refresh

Requirements: TM-01–TM-03, TM-07, TM-10; partial P2-A2/P2-A3/P2-A6 and
P3-A1/P3-A2/P3-A3/P3-A5. Exact tested integration:
`5864a2a3f1c316cb1d6714be93c0daf8d716e19c`, based on PR #44 merge
`7f6e2a248c0ec18b75bd814d1e910b62c8a15fb2`. Ancestry integration changed no
reviewed tree content. Bob implemented; the coordinator owns publication.

## Actual background behavior

One owned Foundation Timer drives explicit, session-only consent for one loaded
project's exact root identity and approved file policy. It is **off by default**,
uses a 60-second interval and the existing bounded lexical indexer, and does not
enumerate new sources, invoke inference or persist consent. Busy ticks are skipped,
never queued; manual operations preempt automatic work and await owned teardown.
Closing management leaves opted-in refresh active; pause, disable, source-policy
changes, selection/configuration changes, removal and Quit stop automatic reads.
Failures stop scheduling with a content-free Needs attention state and require
explicit repair/re-enablement, not an automatic retry loop.

The real CLI/core operation binds expected root, root identity and exact files
before source access, then existing transactional revalidation guards publication.
Reusing an ID cannot redirect automatic reads. Automatic indexing requires an
existing recognized store and cannot recreate a missing store. Source limits,
subprocess timeout/output budgets and currentness semantics remain unchanged.
Human notes and editor drafts are not overwritten or archived; actual index work
invalidates dependent previews. No login item, OS notification, network request,
host launch or filesystem watcher is installed. This is timed bounded full lexical
reconciliation, **not** event-driven/debounced incremental structural indexing.

## Review, failures and repair

Joffrey independently reviewed the new runtime and bound-index paths with no
substantive findings. His initial full 51-test Swift run nevertheless failed an
existing cancellation test and the concurrent actual-core lifecycle test; focused
reruns were not accepted as a clean full result. The coordinator found a concrete
isolation defect: the fixture's non-atomic PID-marker write could expose an empty
file, and the test defaulted parse failure to PID 0. Its nonfatal assertion then
allowed `waitpid(0, ...)`, which can reap another test's child and make that
adapter fail with ECHILD. This is a credible explanation for the paired failures,
not proof of their exact historical interleaving.

Both marker publications are now atomic. Both wait callers require a parsed
positive PID before any wait, eliminating process-group sentinel targets.
Joffrey separately re-reviewed the repair and ran **two complete strict Swift
suites**, each passing all 51 tests/four suites including both actual-core journeys.
The original failed run remains failed; no check was waived.

## Integrated verification and limitations

The coordinator's full check pipeline passed on the exact integration: 83 Rust
tests plus two doctests, formatting, strict lint, docs, smoke, links and negative
gate. All 51 strict Swift tests passed against the rebuilt actual Rust CLI.
Coverage includes a real Timer callback, deterministic consent/pause/revocation/
priority/late-result tests and real private SQLite updates after approved-file
changes. Bob's release bundle/plist passed. Dependency policy, staged secrets and
whitespace checks passed. No schema/dependency/lock change or private user-source
scan was performed. Remote exact-head CI is a separate subsequent gate.

Native GUI/accessibility runtime, robust filesystem event watching/overflow,
Forget, live providers/hosts and phase closure remain open. User work, inherited
progress appends and worktrees were preserved; no orchestration reminder changed.
