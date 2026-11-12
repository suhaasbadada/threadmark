# ADR 0002 — Optional structural extraction feasibility

Status: experiment authorized; production adoption **deferred**. Scope: TM-02,
TM-04, TM-07, TM-10; P1-A1 and extraction subset of P1-A5.

## Protocol declared before the first run

Use only the existing Python 3.12.6 / graphifyy 0.9.101 installation. No install,
model, provider, CLI pipeline, semantic pass, or binary redistribution. Explicit
synthetic file lists only. Run `graphify.extract.extract(paths, root=...,
cache_root=..., parallel=False, max_workers=1)` in a fresh subprocess, isolated
Python mode, empty experiment HOME/cache/temp and allowlisted environment.
These controls are **not** a sandbox or demonstrated network containment.

Provisional limits, not performance acceptance targets: one worker; 15 seconds
per invocation; 256 KiB combined stdout/stderr; at most 16 inputs / 64 KiB total;
2,000 nodes and 4,000 edges. Record elapsed time and worker maximum RSS (observe,
not enforce, 512 MiB provisional investigation threshold). No latency percentile,
medium/large corpus, idle memory, user-value or concurrency claims from tiny runs.
All experiment-owned copies/caches/temp disappear at exit, including failures.

Run each similar-named project separately, then repeat with warm cache, rename
one source, and delete it. Compare exact payloads, file provenance and IDs. Ask:
where is `normalize` defined; what directly calls it; which retention rule applies;
does a deleted definition survive? Lexical baseline is line substring search;
symbol baseline is Python stdlib AST / Rust declaration regex. These are tiny
declared baselines, not an evaluation of an IDE or production repository map.

## Replaceable boundary

Threadmark, not Graphify, would own project/worktree/revision identities and
atomic snapshots. External IDs are producer-local hints. A future adapter must
validate envelope version, exact requested scope, completion, input manifest,
source anchors, unique IDs, endpoint integrity, claim labels and budgets before
admission. This experiment's validator is a disposable test gate, **not** a
Phase 2 importer or authorization implementation. Rejection leaves an in-memory
last-good value untouched; no storage durability is claimed.

Keep this optional and outside foundation CI/runtime dependencies. Defer adoption
until inference labeling, representative language accuracy, packaging/dependency
license audit, containment, cancellation and durable reconciliation are tested.
Results and counterexamples: [experiment record](../progress/phase-1-extraction.md).
