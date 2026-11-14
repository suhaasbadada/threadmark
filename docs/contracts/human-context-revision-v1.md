# Human-context expected revision v1

Scope: TM-01–TM-04, TM-07, TM-10; **partial** P2-A1/P2-A3/P3-A4.
This opt-in compare-and-append (CAS) contract prevents a stale human edit or
retirement from appending over a peer's newer revision. It is not semantic
conflict detection, conflict links, conflict resolution, or phase completion.
No existing serialization, schema, migration, dependency or lockfile changes.

## API and CLI

Core adds `ContextRevisionBinding { root, root_identity, incarnation, revision }`
and separately named `Store::update_context_revision_bound(project, id, kind,
text, binding, cancel)` / `Store::retire_context_revision_bound(project, id,
binding, cancel)`. Daemon adds `UpdateContextRevisionBound(project, id, kind,
text, root, identity, incarnation, revision)` and
`RetireContextRevisionBound(project, id, root, identity, incarnation, revision)`.
All binding strings are non-secret metadata, not credentials or authorization.

```text
threadmark --data-dir EXISTING_STORE context update PROJECT ID KIND \
  --expected-root ROOT --expected-root-identity IDENTITY \
  --expected-incarnation TOKEN --expected-revision N
threadmark --data-dir EXISTING_STORE context retire PROJECT ID \
  --expected-root ROOT --expected-root-identity IDENTITY \
  --expected-incarnation TOKEN --expected-revision N
```

Update text comes only from bounded stdin. Flags are all required together, in
the shown order, exactly once. CLI `N` is ASCII decimal digits parsing to `u32`,
in 1..=32 (leading zeroes allowed; signs, whitespace, overflow rejected). The
revision must already exist and be the latest for this project/note. Revision
32 is valid metadata but cannot append because the history budget is exhausted.
There is no revision-guarded add or implicit conversion of missing IDs to adds.

Existing unbound trusted-operator forms and namespace-only
`write_context_bound` / `retire_context_bound`, daemon variants, and three-flag
CLI forms keep their signatures/behavior. They are **not** revision-guarded.
The new guarantee applies only when the caller opts into the new APIs/four-flag
grammar. Old writers may still append; subsequent guarded stale writes fail.
Native callers are not migrated by this backend-only unit.

## Validation and atomicity

Binding shape, project/note IDs, incarnation, revision and update kind are
validated before stdin/storage reads in the new CLI path. At most 4097 bytes are
read to enforce a 4096 UTF-8-byte text limit; empty/invalid UTF-8/NUL/oversized
text fails before daemon storage access. Typed daemon/core paths repeat the
applicable validation before opening/reading storage. New daemon operations use
`Store::open_existing`, never initialize missing storage or implicitly migrate.
Incarnation-aware operations require an existing v3/v4 registration.

Core captures the bound registration, then begins an **IMMEDIATE SQLite
transaction**. Inside that same transaction it rechecks project root, filesystem
identity and incarnation, rejects Forget suppression, reads the latest revision,
compares the exact expected revision, checks existing budgets, and appends once.
Retire copies kind/text from the compared row in that transaction, not from a
newer reload. No compare-outside-transaction followed by an unbound append.
Concurrent guarded writers for one revision cannot both succeed; database
contention/dependency errors fail closed without automatic retries/resolution.
Captured registration reuse is rejected even if root, note ID and revision repeat.
Source-only policy changes do not change human-history identity, authorize source
reads, widen sources, or make a draft into observed evidence.

A revision or registration mismatch returns content-free `Error::ScopeMismatch`.
Malformed/budget/suppression/missing-record/dependency failures remain existing
non-content errors; the CLI uses the existing generic failure, no history or
current private text in diagnostics. Success receipts retain the existing
`saved`/`retired` shapes; no new wire format or content-bearing conflict receipt.
The final cancellation check precedes commit; pre-commit cancel/error/process
death rolls back. A cancellation arriving after commit cannot retroactively
change success to a failed write in the new daemon variants.

## History and boundaries

The 32-revision per-note and 4096-row per-project budgets are unchanged. Retire
appends a retired revision and suppresses active human search; history remains
inspectable. An explicit fresh update to retired history reactivates it, matching
the existing trusted forms; stale update cannot do so. Fresh retirement of an
already retired revision is another bounded retirement, not implicit deletion.
Forget still removes all human history and suppresses recreation in that
registration. Neither new mutation bypasses suppression. Rebuild/restart keep
human history; sources and other projects are untouched. Source Forget's existing
human-history preservation and retention caveats are unchanged.

Dedicated synthetic tests are in core `knowledge::tests::context_revision_tests`
and CLI `context_revision`. They cover two actual SQLite connections, concurrent
writers, stale/fresh update/retire, identical re-registration, namespace mismatches,
project isolation, bounds, retirement/reactivation, Forget, restart/rebuild,
pre-commit cancellation, SQL failure, killed-process recovery, malformed flags,
pre-stdin rejection, absent-store behavior and trusted-form compatibility.
Evidence and exclusions: [Unit S progress](../progress/unit-s-context-revision.md).
