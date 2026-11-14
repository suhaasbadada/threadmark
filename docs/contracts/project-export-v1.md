# Project export v1 — bounded local inspection archive

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A4/P2-A5/P2-A6.
No database schema change, import/restore, external delivery or background work.

## Invocation and authority

`threadmark --data-dir EXISTING_STORE project export PROJECT
--confirm-export-local-content` selects exactly one registered project. Missing
confirmation or malformed arguments fail before opening/creating storage. Export
requires an existing recognized private store and existing project. Local IDs
are not credentials; existing private-store/source authorization still applies.
The CLI writes one bounded JSON document to stdout only after complete success.
It never chooses a destination, writes an archive file, or sends content anywhere.
Any later file redirection/sharing is the caller's explicit responsibility.

## Contents and exclusions

The versioned envelope identifies format/version, project ID/root identity and
exact approved relative file policy, snapshot/currentness/coverage, selected
current lexical evidence and all human-context revisions for that project.
Evidence retains relative path/line, source hash, extractor producer and kind;
human revisions retain ID/kind/revision/retired state and human-authored,
context-not-authorization provenance. These are separate arrays, never a merged
claim of source truth. Export is inspection/provenance, not an import capability.

Wire fields are fixed (no additional content-bearing fields):

| JSON field | Type/value |
| --- | --- |
| `format` / `version` | `"threadmark-project-export"` / integer `1` |
| `project` | object with `id`, `root_identity` strings and `sources` array of approved relative path strings |
| `snapshot` | recorded 64-character snapshot string or `null` if unindexed |
| `currentness` | `"current-at-read"` or `"stale-or-unindexed"` |
| `coverage` | bounded non-content lexical-only coverage/limitation string |
| `evidence` | array of all eligible persisted anchors, ordered by relative `path`, then integer `line`; never query's eight-anchor prefix |
| evidence entry | `project`, `path`, `text`, `source_hash`, `producer`, `kind`, `currentness` strings, positive integer `line`; same validated anchor semantics as retrieval |
| `human_history` | all revisions ordered by context `id`, then integer `revision`, including retired revisions |
| human entry | `id`, `kind`, `text` strings; positive integer `revision`; boolean `retired`; `producer="human-authored"`, `authority="context-not-authorization-or-observed-truth"` |

All eligible records are selected; exceeding the envelope bound fails the whole
operation, not a prefix export. A current verified snapshot with zero eligible
anchors may be current-at-read. Zero human revisions is valid; empty arrays alone
never prove freshness. An unindexed snapshot remains stale-or-unindexed.

No absolute root/store path, environment, credentials/configuration, host data,
original requests, previews or another project's records are included. Approved
source excerpts and human notes are sensitive user content, not automatically
safe to share; confirmation does not authorize egress. No credential discovery
or secret-file scanning is performed. Synthetic fixtures only in public evidence.

## Snapshot, currentness and failure semantics

All database records come from one coherent read transaction. Selected source
evidence is revalidated against the complete current authorized source manifest,
snapshot binding and exact source-line/hash/provenance constraints used for
retrieval. No indexing happens during export. Recheck source identity/content and
policy before returning; a concurrent source change fails closed, never produces
a mixed archive. Evidence is current-at-read only, not guaranteed current later.

Authorization takes precedence over stale-content handling: lost private-store
authorization, unreadable/replaced registered root, root identity mismatch or
invalid project policy always fails the entire export. Unavailable/changed approved
file content or an unindexed snapshot may produce an explicit stale-or-unindexed
limitation and empty evidence only while root/project authorization remains valid.
Human history remains exportable in that case. A change during an otherwise
current export fails rather than silently switching to a history-only result.
Corrupt/foreign persisted records
fail rather than being silently dropped or exported as trusted evidence.
Concurrent writers/removal cannot mix registration incarnations or histories.

The complete UTF-8 JSON plus CLI newline is at most 1 MiB. Existing per-record,
source and row-count limits remain in force. Account for JSON escaping while
assembling; do not build unbounded history then truncate or repeatedly serialize
the entire growing archive per row. Overflow fails the entire operation with no
stdout, never omits material records silently. Cancellation, store/source
authorization failure, malformed records and dependency errors are content-free
failures with no partial stdout. Export does not mutate project/source/history.

## Required local acceptance

Actual multi-process CLI tests: exact confirmation, no missing-confirmation store
creation, no implicit new-store export, two-project isolation, exact human
history/provenance, current anchors, stale suppression, source-policy revocation,
reopen, bounded escaped output/overflow, no paths/config or request history in
envelope, and unchanged source/store logical records after success/failure.
Core fixtures: deterministic source change/cancel during export, malformed and
foreign evidence, coherent writer/removal boundaries, and no partial publication.
Distinguish approved-file content staleness from root/store authorization loss.
Remote exact-head CI and independent implementation review remain separate gates.
