# Phase-wise product specification

[Documentation home](../../README.md) · [Product requirements](../product.md) · [Roadmap](../roadmap.md)

## Status and authority

This is the implementation contract for Threadmark, not a description of shipped software. Phase 0 engineering evidence is accepted for its [recorded tested revision](../progress/phase-0.md); merge and publication remain unapproved. Phases 1–9 remain open. Publishing a specification does not satisfy an implementation gate.

The background-companion model, human control, editable project knowledge, and coexistence with existing coding tools are agreed product requirements. Component choices, interaction details, and rollout sequence below are proposed designs unless explicitly identified otherwise. Runtime feasibility and usability must be demonstrated before support is advertised.

This specification expands the roadmap; it does not replace it with a competing phase sequence. The product requirements define outcomes, these phase files define behavior and acceptance, architecture defines component boundaries, and integration documentation defines host-specific constraints. In a conflict, preserve the user-control/privacy invariants and resolve the discrepancy before implementation. Do not silently choose whichever document is convenient.

## Product contract

Threadmark is a background project-intelligence companion. The developer continues working in OpenCode, Codex, Claude Code, T3, or another supported environment. Threadmark is not a chat destination, editor, task dashboard, agent launcher, executor, or replacement permissions system.

- A menu-bar/tray surface exposes status, project selection, pause, management, and quit.
- An occasional management window handles projects, context, connections, privacy, and limited enrichment receipts.
- Routine enrichment uses a native host command/hook where supported; otherwise it uses a small explicit review/handoff surface.
- Context mode attaches evidence only with opt-in and a certified hook. Refine mode changes a draft only after explicit review and approval. Bypass leaves the host request alone.
- Project identity is visible whenever context is selected or a brief is approved. An application name alone cannot identify a repository, worktree, or conversation.
- No hidden send, elevated permission, whole-project upload, transcript harvesting, or automatic promotion of agent assertions to truth.

## Phase map and dependencies

| Phase | Specification | Outcome | Depends on |
| --- | --- | --- | --- |
| 0 | [Foundation](phase-0-foundation.md) | Reproducible SDLC and measurable acceptance | None |
| 1 | [Feasibility](phase-1-feasibility.md) | Evidence for extraction, host, and UX assumptions | 0 |
| 2 | [Knowledge core](phase-2-knowledge-core.md) | Authorized, fresh, recoverable project knowledge | 1 |
| 3 | [Background experience](phase-3-background-experience.md) | Onboarding, status, and editable context | 2 |
| 4 | [Refinement](phase-4-refinement.md) | Grounded, reviewable briefs preserving intent | 2–3 |
| 5 | [MVP integrations](phase-5-mvp-integrations.md) | OpenCode workflow and T3 draft bridge | 1, 4 |
| 6 | [Cross-agent continuity](phase-6-cross-agent.md) | Reusable corrections across certified clients | 5 |
| 7 | [Broader coverage](phase-7-coverage.md) | More independently certified host modes | 6 |
| 8 | [Public beta](phase-8-beta.md) | Resource, security, reliability, and user-value evidence | 5–7 |
| 9 | [Stable operation](phase-9-stable.md) | Supportable, recoverable stable release | 8 |

Phases 0–5 form the functional MVP; Phase 6 forms cross-agent private alpha. Phase 7 is incremental: an unsupported host cannot be marketed as supported, but need not block a beta limited to the certified matrix. Packaging experiments begin earlier; Phase 8 qualifies distribution, not the first usable build.

## Common acceptance rules

Acceptance IDs `P<n>-A<m>` are stable references for issues, tests, and evidence. Each implementation work item names its phase, relevant TM requirement, owner, exclusions, and acceptance IDs. Each phase closes with an evidence record containing the full tested revision, environment and dependency versions, checks/results, artifacts, unresolved issues, and explicit go/no-go decision. No fabricated timings, benchmarks, or certification records belong in those reports.

Every feature must cover success, cancellation, invalid scope, unavailable dependencies, restart, and sensitive-data handling where applicable. Security and accessibility are continuous requirements, not postponed until beta. Destructive operations require clear scope and confirmation; external publication/release requires separate authorization.

## Evaluation and unresolved decisions

The bounded [SMALL retrieval pilot](../progress/phase-1-retrieval-pilot.md) now
records actual lexical/symbol/candidate evidence on both frozen synthetic roots.
It establishes neither representative product quality nor caller-retrieval benefit
for the candidate under its fixed eight-anchor envelope; P1-A1/P1-A5 remain partial.

A separate [bounded evidence selector](../progress/phase-1-evidence-selection.md)
now prototypes interleaved declaration/caller drafts. It preserves that pilot,
does not adopt a default retriever, and is not new comparative-quality evidence.

The [scoped extraction experiment](../progress/phase-1-scoped-extraction.md)
demonstrates namespaced Graphify identities, malformed-source rejection and fresh
recovery on the original tiny fixtures. Graphify adoption/packaging and broader
evaluation remain open; this is not a Phase 2 importer or native-host proof.

The [recorded-evidence review walkthrough](../progress/phase-1-evidence-review.md)
joins those fixed source-backed observations to local review/cancel and context
invalidation. It does not copy/send, refresh extraction, or establish host consent.

Phase 1 establishes representative repository/task fixtures and provisional latency/resource budgets before implementation optimizes against them. Phase 4 sets task-quality evaluation thresholds before held-out runs. Phase 8 freezes release budgets and evaluates whether the benefit outweighs latency, cost, and review effort. There are no measured performance claims yet.

The project license is [MIT](../../LICENSE). Decisions still open include desktop shell confirmation, extraction-worker packaging, supported inference profiles, exact host versions, shortcut assignments, retention durations, resource budgets, and public-release support commitments. Each is owned and resolved in its relevant phase rather than treated as an implicit promise.
