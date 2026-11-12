# Phase 1 — Prospective retrieval/scoring method prerequisite

2026-11-12. **Phase 1 OPEN; P1-A1/P1-A5 not complete; ADR 0006 proposed.**
TM-02/04/07/10. Bob's bounded implementation for the parent: a frozen prospective
manifest contract and pure in-process source-anchor scorer with tiny authored
synthetic tests. This addresses the retrieval-method gap recorded by Joffrey in
the [feasibility ledger](phase-1-feasibility-ledger.md), not representative
retrieval quality or the full [P1-A5](../spec/phase-1-feasibility.md) gate.

## Scope and predeclared bounds

- [Scorer/manifest](../../experiments/evaluation-scoring/scoring.py),
  [tests](../../experiments/evaluation-scoring/test_scoring.py),
  [method/admission contract](../../experiments/evaluation-scoring/README.md).
- Schema `evaluation-scoring/1`; full candidate canonical UTF-8 JSON ceiling
  8192 bytes, at most eight submitted anchors including duplicates. Original
  query/instructions canonical object ceiling 4096 bytes. Overflow rejects;
  no silent dropping, truncation or partial state. Zero network/inference/spend.
- Exact source-map anchor match, declared gold subset, stale/forbidden invalidation,
  unique TP/FP/FN, explicit undefined denominators and slot-budget recall ceiling.
  All queries use declared task/scope only; no oracle-aware narrowing of the
  all-definitions/direct-callers objective. Two intent/failure families never
  receive relevance metrics. Three arms remain NOT_IMPLEMENTED / NOT_RUN.
- Pure frozen fixture metadata supplied by tests, not discovered source. No
  corpus filesystem reads/exports, generated-source parsing/import/execution,
  retriever/parser/extractor, worker/runner, subprocess/thread/listener or external
  API in the implementation/tests. No Graphify, external dependency, install,
  download, credential, Docker, site, runtime or lockfile change.
- New [CI](../../.github/workflows/evaluation-scoring.yml): path-scoped PRs,
  path-scoped push to main only, optional manual dispatch, read-only contents,
  pinned checkout with persisted credentials disabled, five minutes per Linux
  ubuntu-24.04/macOS-15 job. No installs or downloads beyond platform checkout.
  Foundation CI's existing PR base filter is unchanged; the parent may dispatch
  supplemental exact-head checks for a dependent PR.

## Independent corpus compatibility, not integration

PR #9 remains a separate unmerged unit: full head
`eba04746fcbf0857e7b8af18e217b047f0353829`, source revision
`df49ecbfd38dbd6c39be3ff214bf2de383dd51a1`.
Only its retained authored source/README were read for schema compatibility;
no code copied, imported, executed, merged or cherry-picked. Immutable
[source](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/corpus.py)
and [README](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/README.md).
Its six-field source facts can map to anchors, but schema `1`, oracle kinds,
rejection recipes and `splitlines()` are not automatically scorer inputs or
complete coverage. A future reviewed adapter must freeze gold/rejected selection,
line mapping, source hashes and exact coverage envelope separately. That gap
is recorded, not repaired by changing/importing the other unit. Its negation
family uses `original`/`constraints`, not this API's `query`; preserving that
metadata requires a separately declared adapter, not silent field dropping.
No corpus
generator integration, scale run or retrieval result is claimed.

## Verification record

Assigned branch: `t3/phase1-evaluation-scoring-manifest`. Inherited base HEAD:
`9227571c6e9f0b090ec883121dc9babfc25cc59f`. Worktree retained unchanged; implementation
is staged **uncommitted**, so this base is **not** a full tested implementation
SHA. Full tested committed SHA, exact remote CI run/head and independent review
are parent-owned and **pending**. No commit/push/PR/merge/deploy/watch/scheduler
or delegation performed by this child.

Actual local commands/results:

- `python3 -B -m unittest discover -s experiments/evaluation-scoring -v`:
  24 tests passed. Tiny fixtures only, not benchmark scores (initial 23-test run
  also passed; final suite adds duplicate-payload overflow coverage).
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: initial attempt passed Rust
  checks/smokes but failed local links because this progress file was not yet
  written. Corrected by adding this file; final rerun passed formatting, build,
  Clippy, workspace/doctests, rustdoc, finite diagnostics, local documentation
  links and the intentional failing assertion gate.
- `cargo deny --offline --locked check`: passed advisories/bans/licenses/sources
  using cached data. Explicit offline mode preserves the task's zero-egress
  boundary; no fresh advisory-database fetch was performed.
- `python3 scripts/secrets.py`, after staging new files: passed tracked/history
  scanning and the synthetic-secret rejection gate.
- `git diff --cached --check`: passed.

Tests cover exact/foreign same-symbol evidence, scope/schema/revision mismatch,
stale/forbidden/unknown source, line/text mismatch, valid irrelevant FP,
duplicates, empty/zero-gold undefined values, eight-item cap, exact 8192-byte
astral UTF-8 payload and 8193-byte rejection, malformed/incomplete coverage,
unknown fields/types including permission/state claims, tampering, nonmutating
reject/fresh-value recovery, deterministic canonical manifest/digest, no oracle
query input and conformance-only classification. The source AST test permits
only the scorer's four stdlib imports; it is a regression guard, not a security
sandbox or proof about arbitrary Python extensions.

## Remaining gates and limitations

No retrieval-quality, comparative, performance, intent-preservation, semantic
permission, actual cancellation, host-support or task-success conclusions.
Rejection/recovery tests establish only pure value validation/nonmutation; they
do not implement runtime cleanup or persistence. Counts/bytes are checked after
objects exist, not hostile-input memory/transport containment. Trusted fixture
labels/coverage are not authentication or evidence of extractor completeness.
Source text may mention permission; this scorer cannot infer semantic intent or
validate approval. It rejects extra permission/state fields, not arbitrary
semantic deception in otherwise trusted source text.

Before comparisons: validate lexical/symbol/graph source normalization; choose
and review a pinned candidate extractor and syntactic/binding coverage; freeze
source/manifest mappings and run environment; separately implement/review the
bounded runner and cancellation/dependency-failure/recovery gates; resolve
full-study budgets/blinding/adjudication. ADR 0006 remains proposed. No phase
completion, product Phase 2 behavior or merged-experiment acceptance is asserted.
