# Unit U — registration-bound human reads

Scope: TM-01–TM-04, TM-07, TM-10; partial **P2-A1/P2-A6/P3-A4** support only.
Contract: [human-context read binding v1](../contracts/human-context-read-binding-v1.md).

## Baseline and ownership

Initial working tree was clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Normal authorized `git merge --no-edit 20e0512f5abeffdd15d89809fb1f5f42c8c55a12`
produced baseline `25f77b9a0a6043d65501fce159346bebf81aeab7`, preserving both the
prepared product adapter contract and landing-page history. No reset, switch,
new worktree, implementation commit, push, PR or further merge was performed.
The primary should integrate **only the uncommitted owned diff**, not these
baseline/merge history changes.

Owned inventory:

- `crates/core/src/knowledge.rs`: module/export and shared transaction-local
  list/history helpers; trusted APIs/output unchanged.
- `crates/core/src/knowledge/human_read.rs` and `human_read/tests.rs`: binding,
  scoped pre-data snapshot admission, fresh publication check and synthetic tests.
- `crates/core/src/knowledge/human_search.rs`: share existing traversal/ranking
  inside the bound transaction; new separately named API.
- `crates/daemon/src/knowledge.rs`: typed bound commands, pre-open validation,
  existing-store routing.
- `crates/cli/src/main.rs` and `crates/cli/tests/bound_human_reads.rs`: closed
  optional three-flag grammar, help and actual-process tests.
- This progress file and the additive versioned contract above.

## Acceptance evidence

- **P2-A1/A6:** same-ID/same-root/new-nonce and different-root replacement by a
  second real SQLite connection fail at the private pre-human-data boundary.
  Dropping human tables still yields namespace mismatch, proving they were not
  consulted first. Exact Unicode byte comparisons reject canonically equivalent
  root/identity strings. Legacy v1/v2 are tested and trusted forms still work.
- **P2-A1/A6:** WAL replacement during LIST/HISTORY/SEARCH sees only snapshot A,
  never B; the fresh publication check rejects the stale result. Another similarly
  named project's malformed rows are not scanned by bound human retrieval.
- **P3-A4 support:** old/bound outputs match; history retains retired revisions,
  Forget suppresses IDs, superseded/retired rows are excluded from active search,
  and history limits remain enforced. This does not implement semantic conflict
  links, human-edit CAS, or native client migration.
- **P2-A6:** deterministic ranking, entry and actual aggregate JSON byte budgets,
  complete text omission, pre-cancel/read/publication cancellation, dependency
  failure and malformed queries fail closed. CLI tests reject partial/repeated/
  reordered/legacy/unknown flags and malformed selectors before store creation;
  valid bound commands also refuse absent stores. Typed daemon preflight is tested.
- Source-policy and snapshot changes alone preserve the human binding. Reads
  succeed with source roots unavailable and the source-access counter remains zero.

## Verification and exclusions

Local check results and final uncommitted-diff fingerprint are recorded below at
handoff. The tested revision is the full baseline SHA above **plus the owned
uncommitted diff**, not a new implementation commit. Exact integrated-head CI,
independent primary review and publication are **not run**; no remote run/head
exists for this work. No earlier green CI is claimed for it. No phase is closed.

Excluded: Swift/model/native editor/provider/transport/site changes, dependencies,
lockfiles, schema, source evidence/ranking redesign, semantic conflict handling,
inference, egress, real credentials/content, host launch, GUI, deployments, Docker,
subagents, implementation commits and PRs. Native Unit T CAS wiring is concurrent
work owned elsewhere and is not duplicated or certified here. Current-at-read
snapshot checking is explicitly not an atomic external revocation lease.

## Final local verification record

Tested full baseline SHA: `25f77b9a0a6043d65501fce159346bebf81aeab7` plus the
uncommitted owned implementation/contract diff. Its SHA-256 fingerprint is
`0acb3dae120ea9ffc3ff1c14b12b1460b4d6139d31d6a3cb038e82993061e836`.
Reproduce with `git diff --binary HEAD -- . ':!docs/progress/unit-u-bound-human-reads.md' | shasum -a 256`.
The evidence file is excluded to avoid a self-referential hash; the primary can
fingerprint the complete final diff independently. Only owned new files were
staged for the secret scan; no implementation commit was created.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**. Includes format,
  locked workspace build, warnings-denied all-target Clippy, full tests/doctests,
  warnings-denied documentation, CLI/daemon diagnostics, documentation links and
  intentional-failure probe. Seven new core and three new real-process CLI tests
  pass. Two inherited deadline tests remain unchanged and **ignored**:
  `actual_cli_idle_deadline_terminates_with_stdin_open` (300 seconds) and
  `actual_cli_provider_deadline_closes_instead_of_original_fallback` (30 seconds).
- `CARGO_NET_OFFLINE=true cargo deny --offline --locked check`: **PASS** for
  advisories, bans, licenses and sources using existing offline data; no advisory
  database refresh/network access was requested.
- `python3 scripts/secrets.py` after staging owned new files: **PASS**, tracked
  scan and synthetic-negative probe.
- `git diff --check` and `git diff --cached --check`: **PASS**.
- Initial targeted compilation found helper visibility and a test error-variant
  typo; both were corrected before the passing full gate. No failed check is
  presented as a passing result.
- Primary independent review/integration and exact integrated-head CI/review:
  **NOT RUN**. No current remote run/head, PR or publication exists for this unit.

The only commit made here is the explicitly authorized baseline merge. No reset,
branch switch, cleanup, Docker resource or external service was used. Full checks
include inherited synthetic loopback transport fixtures, not live providers.
# Primary combined integration

PR #68's separate exact post-merge CI `43573440000`/`43573440001` passed at
`5cf014511d28888958353aeb195f018f347ae3de`. PR #69 passed all five checks at
`8f6de77a82b6728ffe6bfed6b00bdd1a750a9f3e` (CI `43573532206`, integrated
`43573532190`); fresh exact head/main/check/review/approval/discussion/rules gates
preceded merge `93b76c95662f2d88f585688f79c500242721fd46`. Separate exact post-
merge CI remains pending verification. PR #70 was retargeted to main and a branch
update requested; its resulting exact-head checks are a new gate, not inherited
from the previous stacked head. Native migration and bounded export binding
follow as separate product units.

Primary committed only the nine owned files as `a6a793c` in the completed lane
and applied them without conflicts as
`3cc3aff4d4a49d061146969ddba07eff50e96cb4`, the exact combined tested runtime.
No baseline/site merges or native editing changes were replayed. Joffrey's
independent review was **CLEAR**; he passed seven core/three CLI cases, the full
offline workspace gate, dependency policy, secrets and whitespace. Two inherited
production-duration deadline tests remain ignored.

Primary combined workspace gate **PASS**, 247 Rust tests/two doctests; strict
serial actual-CLI/C-fixture native suite **PASS**, 188 tests/26 suites. The
ordinary-import model API compiler gate, dependency policy, staged secrets and
whitespace passed. Primary verified exact binding precedes the shared human-data
callback, callbacks reuse the transaction, and fresh registration checking occurs
after transaction commit. This is not an atomic external revocation lease.

Native human LIST/HISTORY/SEARCH calls are not migrated by this backend unit.
Native revision editing is PR #69; native bound-read integration follows this
additive contract separately. Publication exact-head CI remains required. Nine
inherited progress edits, all worktrees and parent reminders remain preserved;
GUI/AX/live-quality/host-delivery/phase closure remain unverified.
