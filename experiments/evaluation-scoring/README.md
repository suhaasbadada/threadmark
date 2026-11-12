# Prospective retrieval manifest and pure scorer

Phase 1 method preparation only: TM-02/04/07/10; **P1-A1/P1-A5 remain partial**.
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) remains
**proposed**. This closes neither the feasibility phase nor the representative
evaluation gate. All three retrieval arms are **NOT_IMPLEMENTED / NOT_RUN**.
There is no retriever, parser, extractor, worker, evaluation runner, inference,
host integration or Phase 2 knowledge core here. Synthetic scoring assertions
are not retrieval-quality measurements or a benchmark.

Run from the repository root with Python 3.10+ (stdlib only):

```sh
python3 -B -m unittest discover -s experiments/evaluation-scoring -v
```

## Frozen prospective manifest v1

`build_manifest(task)` accepts exactly `schema`, `scope` (project/worktree/revision),
`family`, `query`, `instructions`. It returns canonical JSON bytes and a SHA-256
digest over the complete manifest excluding `digest`. Schema is
`evaluation-scoring/1`. Canonical JSON has sorted keys, compact separators, raw
UTF-8 (`ensure_ascii=False`), no NaN or trailing newline. The static contract has
a pinned digest in tests; changing it requires reviewed schema/pin changes.
No timestamp, host information or random input participates. A digest is an
integrity label, **not authorization**. A future run must retain the exact
manifest bytes/digest before retrieval; this function does not persist a freeze
or authenticate a caller. Exact selected input source hashes must be frozen and
validated separately, never sent as answer-bearing oracle metadata to an arm.

The original `query` and `instructions` are retained unchanged. Their combined
canonical JSON object is limited to 4096 UTF-8 bytes (a conservative request
unit, not a host transport guarantee). No arm adds instructions or has a distinct
query. No oracle parameter, evidence kinds, answer text, answer hashes, handpicked
files or outcome-based query rewrites are allowed. Query words are maximal
ASCII `[A-Za-z_][A-Za-z0-9_]*` matches in the original query, lowercased, unique,
sorted; no stemming, stopword removal or semantic expansion. Case-sensitive
query identifiers retain first-occurrence order. This deliberately simple rule
also retains ordinary words like `Locate`; it does not consult answers.

### Planned arms, scope and ranking (none implemented)

All arms see the same declared instructions/query and all selected-project,
worktree, revision UTF-8 `.rs`, `.py`, `.md` sources. Approved exclusions must be
declared before a run; no posthoc oracle-aware narrowing. Source line numbering
is one-based: split on LF, remove one terminal CR on each line, omit only a final
empty split segment. Interior blank lines count. Emit exact original line text
after that normalization. Rank distinct source lines, not extracted prose.
Final ties use relative POSIX path UTF-8 bytes ascending, then numeric line.

| Arm | Frozen prospective algorithm |
| --- | --- |
| Lexical | Tokenize each whole source line by the same ASCII rule and lowercase. Keep lines with at least one query-word intersection. Rank by descending number of distinct shared words (not frequency). Comments, string literals and Markdown are intentionally included. No symbol/kind tag is required. |
| Symbol | Source declaration lookup only. Match exact case-sensitive query identifiers against Rust `fn`, `struct`, `enum`, `trait`, `type`, `const`, `static`, `mod` declaration names and Python `def`, `async def`, `class` names. Emit the declaration keyword's line once; rank by earliest matching query-identifier position, then path/line. Include Rust modified declarations/impl methods and Python nested declarations; exclude comment/string regex matches and generic parameters. Name and declaration keyword must share a physical line (`static mut` skips `mut`; Python async declarations anchor `async`). Treat source-declared Rust cfg branches textually without evaluating cfg. No caller retrieval in this baseline. |
| Candidate graph/direct-call | Planned contract only: match declarations by query identifier, then resolved direct call sites targeting those declarations, one hop only. Rank declarations before call sites, then earliest target query-identifier position, then path/line. Deduplicate shared sites using their best rank. No inferred edges, embeddings or transitive callers. A pinned extractor, binding-resolution rules and coverage decision are **blocked** pending separate review; this contract does not silently adopt Graphify. |

Symbol gaps: no macro-generated Rust declarations, expansion, reexports/import
alias resolution, Unicode identifiers, generated code, destructuring bindings,
multiline declaration names or Python runtime-created definitions. Candidate
gaps additionally include unresolved/dynamic calls, ambiguous targets and
unverified dispatch. No claim of complete language parsing. A future reviewed
recognizer must distinguish syntax from comments/strings and document failures;
until then the symbol arm is not implemented either. Candidate resolution/pin
is an explicit comparison blocker, not an assumed working algorithm.

Each future arm takes the first eight ranked unique source lines (or all if
fewer). It must emit whole anchors, never snippets or partial lines. The complete
candidate envelope must fit 8192 canonical UTF-8 bytes; otherwise reject the
case, not truncate to smaller text or silently choose cheaper lines. All metadata
and duplicates count toward those bytes. No wall-time/RSS numbers are produced;
ADR 0006's separate runner/containment gates still apply before any worker.

## Scorer API and admission contract

`score(fixture, candidate)` operates only on already-existing Python values.
The trusted frozen `Fixture` supplies exact scope, an ordered coverage-envelope
tuple, immutable source-map entries (`Anchor`), an admissible `gold` subset and
a `rejected` subset marking stale/forbidden facts. The source map has one exact
text per `(project, worktree, revision, path, line)`; it may retain foreign/old
facts for negative controls, but those cannot enter gold. A rejected anchor
must not be gold. This is hand-authored fixture metadata, not repository
discovery or an assertion that arbitrary callers can authenticate permission.

Candidate fields are exactly:

```text
schema: "evaluation-scoring/1"
scope: {project: str, worktree: str, revision: str}
coverage: {status: "complete", envelope: [exact declared coverage strings]}
items: [{project: str, worktree: str, revision: str,
         path: relative POSIX str, line: positive int, text: single-line str}]
```

Scope, schema and coverage envelope must match exactly, including list order
and declared coverage gaps. `complete` means complete within that frozen limited
envelope, **not** complete Rust/Python semantics. Changed/missing coverage,
partial state, unknown fields/types, permission/approval/state claims, wrong
project/worktree/revision, stale/forbidden sources, unknown line/path/text or
budget overflow reject the **whole** case: `status=invalid`, `metrics=null`.
No accuracy numbers, not even zero. No fallback to partial/last-good output.
IDs are not credentials. Strict field rejection does not detect fabricated
semantic permission inside otherwise exact source text or validate actual host
approval; it only disallows such additional claims in this source-only format.

Evidence is the exact six-field source-bound anchor. Single-line text and line
must match the supplied map; no fuzzy/semantic/partial credit, whitespace
normalization, kind-tag matching or substring credit. An allowed current anchor
outside gold is a false positive; stale/forbidden evidence invalidates the case
instead. There are at most eight submitted items, **duplicates included**.
After admission deduplicate the entire source unit once for TP/FP:

- TP = unique admitted gold units; FP = unique admitted nongold units.
- FN = gold count minus TP. Gold is all expected eligible evidence for the
  original selected-scope task, never just the top eight handpicked answers.
- Precision = TP/(TP+FP); recall = TP/gold count. A zero denominator is explicit
  `null`, not 1. A valid empty prediction is not a rejection or perfect result.
- Always report submitted/unique/duplicate counts and exact payload bytes.
- Strict slot-budget recall ceiling = min(8, gold count)/gold count, or `null`
  for empty gold. Duplicate waste is reported separately and never changes the
  predeclared ceiling. The byte ceiling may make even this bound unattainable.
  Low recall on broad capped tasks is not product-quality evidence.

Only `definition_directcall` and `conflictingrules_stale_wrongrevision` are
relevance families. `negations_permission` and
`rename_delete_malformed_interruption_recovery` always return `metrics=null`
and `conformance_only_not_evaluated` for structurally admitted values. They
declare future intent/conformance tests, not relevance denominators or actual
semantic intent, cancellation, dependency/recovery or approval validation.
Bad candidates still reject. Pure fresh-value recovery tests prove nonmutation
only, not extractor recovery, cancellation or persistence.

## Future normalization gates and independent corpus boundary

Before any comparison, independently validate each arm's output normalization:
selected source hashes/scope; exact UTF-8 line convention; declaration/call-site
to source-line mapping; coverage status/gaps; rejected stale/forbidden sets;
whole payload budget and all negative controls. Graph facts or symbol records
cannot invent anchors/kinds or claim completeness through this API. Do not feed
the fixture/oracle/source-answer hashes into retrieval input construction.

PR #9 is separate, unmerged corpus preparation. Its immutable
[schema source](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/corpus.py)
and [README](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/README.md)
were read for compatibility only; no code was copied/imported/run. Corpus schema
`1` is **not** this scoring schema. Its six source-anchor fields can map directly;
its `kind` belongs only to trusted gold/rejection selection, never to lexical
items. It has no arm coverage envelope or scored-output schema: future integration
must freeze that mapping and validate normalization separately. Source line
conventions must also be reconciled (the corpus uses `splitlines()`); current
literal tests do not prove generator integration. Expected unknowns and failure
recipes are not observed output or gold relevance units.
Its negation family also supplies `original`/`constraints` rather than `query`;
this task schema is not a drop-in decoder for that metadata. A future adapter
must preserve every original constraint and declare its mapping before use,
not silently drop fields or claim this source-only scorer checks intent.

The corpus's original definition query asks for **all** `resolve` declarations
and direct callers in selected scope; retain that objective even when gold
exceeds eight. Its current-audit-rule query remains separate. No hidden file
selection or oracle-aware narrowing. No full corpus, scale run or comparison is
claimed. No filesystem corpus reads/exports, external APIs, installs, downloads,
subprocesses, threads, listeners, credentials, Docker or source execution occur
in this module or tests. Count/byte checks occur **after** Python values exist;
there is no hostile-input transport, allocation or memory-containment claim.

See [verification and remaining gates](../../docs/progress/phase-1-evaluation-scoring.md).
