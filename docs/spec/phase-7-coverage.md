# Phase 7 — Broader coding-environment coverage

[Specification index](README.md) · Previous: [Phase 6](phase-6-cross-agent.md) · Next: [Phase 8](phase-8-beta.md)

**Status:** open. **Requirements:** TM-08–TM-10. **User outcome:** understand exactly what Threadmark can do in each supported environment without misleading “works everywhere” claims.

## Scope and rollout

Evaluate Antigravity, Copilot CLI/VS Code, and Cursor in independently releasable adapters. Additional hosts require explicit prioritization rather than expanding this phase indefinitely. Prioritize useful supported surfaces, not a connection-count metric. A client lacking safe injection can still support clearly labeled explicit copy or agent-assisted MCP retrieval; that is not equivalent to native refinement.

## Per-host work package

1. Pin versions/environments and inspect official hook/extension contracts.
2. Determine project/worktree capture, text and attachment fidelity, invocation timing, trust, size limits, and acknowledgment.
3. Prototype the strongest safe mode, plus truthful unavailable/degraded behavior.
4. Run the shared conformance suite and host-specific tests.
5. Document installation diffs, owned entries, uninstall, supported matrix, and limitations before advertising support.

Antigravity repeated invocation needs deduplication without user impersonation. Copilot CLI and VS Code require separate certification; allow/block hook output is not universal context injection. Cursor pre-submit interception does not by itself prove editable refinement or context attachment. Respect current actual contracts over planning assumptions.

## Compatibility behavior

Manifests state capability independently: retrieval, context attachment, review, composer apply, and admission reconciliation. A single green “Connected” light cannot imply all five. Detect unknown versions and disable unsafe behavior or use a certified fallback; never keep silently mutating requests on a broken hook. No UI scraping, credential proxy, hidden database writes, or public unauthenticated transport is permitted as a compatibility shortcut.

## Acceptance

- **P7-A1:** Every advertised host/version/environment/mode has runtime conformance evidence; unsupported modes are visible in setup and documentation.
- **P7-A2:** Shared tests prove scope isolation, fidelity, cancellation, deduplication, limits, and truthful delivery states for each adapter.
- **P7-A3:** Install/uninstall preserves unrelated config and respects host trust; a host update breaking a contract causes a visible safe failure.
- **P7-A4:** Moving between certified clients preserves relevant accepted knowledge without changing execution permissions or introducing a second coding interface.

## Exit and exclusions

Close each adapter independently with a support decision and evidence record. The release matrix must explicitly identify any named host still unsupported; beta can be restricted to certified hosts. Other operating systems, remote execution connectors, and arbitrary third-party clients are not implied commitments.
