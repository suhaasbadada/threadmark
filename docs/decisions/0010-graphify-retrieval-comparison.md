# ADR 0010 — Actual Graphify retrieval under shared interleaving

Status: **single trial complete; no default adoption justified; Rust comparison inconclusive**.
TM-02/04/07/10; P1-A1/P1-A5 partial. Phase 1 remains OPEN.

## Decision

Implement one fixed SMALL comparison, not another wrapper-only quality claim:
three repetitions × two original scopes × authored/Graphify extraction backends.
Both use the same existing evidence-selection/1 interleaved chooser, budget,
original query/instructions and complete selected source set including Markdown.
Factor only that chooser; preserve old APIs, algorithms, corpus, oracle, scorer,
pilot artifacts and historical progress hashes. The old declaration-first quality
results are recorded references, never rescored with this policy.

The [protocol and historical command](../../experiments/graphify-comparison/README.md)
declare exact backend matching, native syntax preflight, all-input accounting,
caps, preregistration, failure handling and interpretation. Graphify's public AST
API supports structural Markdown; its optional metadata does not require changing
the reviewed scoped-static-v1 normalizer/report. Use a task-specific raw-field
adapter, no new parser, resolver, owner or generalized normalization framework.

Scoring uses the existing full 16-anchor gold denominator and six-field source
unit, with backend/policy/observation coverage binding. Kind/confidence counts are
separate auxiliary observations, not semantic correctness scores. Static/macro/
dispatch gaps remain explicit. Any skipped/failed source or invalid result stops
the entire trial with null metrics; no selective exclusions, retries or fallback.

## Acceptance and alternatives

Before any actual worker, require primary independent review and the existing
20-test extraction lifecycle regression. Retain an exclusive flushed/fsynced
manifest before the first of exactly twelve fresh bounded workers. Preserve all
outcomes and partial reports; compare determinism, not independent samples.
No adoption/quality claim before actual results, regardless of outcome.

Reject rerunning/rescoring the frozen 18-case pilot, dropping Markdown, changing
ranking only for Graphify, guessing callable IDs/relations, copying a parser or
scorer, or creating serial preparation PRs. A zero advantage or unavailable
Graphify result is useful evidence, not permission to tune the task to win.

No memory enforcement/RSS, warm/OS-cold/performance claims, larger-corpus scaling,
inference, host operation, native-pause change, daemon, storage, production engine
adoption or phase closure. No dependency installation or lockfile changes.

## Recorded outcome and bounded adoption decision

All twelve preregistered conditions completed ready/exit-zero/cleanup-verified;
all four repetition groups were byte-deterministic. Both backends reached
TP=8/FP=0/FN=8, precision=1 and recall=.5, the eight-slot ceiling. This does not
establish equivalence: authored selected four Rust/four Python lines, while the
Graphify adapter selected eight Python lines. Available definitions/callers were
8/8 versus 4/4. The ceiling masked the language-coverage counterexample.

The frozen adapter requires `_callable=true`. Pinned Rust producer source and
historical raw evidence show Rust declarations without that marker; matching
therefore excludes those declarations and their incoming calls. Current replies
do not retain full raw graphs. This is an adapter-contract gap, not proof of a
Graphify Rust extraction failure or adequate overall backend comparison.

Do not adopt Graphify by default on this evidence; do not reject it generally.
Retain the exact matcher, manifest and results without tuning or rerunning this
trial. A changed language contract needs a separate prospective decision. See
the [outcome record](../progress/phase-1-graphify-comparison.md) for evidence,
review, correction and limitations. P1-A1/P1-A5 remain partial.
