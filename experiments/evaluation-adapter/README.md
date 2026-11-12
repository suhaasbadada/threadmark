# Pure corpus-to-fixture adapter

**Public synthetic preparation only. P1-A5 PARTIAL; Phase 1 OPEN.** This is an
experimental fixture adapter, not a product host adapter, retrieval, evaluation
runner, extractor, inference, source execution or Phase 2 implementation.
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) remains proposed.
Lexical/symbol/candidate arms and runner: **NOT_IMPLEMENTED / NOT_RUN**.

```sh
python3 -B -m unittest discover -s experiments/evaluation-adapter -v
```

Python 3.10+ standard library only. No CLI, filesystem/source loading, arbitrary
path interface, parser, imports of other experiments, network, subprocesses,
threads, providers, packages, Docker, host configuration or clipboard operations.
Sources are supplied inert immutable byte strings and never executed. Count and
byte checks happen **after Python objects exist**, not at a hostile transport or
memory-containment boundary. The surrounding foundation verification script and
CI checkout have their own tooling; they are not capabilities of this module.

## Input and trust boundary

`prepare(sources, manifest, oracle, inputs, selected_scope, *, expected_digest)`
returns a tuple of four frozen `Case` values or raises `ValueError` without a
partial case or fallback. `sources` is a sorted immutable tuple of `(path, bytes)`
pairs. Metadata is canonical ASCII JSON bytes: sorted keys, compact separators,
`ensure_ascii=True`, no NaN, no newline, no duplicate keys. Schema, generator and
template versions are exactly string `1`. Selected scope has exactly project,
worktree and revision; labels are fixture data, not credentials or real Git facts.

**`expected_digest` must come from a trusted, separately predeclared pin.** A
future caller must freeze that supplied pin before any execution, outside the
candidate's control. The adapter never derives the expected pin from the manifest
or refreezes it. Computing and checking a new candidate self-digest is insufficient.
A malicious caller controlling both artifacts and the trusted pin is outside this
boundary: integrity is not authentication, source approval or semantic permission.

The digest is SHA-256 of the canonical manifest without `digest`. That manifest
binds exact source byte hashes/counts, oracle bytes and input bytes. Independently
checked: field sets/types/versions, tier ceilings, fixed file/aggregate caps,
source ordering and uniqueness, project totals, scope/path consistency, per-file
hashes, oracle/input hashes, every fact's exact scope/path/line/text and conflict
references. Unknown fields/kinds/versions, absent families, empty required metadata,
duplicate anchors, wrong scope/revision, foreign/traversal/control paths or mismatched
bytes fail closed. Metadata blobs additionally have a 16 MiB post-allocation bound.
The only paths accepted are the documented paired-root `unit_0000.rs/.py/.md`
grammar, not general repository paths. No path is resolved or opened.

The fixed corpus has 32/256/2048 sources in its tiers, with 1/8/32 MiB aggregate
and 65536-byte per-file ceilings. This adapter accepts **miniature authored
artifacts below a tier's count ceiling** under their own explicitly trusted pins,
so unit tests need not copy or instantiate the generator. They must still have
both roots, all four families and consistent counts/hashes. Production corpus
identity depends on the separately reviewed exact corpus pin, not this relaxed
miniature count bound. This is fixed-artifact validation, not recipe reconstruction
or a validator of arbitrary repositories. Unrecognized schema shapes are unsupported.

## Frozen mapping (declared before any future pilot)

Source text must be valid UTF-8 with LF-only physical lines. CR, CRLF, other
`splitlines()` separators and non-tab/non-LF C0 controls are rejected, never
normalized or truncated. Split on LF, omit only the final empty segment; interior
blank lines count. This preserves current generated LF content while avoiding the
corpus/scorer normalization ambiguity. No source syntax or line semantics are parsed.

For the exact selected project/worktree/revision:

- Allowed anchors include **every source line in every selected source file**,
  ordered path then line, with exactly project/worktree/revision/path/line/text.
  Current irrelevant lines remain available for future false positives. Source
  inputs are never narrowed to oracle facts, relevant files or the first eight.
- Definition/direct-call gold is **all** scoped `definition` and `direct_call`
  facts. The original broad all-resolve objective is unchanged. Gold above eight
  remains above eight; this module does not rank, predict or compute a ceiling.
- Conflicting-rule gold is only scoped `current_decision`. Scoped
  `stale_decision` anchors are rejected in every family, never gold. Other roots
  are excluded from the allowed map. Old/mismatched oracle scopes fail validation,
  rather than being admitted as current. No cross-root source-map mixing.
- `macro_gap` / `dynamic_gap` are declared unknowns, not positive gold. The
  oracle's expected unknowns, conflicts and rejection recipes remain private
  fixed expectations, never observed extractor evidence. There is no invented
  exclusion status or semantic permission check derived from plaintext.
- Negation/permission and rename/delete/malformed/interruption/recovery are
  **conformance_only** with empty relevance gold. All metadata is retained.
  Pure fresh-value recovery proves nonmutation, not actual worker recovery,
  cancellation, dependency handling, malformed-source recognition or task quality.

`Case.fixture` is plain canonical UTF-8 JSON, not a scorer object. It contains
scope, family, ordered coverage strings, anchors, gold and rejected. Coverage binds
schema/generator/template version, trusted corpus digest, oracle/input hashes,
one digest over the complete selected-source manifest (including all source
hashes) and known parser/macro/dynamic gaps. The full manifest remains in the
private sidecar: repeating every hash in a candidate's coverage envelope would
exhaust its 8192-byte budget before any evidence on larger tiers. It describes a
**limited fixture map**, not actual extractor completeness or syntactic
certification. There is **no result `complete` flag**, candidate or metrics.

## Keep future arm inputs separate from answers

Only `Case.arm_input` may go to a future arm:

- `sources`: all exact selected-scope `(path, bytes)` pairs, without answer hashes.
- `declared_task`: canonical data retaining the exact original family fields and
  original instructions, unchanged in content (including negations/newlines).
- `method_task`: UTF-8 canonical five-field `evaluation-scoring/1` task data only
  when the family already has a query. No scorer code is imported or run.

The negation family supplies `original` and `constraints`, not a query.
Its `method_task` is **None** and score-manifest mapping **NOT_AVAILABLE**. No
query is manufactured, no instructions are appended/rewritten and no constraints
are dropped to satisfy the scorer schema. Other mappings are labeled
`task_fields_only_not_integrated`, not drop-in compatibility.

**Never pass `fixture` or `private_sidecar` to an arm.** The sidecar retains the
entire original manifest, oracle and task metadata (all unknowns, constraints,
conflicts, recipes and answer-bearing hashes), classification and prospective
budgets: eight items, 8192 candidate bytes, 4096 original-request bytes. Original
query/instructions use the scorer's combined canonical UTF-8 budget unit; the
non-query family conservatively includes original/constraints/instructions.
Overflow rejects, never truncates. No candidate is accepted or emitted here;
8192/eight-item enforcement belongs to future output admission, not gold truncation.

Frozen dataclasses, immutable source bytes and serialized private payloads avoid
mutable aliases. A bad candidate cannot change prior prepared cases. There is no
last-good state, cache or persistence. The test suite explicitly verifies answer
separation, all four families, all-gold retention, scope isolation, pin forgery,
validation negatives and fresh valid-value recovery.

## Independent source contracts, not integration evidence

Only authored files were read for compatibility design; no implementation was
copied, imported or run from either retained checkout:

- PR #9 reviewed code `df49ecbfd38dbd6c39be3ff214bf2de383dd51a1`:
  [corpus schema](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/corpus.py),
  [contract](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/README.md).
  Supplied PR head: `eba04746fcbf0857e7b8af18e217b047f0353829`.
- PR #10 reviewed code `00bd8e957c45ba8ad9742a320751364263391da4`:
  [scorer schema](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/scoring.py),
  [contract](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/README.md).
  Supplied PR head: `23ad31623dba76fa518de1865c2d92ee836225c1`.

These are supplied immutable source references, not freshly queried remote state.
**No actual full corpus or scorer integration was tested.** Tests use only a tiny
independent authored artifact and pinned expected outputs. The parent may later
declare a separately pinned pure-module compatibility check. A future scorer
constructor still needs to translate this plain fixture's scope/anchors/gold/
rejected/coverage into its own types; no import or caller/worker implementation is
provided here. Retrieval normalization, complete coverage admission, candidate
implementation, runner containment, review and exact-head CI remain separate gates.

See [acceptance and verification](../../docs/progress/phase-1-evaluation-adapter.md).
