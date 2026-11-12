# Phase 0 — Engineering and SDLC foundation

[Specification index](README.md) · Next: [Phase 1](phase-1-feasibility.md)

**Status:** engineering evidence accepted for the [recorded tested revision](../progress/phase-0.md); PR merge and publication remain unapproved. **Requirements:** TM-01–TM-10. **User outcome:** future product behavior can be built, tested, reviewed, and recovered without relying on undocumented operator knowledge.

## Scope and product boundaries

Establish the Rust workspace, repository practices, requirement traceability, threat model, test harness, CI, and documentation ownership. Do not build a replacement coding UI or ship a placeholder app as a completed product. The initial audience is an individual developer on macOS; other platforms and hosted execution remain explicit future scope.

## Required work packages

1. Record ADRs for background operation, component ownership, local storage, project/worktree identity, inference authorization, and preparation versus delivery. Record alternatives and unresolved assumptions.
2. Establish core/daemon/CLI workspace, pinned supported toolchain, reproducible dependency resolution, and developer build/test commands. Add the shell only after the Phase 1 feasibility decision.
3. Configure formatting, Clippy, unit/integration/doc checks, dependency/license review, secret scanning, and a bounded smoke test in CI. CI fixtures must not require personal credentials or private repositories.
4. Establish small repository fixtures: two similarly named projects with conflicting rules, multiple branches/worktrees, deleted/renamed files, excluded secrets, malformed extraction, and an interruption/recovery case.
5. Create an issue template linking requirement, phase, acceptance IDs, scope, test evidence, and privacy implications. Use isolated changes and risk-proportionate independent review.
6. Document supported development environments, migrations/versioning, diagnostic redaction, release authorization, rollback expectations, and vulnerability reporting. Resolve licensing before distributing code or accepting outside contributions under unstated terms.

## Foundation contracts

The core owns knowledge semantics; the daemon owns bounded jobs and authorized transport; adapters own host-specific capture/handoff; the host owns execution and permissions. Tests must be able to substitute an inference provider, extraction worker, clock, and host transport without using real user content.

Keep test inputs synthetic or redistribution-approved. Configuration defaults cannot enable remote egress, telemetry, launch-at-login, or host modification. Do not embed secrets in fixtures, CLI arguments, screenshots, or logs.

## Acceptance

- **P0-A1:** A clean checkout using the documented toolchain builds and passes the declared format, lint, test, and smoke checks in CI. Report the actual revision/run, not a prior green revision.
- **P0-A2:** A deliberately failing assertion fails the test gate; a synthetic secret fixture is detected by the chosen scanner without exposing a real credential.
- **P0-A3:** A contributor can trace each MVP requirement to planned acceptance IDs and run bounded tests without personal provider access.
- **P0-A4:** Architecture boundaries, initial threat model, dependency/license decisions, and release-approval rules have reviewed records; unresolved blockers have named ownership.
- **P0-A5:** Documentation distinguishes proposed behavior, observed prototype results, certified capabilities, and released support.

## Exit and exclusions

Close with CI evidence, initial risk register, ADRs, fixture inventory, and documented commands. Product scaffolding alone is insufficient. No public binary, host installer, full semantic indexer, team service, or performance claim is required here.
