# ADR 0006 — Prospective Phase 1 evaluation protocol

Status: **proposed experiment protocol; not executed or product targets**.
Date: 2026-11-12. TM-02, TM-04–TM-08, TM-10; P1-A5 partial.

## Context and decision

[Phase 1](../spec/phase-1-feasibility.md) requires representative evaluation and
predeclared budgets. Existing tiny fixtures establish individual mechanisms,
not improved task correctness, representative performance or user value. This
protocol applies only to future measurements; it does not retroactively score
earlier experiments. No experiment is launched by accepting this document.

Keep safety conformance, retrieval quality, refinement quality and end-to-end
task outcomes separate. Compare these conditions with the same source snapshot,
task, permissions and executor version:

1. Raw request without added context.
2. Raw request plus fixed instruction-file practices.
3. Raw request plus bounded retrieval only.
4. Reviewed refined brief, without failure guidance.
5. Reviewed refined brief with evidence-backed failure guidance.

Conditions 4–5 require separately authorized inference and an implemented review
path. Live executor comparisons require an independently contained, authorized
host. Neither prerequisite is met. A hand-authored brief or fake provider may
test protocol plumbing but cannot substitute for measured refinement quality.
Conditions 1–3 may be inspected offline; without execution their results are
retrieval/intent observations, not task-success scores.

## Prospective synthetic corpus

Use paired, similarly named projects with conflicting decisions and identical
local symbol names. Each size tier totals both projects:

| Tier | Source files | Aggregate UTF-8 ceiling | Per-file ceiling |
| --- | --- | --- | --- |
| Small | 32 | 1 MiB | 64 KiB |
| Medium | 256 | 8 MiB | 64 KiB |
| Large | 2,048 | 32 MiB | 64 KiB |

Only hand-authored/generated synthetic Rust, Python and Markdown; no downloaded
repositories, private source, executable source evaluation, binaries, symlinks or
package installation. These are test scales, not claims of real-repository
representativeness. Before execution, commit the generator/templates and a
manifest of exact bytes, content hashes, project/worktree/revision labels, file
counts, expected facts/anchors, exclusions and known parser limitations. A
missing manifest, incomplete corpus or changed hash invalidates comparisons.

Declare these four task families for every tier, with expected evidence and
failure outcomes fixed before any extraction:

- Definition and direct-call lookup, including repeated names in the other root.
- Conflicting project decisions, stale evidence and wrong revision/worktree.
- Constraint/negation preservation and unresolved material permission ambiguity.
- Rename/deletion, malformed source, interrupted extraction and fresh recovery.

Keep adversarial/failure variants separately labeled; do not average successful
and fail-closed cases into an accuracy score. Rust macros and Python dynamic
calls remain explicit coverage gaps unless independently verified.

## Measurement and budgets declared before future runs

- One worker, one project selected, no concurrent conditions. Empty owned worker
  cache defines cold; reuse that cache for warm in a new process. Never claim
  OS page-cache eviction. Use three repetitions per applicable condition/tier,
  publish every result, median and range; no p95 from three observations.
- Declare machine model, OS/build, architecture, RAM, tool versions, dependency
  pins, executable/corpus hashes and run order before execution. Those evaluation
  environment fields are currently **unassigned**, not inherited from old probes.
- Prospective worker wall-time ceilings: 30/120/300 seconds for small/medium/large;
  output ceiling 16 MiB per invocation; cancellation termination deadline two
  seconds. Trial-wide ceiling 30 minutes. Stop at a breach; retain its failure,
  do not extend thresholds to make it pass. Existing harness limits still apply
  until a separately reviewed runner implements this protocol.
- Prospective worker peak-RSS stop thresholds: 512 MiB/1 GiB/1 GiB. The runner
  must declare whether enforcement is hard, sampled or unavailable before launch.
  Unavailable enforcement blocks scaling beyond small. Sampling is not hard
  containment; report units and platform conversion. Do not reuse task processes
  between conditions or retain graph/context memory across them.
- Retrieval payload ceiling 8 KiB UTF-8, at most eight anchored evidence items;
  original request ceiling 4 KiB; candidate ceiling 8 KiB. These are evaluation
  limits, not host transport claims. Original constraints cannot be silently
  truncated. Overflow is a recorded rejection, not a selectively dropped result.
- Inference/network/spend budget **zero** under current authorization. No login
  token reuse, remote provider, model download, real host action or clipboard.
  Positive provider budgets need a separate consent/cancellation/redaction plan;
  do not reinterpret zero as permission for a free remote endpoint.

Record retrieval, inference, review, handoff and executor time/cost separately.
Unrun stages are `not_run`, not zero-duration successes. Record worker peak RSS
and measurement method, relevant-evidence precision/recall against the frozen
oracle, unsupported/stale claims, intent violations, correction effort and task
correctness. Human review effort requires an actual declared reviewer/task and
timing protocol; synthetic button activation is not user effort.

## Safety and result interpretation

Any cross-project/revision admission, lost constraint, fabricated permission,
send on cancellation, unreviewed change or retry after unknown admission fails
that condition. A blocked request can pass a rejection test but cannot count as
a completed useful task. Tests must include dependency failure and fresh recovery.
No quality-improvement threshold is selected from these unrun results. A future
claim requires predefined scoring, all conditions and independent outcome review;
passing synthetic conformance alone never establishes product value.

## Consequences and exclusions

Next safe implementation is a reviewed offline corpus/manifest and measurement
runner on an isolated task branch, not a product indexer or adapter. This ADR
does not approve an architecture change, adoption of Graphify, packaging, service
startup, provider access, merging other PRs or Phase 2. Actual corpus, evaluation
environment, measurements and full P1-A5 acceptance remain pending.
