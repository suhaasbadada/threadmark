# Actual Graphify retrieval comparison

TM-02/04/07/10; P1-A1/P1-A5 **partial; twelve-condition trial complete**. Phase 1 remains open.
[ADR 0010](../../docs/decisions/0010-graphify-retrieval-comparison.md).
No Graphify adoption, native-host readiness, inference, storage or companion claim.
Primary independent review and the existing 20-test extraction retained-owner
lifecycle regression passed before the single authorized execution. The study is
now stopped; its frozen matcher/results must not be tuned or rerun implicitly.

## Observed outcome and decision

The retained [manifest](evidence-v1/manifest.json) was flushed/fsynced before all
twelve workers; [report](evidence-v1/report.json) records every condition ready,
exit zero and cleanup verified. All four project/backend groups were
byte-deterministic across three repetitions. In every condition TP=8, FP=0,
FN=8, precision=1.0 and recall=.5 (the eight-slot ceiling against 16 gold lines).

**Equal scores mask an adapter coverage gap, not backend equivalence.** Authored
available evidence was eight definitions/eight callers; its selection contained
four Rust/four Python lines (units 0000/0001/0004/0005). Graphify adapter available
evidence was four definitions/four callers; its eight selected lines were all
Python (units 0001/0005/0009/0013), in both projects. Both selected four definitions
and four callers, but the source sets differed.

The declared `_callable=true` requirement excludes Rust function nodes without
that marker, and consequently their incoming calls. Read-only pinned producer
source and the historical raw holdout support this adapter-contract explanation;
the current trial did not retain full raw graphs. This does **not** demonstrate
that Graphify cannot extract Rust, nor an adequate Rust/backend comparison.

Decision: this trial provides no justification for default Graphify adoption.
It does not establish overall equivalence, general rejection, scaling or user
value. Preserve the matcher, valid limited-envelope scores and counterexample;
any revised cross-language contract requires a separate prospective decision.

## Fixed question and comparison

Does actual pinned Graphify AST output supply useful source evidence under the
same prospective interleaved ranking as the authored directcall backend?
Exactly 12 fresh workers: repetitions 1, 2, 3; within each, harbor authored,
harbor graphify, harbour authored, harbour graphify. Three repetitions test
determinism, not independent samples. No tuning queries/ranking after outcomes.

Both arms use the unchanged SMALL corpus digest
`c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8`, original
definition_directcall query/instructions and all 16 selected sources per scope:
8 Rust, 4 Python, **4 Markdown**, 2076/2088 bytes. Scope filtering is solely the
original selected project, never query/oracle-based. The worker receives only
sources, their hashes, original method task and fixed backend identity; no oracle.

`selection._choose` is the single shared rank/dedup/interleave implementation:
original query identifier order, UTF-8 path, line; alternate definition/call,
definition first, spill, eight unique whole lines. Authored uses the existing
`selection.select` API. That API, policy `evidence-selection/1`, envelope and
historical canonical/readable demonstrations remain byte-compatible; historical
source hashes are not rewritten. The new authored condition must be measured
fresh: the old demonstration is not a comparative result.

Graphify uses only `graphify.extract.extract(paths, root=..., cache_root=...,
parallel=False, max_workers=1)` with every selected file. Markdown structural
headings/links are supported by the installed public extractor; no semantic/LLM
pipeline. Match only `file_type=code`, `_callable=true`, nonclass bare ASCII
`name()` labels against original query identifiers, then returned one-hop
`calls` edges targeting those IDs. Never guess from a label without the marker,
search source text for calls, resolve names ourselves, or upgrade confidence.
Validate unique IDs, every node/edge anchor, known endpoints, AST origin,
confidence labels, line bounds and exact input-path accounting. Any failed or
skipped source (including Markdown), unknown shape or overflow invalidates the
whole case. `unsupported_coverage` is reported explicitly. Optional upstream
metadata, including Markdown `node_kind`, is ignored and never forwarded.

## Scoring and interpretation declared before a run

Both adapters return exact six-field source anchors to the **existing** full
adapter Fixture/scorer: gold denominator 16, maximum eight items, entire canonical
candidate including coverage at most 8192 bytes; no truncation. Base fixture
coverage is augmented with the same selection policy, backend limitations and a
selection-metadata binding. Scorer `coverage.status=complete` means the declared
evaluation envelope is complete, **not** that Graphify's graph is complete.
Both remain LIMITED_STATIC; syntactic preflight is not runtime or macro proof.

Report TP/FP/FN, precision/recall and ceiling from the existing scorer, plus
available/selected unique-line definition/call counts. A shared line may count
both categories, never two slots. Declared confidence fact counts (including
UNDECLARED) are auxiliary, not a claim that anchor scoring measures confidence
or relationship correctness. All valid results, including zero matches or no
advantage, are useful; no graph benefit/adoption claim before actual results.
Invalid/unavailable results have null metrics, stop the entire trial immediately,
retain the partial report, and never retry, fallback or widen coverage.

The old 18-case declaration-first lexical/symbol/candidate study is frozen:
report SHA-256 `5970f8d28c1cccaf7184fa17997d9a0a3b0bb3f732750392b703ad559541b1f2`;
manifest `a816fab893d9e8010eb1f06ccf38910f0578fd5af200ddff7641e2109cd8e455`.
Its recorded precision/recall are lexical .875/.4375 and symbol/candidate 1/.5
in each scope. These are recorded references, not reruns or retroactive rescoring.
The new manifest verifies unchanged old algorithm hashes, corpus and originals,
and copies recorded quality objects without invoking a scorer on old results.
Different selection policy and trial: **no historical timing comparison**.

## Historical invocation contract — no new run authorized

No default launch. The one authorized trial used this command shape:

```sh
python3 -B experiments/graphify-comparison/pilot.py --run-small \
  --output NEW_PUBLIC_EVIDENCE_DIRECTORY \
  --private-diagnostics NEW_PRIVATE_DIRECTORY_OUTSIDE_REPOSITORY \
  --hardware-model DECLARED_MODEL --ram-bytes DECLARED_POSITIVE_RAM_BYTES
```

Both directories must be new; no arbitrary source, executable, query, pin,
backend, environment or budget override. Dependencies must already be installed:
graphifyy 0.9.101, tree-sitter 0.25.2, tree-sitter-python 0.25.0,
tree-sitter-rust 0.24.2; metadata fails closed, no installation. Only the explicit
future worker imports native parsers/Graphify. Python `ast.parse` and reused Rust
`root.has_error` preflight check syntax without executing sources; Markdown is
not parsed as a programming language. Read-only installed-source inspection is
not a native result.

The manifest is exclusively written, flushed and fsynced **before any worker**:
exact order, original tasks/hashes, corpus/source hashes, full gold denominators,
existing scoring manifest, selection definitions, all authored code dependencies,
installed pins, declared hardware/RAM, Python binary hash and OS metadata, budgets,
old references and interpretation. Recheck bindings before/after each condition.
Public reports contain relative synthetic citations only. Private bounded worker
stdout/stderr are retained separately before admission, never echoed; failed API
diagnostics are not public. The worker protocol does not expose the whole raw graph.

Reuse the existing extraction retained owner, not a new supervisor/receipt
framework or expanded Runner arm universe. Both arms: 15 seconds, 256 KiB aggregate
stdout+stderr cap, 16 files/64 KiB input, 2000 declarations/nodes and 4000 calls/edges.
Fresh owned source/cache/HOME/all XDG base directories and allowlisted environment,
`sys.executable -I -B` fixed authored worker, no source import path. Retained owner
proves process-group cleanup; temporary trees are removed before admission.
Worker stdout/stderr loss on owner/cleanup failure remains an existing limitation;
partial public report survives, but no new diagnostic-retention guarantee exists.

30-minute trial ceiling with full 15+2 second worker/cleanup reservation before
each next launch. Helper elapsed observations include its existing lifecycle,
not a retrieval-only benchmark. No enforced memory/RSS claim, OS-cold claim,
performance conclusion, warm cache measurement (NOT_AVAILABLE), scaling beyond
SMALL, network/inference/provider, host/VM/account or product change.

## Offline verification

```sh
python3 -B -m unittest discover -s experiments/graphify-comparison
```

27 pure/mocked tests cover both scoring adapters, frozen reference bytes,
historical raw holdout, Markdown metadata/coverage, IDs/endpoints/provenance,
Unicode/line anchors, budgets, no native import, default opt-in, fixed order,
manifest-before-launch, bounded owner invocation/cleanup and stop/no-retry.
These do **not** replace the primary lifecycle gate or actual 12-worker trial.
Integrated offline CI runs these pure/mocked tests, never the Graphify study.
