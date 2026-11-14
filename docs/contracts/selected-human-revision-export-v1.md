# Selected human revision export v1

Frozen AT contract before runtime implementation. TM-01–TM-04, TM-07, TM-10;
partial P2-A1/A3/A4/A5/A6 and P3-A4 only. No phase closure/native integration.

## Selection and consent

`ExportHumanRevisionsPlan` privately owns project ID, exact full human-read
binding (root UTF-8 bytes, identity, incarnation), and 1..8 distinct `(id, revision)`
pairs. Pure construction uses existing ID/binding grammar and byte limits and
revision integers 1..32. Canonical order: ID bytes then revision ascending.
Same ID with different revisions is allowed; duplicate pairs fail. No latest
substitution, retirement filter, resolution, import or restore. The plan is data
selection, not transport authority, credentials, consent token or file permission.

`Store::export_human_revisions(&plan, cancel)` and daemon
`Command::ExportHumanRevisions(plan)` require separately obtained explicit local
content export consent from typed callers. Closed CLI grammar:

```text
context export-revisions PROJECT --confirm-export-local-content --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

All flags once, in exactly this order before stdin/storage. Stdin: one strict UTF-8
JSON document <=4096 bytes through EOF (at most 4097 bytes consumed):
`{"version":"selected-human-revision-export-v1","revisions":[{"id":"memo","revision":1}]}`.
Only these keys, each once, including escaped-equivalent keys. Revision must be
canonical JSON unsigned integer 1..32: no bool/fraction/exponent/sign/overflow or
string. Extra frames/missing/unknown/duplicate keys fail. Stdin carries selection
metadata only, never note text/originals/secrets.

## Snapshot, validation and refusal

Existing private recognized v3/v4 storage only, no creation/migration/journal
normalization/cleanup. Read-only open accepts WAL, unlike source inspection.
Reuse one `read_human_bound` snapshot: exact registration before ANY human SQL;
bounded validated suppression markers first; project revision count <=4096;
complete selected-note histories sequential 1..32, valid kind, nonempty text
<=4096 UTF-8 bytes without NUL, boolean retirement. Producer is structurally
human-authored (context schema has no producer column). Validate unselected
revisions of selected IDs; never read other notes' text or another project's rows.
Forgotten IDs refuse even with stale rows. Missing/corrupt/future/suppressed/
overflow/dependency/cancellation rejects WHOLE export; no fallback or omission.

Reuse snapshot/fresh-view namespace/private-health/cancellation publication
fences, including WAL. Append/retire/Forget after snapshot need not revoke A text;
committed namespace replacement visible at publication refuses. Current-at-read
checking is not an atomic revocation lease. Later Forget cannot recall emitted
data; no forensic erasure claim. No source-policy/snapshot/currentness authority,
source filesystem content read, semantic resolution, provider/network/clipboard/
host/archive-file write. Missing roots/unsafe source drafts do not affect human
selection. Whole-project export/root authorization and old wires stay unchanged.
Existing store-open schema admission is preserved: v4 performs its existing global
registration/source-policy/non-content suppression integrity checks, not human
text selection. Malformed persisted policy may therefore refuse opening; this
does not read source files or make source currentness a human export authority.
An unsafe unsubmitted source draft is not an argument to this API.

## Exact closed output

One complete compact UTF-8 JSON frame plus LF <=65536 bytes inclusive. No partial
records, truncation, omission or budget waiver. Escaping may cause whole failure
for eight valid texts. Bounded records encoded linearly, no growing serialization.

Top-level keys ONLY:

| Field | Type/exact value |
| --- | --- |
| `format` | `"threadmark-selected-human-revision-export"` |
| `version` | integer `1` |
| `project` | object: `id`, `root_identity`, `incarnation` strings |
| `selection_semantics` | `"specific-stored-revisions-not-current-policy"` |
| `count` | integer 1..8 |
| `records` | canonical array of exactly count complete selected revisions |

Each record ONLY: `id` string, `revision` integer 1..32, `kind` stored kind,
`text` exact stored UTF-8, `retired_at_revision` boolean (stored state AT THIS
REVISION, not today's status), `producer="human-authored"`, and
`authority="context-not-authorization-or-observed-truth"`.
All records are historical selections, even when latest. No absolute root/store
path, sources/hashes/evidence, unselected text/history, current query, original,
provider config or OS error. Sensitive private user content: explicit confirmation
authorizes local stdout ONLY; redirection/sharing is caller responsibility.
Native opaque one-use review/export/filewriter integration requires separate gates.

## Stable acceptance IDs

- **AT-01:** pure owned plan; strict pre-open confirmation/closed JSON/held stdin;
  canonical pairs and input/count/ID/revision/UTF-8 bounds.
- **AT-02:** actual core/daemon/CLI exact old/current/retired provenance, same-ID
  pairs; no unrelated note/history/project/source content or mutations.
- **AT-03:** complete selected histories/global/marker budgets; missing/corrupt/
  forgotten/future fails whole; Forget/reopen/rebuild suppression.
- **AT-04:** exact binding before human SQL; coherent WAL peer append/retire/
  Forget and namespace replacement refusal; zero source content reads.
- **AT-05:** per-history/publication cancellation; permission/dependency failure
  and recovery; complete escaped LF framing, inclusive output boundary.
- **AT-06:** real CLI absent/legacy/byte-quiet store/source preservation;
  unchanged old export/read/search/Context wires; offline checks recorded.

Evidence/limitations: ../progress/unit-at-selected-human-revision-export.md.
