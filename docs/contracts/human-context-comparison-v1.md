# Human-context revision comparison v1

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A5/A6 and P3-A4.
This is explicit bounded textual review after an edit/CAS conflict, not semantic
conflict detection, inference, authorization or automatic resolution. No schema,
dependency, migration, lockfile, native client, source inspection or export change.

## Entry points

`Store::context_comparison_bound(project, id, from, to, binding, cancel)` and
daemon `CompareContextBound(project, id, from, to, root, identity, incarnation)`
are bound-only APIs. Binding is the existing `ContextReadBinding`.

```text
threadmark --data-dir EXISTING_STORE context compare PROJECT NOTE FROM TO \
  --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

All flags are required once in exactly this order, without extra arguments.
FROM/TO are ASCII decimal u32 values in 1..32, FROM <= TO; equal is allowed.
Leading zeroes are allowed; signs, overflow, whitespace and missing values fail.
Project/note/binding/revision validation precedes storage and never consumes
stdin. Existing commands and their JSON remain unchanged and unbound operator
forms remain explicitly unauthenticated. Metadata bindings are not credentials.

## Snapshot and failure semantics

Existing storage only, schema 3/4, no implicit creation or migration. Reuse the
reviewed `read_human_bound` transaction: exact UTF-8 registration check before
human SQL, one complete validated bounded same-note history for both selections,
and a fresh registration publication check after the snapshot ends. No two public
history calls, preflight/unbound reload, nested transaction or latest substitution.
History must be sequential, 1..32 revisions, each valid kind and nonempty UTF-8
text of at most 4096 bytes. Forgotten/missing revisions, malformed history,
legacy registration, binding mismatch, dependency failure or cancellation fail
without content or mutations. Replacement during a WAL read rejects publication,
including same ID/root with a new nonce. Peer append/Forget after the snapshot
does not revoke an already captured history; this is not a revocation lease.

Human-only reads ignore source policy/snapshot and require no source filesystem,
Git, provider or host calls. They preserve all notes, evidence and source bytes.
Context Forget prevents later reads and resurrection; source Forget retains human
comparison. Values leave only on explicit CLI stdout; no file/provider flow.

## Result and exact reconstruction

Version `human-context-comparison-v1`; project/id, from/to revision/kind/retired
metadata, `producer: human-authored`, and
`authority: context-not-authorization-or-observed-truth`. Boolean `text_changed`,
`kind_changed`, `retirement_changed` describe only exact values, not meaning.
Delta uses `common-prefix-suffix-logical-lines-not-minimal`: split at LF including
the LF in each segment, take the longest equal prefix then nonoverlapping equal
suffix. Store each common segment once, with the two differing middles.
Old = prefix + from + suffix; new = prefix + to + suffix. Empty text delta has
both middles empty. No Unicode/CRLF/trailing-newline normalization, phantom final
empty line, truncation, duplicate full texts, or minimal/semantic-diff claim.
The whole compact encoded JSON plus stdout newline must fit 65536 bytes; failure
is whole-response, never partial. Errors/logs disclose no private text or paths.

## Stable acceptance IDs

- **AA-01:** Actual core/daemon/CLI add/update/retire/reactivate, explicit compare,
  stale CAS rejection and fresh compare; deterministic truthful metadata/delta.
- **AA-02:** Exact reconstruction for equal text, kind/retirement-only changes,
  canonical Unicode byte differences, CRLF, multiline, final LF, and escaping;
  byte budgets include encoded JSON and newline, overflow never truncates.
- **AA-03:** One snapshot for both revisions/history, peer append/Forget and
  registration replacement; exact binding before human SQL and WAL publication
  rejection; never return replacement text.
- **AA-04:** Missing root/policy/snapshot independent, zero source accesses;
  reopen/rebuild preservation, human Forget suppression, source Forget retention,
  unrelated projects isolated.
- **AA-05:** Missing/reversed/overflow revisions, malformed/budget/legacy DB,
  cancellation/dependency failures are content-free and mutation-free.
- **AA-06:** Actual CLI closed grammar rejects malformed/duplicate/reordered flags
  before held stdin/storage; daemon validates before opening; no missing-store
  creation or legacy migration; trusted forms unchanged.

Evidence and remaining gates: [AA progress](../progress/unit-aa-human-revision-comparison.md).
