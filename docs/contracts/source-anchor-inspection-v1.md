# Bounded source-anchor inspection v1

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A6. Additive,
source-only explicit inspection, not indexing, export or a new content authority.
No schema, dependency, Query/Export wire-format or native UI changes.

## Request and enforcement

`Store::inspect_source_anchor(expected: &Project, anchor: &SourceAnchorInspection,
cancel)` and daemon `InspectSourceAnchor(Project, SourceAnchorInspection)` require
the complete captured registration (ID, exact root bytes/device-inode/incarnation,
ordered policy and non-null snapshot), relative approved path, indexed line and
expected lowercase SHA-256. Radius is explicit, 0..3; line is 1..4096.
No unbound or implicit current-ID adoption form exists.

```text
threadmark --data-dir EXISTING_STORE source inspect PROJECT PATH LINE --radius RADIUS --expected-source-hash HASH --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH --expected-sources [FILE ...]
```

Flags appear exactly once in that order. Decimal coordinates use canonical digits
(no signs, whitespace or leading zeroes). All shape checks precede store opening;
no stdin is consumed. Missing store never creates one. Metadata is stale-approval
protection, not credentials. Validate the entire binding and indexed evidence
membership/hash before the first source authorization/traversal. Use that same
captured current project through full-manifest read/revalidation. Indexed center
text must equal the exact admitted current source line and hash. Forged coordinates,
unindexed/forgotten paths, stale snapshots and source changes fail without content.

The daemon uses `Store::open_existing_for_inspection`: the validated existing
database header must declare rollback journaling before SQLite opens it, and the
connection is read-only. Journal mode is checked without normalization; WAL is
not converted to DELETE, and no store/database/sidecars are created for rejection.
The CLI admits the complete 64-file policy (84 total arguments including
`--data-dir STORE`); per-command policy validation still rejects excess sources.

One read transaction retains the existing DELETE-journal reader-lock guard: reject
WAL, do not allow peer policy/re-registration commits behind the snapshot. Recheck
store health, current source manifest, complete project binding and cancellation
before publication. Source helpers retain root/file/device/inode/link/nested-repo
containment. Any dependency failure, cancellation or mismatch refuses all output;
no autoindex, persistent writes, source changes or late content publication.

## Response

`format="threadmark-source-anchor-inspection", version=1`, project,
root_identity, incarnation, snapshot, path, source_hash, producer, anchor_line,
radius, currentness=`current-at-read`, and `lines`. Each line has its original
one-based `line`, complete `text`, `is_anchor`, and
kind=`indexed-anchor` for the center or `observed-source-text` for neighbors.
Producer labels extraction of the center only; neighboring (including blank) lines
are freshly observed source text, not new indexed claims. No absolute root or human
notes are returned. At file boundaries the window ends naturally. At most seven
whole lines, whole escaped JSON plus CLI newline <=8192 bytes; overflow fails,
never silently truncates a line or substitutes a smaller window. Line semantics
match existing Rust `str::lines()` indexing (CRLF terminators excluded).

## Stable acceptance IDs

- **Z-A1 (P2-A1/A6):** exact complete binding, including Unicode byte limits,
  ordering, nonce/policy/snapshot/hash mismatches before first source access.
- **Z-A2 (P2-A4):** actual query→inspection core/daemon/CLI journey, full neighboring
  code, center distinction, provenance, blank lines, forged/unindexed/wrong lines.
- **Z-A3 (P2-A3/A4):** source mutation/containment/dependency refusal, cancellation,
  recovery, whole-output overflow and JSON escaping, no evidence/note/source writes.
- **Z-A4 (P2-A1/A3):** publication peer replacement/revocation fencing, DELETE guard,
  source Forget/rebuild omission and no resurrection.
- **Z-A5 (P2-A6):** strict closed pre-open CLI grammar, bounds/duplicates/missing
  metadata/held stdin/missing store, output and existing-only storage bounds.

Local evidence and exclusions are recorded in the unit Z progress document;
independent review and exact-head CI remain primary integration gates.
