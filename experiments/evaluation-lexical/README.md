# In-memory lexical feasibility baseline

Phase 1 only: TM-02/04/07/10, **P1-A1 baseline portion / P1-A5 PARTIAL**.
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) remains
proposed; Phase 1 remains open. This implements one lexical source-line method,
not a product indexer, semantic safety/intent check, parser, symbol/graph arm,
worker, evaluation pilot, inference or functioning companion. Other arms remain
unimplemented. No scorer manifest in another branch is changed by this unit.

Python 3.10+ standard library only, from the repository root:

```sh
python3 -B -m unittest discover -s experiments/evaluation-lexical -v
```

## Pure API and preregistered scope

`retrieve(sources, task)` returns an immutable tuple of frozen `Anchor` values,
or raises `ValueError` with no partial/fallback output. No cache or last-good
state. Inputs are not modified. `sources` is an immutable tuple of `(path, bytes)`
tuples, strictly ascending by path UTF-8 bytes, without duplicates. These are
already approved synthetic inputs, not authenticated repositories. Every selected
source must be supplied, without oracle-based narrowing. The API cannot prove
that the caller supplied the full approved selection.

`task` is a dict with exactly `schema`, `scope`, `family`, `query`, `instructions`.
Schema is exactly `evaluation-scoring/1`; scope has exactly `project`, `worktree`,
`revision`. Labels use `[A-Za-z0-9_-]{1,128}` (a deliberately bounded subset of
the prospective scorer's strings). They are not paths, credentials, permission
or verified Git facts. Query and instructions are nonempty valid UTF-8 strings,
preserved verbatim; instructions never contribute query tokens. Only
`definition_directcall` and `conflictingrules_stale_wrongrevision` are supported.
Conformance and unknown families reject, not empty quality successes.

Paths are normalized relative POSIX strings **including the selected project as
the first component**, e.g. `harbor/src/a.py`; only `.rs`, `.py`, `.md` suffixes.
Absolute, backslash, C0/DEL control, empty/dot/traversal components, foreign roots,
duplicates and out-of-order sources reject the entire invocation, even if they
contain no matching tokens. Same-local-name `harbor`/`harbour` roots stay distinct.
Source bytes carry no independent worktree/revision identity: checking their true
provenance remains a trusted caller gate. Unknown fields, wrong types (including
mutable source containers/bytes), invalid UTF-8 and bad schema/scope reject.

## Frozen algorithm and exact units

1. Extract unique lowercased maximal ASCII `[A-Za-z_][A-Za-z0-9_]*` query matches.
   No stopwords, stemming, semantic expansion, oracle filter or prompt rewrite.
2. Split each UTF-8 source on LF; omit only the final empty split segment, remove
   one terminal CR on each remaining line, keep interior blank line numbers.
   A remaining CR rejects as unrepresentable by the scorer's single-line anchor;
   other Unicode line separators are not LF and remain in the same line.
3. Tokenize each whole line by the same rule. Keep lines sharing at least one
   query token. Rank by descending **distinct** overlap, then UTF-8 path bytes
    ascending, then numeric one-based line. Rank each line after full validation.
4. Return the top eight distinct coordinates, retaining identical text at
   different coordinates. Whole six-field anchors only: project, worktree,
   revision, path, line, text. No classifications, fuzzy or partial credit.

Validation precedes selection for every source. Decoded lines are retained only
for the current file; source references remain immutable. Selection retains the
best eight incrementally (at most nine live ranking candidates during insertion),
not every match. A regression measures candidate-object retention on 1024 authored
matching lines. This is not a hard RSS, CPU or hostile-input containment proof.

Comments, strings, Markdown and stale/negated/foreign-looking **text** are
intentionally retained. Filtering those to match gold would change the method.
No ASCII query tokens gives an empty anchor tuple after full input validation;
that is not a relevance or safety claim.

Limits, all inclusive and checked **after Python objects are allocated**:

| Unit | Ceiling |
| --- | --- |
| Selected sources | 2048 files / 32 MiB aggregate / 65536 bytes per file |
| Canonical `{query,instructions}` JSON | 4096 UTF-8 bytes |
| Selected anchor list canonical JSON | 8192 UTF-8 bytes / 8 items |

Canonical JSON sorts keys, uses compact separators, raw UTF-8, no NaN and no
trailing newline. No transport/allocation/RSS/timeout containment is implied.
Source-size arithmetic tests use repeated authored inert bytes, not an evaluation
corpus or scale/performance run.

**The returned tuple is NOT a complete scorer candidate.** It has no coverage,
schema envelope, oracle or answer-bearing hashes. The list-only 8192-byte check
is a necessary early rejection, not proof the full candidate fits. A future
trusted normalizer must independently validate scope/source provenance and exact
anchors, add separately reviewed coverage plus scope/schema, then check the
**complete** canonical 8192-byte candidate. Preserve the frozen top eight: reject
overflow, never truncate text, drop costly lines or substitute cheaper ranks.
Neither list fitting nor successful retrieval authorizes `complete` coverage.

## Source contracts and future gates

Read-only design references (no implementation copied, imported or run):

- PR #10 reviewed [scorer](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/scoring.py)
  and [contract](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/README.md);
  supplied head `23ad31623dba76fa518de1865c2d92ee836225c1`.
- PR #12 reviewed [adapter schema](https://github.com/suhaasbadada/threadmark/blob/318dc02e3d9dd299b66b1c080892c4e0a1954f1c/experiments/evaluation-adapter/adapter.py)
  and [contract](https://github.com/suhaasbadada/threadmark/blob/318dc02e3d9dd299b66b1c080892c4e0a1954f1c/experiments/evaluation-adapter/README.md);
  supplied final head `3220bde0ecceea5c1e03d4632be007837222df68`.

These are supplied immutable public references, not a fresh remote-state check.
No full corpus was read or instantiated. Future caller integration must decode
declared task bytes separately, keep private fixture/sidecar/coverage/oracle hashes
away from this API, and review normalization. The adapter rejects CR inputs while
this scorer-aligned baseline normalizes terminal CR: LF-only compatibility is
plausible, not integration evidence. Other-source/corpus mappings remain gated.

No file IO/export/discovery, source parsing/import/execution, subprocesses,
threads, network, listener, providers, host/clipboard/config actions, packages,
Docker, downloads or new dependencies occur in the module/tests. Foundation
checks and CI checkout are separate tooling, not baseline capabilities.
See [observations, checks and open gates](../../docs/progress/phase-1-evaluation-lexical.md).
