# Incremental lexical index v1

Unit AG; TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6.
Frozen request and acceptance contract before implementation.

## Explicit request

`Store::index_incremental(&Project, cancel)` and finite
`index_incremental_with_progress` using existing `IndexStage`;
daemon `IndexIncremental(Project)`. No unbound or automatic form.

```text
threadmark --data-dir EXISTING_STORE index-incremental PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Closed grammar: all flags once, in this order, list last, 0..64 files, no stdin.
Pure shape validation precedes storage. Existing writable explicit-index store
only; no creation or migration. Require schema v3/v4 and complete captured root
bytes, identity, nonce, ordered policy and snapshot (including none) inside one
immediate transaction before source authority/traversal. Serialize concurrent
writers for this bounded operation; never reload an unbound project ID. Validate
suppression and exact binding again before SQL and commit. This is stale-approval
protection, not authentication or an external permission lease.

## Validation and publication

Read every approved source under the existing descriptor containment and budgets:
NOFOLLOW, same device, one hardlink, regular files only, no nested repositories;
64 KiB/file, 1 MiB/scan, 4096 lines/file, 1024 bytes/line, 16384 anchors total,
UTF-8 and no NUL. Full freshness scans follow extraction and staged SQL, including
ready-to-commit observer cancellation. No filesystem discovery or I/O skip.

Validate old manifest hash, ordered paths, content hashes, identities and every
evidence row's provenance, bounds and membership. Missing baseline requires null
manifest and zero evidence. Malformed baseline/evidence fails without repair.
Reuse only identical path/hash/device/inode with a complete exact rowset matching
fresh `LexicalLines` output and producer `lexical-lines-v1`. Missing, extra or
corrupt lexical anchors on unchanged sources fail. Valid non-default producers
cause complete-file lexical re-extraction with zero reuse for that file; validate
their coordinates/text too when the source still matches. An empty stored rowset
on a nonempty lexical result is ambiguous and fails rather than claiming reuse.
Changed/new-identity files replace all their rows. Same bytes/new inode is changed.
Every source is read and lexical output computed even when SQL rows are reused;
no claim of skipped CPU extraction, AST, semantic coverage or measured speedup.

One transaction commits changed rows and the complete manifest/snapshot. Human
history and suppression survive. All-unchanged validated requests do no persistent
SQL writes (transaction completion is not a snapshot update). Default full index
keeps its full replacement behavior and unchanged JSON. Cancellation/error before
commit rolls back; commit errors retain existing uncertainty semantics. No cancel
check after successful commit may falsely report a rolled-back mutation.

## Report

`format=threadmark-incremental-lexical-index`, `version=1`, project,
baseline_snapshot, snapshot, coverage=`lexical-lines-only; no semantic coverage`,
files, anchors, reused_files, reindexed_files, reused_anchors, written_anchors,
deleted_anchors, snapshot_updated, persistent_writes, empty. Counts describe SQL
evidence-row reuse/writes, never permission leases or skipped source reads.
Whole escaped JSON including newline <=65536 bytes; fail before SQL, no truncation.
No source text, absolute root, OS errors or human content in the report.

## Stable acceptance IDs

- **AG-A1 (P2-A1/A6):** complete binding and closed pre-open CLI; peer snapshot,
  policy, root or incarnation mismatch fails before source access; legacy/missing
  storage never creates or migrates.
- **AG-A2 (P2-A2/A4):** none-build/query/incremental/query, exact provenance,
  Unicode/empty/64-file results; unchanged SQL-write counters and one-file-only
  replacement; inode replacement never counted reused.
- **AG-A3 (P2-A3/A4/A6):** strict manifest/row validation and exact lexical
  equality; custom producer full-file fallback honestly counted; all resource,
  containment and escaped-report bounds retained.
- **AG-A4 (P2-A1/A2/A3):** cancellation/read/source/SQL/dependency failures at
  staging/publication boundaries preserve previous snapshot/history; recovery;
  writer serialization prevents stale plans overwriting peer updates.
- **AG-A5 (P2-A3/A5):** Forget/rebuild omits revoked files, source bytes and
  independent human histories preserved; old full index/query/export/inspection/
  read-only coverage behavior unchanged.

No schema/dependency/lock/Git/listener/provider/native UI/site changes. No automatic
refresh integration, inference, performance or phase-closure claim. Independent
review and integrated exact-head CI remain separate gates.
