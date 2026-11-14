# File-scoped Context v1 (unit AM)

TM-01–TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6, P3-A3/A4,
P4-A1/A2/A3. Defined before implementation; not phase closure.

`FileContextPlan::new(Project, FileQuery)` consumes and privately freezes the FULL
captured project (root bytes, identity, non-null incarnation, ordered full policy,
nullable snapshot), exact query, explicit algorithm and canonical nonempty 1..64
selected paths. Pure AK validation precedes stdin, storage and source authority.
Typed daemon `PrepareContextFiles(plan, original)` requires existing schema v3/v4;
no create, upgrade, unbound project reload or reduced policy is allowed.

Closed CLI grammar (all flags required once, in this order):

```text
context prepare-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Original is stdin only: nonempty UTF-8, <=4096 bytes, no NUL, exact bytes retained
in memory only. Literal/ranked semantics are exactly file-scoped-retrieval-v1.
Selection filters output candidates only: ALL approved sources are read for full
freshness, including unselected files. No I/O avoidance, privacy, AST, semantic
coverage or performance gain is claimed. No new source permission is granted.

Initial selection, engine prepare authority and final publication authority use
the same owned immutable full Project/FileQuery plan through AK `query_files_bound`.
The private authority is bound to the exact immutable engine Request and exists
only in one call; no global request-ID capability/cache or cross-request reuse.
Mode is Context, provider access None. Existing engine validates/renders quoted
source data; source instructions never grant authority. No hand-built brief.
No provider/approval/delivery/clipboard/host/network/file write or original storage.
Missing/stale/unindexed/no-match context is needs-input, with exact original as
proposed and changed=false. Authority changes during preparation fail the whole call.

Distinct closed JSON response: `format=threadmark-file-scoped-context`, `version=1`,
`project`, `snapshot` (effective evidence snapshot, nullable), `selected_paths`,
`retrieval_mode` (literal or ranked-any-terms), `coverage`, `selection`, `truncated`,
`matching_anchors`, `scanned_anchors`, `evidence` (existing engine provenance DTO),
`mode=context-only`, `state=needs-input|ready-for-review`, `original`, `proposed`,
`changed`, `provider=not-invoked`, `approval=not-requested`,
`delivery=not-attempted`, `limitations`. No invented root/nonce wire fields.
The scope header is included in the engine output budget and full escaped JSON
including LF is <=8192 bytes. Oversized scope/header/response fails whole, never
partial, shortened or unfiltered. AK's own <=8192 response selection budget remains.
No automatic native Refine consent widening. All old serialization is unchanged.

## Stable acceptance IDs

- **AM-A1:** immutable complete capture/canonical subset and pure admission before
  stdin/open, invalid/missing/legacy store fails without create/upgrade.
- **AM-A2:** actual AK literal/ranked selection at initial AND every authority call;
  >8 strong unselected anchors never enter evidence/brief; exact Unicode/escaping,
  whole-subset equivalence where budgets/metadata permit.
- **AM-A3:** peer root/nonce/policy/snapshot/Forget/source edits at all three
  boundaries fail closed; unselected edits invalidate full freshness; cancellation
  and dependency failure never publish partial or replacement content.
- **AM-A4:** truthful needs-input, exact original, provenance/coverage/truncation;
  full JSON/LF and scope header budgets reject overflow without fallback.
- **AM-A5:** real CLI query-files then explicit prepare-files, no provider,
  approval or delivery, original absent from storage/logs; source/human history
  preservation and Forget/rebuild non-resurrection.
- **AM-A6:** default Context/Refine/retained/client-v1/query contracts unchanged;
  full relevant offline checks, owned inventory and honest limitations recorded.
