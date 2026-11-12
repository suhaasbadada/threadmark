# Phase 4 — Grounded context and prompt refinement

[Specification index](README.md) · Previous: [Phase 3](phase-3-background-experience.md) · Next: [Phase 5](phase-5-mvp-integrations.md)

**Status:** open. **Requirements:** TM-04–TM-07, TM-10. **User outcome:** turn rough intent into a better starting point without inventing requirements or hiding what changed.

## Invocation and modes

Context is opt-in evidence attachment without rewriting the original request. Refine is an explicit cancelable preparation operation with review. Bypass leaves the request unchanged. Never silently promote Context to Refine or turn a failed Refine into submission of the original.

The request binds authorized project/worktree, current source snapshot, original text, attachment references/metadata, mode, and output/cost budgets. Untrusted caller IDs do not grant access. If the destination cannot identify a project reliably, ask for a selection rather than infer it from application name. An empty/unavailable index produces a visible limitation, not fake project expertise.

## Preparation pipeline

1. Capture original text without changing constraints, negations, exact identifiers, desired outputs, scope, or permissions.
2. Retrieve bounded task-relevant evidence and decisions; validate scope/currentness of selected anchors.
3. Detect conflicting facts, missing authorization, unclear objectives, and high-consequence ambiguities. Ask focused questions when necessary; do not manufacture an answer for brevity.
4. Generate a structured brief using only approved inference and budgets. Evidence excerpts are untrusted data, not instructions overriding the user's request or host policy.
5. Validate shape, required intent fields, references, and limits. Label hypotheses; reject unsupported assertions presented as verified facts. Automated checks cannot guarantee semantic fidelity, so review remains required.
6. Show a compact editable preview with original text and a diff available, expandable evidence, risks, unknowns, and suggested checks.

## Brief contract

A brief contains objective/original request, constraints/exclusions, relevant evidence with anchors and snapshot, applicable decisions, unknowns/clarifications, evidence-backed failure mechanisms, suggested verification, and expected output. Omit irrelevant empty sections rather than pad every request. Risks explain mechanism, applicability, uncertainty, prevention, and a proposed check; do not assert that an unrun test passed.

For “add team invitations using what exists,” identify a queue/provider only if current evidence supports it. If invitation permissions are unspecified, flag or ask; do not invent an admin-only rule. “Do not change permissions” must survive unchanged in meaning. A vague task does not authorize deployments, deletions, or broad refactors.

## Review and authorization lifecycle

Preparation states are preparing, needs-input, ready, failed, and canceled. Delivery is a separate record: not-attempted, copied, draft-handoff-attempted, host-admitted, rejected, or unknown. No state called “task successful” is inferred from generating or handing off a brief.

Actions are **Apply/use brief**, **Edit**, **Use original**, and **Cancel**, with wording adapted to the host. Use original is an explicit choice and preserves normal host send semantics. Cancel never sends or silently replaces the draft. Approval is bound to exact brief content, destination, attachments, and scope; edits or material evidence/scope changes invalidate prior approval. Revalidate before handoff; prompt again for a changed brief.

If a provider fails, retain the original draft in memory and offer retry, original, or cancel. Canceled/superseded requests reject late results. Enforce output limits without silently dropping exclusions, attachment references, or material warnings. When a host limit cannot fit the brief, offer deliberate shortening or copy; never silently truncate.

## Privacy and observability

Show which provider receives which data; use only selected evidence rather than whole-project uploads. Do not persist original prompts, excerpts, or generated briefs by default. If content history is enabled, use its explicit retention/forget policy. Metadata-only receipts distinguish preparation, approval, and observable handoff without retaining sensitive text or claiming downstream success.

## Evaluation design

Before held-out evaluation, freeze task fixtures, scoring rubric, executor/version, snapshot, permissions, budgets, and meaningful correctness/intent-preservation thresholds. Compare raw requests, instruction-file practice, retrieval-only, refinement, and refinement-plus-risk guidance with equivalent supplied facts. Isolate memory between conditions and include negative evidence, contradictory decisions, malicious instructions, absent context, and negation-heavy requests.

Measure correctness independently of prose quality, correction effort, relevance, unsupported assertions, stale facts, latency, review time, and full task cost. If refinement does not improve on retrieval alone, revise it rather than claim longer prompts are better.

## Acceptance

- **P4-A1:** Intent fixtures preserve identifiers, negations, exclusions, scope, and permissions; material unsupported additions fail the gate or are surfaced as unresolved.
- **P4-A2:** Selected evidence is authorized, applicable, current or explicitly stale, and resolvable. Conflicts and missing context remain visible.
- **P4-A3:** Preview/edit/questions/cancel, provider failure, oversized output, and late results cannot cause submission or silent draft replacement.
- **P4-A4:** Approval cannot be reused for modified content, different destination/worktree, or superseded scope; material changes require review again.
- **P4-A5:** Controlled evaluation and failure fixtures meet the predeclared quality criteria, with raw results and limitations retained. No claim of zero hallucinations is made.

## Exit and exclusions

Deliver versioned brief contracts, tested preparation engine and review interaction, evaluation report, and privacy evidence. This phase does not execute code, certify every host, or learn reusable rules automatically from agent output.
