# Approved-file events with periodic reconciliation

Requirements: TM-01–TM-03, TM-07, TM-10; partial P2-A2/P2-A3/P2-A6 and
P3-A1/P3-A2/P3-A3/P3-A5. Exact tested integration:
`9680d643d3c31b0484c834e96ea77b3b3c9c237b`, based on PR #48 merge
`399f0c8d472c6dc7669f0247182dff3de5bb7b47`. Ancestry integration changed no
reviewed tree content. Bob implemented; the coordinator owns publication.

## Actual behavior

Opt-in refresh now installs metadata-only Dispatch sources on at most 64 exact
approved files, never a whole-directory event stream or recursive enumeration.
Descriptor-relative no-follow traversal checks root identity and rejects unsafe
file kinds/links, nested repositories and mount changes. Intermediate descriptors
close during setup; watch descriptors are owned and released on stop/failure.
One pending delivery and 300-ms debounce bound event bursts. Rebinding follows
atomic replacement; existing 60-second full lexical reconciliation covers missed
or busy-skipped hints. Missing/unavailable paths stop monitoring with Needs attention
rather than silently widening access or reading an old inode indefinitely.

Consent remains default-off, session-only and bound to root identity, incarnation
and exact sources. Pause/disable/revocation/configuration/selection/removal/Forget/
Cancel/Quit stop producers and late callbacks; manual actions retain priority and
serialized teardown. Closing management preserves opted-in background behavior.
No inference, network, host launch, persisted consent or login item is introduced.
This is bounded full lexical reconciliation on hints, not incremental AST coverage.

## Independent review and repairs

Joffrey found a high-severity implementation gap: filesystem identity checks and
the later bound index did not authorize metadata watch installation. The original
handoff's preflight claim was not present in the reviewed working tree. Bob repaired
the production driver to call the configured actual `CoreService.project` before
every initial install/resume/event/periodic rebind and compare all captured scope
fields. Old watches close before awaiting authority; generation checks prevent
late opens. One retained query coalesces restarts and shutdown joins teardown,
including cancellation-ignoring fixtures. Tests prove zero additional install/open
attempts for stale incarnation and externally revoked policy, not only eventual
zero watch count. Joffrey independently closed the high and passed all 82 tests.

A remaining medium presentation defect showed “enabled” before async readiness.
The coordinator changed the management header to “approved,” using a tested model
summary; actual readiness remains in the guarded status callback. A held-authority
assertion verifies no enabled claim before setup. Preflight is not an atomic lease
against concurrent external revocation; core still rechecks before content access
and transactionally before publication. No stronger guarantee is claimed.

## Integrated evidence and limits

The coordinator rebuilt the exact integrated tree: full Rust check pipeline passed
(118 tests plus two doctests), and all 82 strict Swift tests passed against the
actual rebuilt core. Coverage includes real event-to-SQLite refresh, atomic
replacement, periodic fallback, approved/omitted/other-project isolation, debounce,
pause/revocation, late callbacks and descriptor cleanup. Final release bundle and
plist validation passed after the last edits, as did dependency policy, staged
secrets and whitespace checks. No schema/dependency/generated lock changed.

Remote exact-head CI remains a subsequent gate. Cross-device and unsupported-
filesystem fixtures, native GUI/accessibility runtime, source-derived Forget,
live providers/hosts and full phase closure remain open. No private user-source
watching was enabled. All inherited appends, user work and worktrees were preserved;
the entire inherited Phase 2 ledger remains excluded, including a delegate append.
