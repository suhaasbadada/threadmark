# Unit N — Explicit ranked retained Rust review

Requirements **TM-04–TM-07, TM-10**; partial **P4-A1–A4**, with inherited
**P2-A1/A2/A6** binding/currentness gates. This is one bounded, process-private
Rust stdio review, not a native UI, listener, host adapter or completed phase.
All fixtures are synthetic; HTTP tests use only test-owned ephemeral loopback.

## Implementation and compatibility

- `refine review PROJECT QUERY --terms` intentionally opts into existing ranked
  lexical retrieval. Inspect `query-terms` with that exact query, registration and
  snapshot before confirming inference. No flag means the existing literal mode.
  The shared strict launch parser already validates terms, duplicates, unknown
  flags and mandatory inference confirmation before store/stdin/provider access;
  no parser change was necessary.
- `LocalReview::start_with_retrieval` validates terms before opening the existing
  store, captures through `ReviewSession::capture_bound_with_retrieval`, and keeps
  `start` as its literal wrapper. The existing captured Project (root, identity,
  incarnation, snapshot and exact source policy) goes to bound selection before
  source traversal. No replacement ID-only traversal or postcheck-only guard.
- The existing immutable Request carries retrieval mode through provider consent,
  selection revalidation, edit, approval and core handoff. The opaque equality
  digest explicitly includes mode, in addition to the existing frozen request,
  brief, expected/core bindings, provider, coverage and session identity.
- No JSON field, version, schema, dependency or lockfile change. Ranked coverage
  already identifies selection/limitations. Mode is launch-only; the closed v1
  capture/action grammar cannot change it. Existing native literal consumers are
  not asked to decode a new DTO. Digest values are opaque per-session equality
  challenges, not stable external hashes or credentials.
- Provider identity/data scope, one call, 1024 requested tokens, 30-second provider
  and 300-second session deadlines, frame/queue/total-byte bounds and full-output
  rejection remain unchanged. No fallback, retry, persisted content or send.

## Acceptance evidence

Nine new tests are in `crates/cli/tests/local_review/ranked_retrieval.rs`.
Small shared fixture helpers retain the original literal tests unchanged in
meaning while exercising the same scenarios with explicit ranked capture.

| Partial acceptance | Evidence |
| --- | --- |
| P4-A1/A2 | Actual CLI literal phrase `synthetic blue` has no matches; ranked retained review sends the exact inspected ranked evidence path/line/text/hash/producer/kind/coverage and snapshot to the owned fake provider. Unicode, negation and original action-looking text remain intent data. |
| P4-A3/A4 | Edit produces a fresh revision/digest; old approval rejects with ReviewRequired, then a fresh challenge hands off exactly the edited preview text. Material questions survive edits and block prepared approval. Provider failure offers only explicit original/cancel, never fallback or another call. |
| P4-A2/A4, P2-A1/A6 | Source, policy, incarnation, root and indexed-snapshot changes after edit reject handoff, including explicit original/provider-failure cases. Wrong expected namespace and stale sources before preparation contact zero providers. Inherited core bound-query tests verify same-Project pre-traversal checks. |
| P4-A3, P2-A6 | Invalid/repeated/unknown flags and malformed ranked terms fail with closed JSON while stdin is open and the store path absent; no provider call/store creation. Direct library invalid terms return Invalid rather than opening the absent store. Capture/action mode injection rejects. Existing strict duplicate/object/frame/queue/output tests remain passing. |
| P4-A3/A4 | Literal/ranked identical-evidence sessions cannot replay each other's challenges. Inherited daemon tests separately prove consent cannot cross modes even with identical or empty evidence and the same Control, and approvals cannot cross mode/selection. Ranked cancel/EOF during provider call or idle review closes/reaps without late handoff. |

Source/history preservation and SQLite plaintext-marker scans pass for the normal,
edit, failure, parser and replay scenarios. No private input, credential or live
provider was used. This is safety/behavior evidence, not retrieval/inference quality.

## Exact base and local verification

- Assigned starting HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required full local base: `029025ea4abe35897381b99bba49e8fe9b301dee`.
- Normal in-place `git merge --no-edit` produced tested HEAD
  `0ba38dabc5916c836a165a0a543bd19289b51857`, preserving the assigned branch's
  independent contract/site history. This is a merge-only prerequisite, **not**
  an implementation commit. Coordinator should integrate only the owned diff.
- Runtime/tests are intentionally **uncommitted** at that HEAD per task scope.
  SHA-256 of the staged runtime/test diff (four Rust files, `git diff --cached --`
  their paths): `a4abe714b600cf9a03ca0920657faf09d1e5483a22207d316dc39bf15fd3febc`.
  There is no committed implementation SHA to claim.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, 224 Rust tests and
  two doctests, format, locked workspace build, all-target strict Clippy, rustdoc,
  finite diagnostics, documentation links and intentional failure probe.
- Two inherited production-duration tests remain **ignored/not rerun**: the real
  300-second idle watchdog and 30-second provider timeout. Their deadline/watchdog
  paths were not changed; prior-lane execution is not claimed as this diff's run.
  Fast actual-process cancel/EOF/parent-kill/I/O/bounds tests passed.
- `cargo deny --offline --locked check`: **PASS**, cached advisory/policy data;
  no advisory refresh or network access.
- `python3 scripts/secrets.py`: **PASS** after staging owned new files.
- `git diff --check` and `git diff --cached --check`: **PASS**.
- Ignored local logs: `target/unit-n-check.log`, `target/unit-n-deny.log`,
  `target/unit-n-secrets.log`. No content-bearing public evidence is published.

Exact remote CI run/head: **not run**, no push or PR. Independent review,
integration/native compatibility and CI are coordinator-owned pending gates, not
passes inferred from local checks. No implementation commit, branch switch, reset,
new worktree, subagent, Docker, install, external egress, live model, credential,
host launch, deployment, merge-to-main or phase closure. Native Unit O, Swift,
common model/app/adapters and provider transport were not touched. The linked
Plum environment was unreachable; no coordination message/follow-up was sent.

Owned files: `crates/cli/src/local_review.rs`,
`crates/daemon/src/review_session.rs`, `crates/cli/tests/local_review.rs`,
`crates/cli/tests/local_review/ranked_retrieval.rs`,
`docs/contracts/local-review-stdio-v1.md`, and this progress record.
# Primary integration and independent review

Primary committed only the six owned files as `05b9007` in the completed task
checkout and applied that unit as
`5cd93c3523c1c0c87b86d51b1ca104a8bebd765c`. No baseline site/contract commits or
other task changes were replayed; all worktrees remain intact.

Joffrey independently reviewed the exact staged fingerprint **CLEAR** and passed
the full offline workspace gate (224 Rust tests/two doctests), dependency policy,
secrets and whitespace. Primary combined full workspace gate and actual-CLI/C
fixture strict serial native suite **PASS**, 149 tests/19 suites. Dependency policy,
staged secrets and whitespace also passed. The two production-duration deadline
tests remain explicitly not rerun; timeout paths and budgets are unchanged.

PR #61's failed macOS run was repaired, not retried/waived. All five checks passed
at `571ab22807ba0bbd83e175566536cb6bfb402522` (CI `43566317275`, integrated
`43566317243`); fresh main/rules/review/discussion checks preceded merge
`319ab5e0c86fa7c5f6da5ac9a4062741b2f6d61c`. Separate exact post-merge runs
`43566846957`/`43566846959` passed. PR #62 was retargeted/updated to main, all five
new-head checks passed at `149a212fa7ecef22d1f6c4ccb2cccaa7c4ce21a5` (CI
`43566854610`, integrated `43566854556`), then fresh clean target/review/rules/
discussion gates preceded merge `30e9f9ca1b66a0db1ad0326a09fea8dfa8e6c195`.
Its exact post-merge checks remain separate and pending verification.

Native retained mounting remains Unit O, independently active. This unit adds no
Swift retrieval selection or GUI/AX/live-provider/host-delivery certification.
New publication exact-head CI remains required; no phase closure. Nine inherited
progress modifications remain untouched and excluded.
