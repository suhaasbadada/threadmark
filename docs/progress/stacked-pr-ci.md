# Stacked PR foundation CI

2026-11-12. Owner: parent implementation agent / project maintainer.
Scope: verification infrastructure only; [Phase 0](../spec/phase-0-foundation.md)
P0-A1 (declared CI checks), P0-A4 (reviewed boundaries and approval rules),
P0-A5 (honest evidence limits); TM-08 honest integration claims and TM-10 human
control. This change does not complete an acceptance gate or phase. Phase 0
remains a finite offline foundation; [Phase 1](../spec/phase-1-feasibility.md)
remains OPEN, not host validation or a working companion.

## Problem and event semantics

The parent reported that PRs #9/#10 target `t3/phase-0-rust-foundation` rather
than `main`. The foundation workflow filtered both push and pull_request events
to `main`: the latter tests the PR's **base**, not its source branch. Those stacked
PRs therefore needed supplemental workflow_dispatch verification, which the
parent observed was absent from PR status rollup/nativewatch. This unit did not
query any PR, run or remote CI; these are parent-reported observations, not fresh
run evidence. PR #10's current supplemental run status remains unverified here.

The sole workflow edit removes `pull_request.branches: [main]`. Ordinary
pull_request events can now run the same foundation/security jobs against any
base branch, with GitHub's default activity types (opened, synchronize, reopened)
unchanged. Push remains restricted to `main`; workflow_dispatch is unchanged.
This is not an added feature-branch push trigger or an automatic restart.

## Trust boundary and risk

The event remains unprivileged `pull_request`, never `pull_request_target`.
Workflow permissions remain `contents: read`; no secrets, environment access or
permissions are added. Both SHA-pinned checkouts retain
`persist-credentials: false`. Concurrency/cancellation, job timeouts, runners,
tool/version/checksum pins, locked verification commands, and all security and
negative-test guards are unchanged. No deployment/site workflow changes.

The incremental risk is more PR base refs receiving the existing checks and
consuming CI capacity. PR-controlled code still runs within the existing
read-only-token CI boundary, not a new privileged execution path. No product
runtime, worker, extraction, inference, host, clipboard, application/database,
credentials or dependencies change. Branch status is not permission policy.

## Evidence and handoff limits

Assigned base: `9227571c6e9f0b090ec883121dc9babfc25cc59f`; it includes unmerged
PR #8 documentation. Only this record and `.github/workflows/ci.yml` change;
the parent chooses the correct dependent PR base. Work remains staged and
uncommitted; there is no committed tested SHA for this patch yet.

Local verification on this uncommitted patch passed:

- Offline PyYAML parsing with BaseLoader (preserving `on` as text) and comparison
  against the assigned base: removing the PR base filter is the only parsed
  workflow difference. Full-workflow static review confirms the event semantics
  and preserved security settings above; this is not GitHub execution proof.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: format, locked build,
  warning-denied Clippy/rustdoc, 2 unit tests, 8 integration tests, 1 doctest,
  finite CLI/daemon smokes, local Markdown links and intentional assertion failure
  probe passed. Remote links were not fetched.
- `cargo deny --offline --locked check`: advisories/bans/licenses/sources passed
  using cached advisory data; no advisory freshness claim or remote refresh.
- `python3 scripts/secrets.py` after staging the new record: history/tracked-file
  scans passed and the synthetic sentinel was correctly rejected.
- `git diff --cached --check` passed. No new tools or dependencies installed.

Until the change is merged into the applicable base, there is no guarantee that
existing PRs attach new checks. Do not automatically retarget or restart them.
No existing CI was inspected, polled, retried or dispatched, and no watch or
schedule was created. Historical results in the existing evidence ledgers do not
certify this patch. Parent owns independent review, publication, full committed
tested SHA and exact-head native PR CI/run evidence; none is fabricated here.
