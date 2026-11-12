# Development process

Threadmark is in early foundation development. Start with the [reproducible development guide](docs/development.md) for the pinned toolchain, checks, fixtures, versioning and release rules. No production application or certified integration exists yet.

## Working principles

- Understand requirements and failure modes before editing.
- Make the smallest complete, reversible change consistent with the architecture.
- Preserve unrelated work and use task-isolated branches/worktrees rather than another task's checkout.
- Keep scope tied to a [roadmap phase](docs/roadmap.md) and [product requirement](docs/product.md).
- Use the [phase specifications](docs/spec/README.md) for behavior and stable acceptance IDs. Implementation work items and evidence records must reference the applicable IDs; specification publication does not close a phase.
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

Threadmark is licensed under [MIT](LICENSE), copyright 2026 Suhaas Badada. Contributions are accepted under the same license; no CLA is required. Preserve third-party attribution and obtain review before introducing dependencies or redistributed extraction workers.
