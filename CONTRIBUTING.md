# Development process

Threadmark is currently documentation-first. This guide establishes the intended SDLC; build/test commands will be added with the actual implementation, not invented in advance.

## Working principles

- Understand requirements and failure modes before editing.
- Make the smallest complete, reversible change consistent with the architecture.
- Preserve unrelated work and use task-isolated branches/worktrees rather than another task's checkout.
- Keep scope tied to a [roadmap phase](docs/roadmap.md) and [product requirement](docs/product.md).
- Distinguish documentation-backed possibilities, prototypes, certified integrations, and released behavior.

## Change workflow

1. Describe the user outcome, requirement ID, phase, non-goals, and acceptance tests.
2. Record consequential design choices in a short architecture decision record. Prefer proportional design over ceremony.
3. Implement in isolation with relevant unit, integration, or host-contract fixtures.
4. Run formatting, lint, tests, documentation/link checks, and applicable dependency/secret checks. Report checks not run.
5. Seek independent review when risk warrants it, especially for permissions, storage, credential handling, and host delivery.
6. Verify failure paths, recovery, and representative behavior before release.

Do not introduce network egress, credential access, new external infrastructure, or destructive cleanup as an incidental implementation detail.

## Definition of done

- Acceptance criteria are met with evidence.
- Relevant tests and checks pass; failures and limitations are explicit.
- No unsupported capability or success claim is introduced.
- Security/privacy, cancellation, retry, and recovery behavior are covered in proportion to risk.
- Documentation and compatibility declarations match behavior.
- Diagnostics avoid source/prompt/credential leakage.
- Release or rollback implications are understood.

CI success, host admission, deployment readiness, and functional acceptance are separate gates. Publishing or deploying requires the appropriate explicit authorization.

## Rust direction

The planned core uses safe Rust and bounded resource usage. Formatting, Clippy, unit/integration tests, schema compatibility fixtures, and dependency/license review belong in the initial CI. Pin and document toolchain/dependency decisions when the workspace exists. Do not add unsafe Rust or custom allocators without profiling evidence and a narrow reviewed boundary.

## Documentation

Use relative links within the repository. Clearly label proposed behavior and hypothetical targets. Avoid private machine paths, internal coordination details, credentials, and real user data in examples. Prefer a small, current document set over duplicate competing plans.

## Licensing

The repository's license has not been selected. Public visibility alone does not grant reuse rights; do not assume an open-source license or contributor terms that have not been adopted. Contributions and redistribution policy must be resolved before accepting outside code.
