# Bound ranked human-note search v1 (AO)

Frozen before implementation. TM-01–TM-04, TM-07, TM-10; partial
P2-A1/A3/A4/A5/A6 and P3-A4. Human declarations are not observed truth,
instructions, authorization, semantic/AST retrieval or source evidence.

## Closed opt-in request

`context search-terms PROJECT QUERY --kinds KIND... --expected-root ROOT
--expected-root-identity IDENTITY --expected-incarnation TOKEN`

Exactly this order, once; no extra arguments, stdin or fallback. Kinds are 1..5
unique constraint/correction/decision/note/pitfall, canonical ASCII order in the
immutable typed plan and reply. Selecting all is allowed. `HumanRankedQuery::new`
validates before storage; daemon repeats project/binding admission before opening
existing v3/v4 storage. Missing storage is not created; v2 is not upgraded.
Existing literal APIs, kind-filtered APIs and their wire bytes are unchanged.

Query is nonempty, at most 256 UTF-8 bytes, with no control characters. Reuse
source ranked query's whitespace split, Unicode lowercase, first-seen distinct
terms: 1..8 terms, at most 64 UTF-8 bytes each after lowercase. No normalization,
stemming, expansion, query retention, logging, source read, inference or cache.

## Snapshot and selection

Full ContextReadBinding is mandatory: exact root bytes, identity and non-null
incarnation before ANY human rows, in one bounded SQLite read snapshot. Reuse
human-read private-file/WAL/health/fresh-publication fences; no ID reload/unbound
fallback. Source policy/snapshot changes, missing sources and stale/unindexed
source evidence do not invalidate human-note authority. Registration replacement
does. This is current-at-read checking, not an external atomic revocation lease.

Read suppression markers first, then reject more than 4096 persisted project
revisions. Validate every nonsuppressed latest row before filtering, including
unselected/retired rows (ID, revision 1..32, known kind, nonempty NUL-free text
at most 4096 bytes, boolean retirement). Suppressed stale content follows existing
human-search policy. Only active latest selected kinds match. Count all eligible
matches before caps. Rank distinct matched terms descending, then total
nonoverlapping occurrences descending, then ID UTF-8 byte order ascending.
Occurrences within each term do not overlap; distinct terms count independently
even when their spans overlap. Historical, replaced, retired and forgotten notes
are not results. Cancellation/dependency/mismatch/corruption publishes nothing.

## Closed response

Top-level fields exactly: version (`human-search-ranked-v1`), project,
root_identity, incarnation, selected_kinds, terms (normalized, never raw query),
producer (`human-authored`), status (`active-latest-at-read`), authority
(`context-not-authorization-or-observed-truth`), coverage, selection, limitations,
matched_entries, omitted_entries, truncated, results.
Each result exactly: id, revision, kind, text, producer (`human-authored`), status
(`active`), matched_terms (normalized first-seen subset), occurrences (total).
Selection/coverage/limitations are fixed explanatory strings, not quality claims.
At most eight whole entries and 8192 encoded compact JSON bytes including LF and
all headers. Omit oversized entries whole, allowing later fitting candidates.
Never truncate text/metadata. Reject an oversized header. omitted_entries equals
all matched entries minus returned entries; truncated is exactly omitted != 0.

## Stable acceptance IDs

- **AO-01:** typed plan limits/Unicode/distinct/overlap/ties and actual ranked gain;
  all-kind single-term equivalence and unchanged old wire.
- **AO-02:** latest/revisions/retirement/Forget/rebuild; filter before all counts,
  ranking/caps; all scoped latest validation, 4096/32/text bounds and suppression.
- **AO-03:** whole-entry escaped-text/LF/header budgets, counts and deterministic
  later-fitting selection, closed provenance and normalized-term response.
- **AO-04:** exact pre-human-read binding and coherent peer transactions; first/
  last read cancellation/dependency/replacement/private health publication fences.
- **AO-05:** actual daemon/CLI closed grammar, prestdin/prestorage rejection,
  missing-store/no-upgrade, no fallback and default compatibility.
- **AO-06:** no filesystem content reads, source-policy/currentness independence,
  logical/byte preservation with honest WAL caveats; human history/markers intact.
- **AO-07:** offline workspace/deny/staged-secrets/whitespace evidence; owned diff,
  tested baseline/fingerprint and limitations. Native/remote CI/phase closure excluded.
