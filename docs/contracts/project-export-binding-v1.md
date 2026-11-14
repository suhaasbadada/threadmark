# Captured local project export binding v1

Additive API contract, pending independent review. Requirements TM-01–TM-04,
TM-07, TM-10; partial P2-A1/P2-A5/P2-A6. This extends invocation guards only;
[project export v1](project-export-v1.md) remains the unchanged output contract.
No schema, dependency, serialization, native adapter or delivery change.

## Invocation and consent

`Store::export_project_bound(expected: &Project, cancel: &AtomicBool)` accepts the
complete previously captured Project. `Command::ExportProjectBound(Project)`
passes that same approval into core, with no metadata preflight followed by an
unbound ID reload. Typed callers must obtain explicit sensitive-local-content
consent before invoking it, just as for the trusted operator API.

The opt-in CLI form is:

```text
threadmark --data-dir EXISTING_STORE project export PROJECT --confirm-export-local-content --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Confirmation is mandatory even with complete metadata. Flags occur exactly once,
in this order; the ordered source list is last, may be empty, and has at most 64
entries. Partial, repeated, unknown or malformed flags fail before opening storage.
`none` means exactly an absent stored snapshot, never a wildcard. Existing trusted
operator forms and their JSON generation are unchanged. Output is local stdout
only after complete success; there is no file destination, copying, upload,
network, provider, native UI or automatic export. A future explicitly approved
native action may choose a private file outside this unit.

## Shape and exact binding

`validate_export_binding` is pure and runs in daemon before existing-store open
and in core before store health/source access. It reuses the existing complete
source-read metadata validator: valid local ID, absolute root at most 4096 UTF-8
bytes without NUL, nonempty root identity at most 128 bytes without NUL, required
32-character lowercase hex incarnation, existing ordered relative-path policy
limits, and absent or exactly 64-character lowercase hex snapshot. No paths from
approval metadata are opened. Existing ASCII-only relative source policy is not
broadened; Unicode registered roots remain byte-bounded, not character-bounded.

Within the existing export read transaction, capture the current SQL Project and
compare ID, root bytes, root identity, incarnation, ordered source policy and
stored snapshot (including absence) before the first `root_authorized`, source
filesystem access or export record selection. Continue using that exact captured
Project throughout the existing pipeline. A mismatch fails closed with no content.
Legacy stores without registration incarnations require explicit operator upgrade
and a fresh capture; bound export never upgrades or creates storage implicitly.

Local IDs, roots, inode identities, tokens, policy and snapshots are stale-approval
guards, **not authentication, credentials, consent or an external revocation
lease**. Current private-store/root/source authorization remains mandatory.

## Preserved export semantics and acceptance

All existing root/inode checks, full-manifest and selected-source freshness,
Forget suppression, separate human-history provenance, cancellation, row bounds,
escaped whole-output 1 MiB limit including CLI newline, source preservation and
final pre-publication revalidation remain. The DELETE-journal reader-lock guard
is unchanged; externally switched WAL is rejected, never supported by a lease or
a relaxed check. Concurrent writers cannot commit replacement, policy revocation
or human-history edits behind the coherent read snapshot; contention fails without
implicit retries. Source changes during a current export fail rather than publish
partial/stale mixed output. The final project recheck is validation, not a new
project used for export selection.

Required deterministic fixtures cover each binding field before the private first
root/source boundary, same-ID same-root and different-root replacement, writer
attempts after binding, source mutation and cancellation before publication,
unindexed/empty policy, ordered policies, Unicode byte bounds, legacy upgrade,
Forget/human history and unchanged JSON. Real CLI processes cover exact consent,
closed flags, malformed/partial approvals before absent or unusable storage, and
trusted-form compatibility. Existing export tests continue exercising whole-output
overflow/escaping, corruption, stale content and authorization loss on the shared
pipeline. Independent contract/implementation review and exact-head CI are separate
primary integration gates, not satisfied by local tests or this draft.
