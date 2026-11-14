# ADR 0011 — Bounded current audit marker brief

Status: **isolated offline experiment contract; not runtime/adoption approval**.
Date: 2026-11-13. TM-02, TM-04–TM-08, TM-10; partial P1-A1/P1-A4/P1-A5.

## Decision and boundary

Under [Phase 1](../spec/phase-1-feasibility.md) and
[ADR 0006](0006-phase-1-evaluation-protocol.md), implement one runnable fixed
SMALL current-audit decision brief using only the already public
`conflictingrules_stale_wrongrevision` and `negations_permission` tasks. Preserve
the corpus, queries, original, instructions, constraints, oracle, algorithms,
scorers, prior reports and Graphify comparison evidence unchanged. No workers or
measurement study. Core later owns semantics; this experiment owns no runtime
parser, resolver, index, service, storage or host integration.

Use an explicit syntactic `Current rule: ` whole-line protocol on `.md` only,
not Markdown/NLP authority. Identical values repeat evidence, not conflicts;
distinct values mean ambiguity without a usable current answer. Absence means
unknown. Never choose latest, infer priority, use retired statements, or interpret
a source statement as permission. All source prose remains separately quoted
untrusted data. The original negations and permission question always survive.
See the [complete contract](../../experiments/decision-brief/README.md).

All 16 selected byte sources must match caller-supplied scope/manifest before
any evidence is emitted. Scope is not authenticated or live Git-verified. This
boundary accepts no filesystem handles or symlinks, no oracle selectors and no
arbitrary source execution. Immutable pure selection plus a small fixed
stdin/stdout inspector is sufficient; do not extend the earlier orbit review
controller or build a general workbench. Fresh checks, project changes and
dependency failure/recovery cannot reinstate old inspection. No send or execution
capability exists. Original-only fallback has zero evidence.

## Prospective acceptance (declared before primary CLI journeys)

- **DB-A1:** For each frozen project, four exact line-2 current-rule citations
  with correct source SHA, deterministic path/line ordering, and different retain
  versus delete marker values; no retired or foreign source. Independent oracle
  assertions/existing exact-anchor relevance scoring only.
- **DB-A2:** All 16 files validate, including non-Markdown. Wrong scope,
  worktree/revision, stale hash, rename, deletion, foreign/duplicate/traversal,
  malformed encoding/manifest, and bounds fail atomically to zero evidence.
- **DB-A3:** Repeated current values remain one syntactic answer; distinct values
  produce cited ambiguity/no usable answer, absence produces unknown. No guessed
  precedence or multiline/Unicode/control bypass. Empty values reject.
- **DB-A4:** Exact original, query, constraints and instructions remain visible;
  malicious source permission claims cannot alter them or resolve permission.
  Local inspection is never authorization; no send/execution-ready assertion.
- **DB-A5:** Fixed project switch clears inspection; simulated stale/outage and
  actual loader exceptions clear evidence/inspection. Recovery requires fresh
  inspection; cancel/EOF/limits end original-only, no final candidate leak.
- **DB-A6:** The primary, after independent review, may run single fixed scripted
  mechanical journeys: each project `show, json, inspect, cancel`; one switch
  `inspect, project harbour, show, inspect, cancel`; stale and unavailable
  `inspect, stale|unavailable, show, recover, show, inspect, cancel`; EOF with
  no command. Inspect the final canceled block, scope/rules, original and
  inspection invalidation. These are synthetic mechanics, not human usability,
  permission approval, host support or comparative task success. The implementation
  subagent does not run these actual CLI journeys.

Budgets: zero network/inference/spend; 16 sources, 64 KiB total; 4 KiB original;
eight evidence items; 8 KiB whole canonical JSON; 32 stdin commands of at most
1,024 characters. No silent truncation or partial ambiguity selection.

## Exclusions and consequences

No Graphify matcher changes/rerun, native parser/extractor, host/clipboard/browser,
dependency install, Docker, landing page, inference, user-value/performance claim,
Phase 2, or new semantic conflict resolver. This can establish only fixed
syntactic conformance. It neither validates the task's audit policy as true nor
answers the materially unresolved permission question. Full study conditions
4–5 and real-host acceptance remain blocked on separate prerequisites.

## Recorded bounded acceptance

Independent review found an incomplete C1 control-range rejection; primary
corrected it and added regressions. The 27 pure tests and six declared mechanical
CLI journeys then passed. Both roots supplied their distinct four current-marker
citations, inspection invalidated across switch/failure/recovery, and cancel/EOF
returned original-only. [Progress](../progress/phase-1-decision-brief.md) records
evidence hashes, limitations and publication gates. This establishes only the
declared synthetic marker/inspection behavior, not inferred semantics, human
review acceptance or authority to act on either audit policy.
