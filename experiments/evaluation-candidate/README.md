# Frozen full-candidate admission integration

Phase 1 offline conformance, **not** a production knowledge core, refinement
engine, host adapter, runner or completed product. The complete agreed context,
refinement, OpenCode/T3, inference, UX and safety scope remains required.
[Phase 1](../../docs/spec/phase-1-feasibility.md),
[ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md) and
[progress](../../docs/progress/phase-1-evaluation-candidate.md).

## Interface and trusted boundary

`candidate.build(artifact, selected_scope, family, *, method="lexical", canceled=None)` accepts the
actual corpus module's immutable `Corpus`, exact selected scope and family ID.
It returns a frozen `Result(status, reason, original_input, candidate)`:

- `ready`: canonical full candidate UTF-8 **bytes**, independently admitted by
  the actual scorer; original declared task bytes are separate.
- `blocked`: invalid method/artifact/scope, unsupported family, changed task, malformed
  retrieval or rejected whole candidate; **candidate is None**.
- `canceled`: a declared synchronous checkpoint canceled; **candidate is None**.
- `unavailable`: dependency/probe failure, no provisional/last-good candidate.

Public policy approves only the actual frozen **small** recipe and pin from
`evaluation-corpus/corpus.py`. It first uses `corpus.validate`, then
`adapter.prepare` with the separately trusted authored pin. The caller cannot
supply an expected pin, private fixture, coverage, candidate headers, query
replacement, module name or filesystem path. Larger-tier integration/studies
are not performed here. Tiny boundary tests use a **private test-only** pin
seam and separately declared fixed pins, not production recipe acceptance.
Python privacy is a code ownership convention, not protection against arbitrary
code execution or monkeypatching in the same interpreter. Scope/digests enforce
value consistency and lineage, **not authentication or real Git identity**.

The optional keyword-only `method` must be an exact `str`: `lexical`
(unchanged default), `symbol` or `candidate`, matching the frozen scorer arm names. No
subclass acceptance, coercion, plugins or caller module/path selection. The
scope snapshot and preparation cancellation probe precede method validation;
invalid methods then block as `invalid_method` before any dependencies/retrieval.
No method field is added to existing results or candidate bytes.

Imports use fixed internal namespace-module names, resolving authored
modules in this checkout; run from the repository root. There is no arbitrary
module loader, generated fixture-source execution or dependency installation.
Existing module APIs, pins and algorithms are unchanged.

## Exact flow

1. Snapshot the selected scope before any cancellation/dependency callback;
   preparation checkpoint; validate immutable artifact and frozen scope;
   prepare all four adapter cases; retain the exact canonical declared original
   (including family/query or original/constraints and instructions).
2. Non-query **and** conformance families are explicitly unsupported. No invented
   query, negation mapping, fallback request, semantic permission or send occurs.
3. Construct scorer `Fixture`/`Anchor` values **only** from validated immutable
   adapter output. Keep all selected source lines, all gold and all rejected
   anchors; never narrow source selection to oracle facts.
4. Retrieval checkpoint; give actual selected `lexical.retrieve`,
   `symbol.retrieve` or `directcall.retrieve` only selected public
   source bytes and declared method-task fields. No oracle, fixture, coverage,
   fact kinds, hashes or answer labels. Reject mutation of task bindings.
5. Admission checkpoint; require the exact selected module's `Anchor` class,
   not a ducktyped or other-arm anchor; preserve its top-eight order and whole text.
   Construct schema/scope/coverage/items. Coverage `complete` means complete
   **within the original frozen limited adapter source-map envelope only**, not complete
   syntax, extraction, language coverage or useful context. The envelope retains
   adapter hash/version/source-map bindings and macro/dynamic gaps.
6. Serialize and call the **actual scorer** for exact source/scope/revision,
   rejected/stale, malformed/unknown, schema/coverage, duplicate/item and full
   **8192 canonical UTF-8 byte** admission. Full envelope fit is not list fit.
   Overflow/rejection blocks everything; no rank/text truncation or cheaper
   anchor selection. Scorer metrics are discarded, not measurements or output.
7. Final-return checkpoint; return immutable bytes only. There is no persistence,
   logging, retry, cache, fallback, clipboard, host action or implicit send.

## Candidate direct-call normalization (new review gate)

`candidate` realizes only the conservative one-hop subset documented in
[directcall](../evaluation-directcall/README.md), not Graphify or full Rust/Python
semantics. `_trusted.py` is a shared **private** normalization contract used here
and by parent runner admission. It retains the original adapter map/hash/gaps and
appends exactly two compact strings: `candidate policy sha256=…` and
`candidate observation sha256=…`. Both the trusted Fixture and submitted envelope
carry these exact ordered strings. Detailed observations remain immutable internal
canonical bytes, not unbounded candidate metadata.

Before preparation, authored source pins and the predeclared grammar-specific
standalone policy digest must match. Before retrieval callbacks, normalization
captures the supplemental integration policy and canonical full extraction
(declarations, endpoints/spans, every file's status/counts/unresolved/gaps), bound
to selected scope and each selected public source's path/length/SHA-256. No file
is dropped or selected using an oracle. Rechecks before retrieval, admission and
final return reconstruct observations through pure `directcall.extract`, never
ranking. Task bindings are checked after late callbacks too. Wrong/missing/extra/
reordered observations or changed code/policy block whole output with no fallback.
Fixed authored-code files alone are read for integrity; source inputs remain
in-memory bytes, never discovered/opened/executed. This is same-reviewed-extractor
consistency, **not an independent semantic oracle or runtime certainty**; arbitrary
same-interpreter code remains trusted. A current but irrelevant source anchor may
still admit under the unchanged scorer; this does not certify retrieval relevance.

The supplemental policy binds `evaluation-directcall-admission/1`, exact directcall
and dependency source hashes, grammar, historical standalone policy digest and
observation/admission rules. It does not rewrite the old pending manifest to
manufacture approval. Grammar 3.10–3.14 states have predeclared authored-manifest
digests; unknown versions reject rather than self-approve. Only **Python 3.12.6**
was locally exercised; native CI records its actual version/grammar, not universal
runtime certification. Parent independently reviewed exact integration
`07e1c802c3e84fc6d2d0b9afb9205ce68f3e4efb` through Joffrey (no substantive
findings), then verified two actual SMALL candidate-worker transport cases.
Exact-head native CI remains pending; these are not comparative quality results.

SMALL's eight returned declarations do not prove calls work. Separate fixed-pin
tiny Rust/Python fixtures prove call anchors after normalization; public build
rejects those refrozen recipes. The decision query admits an **empty** list, not a
quality win. Full canonical 8192 UTF-8 bytes count both commitments, original
coverage and duplicates; a fitting anchor list alone is insufficient.

The lexical decision query really retrieves retired evidence from the small corpus;
the **whole candidate blocks**. This normal counterexample is retained rather
than repaired with an oracle-aware lexical filter. The actual symbol decision
query returns an admitted **empty** item list: Markdown decisions supply no
declarations. This is not a quality win, completeness or stale-detection claim.
Injected exact stale evidence separately proves whole-candidate rejection for
both arms. Symbol declaration gaps remain as documented in its
[baseline contract](../evaluation-symbol/README.md); integration does not promote
source-map coverage to extraction/semantic/syntax completeness. An empty denominator or score
is not host-send permission; even `ready` is only value admission, never delivery
or authorization. Unsupported/failed results preserve the validated original if
preparation reached it; pre-preparation cancellation/failure has
`original_input=None`, while caller-owned immutable input remains untouched.

Cancellation invokes `canceled(stage)` at `preparation`, `retrieval`, `admission`,
`final_return` only. It must return bool; exceptions/non-bool fail unavailable.
It does **not** stop an uncooperative synchronous call, implement timeouts, kill
workers/descendants or prove runtime cleanup. Checks are post-allocation, not
hostile input memory containment. A fresh deliberate invocation can recover
after a failure; nothing reuses a last-good result.

## Bounded reproduction

```sh
python3 -B -m unittest discover -s experiments/evaluation-candidate -v
```

Tests use actual small frozen artifacts (both scopes), tiny separately pinned
two-line budget/original-preservation artifacts and explicit external-boundary
mocks. Assertions inspect public results and independently serialized/declared
anchors, not source grep/AST shape. No medium/large retrieval, quality study,
accuracy/precision/recall publication, timing/RSS comparison, model/provider,
network, process/worker, source discovery, export or execution. The existing
integrated read-only Linux/macOS CI has one additional fixed unittest command;
all previous commands and limits remain intact. The original suite has 24 tests,
retaining all 16 lexical regressions plus eight parameterized method-integration
tests. Both roots, private-input separation, exact selected anchor class,
invalid methods, task/scope mutations, cancellation call counts, dependency
recovery, stale/unknown/duplicate/overflow rejection and full-envelope boundaries
are observable assertions. Symbol full-byte boundary tests inject independently
authored anchors into the existing private test-pin seam (their inert boundary
text is not a declaration); real frozen SMALL symbol retrieval is tested
separately. No algorithm or pin is changed to manufacture expected output.
The same discovery command also runs the new pure directcall-admission tests;
no actual candidate worker or study is launched by them. See the
[integration evidence](../../docs/progress/phase-1-evaluation-directcall-admission.md).
