# Human-context registration-bound reads v1

Scope: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/P2-A6/P3-A4** support.
This additive opt-in contract fences cached human-context reads before stored
human data is read. It is not semantic conflict detection/resolution, source
evidence, authenticated authorization, or phase completion. No schema, migration,
dependency, lockfile, native client or transport change is introduced.

## API and closed CLI grammar

Core adds `ContextReadBinding { root, root_identity, incarnation }` and:

- `Store::contexts_bound(project, binding, cancel)`
- `Store::context_bound(project, id, binding, cancel)`
- `Store::search_context_bound(project, query, binding, cancel)`

Daemon adds `ContextsBound(project, root, identity, incarnation)`,
`ContextBound(project, id, root, identity, incarnation)` and
`SearchContextBound(project, query, root, identity, incarnation)`.
These operations open **existing storage only**, never create or migrate it.
An existing v3/v4 registration nonce is required; v1/v2 cannot satisfy a binding.

```text
threadmark --data-dir EXISTING_STORE context list PROJECT \
  --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
threadmark --data-dir EXISTING_STORE context show PROJECT ID \
  --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
threadmark --data-dir EXISTING_STORE context search PROJECT QUERY \
  --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

All three flags are required together, in this exact order, once. Partial,
repeated, reordered, unknown, two-flag legacy, source-policy/snapshot and revision
arguments fail before storage or stdin. These reads never consume stdin. Root,
identity, nonce, project/note ID and search query shape validation precedes opening
storage in CLI/daemon; core repeats applicable validation before its read
transaction. Validation reuses existing byte limits and nonce/identifier grammar.
Valid bindings compare **exact Rust UTF-8 strings**: no normalization, case folding,
path resolution or filesystem lookup. Root/identity/incarnation metadata is not
credentials. Same ID and same root with a new nonce is a different registration.

All unbound trusted-operator methods, daemon commands and CLI forms retain their
signatures and output shapes. They do not gain a captured-registration guarantee.
Existing revision/write/retirement APIs are unchanged; see
[expected-revision v1](human-context-revision-v1.md).

## Coherent snapshot and publication

The bound operations start one deferred SQLite read transaction. A scoped
registration metadata query establishes its snapshot and compares the **same
caller-supplied binding before** any human Forget markers, context text/metadata,
history rows or search candidate traversal. The private admitted-read callback is
the tested boundary. It reuses this transaction; no preflight/unbound-method/new
transaction sequence and no nested transaction is used. Only the requested
project's human rows are selected; no database copying or new cross-project scan
is introduced. Existing store-open schema/private-file admission remains in force.

Before publication, core checks cancellation, registration inside the snapshot,
private store health, ends the transaction and reads registration in a fresh view.
A committed namespace replacement visible in that fresh view rejects publication,
including replacement while a WAL reader retained snapshot A. A read cannot
silently adopt B's human data. Mismatch is content-free `Error::ScopeMismatch`;
missing/dependency/malformed/suppression failures retain existing non-content
errors. Daemon rechecks cancellation; CLI prints only the existing generic failure.

This is a **coherent snapshot with current-at-read registration rechecking**, not
an atomic external revocation lease. A replacement after the last check cannot
recall a returned value or earlier stdout. Edits, retirements and Forget committed
after the snapshot do not retroactively revoke its human data. Callers must still
discard stale asynchronous results and enforce their own selection/publication
scope; these APIs do not replace native pre/post checks. No source-policy or source
currentness claim follows. Source-policy/snapshot changes alone do not invalidate
human history and no source filesystem read is performed.

## Existing semantics and limits

LIST still lists latest metadata including retired markers, without text. HISTORY
returns one complete bounded history, including retired revisions; sequential
revisions and the 32-revision/4096-byte-text bounds are unchanged. Human Forget
suppresses the whole ID before history/text selection. SEARCH still considers
only active latest non-forgotten rows and rejects project history overflow above
4096 rows. Superseded text and retired latest rows are not active search results.

Search retains literal Unicode-lowercase matching, occurrence-count descending
then ID ascending ranking, 8-result/8192-JSON-byte limits including newline,
whole-entry omission, cancellation checks and provenance/authority disclosures.
No new ranking algorithm, source evidence or inference is added; output is
identical to a successful unbound read of that same snapshot. Human text remains
untrusted human-authored context, not observed truth or permission. No forensic
erasure, listener, credential or external-host support claim is made.

Evidence and remaining gates: [Unit U progress](../progress/unit-u-bound-human-reads.md).
