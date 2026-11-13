# ADR 0009 — Scoped static extraction normalization experiment

Status: one primary-authorized six-case experiment executed after independent
review, coordinate repair and existing bounded lifecycle tests. Results are in
the progress record below; no repeat is automatically authorized. Graphify
production adoption remains deferred. TM-02/TM-04/TM-07/TM-10;
P1-A1 / extraction-only P1-A5 partial.

## Decision and boundary

Keep [ADR 0002](0002-extraction-feasibility.md), its historical validator and
[raw results](../../experiments/extraction/results.json) unchanged. A separate
stdlib normalizer accepts only the pinned AST API's needed public shape and
exact source bytes plus supplied project/worktree/revision labels. Reject the
whole candidate on unknown shape, ambiguous IDs, dangling edges, foreign paths,
invalid/out-of-range anchors or incomplete source coverage. Do not repair or
adopt Graphify, fabricate kinds/direction, or upgrade confidence from AST origin.

`threadmark.scoped-static.v1` preserves upstream IDs, labels, file types, origin,
edge relation/direction/confidence and optional context. Nodes have no invented
confidence. Anchors expose canonical relative paths, inclusive start/end lines,
source SHA-256 and exact synthetic excerpts. Line coordinates count LF rows;
CRLF is normalized to LF, embedded Unicode separators and bare CR remain literal,
and one terminal empty split segment is omitted. Node identity is a canonical SHA-256
of contract version, supplied scope, raw ID and source anchor (including content
hash); edge identity includes scope and its normalized endpoints/facts/anchor.
Reordering is immaterial; changing scope or source changes affected identities.
These hashes are local identity/snapshot consistency, **not** authentication,
freshness, rename lineage or cryptographic receipts. No persistence, last-good
fallback, host authority, retrieval ranking or Phase 2 importer is implemented.

Every accepted result is `LIMITED_STATIC`. Before importing Graphify, Python
uses stdlib `ast.parse`; Rust uses installed tree-sitter's `root_node.has_error`.
Syntax success is not semantic closure, macro expansion or runtime certainty.
Keep the documented dynamic-callback and macro gaps; no new language taxonomy.

## Prospective six-case protocol and output

Only copied approved public synthetic `orbit` / `orbit-next` fixtures. For each:
baseline, fresh copy plus authored `broken.py` containing `def broken(`, then
fresh unmodified recovery. Six sequential fresh bounded workers, each with its
own source/cache/HOME/XDG directories and clean environment. Preserve existing
15-second / 256-KiB aggregate output / 16-file / 64-KiB input / 2,000-node /
4,000-edge caps and retained-owner teardown; no copied process implementation.
Memory remains observed only by the historical experiment, not enforced here.

Require already installed graphifyy 0.9.101, tree-sitter 0.25.2,
tree-sitter-python 0.25.0 and tree-sitter-rust 0.24.2; version or dependency
failure rejects, never installs. Inspecting installed source confirms
`extract(paths, root=root, cache_root=cache, parallel=False, max_workers=1)`.
No fixture execution/compilation, network, inference, provider/CLI pipeline,
credential reuse, runtime installation or policy change. This is trusted local
package execution, **not a sandbox** or dependency redistribution approval.

Parent CLI produces `threadmark.scoped-static-experiment.v1`: declared caps,
case/status/version metadata, accepted snapshots and two exact-label question
rows (where `normalize()` occurs; which returned `calls` edges target it), with
namespaced IDs, relative citations and synthetic source excerpts. It requires
two rows for each question per valid fixture. No broad quality claim follows.
Full baseline/recovery snapshots must match within each scope, cross-root node
IDs must be disjoint, and malformed cases must accept zero nodes. If Python
preflight rejects before Graphify import, record **Graphify NOT_RUN**, not a new
observation of Graphify's malformed-source behavior. The old counterexample
remains historical evidence. No last-good state exists to lose or restore.

Raw returned stdout/stderr and failed API payloads stay in an explicitly new
private directory outside the repository; public failures contain only stage
categories. Diagnostics survive temporary-source cleanup. Abrupt process death
and output-budget/teardown failures retain only what the existing owner can
return; no new diagnostic retention guarantee is invented for those failures.
The new report must be separately named and reviewed before staging; never
overwrite historical `results.json`. CI runs only stdlib/mocked tests, not this
actual six-worker gate. See [prospective progress](../progress/phase-1-scoped-extraction.md).

## Alternatives and exclusions

Reject trusting Graphify's completion arrays alone (known malformed-source
counterexample), merging raw producer IDs across roots (known collision), and
writing a custom parser/resolver. Syntax preflight plus a replaceable normalized
boundary is deliberately narrower than engine repair or product adoption.
P1-A1/A5 remain partial: representative evaluation, inference behavior,
transitive licensing/packaging, containment, persistence and host integration
remain open. Native-host launches and T3 handoff remain paused/out of scope.
