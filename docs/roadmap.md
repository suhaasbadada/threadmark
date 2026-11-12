# Roadmap: Phases 0–9

[Documentation home](../README.md) · [Product requirements](product.md) · [Detailed phase-wise specification](spec/README.md)

**Current status: Phase 0 engineering evidence accepted for the [recorded tested revision](progress/phase-0.md); merge and publication unapproved. Phases 1–9 remain open.** These are gated scopes, not calendar estimates. Security, tests, and failure handling begin with each feature; Phase 8 does not postpone them.

This is the concise roadmap. The linked specifications expand each phase into user outcomes, behavior, work packages, exclusions, and testable acceptance IDs. Threadmark is a background companion; no phase introduces a replacement chat, editor, task dashboard, or agent launcher.

## Release boundaries

- Phases 0–5: functional MVP with explicit refinement, OpenCode integration, and T3 draft handoff.
- Phase 6: cross-agent private alpha.
- Phases 7–8: broader certified coverage and public beta.
- Phase 9: stable release and maintenance.

### Phase 0 — Engineering and SDLC foundation

[Full product specification and acceptance criteria](spec/phase-0-foundation.md)

**Scope:** requirements/non-goals, canonical repository and task isolation, architecture decisions, supported Rust toolchain, CI, review standards, test strategy, secret handling, threat model, dependency/license policy, release/versioning rules, and evaluation fixture format.

**Deliverables:** requirement IDs, ADRs, contributor guide, initial backlog, risk register, reproducible workspace/CI, and definition of done.

**Exit:** a clean checkout builds, formats, lints, and passes a bounded smoke test in CI with secret checks; scope and critical risks are reviewed. This documentation commit is not completion of Phase 0.

### Phase 1 — Feasibility and integration contracts

[Full product specification and acceptance criteria](spec/phase-1-feasibility.md)

**Scope:** disposable Graphify extraction/provider/packaging spikes; OpenCode command, preview, context, and attachment behavior; T3 draft prefill; inference adapters; a representative task/evidence corpus and retrieval baselines.

**Deliverables:** pinned versions, extraction fixtures, capability manifests, measured prototype findings, and revised ADRs where assumptions fail.

**Exit:** runtime evidence for the MVP delivery paths and safe failure behavior. Graphify is selected or replaced behind the same extraction contract. No unsupported capability becomes an unexamined launch dependency.

### Phase 2 — Rust mem-z core

[Full product specification and acceptance criteria](spec/phase-2-knowledge-core.md)

**Scope:** project identity and source authorization, structural indexing/graph import, SQLite evidence store, lexical/symbol retrieval, freshness/coverage, bounded incremental updates, restart/migration recovery, export/forget, and versioned local API.

**Deliverables:** daemon/CLI and tested extraction, storage, and retrieval contracts. Structural-only operation needs no inference.

**Exit:** a real project can be indexed and queried with resolvable evidence. File changes, renames, deletion, and branch switches do not silently leave invalid facts active. Projects remain isolated and recovery preserves knowledge.

### Phase 3 — Background onboarding and editable context

[Full product specification and acceptance criteria](spec/phase-3-background-experience.md)

**Scope:** add/select projects, Build understanding, source and egress consent, inference profiles, estimates/budgets, progress/cancel/resume, context CRUD, scopes, history/conflicts, activity inspection, and privacy controls.

**Deliverables:** a thin menu-bar companion and occasional management window using the same daemon API; semantic extraction jobs only under an authorized profile and budget. Native host UI or temporary review surfaces serve routine refinement, not a standalone workbench.

**Exit:** a user excludes sensitive content, builds understanding, adds/corrects context, rebuilds without losing edits, and forgets an entry without active retrieval resurrecting it. Partial, stale, and failed coverage remain visible.

### Phase 4 — Grounded context and prompt refinement

[Full product specification and acceptance criteria](spec/phase-4-refinement.md)

**Scope:** relevant evidence/decisions, source rechecks, missing-context detection, applicable failure guidance, proposed verification, explicit inference-backed refinement, original/diff preview, editing, clarification, and output budgets.

**Deliverables:** canonical execution brief/API, source-linked preview, and controlled held-out evaluation fixtures. Context-only is a baseline; Refine is a central MVP feature.

**Exit:** constraints, negations, identifiers, scope, and permissions survive. Unsupported additions are labeled or rejected. Material ambiguity is exposed. Canceling never sends. Compare raw, retrieval-only, refinement, and refinement-with-risk-guidance using the same executor and supplied facts.

### Phase 5 — First complete OpenCode and T3 workflows

[Full product specification and acceptance criteria](spec/phase-5-mvp-integrations.md)

**Scope:** OpenCode server/TUI command → preview → approval → one admission; opt-in context, sources, faithful attachments, status, owned config install/uninstall; T3 desktop draft prefill with copy fallback. OpenCode Desktop composer support stays experimental until independently certified.

**Deliverables:** end-to-end demonstrations, versioned capability manifests, installation ownership, and preparation/delivery records.

**Exit:** no send before approval; cancel preserves drafts; retries do not duplicate admissions; T3 handoff never auto-sends or claims an acknowledgment it lacks; oversized prompts fail visibly; host permissions and unrelated configuration remain intact; daemon failure does not break normal use.

**Milestone: functional MVP.**

### Phase 6 — Cross-agent continuity

[Full product specification and acceptance criteria](spec/phase-6-cross-agent.md)

**Scope:** Claude Code and Codex adapters, user-approved correction inbox, and T3 provider-specific certification where applicable. No universal inheritance assumptions.

**Deliverables:** both named adapters with a certified mode, correction provenance, and request-scoped observational feedback.

**Exit:** endorse a correction in one client and verify it helps a later relevant request in another. The same fact must not leak into unrelated projects or incompatible branches. Failed tests may propose pitfalls but cannot automatically establish reusable truth.

**Milestone: cross-agent private alpha.**

### Phase 7 — Broader coding-environment coverage

[Full product specification and acceptance criteria](spec/phase-7-coverage.md)

**Scope:** Antigravity, Copilot CLI/VS Code, Cursor's supported subset, and selected further clients. Version, environment, mode, capture, and acknowledgment differences are explicit.

**Deliverables:** reusable adapter conformance tests, compatibility manifests, and host-specific install/trust guidance.

**Exit:** every advertised mode has runtime evidence. MCP configuration alone is insufficient. Unsupported surfaces stay labeled unsupported. No UI scraping or model credential proxy.

### Phase 8 — Hardening and public beta

[Full product specification and acceptance criteria](spec/phase-8-beta.md)

**Scope:** performance/resource profiling, large repositories, adversarial memory/prompt injection, local API/privacy review, recovery/migrations, accessibility, signed/notarized packaging, updates, documentation, opt-in content-free diagnostics, and real-user evaluation.

**Deliverables:** security/performance/reliability evidence, reproducible beta artifacts, and support runbooks.

**Exit:** no unresolved release-blocking leakage, intent inversion, data loss, unsafe submission, or permission bypass. Establish bounded resources and measured user value against chosen baselines without meaningful correctness regression. Publishing requires explicit release approval.

### Phase 9 — Stable release and sustainable operation

[Full product specification and acceptance criteria](spec/phase-9-stable.md)

**Scope:** stable contract/version policy, supported client/OS matrix, compatibility regression CI, update/rollback recovery, dependency/host-change monitoring, incident response, privacy-respecting support, and ongoing evaluation.

**Deliverables:** release checklist, support policy, maintenance ownership, go/no-go record, and next-version backlog.

**Exit:** the exact release revision passes required checks and representative acceptance tests, with explicit publishing approval.

## Deferred scope

Team sync, remote/cloud connectors, further operating systems, linked-project retrieval, automatic cross-project sharing, and broad write-capable orchestration require separately approved follow-on scope. They are not hidden Phase 9 commitments.

## Phase governance

Each feature has a requirement, phase, owner, acceptance tests, and explicit exclusions. Failed gates are repaired or cause an intentional scope revision. New requests are deferred or reprioritized visibly; no phase is complete merely because its code compiles.
