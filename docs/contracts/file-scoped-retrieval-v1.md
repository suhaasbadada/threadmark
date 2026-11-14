# File-scoped retrieval v1

TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6.

## Contract (unit AK)

New opt-in `Store::query_files_bound(Project, FileQuery, cancel)` and typed daemon
`QueryFilesBound` require the complete captured Project, including root bytes,
root identity, non-null incarnation, ordered FULL source policy and nullable
snapshot. No unbound form, implicit migration, discovery or indexing exists.
`FileQuery` selects Literal or RankedAnyTerms and 1..64 distinct exact approved
relative paths. Shape validation precedes storage; full binding comparison precedes
source authority. Selection is copied into canonical captured-policy order.

Selected files filter OUTPUT CANDIDATES ONLY, not permissions or filesystem scope.
Full bounded manifest/source reads and publication freshness checks retain ALL
approved files. Changed/deleted/unsafe unselected approved files suppress the whole
snapshot. No I/O avoidance, privacy lease, filesystem lock or performance gain.

Literal uses existing SQLite `instr(lower(text),lower(query))` substring semantics
(ASCII-only case folding, not Unicode normalization). RankedAnyTerms uses existing
Unicode lowercase, whitespace splitting, distinct-term/occurrence ranking and
path/line ties. Filtering precedes matching counts, scores, top eight and byte
selection. Existing query, terms, Context and Refine formats/defaults are unchanged.

CLI closed grammar (no stdin):

```text
query-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Existing store only. Full encoded JSON plus newline <=8192 bytes, at most eight
whole entries, no partial text. Explicit list header overflow fails the whole call.
Response has `format=threadmark-file-scoped-retrieval`, `version=1`,
`selected_paths` in policy order, `mode`, and existing ranked response metadata
(`terms` only in ranked mode), provenance, currentness, lexical coverage, selection,
matching/scanned anchors and truthful truncation. Scanned anchors counts selected
validated rows; full traversal remains bounded independently. Matching counts
cover selected candidates only. No omitted content is exposed. Errors publish no
partial response. Output source content goes only to explicit local stdout.
No native UI/Model, Context/Refine consent, provider, export or retained integration.

Closed response keys: `format`, `version`, `project`, `root_identity`,
`incarnation`, `snapshot`, `selected_paths`, `mode`, `currentness`, `coverage`,
`selection`, `truncated`, `matching_anchors`, `scanned_anchors`, `results`,
`limitations`; ranked mode additionally has `terms` (normalized in first-seen
deduplicated order). Each result has exactly `project`, `path`, `line`, `text`,
`source_hash`, `producer`, `kind`, `currentness`, `coverage`; ranked results
additionally have `matched_terms`, `occurrences`. Omitted matching anchors are
`matching_anchors - results.length`; no out-of-filter counts are published.
Stale responses clear results/matching count/truncation; scanned count may describe
the selected rows validated before a publication-time source change. Literal
controls other than NUL retain old bound-literal semantics; ranked rejects controls.
Paths retain the existing ASCII `.rs/.py/.md/.txt` policy (no Unicode path expansion).

## Stable acceptance IDs (defined before implementation)

- **AK-A1:** full binding/query/subset validation before store/source authority;
  canonical scope order, UTF-8 bounds, unknown/duplicate/forbidden paths rejected.
- **AK-A2:** both exact algorithms; >8 unselected earlier/higher matches cannot
  consume result/byte budget; ties, Unicode/escaping, all-subset equivalence.
- **AK-A3:** full-policy stale/unindexed/unsafe suppression, publication fencing,
  cancellation/dependency failure, no partial or replacement-project content.
- **AK-A4:** whole-frame/header/whole-entry bounds, metadata and old wire regressions.
- **AK-A5:** Forget invalidates old capture and forbids forgotten selection under
  new capture, no resurrection; notes/source bytes preserved.
- **AK-A6:** closed existing-only CLI, no stdin, invalid requests pre-open;
  inherited source containment/resource limits and explicit local-only output.
