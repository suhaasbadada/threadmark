# Phase 6 — Cross-agent continuity

[Specification index](README.md) · Previous: [Phase 5](phase-5-mvp-integrations.md) · Next: [Phase 7](phase-7-coverage.md)

**Status:** open. **Requirements:** TM-03, TM-07–TM-10. **Milestone:** cross-agent private alpha. **User outcome:** an endorsed project correction can help a later task in another supported client without repeating the same explanation.

## Primary journey

A developer corrects a project assumption while using one certified client. Threadmark offers a candidate only through an authorized capture mechanism or explicit Add context action. The developer reviews the statement, evidence, scope, and sensitivity, then endorses it. A later relevant request in another client retrieves that decision with provenance. An unrelated project, incompatible branch, or irrelevant task does not receive it.

## Adapter scope

Add Claude Code and Codex with independently verified context/refinement or agent-assisted modes. Label the actual mode: prompt-submit context is not editable composer replacement, and MCP retrieval is not automatic pre-model injection. Respect hook trust, limits, cancellation, local/cloud distinctions, and host policy. Certify T3's provider-specific behavior separately instead of assuming adapters are inherited.

## Candidate lifecycle

Candidates are suggested, accepted, rejected, superseded, or retired. Show original statement, supporting evidence, originating client, applicable project/worktree/revision, proposed scope, and conflicts. Editing or accepting creates an auditable revision; rejecting prevents the same observation from repeatedly resurfacing without new evidence. Do not retain an entire conversation just to capture one rule.

Agent observations, passing tests, merged patches, and user policies are different evidence types. A failed test can suggest a pitfall but cannot establish a general rule. User endorsement establishes a chosen policy, not proof that the code follows it. Contradictory evidence opens a conflict; no last-writer-wins memory override.

## Authorization and lifecycle

Capture is explicitly enabled per source/client and can be disabled independently of retrieval. Never scrape conversations or silently import historical sessions. Apply existing retention/forget policies to candidates and derivatives. Reject late observations from revoked sessions or mismatched scope. Existing accepted human decisions remain intact if a client is uninstalled; disabling capture stops new observation ingestion.

## Acceptance

- **P6-A1:** Claude Code and Codex each pass exact-version conformance for at least one advertised mode, with documented limitations.
- **P6-A2:** A correction accepted in one client is retrieved in a relevant task in another, while project/worktree and relevance counterexamples do not retrieve it.
- **P6-A3:** Unendorsed observations are never presented as accepted policy; endorsement, edits, rejection, supersession, and conflicts have tested behavior.
- **P6-A4:** Capture opt-out, uninstall, revoked session, candidate deletion, and rebuild do not silently ingest content or resurrect forgotten entries.
- **P6-A5:** Continuity evaluation measures reduced repeated correction without a meaningful increase in wrong-scope or stale-policy application, against predeclared criteria.

## Exit and exclusions

Deliver two adapter certifications, candidate-review UX, cross-client fixtures, and private-alpha evidence. No global personal-memory import, automatic policy learning, team synchronization, or hosted transcript archive is included.
