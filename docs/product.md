# Product requirements

[Documentation home](../README.md) · [Roadmap](roadmap.md) · [Detailed phase specifications](spec/README.md)

**Status:** proposed product behavior, not shipped functionality.

## Objective

Give a coding agent the task-specific evidence, project decisions, likely failure warnings, and verification guidance needed to act on rough intent with fewer unsupported assumptions. Preserve user intent and let knowledge travel between certified clients.

The first audience is an individual developer working locally on macOS. The architecture should accommodate other operating systems and execution environments without promising immediate support.

## Core requirements

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| TM-01 | Add and manage multiple projects with approved sources. | Similar project names and conflicting decisions do not cause cross-project retrieval. |
| TM-02 | Build source-backed project understanding with visible coverage. | Every material extracted claim has provenance; partial or failed extraction is labeled. |
| TM-03 | Add, edit, scope, retire, and forget context. | User changes survive rebuilding; deletion removes active derivatives and prevents unintended re-import. |
| TM-04 | Compile relevant execution context, not a repository dump. | Retrieved evidence is applicable, current, and within explicit size budgets. |
| TM-05 | Refine rough intent transparently. | Original constraints, negations, identifiers, permissions, and scope survive; differences are reviewable. |
| TM-06 | Identify evidence-backed failure mechanisms. | Each applicable risk has uncertainty, prevention guidance, and a proposed verification step. |
| TM-07 | Reduce unsupported claims. | Facts, accepted decisions, hypotheses, stale information, and unknowns remain distinguishable. |
| TM-08 | Integrate honestly with coding environments. | Each advertised host/version/mode passes its own conformance tests. |
| TM-09 | Maintain useful knowledge across clients. | An endorsed correction applies in a later relevant request in another certified client. |
| TM-10 | Keep the user in control. | Cancel sends nothing; no silent execution, credential reuse, or permission escalation occurs. |

## Background-companion experience

The coding environment remains the developer's workspace. Threadmark runs in the menu bar, maintains knowledge in the background, and offers native host commands/hooks where certified. Explicit refinement uses host review where possible or a temporary companion panel where necessary. There is no replacement chat, editor, task dashboard, or agent launcher.

The menu-bar surface shows project/status, pause/resume, management, connections, and quit. A small management window is opened occasionally for the following areas—not as the destination for everyday coding:

- **Projects:** add folders, select a project, inspect indexing progress, freshness, exclusions, and gaps.
- **Context:** editable notes, constraints, decisions, pitfalls, sources, scopes, conflicts, and history.
- **Connections:** inference providers separately from coding-client adapters; exact capability and trust status.
- **Receipts:** inspect limited preparation/approval/handoff metadata in project details. Content-bearing history requires explicit retention consent; original text and evidence remain ephemeral by default.
- **Privacy:** source access, network destinations, budgets, retention, export, and forgetting.

## Onboarding

Add project → approve sources → choose inference profile if needed → inspect scan scope and estimated work/cost → Build understanding → review gaps → add/correct context → enable a certified client adapter.

Structural-only indexing does not require a model. Semantic extraction and refinement require explicitly authorized inference. A coding-agent subscription or login does not automatically authorize Threadmark to reuse its tokens as an API credential.

Closing management leaves the companion running; Quit stops owned background work. Launch-at-login is opt-in. Project identity is visible during refinement; a host/worktree mismatch requires resolution rather than silently using the menu-bar selection. Routine updates do not generate popups. Detailed journeys, status semantics, privacy defaults, and accessibility acceptance appear in [Phase 3](spec/phase-3-background-experience.md).

## Modes

- **Context:** optional, bounded project evidence without reinterpreting the original request. Automatic use requires an explicit opt-in and a supported host hook.
- **Refine:** an explicit, cancelable operation that creates a reviewable execution brief.
- **Bypass:** normal host behavior without Threadmark enrichment.

## Execution brief

The canonical brief separates:

- Original request and objective.
- Constraints and explicit exclusions.
- Current evidence, relevant sources, and revision applicability.
- Applicable project decisions.
- Unknowns, conflicts, and material clarifications.
- Likely failure mechanisms and preventative steps.
- Suggested verification and output expectations.

Questions are focused, not bureaucratic. Missing authorization or ambiguity affecting irreversible actions requires clarification; the product must not manufacture certainty to avoid asking.

## Example

Rough request: **“Add team invitations using what we already have.”**

If supported by current project evidence, a brief could identify the existing identity provider and email queue, tenant boundaries, relevant entry points, and checks for expired or repeated invitation acceptance. If invitation permissions are unspecified, it should ask rather than invent an admin-only policy.

## Learning and control

An accepted patch, passing test, completed agent turn, and endorsed reusable rule are different signals. Agent-generated lessons enter a candidate inbox. Background extraction does not overwrite user-authored decisions. A source correction is an overlay with provenance, not a claim that the underlying file changed.

Project management includes multiple projects from the start; automatic cross-project knowledge sharing does not. Linked-project retrieval, team sync, and remote/cloud execution need separately scoped follow-on designs.

## Evaluation

Compare raw requests, existing instruction-file practices, retrieval-only context, refined briefs, and refinement with failure guidance. Keep the executor, repository snapshot, facts, permissions, and budgets controlled. Prevent memory leakage between experiment conditions.

Measure independent task correctness, correction effort, intent preservation, evidence relevance, unsupported claims, stale facts, latency, and full task cost. Refinement must provide value beyond retrieval alone; more elaborate text is not a success metric.
