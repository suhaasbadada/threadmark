# Phase 9 — Stable release and sustainable operation

[Specification index](README.md) · Previous: [Phase 8](phase-8-beta.md)

**Status:** open. **Requirements:** TM-01–TM-10. **User outcome:** depend on Threadmark within a clear support boundary, with safe upgrades and an honest response when hosts change.

## Stable contract

Publish the exact supported OS/architecture and host/version/mode matrix. Version daemon/client protocols, extraction imports, brief schemas, storage migrations, and adapter manifests independently where needed. Document compatibility negotiation and deprecation; unknown versions cannot silently receive unsupported behavior. Keep the management surface optional in routine use.

## Release workflow

1. Freeze a candidate revision and identify exact artifacts/dependencies.
2. Run required CI, host conformance, security/privacy regression, migration/recovery, performance, accessibility, and representative functional acceptance for that revision.
3. Review approvals, unresolved findings, known limitations, support ownership, release notes, and rollback plan.
4. Obtain explicit authorization before publishing the stable release.
5. Verify published artifact identity and representative install/refine/handoff behavior; do not confuse a release upload with functional acceptance.

Release evidence tracks revision, artifact identity, test environment, exact check runs, results, and go/no-go decision together. Earlier green heads and superseded artifacts are not evidence for the current candidate.

## Maintenance and incidents

Assign ownership for dependencies, host API changes, extraction compatibility, vulnerability response, migrations, and documentation. Use compatibility fixtures to detect drift. A broken adapter can be disabled without disabling the user's host or deleting project knowledge. Recovery instructions distinguish application rollback from storage compatibility; never downgrade a database blindly.

For unsafe delivery or scope leakage: stop the affected capability, preserve non-sensitive evidence, identify impacted versions, communicate practical mitigation, and verify repair before re-enabling it. Do not silently collect prompts for debugging. Support bundles are previewable/redacted and opt-in; diagnostic consent is not blanket authorization to read projects.

Choose response targets, update cadence, deprecation windows, and support commitments explicitly before advertising them. Feedback creates scoped backlog items, not automatic permission to add hosted sync, billing, or autonomous execution.

## Acceptance

- **P9-A1:** The exact stable revision/artifacts pass all declared release gates, with no unresolved release blocker and explicit publishing approval.
- **P9-A2:** Upgrade, interrupted migration, backup restore, and supported rollback paths preserve user decisions, privacy choices, and owned host configuration.
- **P9-A3:** Host-contract drift is detected in regression fixtures; unsupported/broken adapters fail safely and show actionable status.
- **P9-A4:** Security/support ownership, incident procedure, compatibility policy, and user-facing limitations are published and exercised in a recovery drill.
- **P9-A5:** Published artifacts match the approved identity and a representative installation performs the intended review/handoff workflow without replacing the coding host.

## Completion and continuing work

The initial stable release closes only after post-publication verification. Maintenance continues with the same gates. Team sync, linked-project sharing, remote/cloud connectors, additional platforms, and autonomous orchestration require separately approved specifications and are not hidden stable-release obligations.
