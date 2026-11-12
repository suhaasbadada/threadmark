# Phase 1 — Feasibility and integration contracts

[Specification index](README.md) · Previous: [Phase 0](phase-0-foundation.md) · Next: [Phase 2](phase-2-knowledge-core.md)

**Status:** open. **Requirements:** TM-02, TM-04–TM-08, TM-10. **User outcome:** the proposed low-friction experience is grounded in actual host and extraction behavior before significant implementation investment.

## Questions to answer

Can Threadmark obtain useful evidence without an expensive full semantic pass? Can OpenCode expose explicit refinement and bounded context without changing host permissions? Can T3 receive a draft safely without pretending handoff is delivery? Can review remain occasional and lightweight rather than forcing users into a new workbench?

## Required experiments

1. **Extraction:** Pin a Graphify release; test structural facts, inferred relationships, provenance, language coverage, rename/deletion behavior, partial failure, IDs, licensing, and packaging. Compare useful retrieval against lexical/symbol baselines. Keep the worker replaceable if it fails the contract.
2. **OpenCode:** Verify commands, attachments, review/approval, context hooks, continuation deduplication, canceled/disconnected review, admission identity, and unavailable daemon behavior on declared versions.
3. **T3:** Verify local draft-link handling, destination selection, occupied composer, oversized briefs, cancellation, and available acknowledgments. Treat the previously observed 8,000-character limit as version-specific, not permanent API truth.
4. **Inference:** Verify explicitly authorized provider setup, cancellation, output validation, timeouts, budget enforcement, redaction, and local-versus-remote behavior. Do not reuse coding-tool login tokens without a documented authorized API.
5. **UX:** Walk through first project, second project, stale context, a refinement review, ambiguity, and unavailable service using a disposable prototype. Compare with normal host usage. Record where users leave the host and why.

## Capability record

For each host experiment record product/version, OS, execution location, integration mode, capture/attachment limits, configuration scope, trust/permission requirements, size limits, cancellation behavior, acknowledgment semantics, evidence artifacts, and unsupported cases. A capability can be documentation-backed, prototyped, certified, or unsupported; these labels cannot be collapsed.

## Measurement protocol

Choose declared small/medium/large repository fixtures, task types, cold/warm conditions, and evaluation hardware. Separate local retrieval, inference time, host handoff, review effort, and total task cost. Record observed measurements; choose provisional latency, memory, concurrency, and cost budgets in an ADR before subsequent optimization. Do not set retroactive thresholds just to make a result pass.

## Failure and decision handling

Experiments are isolated and reversible. No private source leaves the machine without consent. Remove only experiment-owned configuration/resources. If a host hook does not support the proposed behavior, narrow the advertised mode or revise the design; do not substitute UI scraping or undocumented application-database writes. A failed core MVP assumption requires an explicit scope decision rather than being hidden in a later phase.

## Acceptance

- **P1-A1:** Extraction fixtures demonstrate traceable structural evidence, labeled inference, and safe behavior on partial/invalid output. Graphify adoption or replacement is justified by recorded evidence.
- **P1-A2:** The proposed OpenCode path demonstrates zero admission before approval and zero sends on cancellation; attachment and retry limitations are explicit.
- **P1-A3:** The T3 experiment produces only a draft/handoff, preserves existing draft safeguards, and never asserts a send acknowledgment it cannot observe.
- **P1-A4:** Prototype walkthroughs cover project selection, review, cancellation, and dependency failure. Findings include friction and counterexamples, not only a successful demo.
- **P1-A5:** Versioned capability records, a representative evaluation corpus, provisional budgets, and resulting ADRs exist. Unsupported MVP assumptions are resolved or identified as blocking.

## Exit and exclusions

Deliver the feasibility report and updated contracts before Phase 2 relies on them. No product-quality UI, universal adapter, public release, or claim of user-value validation is required or implied.
