# Phase 8 — Hardening and public beta

[Specification index](README.md) · Previous: [Phase 7](phase-7-coverage.md) · Next: [Phase 9](phase-9-stable.md)

**Status:** open. **Requirements:** TM-01–TM-10. **User outcome:** a background companion that is useful, bounded, recoverable, and transparent enough for broader real-world use.

## Reliability and resource qualification

Measure idle CPU/RSS, peak RSS, cold/warm retrieval p50/p95/p99, index catch-up, queue bounds, disk growth, inference spend, and total request/review latency on declared hardware and repository fixtures. Freeze beta budgets before qualification, justified by Phase 1 measurements and user tolerance. Report model/network time separately from local processing. No claim that Rust alone guarantees performance.

Exercise large repositories, rapid file bursts, branches, permission loss, offline providers, malformed worker output, disk-full, restart, forced termination, and migration interruption. Verify cancellation releases owned resources, snapshots recover, human edits remain intact, and ordinary host use stays available when Threadmark fails.

## Security and privacy qualification

Test malicious repository instructions, poisoned memory candidates, cross-project identifiers, hostile local API callers, path traversal/symlinks, oversized input, sensitive-data exclusions, logs, prompt links, exports, and deletion/forget behavior. Review local IPC authentication/permissions and origin protections. Do not claim extraction-worker sandboxing without evidence. Revoke source/provider access during active jobs and verify late results cannot escape or commit.

Default diagnostics contain no prompts, source snippets, tokens, credentials, or prompt-bearing URLs. Any optional content sharing requires separate explicit consent and preview. Verify no telemetry or content history is enabled by default. Document unavoidable retention in backups, OS/application logs, clipboard, exports, and already-sent host transcripts.

## Packaging and experience

Qualify signed/notarized macOS artifacts, launch-at-login consent, clean install, upgrade, downgrade/restore strategy, and owned-config uninstall. Updates cannot bypass consent or silently change source/egress policy. Verify keyboard and assistive-technology journeys, focus return after review, reduced motion, light/dark themes, long text, and actionable error recovery. Do not ship a replacement chat/dashboard to compensate for integration friction.

## User-value gate

Run consented beta trials using the Phase 4 controlled comparisons and representative real workflows. Measure task correctness, repeated corrections, review overhead, time to usable request, unsupported claims, and total cost. Include users who abandon or bypass refinement and explain why. Separate demonstrated benefit from user preference and anecdotal praise.

If quality gains do not justify latency/cost/attention, narrow the workflow, improve retrieval, or defer rollout. Do not lower post-hoc success criteria or market a failed experiment as validated intelligence.

## Acceptance

- **P8-A1:** Declared resource budgets pass on the published qualification fixtures; regressions and unsupported scales are visible.
- **P8-A2:** Crash/migration/disk/permission/cancellation fault tests preserve accepted knowledge and recover usable snapshots without unsafe submission.
- **P8-A3:** No unresolved release-blocking leakage, permission bypass, intent inversion, unsafe handoff, or data loss remains; security findings have explicit disposition.
- **P8-A4:** Exact beta artifacts pass install/upgrade/recovery/uninstall and accessibility checks on the stated supported matrix.
- **P8-A5:** Predeclared user-value criteria pass without meaningful correctness regression, with limitations and raw evaluation evidence retained.
- **P8-A6:** Release notes, privacy/retention guidance, support route, known issues, and explicit publishing authorization are present for the exact beta revision.

## Exit and exclusions

Produce a beta go/no-go record, qualification reports, support runbooks, and approved artifacts. Green CI is not sufficient. No automatic public publishing, paid service, or unsupported-platform expansion follows from this specification.
