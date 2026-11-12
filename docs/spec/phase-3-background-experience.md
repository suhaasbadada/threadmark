# Phase 3 — Background companion and editable context

[Specification index](README.md) · Previous: [Phase 2](phase-2-knowledge-core.md) · Next: [Phase 4](phase-4-refinement.md)

**Status:** open. **Requirements:** TM-01–TM-03, TM-07, TM-10. **User outcome:** configure Threadmark once, then let it work quietly without moving daily development into another app.

## Interaction model

The menu-bar surface opens a compact status menu: active project, understanding status, pause/resume, Manage projects/context, Connections, and Quit. It is not a chat, task feed, or agent launcher. Launch-at-login is an explicit preference. Closing the management window leaves the background companion running and explains that behavior once; Quit stops Threadmark-owned work.

The occasional management window has Projects, Context, Connections, and Privacy/settings. Limited enrichment receipts live inside project details, not a permanent task dashboard. Follow system light/dark appearance, provide keyboard navigation, accessible labels, visible focus, reduced-motion behavior, and textual statuses independent of color. Exact visual styling and shortcut bindings remain prototype decisions.

## First-run journey

1. Explain local storage, optional inference, and the fact that no coding environment is replaced.
2. Add a folder; show project identity and proposed source scope, exclusions, external paths, and unsupported files before scanning.
3. Offer structural-only understanding without a model. For semantic work, select an authorized inference profile and show destination, content categories, estimate uncertainty, and budget.
4. User chooses **Build project understanding**. Show bounded progress, stages, skipped content, cancel, and background continuation without forcing the window to stay open.
5. Show usable coverage, gaps, revision, and freshness rather than a misleading completeness percentage.
6. Offer Add context and Connect a coding tool. Do not modify a host or submit any request during onboarding.

Adding a second project repeats source authorization, not all education. Active-project selection is a fallback, not authority for a host request that identifies another worktree. If host identity and user-selected project disagree, stop enrichment and ask for explicit resolution.

## Status and interruptions

| Status | Meaning and available action |
| --- | --- |
| Not built | No usable snapshot; Build understanding |
| Updating | Prior snapshot remains labeled with age; inspect/cancel job |
| Ready | Usable coverage at the shown snapshot, not complete comprehension |
| Partial | Known extraction/readability gaps; inspect affected sources |
| Needs attention | Permission, conflict, migration, or worker issue; actionable repair |
| Paused | No new automatic work; explicit actions identify what they will run |

Avoid routine notifications for each file or prompt. Notify only actionable failures or user-requested job completion. Never put sensitive prompt/source text in OS notifications. Indexing is bounded and debounced; configuring pause or excluding a source must work even during a job.

## Context editing

Default to a searchable readable list of decisions, constraints, notes, and pitfalls. Each row shows scope, authorship, and freshness/status. Opening it reveals evidence, applicable worktree/revision, history, conflicts, and Edit/Retire/Forget actions. A graph, if later useful, is optional exploration—not required navigation.

**Add context** starts with plain text and an explicit project; advanced scope/evidence fields are optional. Distinguish user-declared policy from observed implementation. Editing creates a revision and invalidates dependent prepared briefs; rebuilding never overwrites human edits. Conflicting accepted decisions require an explicit resolution or remain visible; do not quietly choose the newest one.

Retire excludes an entry from normal future use while retaining inspectable history. Forget explains removal/suppression and retention limits and asks for confirmation. Source exclusions and project removal offer a clear derived-data cleanup choice; they never alter the source repository.

## Connections and privacy

Show inference profiles separately from coding-client adapters. A connection screen displays exact version/mode, trust/config changes, test status, disable/uninstall, and data flow. Credentials use protected storage and are never shown in receipts. Content-bearing request history is off by default; an explicit opt-in chooses retention and deletion behavior before recording content. Ephemeral previews remain memory-only without that consent.

## Acceptance

- **P3-A1:** A first-time user adds/excludes sources, builds structural understanding, closes the window, and sees truthful background progress without configuring inference.
- **P3-A2:** A remote semantic job cannot start before provider/content/budget consent; cancel, timeout, permission revocation, and restart show accurate state.
- **P3-A3:** Multiple projects, ambiguous host identity, and mismatched worktrees cannot silently select the wrong context.
- **P3-A4:** User edits, conflict resolution, retire, and forget survive rebuild/restart with the semantics from Phase 2.
- **P3-A5:** Pause, resume, window close, and Quit have distinct tested effects; routine host use requires no management window.
- **P3-A6:** Core journeys work with keyboard and assistive technology; statuses are understandable without color; notifications and default diagnostics contain no private content.

## Exit and exclusions

Deliver walkthroughs and accessibility/failure-path evidence. No full-time workbench, replacement composer, conversation archive, agent scheduler, or mandatory graph dashboard belongs in this phase.
