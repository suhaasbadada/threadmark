# Suppression-marker registration-bound reads v1

Scope: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/A3/A5/A6, P3-A4**.
This closes the two explicitly excluded marker-read boundaries in
[Unit V](../progress/unit-v-native-bound-human-reads.md), not all metadata APIs.
It extends the [human-read binding](human-context-read-binding-v1.md), preserving
[human Forget](context-forget-v1.md) and [source Forget](source-forget-v1.md).
No schema, dependency, lockfile, envelope or receipt-vocabulary change.

## API and closed grammar

- Core `Store::forgotten_contexts_bound(project, binding, cancel)` and
  `Store::forgotten_sources_bound(project, binding, cancel)` reuse
  `ContextReadBinding { root, root_identity, incarnation }`.
- Daemon `ForgottenContextsBound(project, root, identity, incarnation)` and
  `ForgottenSourcesBound(project, root, identity, incarnation)` validate before
  opening **existing** storage only, never create/migrate storage.
- CLI optionally accepts exactly this complete ordered suffix, once:

```text
context forgotten PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
source forgotten PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

Partial, repeated, reordered, unknown, two-flag legacy, policy/snapshot/revision
flags and malformed metadata fail before storage or stdin. Neither read consumes
stdin. Root/identity/nonce validation uses the reviewed byte bounds and grammar;
comparison is exact UTF-8, without normalization, case folding, path resolution
or source filesystem access. IDs and relative source paths are scoped metadata,
not content or authenticated credentials. A same-ID/root/new-nonce registration
is a different namespace.

Bound human markers require an existing v3/v4 nonce; v2 trusted human-marker
inspection remains supported. Source markers still require **v4**, not just a
v3 incarnation. Legacy/no-nonce fails closed, without implicit upgrade or unbound
fallback. Native explains explicit upgrade after stopping old workers (human v3,
source v4, both confirmations); stopping workers remains operator attestation.

## Admission, snapshot and publication

The reviewed private `read_human_bound` helper is shared, not copied. One deferred
SQLite transaction first reads only the target registration and admits the exact
binding **before the first marker rows or Forget metadata query**. Transaction-local
marker helpers share the existing query/validation/JSON logic with trusted reads;
they never open a nested transaction or call the old unbound API. Existing
store-open schema/private-file admission remains separate and unchanged.

The same snapshot contains admission and marker selection. Before publication,
core checks cancellation, snapshot registration and private-store health, commits
the read transaction, then checks the binding in a **fresh** registration view
and rechecks health/cancellation. A committed WAL replacement cannot return B's
IDs/paths or publish stale A markers. Errors retain content-free generic CLI
failure and empty stdout, without exposing replacement metadata.

This is current-at-read checking, **not an atomic external revocation lease**.
Replacement after the last check cannot recall returned metadata. No source-policy
or snapshot equality is required by these receipt reads; policy-only changes,
unavailable source roots and missing source files do not invalidate the binding.
Existing source-marker integrity validation remains in force, including malformed
policies/overlaps. This does not grant source authorization or expose a listener.

## Native and retained semantics

`forgottenContextsBound` / `forgottenSourcesBound` carry immutable exact-byte
`HumanContextReadBinding` through ProcessService. Existing strict decoder, empty
stdin, cancellation/timeout teardown and 1 MiB whole-output limit remain. Model
cached inspections, both Forget success follow-ups and human mutation suppression
corroboration use only these bound operations. Native pre/post checks and existing
source-policy confirmation checks remain additional UI/Forget fences, not core
source-policy binding for marker reads.

Same-namespace inspection failure/cancellation retains loaded human history,
editor base/revision and unrelated original. Forget still clears the target human
editor only on dispatch; source Forget retains human history/drafts. Failed or
canceled post-mutation reads remain **uncertain**, never proof of no effect or
rollback. Replacement clearing/classification and refresh gates are unchanged.
No automatic refresh, provider call, implicit migration or unbound retry is added.
LIST/HISTORY/SEARCH and export are outside this implementation's native scope.

Successful wire JSON stays `{"project":...,"forgotten":[{"id":...}]}` or
`{"project":...,"forgotten":[{"path":...}]}`, with deterministic ordering and
existing 4096-human/64-source counts and 1 MiB aggregate bound, no prefix truncation.
Suppression, revocation, retention limits and Forget receipt fields are unchanged.
No restore/unforget or forensic-erasure claim.

Explicit project inventory/show metadata and trusted unbound operator core,
daemon and CLI forms remain outside the cached marker-binding contract. Local
registration metadata is not authentication; this is not “all APIs authenticated.”

## Stable acceptance IDs

- **Y-01 (P2-A1/A6):** both public reads reject same-root/new-incarnation and
  different-root replacements before marker SQL, even with marker tables absent.
- **Y-02 (P2-A1/A6):** two real SQLite WAL connections retain A-only marker
  snapshots for both endpoints and reject publication after B commits.
- **Y-03 (P2-A3/A5/A6):** exact Unicode bytes, policy/source independence,
  cancellation, dependency/malformed markers, read-only/count/output bounds and
  v2/v3/v4 compatibility, without implicit migration.
- **Y-04 (P2-A6):** real CLI closed grammar with held stdin, no absent-store
  creation, typed daemon preflight, compatible trusted output and no B metadata.
- **Y-05 (P2-A1/A3, P3-A4):** real native dispatch races after prechecks for both
  inspections and Forget follow-ups, zero unbound fallbacks, legacy no-I/O,
  cancellation, uncertain commits and history/editor/original preservation.

Evidence and separate review/integration/CI gates:
[Unit Y progress](../progress/unit-y-bound-marker-reads.md). No phase closure.
