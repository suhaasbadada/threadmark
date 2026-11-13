# Human-context Forget and explicit schema upgrade

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A3/P2-A5 and P3-A4.
Exact tested integration: `debb6a216133cab0f0cd04dcb289b86ff18c53c8`, based on
PR #45 merge `2cb693fbcb57f7772d488ff7c0baf0871297e643`. Ancestry integration
changed no reviewed tree content. Bob implemented; the coordinator owns publication.

[Forget v1](../contracts/context-forget-v1.md) was independently reviewed before
implementation. Review fixed legacy already-open writer/remover protection and
specified all three canonical SQL guards. Joffrey re-reviewed and cleared the
contract before coding. New stores initialize schema v2; existing recognized v1
stores do not silently migrate on open, ordinary commands or export. Explicit
confirmed upgrade adds the marker table, three guards and version in one atomic
transaction. Older binaries cannot reopen v2; there is no automatic downgrade.

Confirmed CLI Forget removes all revisions of one human entry and retains only
bounded project/context IDs for suppression. Subsequent add/update/retire/show/
list/export cannot recreate or expose that entry; rebuild leaves markers intact.
Marker listing is inspectable, deterministic, content-free and bounded. Project
removal clears its markers before registration deletion; legacy removers cannot
leave orphaned suppression on a later registration. Sources and unrelated local
records are untouched. No real user upgrade, Forget or private export was run.

This is human-context Forget, **not source-derived Forget or forensic erasure**.
SQLite free pages, journals, backups, earlier exports and already displayed copies
may retain bytes. No implicit unforget, restore, VACUUM or cleanup follows. Export
v1 format is unchanged; existing schema-v1 stores remain usable without migration.

## Review finding and repair

Joffrey's implementation review found a medium schema-normalization defect:
removing every whitespace byte equated canonical `TEXT NOT NULL` with SQLite's
nullable `TEXTNOTNULL` custom type. The coordinator preserved word-token separators
while retaining optional punctuation spacing and exact literal bytes. Tests cover
whitespace/literal/doubled-quote cases and an actual malformed SQLite table whose
reopen is rejected without modifying database bytes. Joffrey independently cleared
the repair and passed all 55 core tests plus a doctest. This is strict comparison
of the fixed DDL subset, not an advertised general SQL parser.

## Integrated evidence and open gates

The coordinator's full check pipeline passed on the exact integration: 102 Rust
tests plus two doctests, formatting, strict lint, docs, smoke, links and negative
gate. All 51 strict Swift tests passed against the rebuilt real core. Dependency
policy, staged secrets and whitespace checks passed. Synthetic tests cover v1
compatibility, upgrade idempotence, cancellation/disk-full/killed-child rollback,
forward-header hot-journal byte preservation, canonical guard validation, legacy
writers/removers, corrupt overlap, 4096-marker capacity, 32-revision receipts,
scope/restart/rebuild/export suppression and source/other-project preservation.

Remote exact-head CI and PR outcome remain subsequent gates. No dependency,
generated lock, UI or live integration changed. Native Forget UX, source-derived
Forget, event watching, GUI/accessibility runtime, live providers/hosts and phase
closure remain open. User work, inherited appends and worktrees were preserved.
