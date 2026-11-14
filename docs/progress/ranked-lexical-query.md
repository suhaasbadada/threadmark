# Explicit ranked lexical query — Lane G

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A2/P2-A4/P2-A6.
No phase closure or retrieval-quality superiority claim follows from these fixtures.

## Baseline and tested revision

- Assigned isolated T3 branch: `t3/core-ranked-lexical-query`; no branch switch,
  worktree creation, reset, discard, subdelegation, push or PR creation.
- Fetched and merged reviewed `origin/main`, including required baseline
  `b65e3515949ae6b89e04660fe419f34bb4fe2223` (PR #53), in local merge commit
  `2b3ec88737fb57b6deb4814dee26c70b6b3cd464`.
- Full tested implementation SHA:
  `9d52ba20100eeb186bb6732e7857fd07ed6b6de5`
  (`feat(core): add explicit bounded ranked lexical query`). This evidence-only
  document follows that implementation; it does not change runtime behavior.
- Baseline CI runs 43551559865 / 43551559839 were reported passing by the primary;
  this lane did not independently inspect them. No CI run exists for this unpushed
  implementation. Independent review, PR integration and current-head CI remain
  primary-owned gates, not passed gates claimed here.

## Explicit command contract

`threadmark --data-dir EXISTING_STORE query-terms PROJECT QUERY`

- Separate opt-in command. Existing `query PROJECT TEXT` retains its exact literal
  substring, SQLite lowercase, path/line-prefix selection and JSON semantics.
  Context/Refine defaults and preparation/session/native code are unchanged.
- Query is at most 256 UTF-8 bytes, contains no control characters, and is split
  only on Unicode whitespace. Each term uses Rust Unicode lowercase (no Unicode
  normalization), then stable first-occurrence deduplication. Require 1–8 nonempty
  distinct terms, each at most 64 UTF-8 bytes after lowercase. No stemming,
  punctuation tokenization, hidden AND, semantic expansion or symbol interpretation.
- Match literal terms against lowercase complete indexed source-line text, not
  paths, human notes or history. Any term is sufficient. Rank distinct matched
  terms descending, summed nonoverlapping occurrences **per term** descending,
  then relative path and numeric line ascending. Different terms may overlap each
  other; there is no token/word-boundary or cross-line match claim.
- Validate selector/query before opening storage in daemon preflight. This read
  command requires recognized existing private storage, never creates a store,
  indexes files, migrates schemas or widens source policy.
- Reuse existing private-store health, manifest/hash/root identity and exact-source
  allowlist checks. Any stale, missing or unreadable approved source suppresses
  the entire old snapshot, including when that source has no selected match.
- Stream **all** current evidence rows under a `64*4096` plus one sentinel row
  limit; never combine each term's bounded literal-query prefix. Validate path,
  positive line, exact current source text/hash and bounded producer identity.
  Invalid evidence fails closed, including malformed nonmatching rows. Precompute
  each source's line lookup once rather than repeatedly traversing lines.
- Retain eight ranked candidates, transiently nine during insertion; no vector of
  all candidate rows. Current source bytes/line tables remain under existing
  64-file / 64-KiB-file / 1-MiB-total bounds. Production indexing's existing
  **16,384 total-anchor cap is unchanged**; the larger query bound is independent.
- Recheck cancellation, project/root identity, registration incarnation, source
  policy and snapshot before publication; reread full source freshness and recheck
  policy after that read. Filesystem currentness is `current-at-read`, not a file
  lock or a promise that sources cannot change after the final read.
- Return at most eight complete entries and at most 8192 serialized UTF-8 bytes
  **including stdout newline and the entire JSON envelope**. Omit whole entries
  when the budget is reached, never truncate source text. `truncated`, `terms`,
  `selection`, `matching_anchors`, `scanned_anchors`, `coverage` and `limitations`
  make ranking, omission and lexical-only coverage explicit. Ranked-prefix output
  does not imply complete source/extractor coverage or search relevance quality.
- Every result retains source project/path/line/hash/producer, observed-source-line
  kind and currentness. Source contents never grant permission or become executable
  instructions. No dependency, persistent index, schema or generated lockfile change.

## Acceptance evidence (synthetic only)

New tests live in `crates/core/src/knowledge/ranked_query/tests.rs` (10 tests) and
`crates/cli/tests/ranked_query.rs` (3 real-process tests). Existing CLI knowledge
tests are unchanged.

| Stable acceptance | Evidence and limits |
| --- | --- |
| P2-A1, partial | Actual SQLite two-project isolation, no unapproved-file/history retrieval, same-root same-content remove/re-register rejection by incarnation at the final boundary. No cross-host authentication/certification claim. |
| P2-A2, partial | Stale edits, missing files, symlink/unreadable-source rejection, complete source-policy revocation, root replacement and recovery after explicit reindex. Final-boundary edit/delete/root replacement suppress results; policy/snapshot changes reject publication. No new watcher, branch-event or OS permission system. |
| P2-A4, partial | All returned lines resolve to approved current files. Forged path/line/text/hash/producer rows fail. Dispersed `alpha ... beta` matches where literal `alpha beta` returns none; a two-term line beyond the first eight hits of **both** individual terms wins. No AST, inference or structural completeness claim. |
| P2-A6, partial | Strict original-query/lowercased-term byte, deduplication and control bounds; Unicode lowercase/combining-character non-normalization; deterministic path/line ties; nonoverlap counting; cancellation before work and at final publication; whole-envelope escaping and complete-entry omission via actual CLI stdout. Source/row/output budgets exercised on declared fixtures, not a hard real-time or resident-memory certification. |

The cancellation/mismatch tests do not mutate source or human records through
retrieval. Test-owned source changes are deliberate synthetic fixtures. Existing
workspace recovery, preparation/refinement, source-Forget and CLI tests also pass;
these are regression coverage, not newly implemented capabilities in this lane.

## Observed resource fixtures

Local macOS arm64, Rust/cargo 1.97.1, debug test profile, 2026-11-13:

- Production-indexed fixture: 64 synthetic files × 256 lines = 16,384 anchors;
  all anchors match, best two-term match at the last path/line. Observed ranked
  call: **53 ms**, including source reads/rechecks and result serialization.
- Lower-level SQLite fixture: 64 files × 4096 source-resolvable lines = 262,144
  anchors. A synthetic sparse extractor establishes a valid source manifest;
  test-only SQL expands exact valid rows to exercise query's independent upper
  bound without changing the production index cap. Observed call: **673 ms**.
  Deterministic top eight verified; an added 262,145th row is rejected.
- These are individual local observations, not statistical comparisons or latency
  guarantees. No RSS measurement, benchmark superiority, user study, broad query
  relevance dataset or production-scale coverage is claimed.

## Verification and exclusions

Passed against the full implementation SHA above:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: workspace format/build,
  warnings-as-errors clippy, all tests/doctests, documentation, finite diagnostics,
  documentation links and intentional failing-assertion gate.
- `cargo deny --offline --locked check`: advisories, bans, licenses, sources pass
  using locally cached data. Offline mode is deliberate: no advisory refresh or
  network egress authorized for these checks.
- `python3 scripts/secrets.py`, after explicitly staging only this lane's owned
  files: tracked-file scan passed; synthetic secret rejection probe passed.
- `git diff --check` and staged whitespace checks passed. No unrelated changes
  discarded. The evidence document is staged/scanned separately before handoff.

Initial local checks caught a private helper visibility error, an existing index
cap violation in the first oversized fixture, and two clippy assertion-style
warnings; these were repaired before the passing full run. No limits were relaxed
to hide those failures. The separate SQL-expanded fixture labels its construction.

No native changes/tests or Swift invocation, GUI/paused-host launch, sensitive
desktop capture, Docker, installation, external provider access, environment-key
reuse, real data, global configuration change, deployment, merge or release.
Existing workspace tests use only bounded test-owned loopback providers and close
their resources. The sole authorized remote operation here was fetching the
requested reviewed Git baseline. Primary retains integration/review/CI ownership;
this lane does not claim a working background companion, daemon listener, semantic
retrieval, authenticated transport or complete Phase 2 acceptance.
