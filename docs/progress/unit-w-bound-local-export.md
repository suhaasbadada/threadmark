# Unit W — captured local sensitive-content export backend

## Primary integration and review

Primary committed only the nine owned files as `f2cfbb8` in the completed lane
and applied them as `a15ae00f0f674adb872f45e71ce9f07d75b2cd24`, the exact combined
tested runtime. No baseline/site merges or native read changes were replayed.
Joffrey independently reviewed the source fingerprint **CLEAR** and passed 19
existing compiled core export fixtures plus three bound-export CLI/daemon cases.
He did not rebuild artifacts or rerun the full pipeline/long deadlines.

Primary combined normal workspace gate **PASS**, 255 Rust tests/two doctests;
strict serial actual-CLI/C-fixture native suite **PASS**, 188 tests/26 suites.
The ordinary-import model API compiler gate, dependency policy, staged secrets
and whitespace passed. Original separate 300s/30s tests completed through native
notification, exit zero, two passed in 300.34s; primary read their final log. That
is separately attributed lane evidence, not a repeated exact-integration deadline
run. Source fingerprint remained unchanged. Their teardown/preservation and
fixture cleanup assertions passed; no restart or broad cleanup was performed.

PR #70 merged as `3e538259ba3478cee85471aa3c122e6742037ba5`; its separate exact
post-merge runs `43574865898`/`43574866000` both passed. Native human-read migration
is independently active. This backend only returns confirmed local stdout data;
native consent/private-file UX and publication exact-head CI remain separate
gates. Nine inherited progress edits, all worktrees and parent reminders remain
preserved. No GUI/AX, live model, network upload, host delivery or phase closure.

Requirements TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A5/P2-A6.
Implementation sub-agent: Bob product unit W. Synthetic local fixtures only.
No phase completion, certified host support or native export acceptance claim.

## Baseline and owned inventory

Initial worktree was clean at
`661bdb3e11118efe979cc7adf06c39db723bf133`, retaining prepared unique adapter
contract/site history. As explicitly requested, normal `git merge --no-edit`
of `d7253943fc4ebe1441c30cf7073a65cae327f37a` created merge-only baseline
`0a9db5e26561f820ba29b49407e35e1e13db544f` (tree
`066167fc22e8ac3ce156db849c215d561922d58d`). Both full parents are retained.
No branch switch, reset, new worktree or implementation commit was made.

The tested implementation is this baseline **plus uncommitted owned changes**,
not the baseline SHA alone. Owned implementation/test/contract inventory:

- `crates/cli/src/main.rs`
- `crates/cli/tests/bound_export.rs` (new)
- `crates/core/src/knowledge.rs`
- `crates/core/src/knowledge/export.rs`
- `crates/core/src/knowledge/tests/export_tests.rs`
- `crates/core/src/knowledge/tests/export_tests/bound.rs` (new)
- `crates/daemon/src/knowledge.rs`
- `docs/contracts/project-export-binding-v1.md` (new)

SHA-256 fingerprint of that exact inventory:
`c49d0a2f50b804e4e9c8e96e1b51c9e9e5a8771c2519b8d6450493458c65a52d`.
Reproduce by lexically sorting the eight relative paths above and hashing their
concatenated UTF-8 path, NUL, raw file bytes, NUL for each file. This progress
file is the ninth owned file and intentionally excluded from its own fingerprint.
New files are staged so the tracked-file secret gate includes them; existing
files remain unstaged. All implementation changes remain uncommitted for primary
review/integration. No unrelated work was present or modified.

## Behavior and acceptance evidence

The additive [binding contract](../contracts/project-export-binding-v1.md) is a
review draft, not an independently approved contract. The existing
[export v1](../contracts/project-export-v1.md) envelope/generator is unchanged.

`export_project_bound(&Project, cancel)` and daemon `ExportProjectBound(Project)`
validate complete approval shape before store access. Core captures one SQL
Project inside the existing export read transaction and checks exact ID, root,
root identity, incarnation, ordered source policy and stored snapshot, including
None, before first root authorization/source access or export selection. The
exact captured Project continues through the existing export pipeline; there is
no preflight A followed by unbound ID reload B for selection. Final existing
project/source rechecks remain before publication. The pure shape validator
minimally reuses existing complete source-read metadata validation without
refactoring human reads, human CAS or source-read behavior.

The opt-in CLI requires the existing explicit local-content confirmation plus
all five binding flags in exact order, once, with the at-most-64 source list last.
Absent stores are never created; legacy nonce-less registration requires explicit
upgrade and a fresh capture. Metadata/IDs are not authentication, credentials,
export consent or a lease. There is only one complete local stdout JSON v1 on
success, never file writing/copy/upload/delivery.

Five new core fixtures and three new real-process/daemon CLI fixtures cover:

- **P2-A1/A6:** private deterministic boundary before first root/source access
  proves every field mismatch rejects, including root, inode identity, valid
  changed nonce, ordered policy, snapshot hash/None and ID. Same-ID same-root
  re-registration and different-root replacement cannot use old approval.
- **P2-A1/A5/A6:** writer attempts immediately after binding cannot commit project
  removal/replacement, source-policy revocation or human-history mutation behind
  the DELETE-journal read lock. Reader teardown permits later revocation; old
  approval then fails. WAL is explicitly rejected, not relaxed or leased.
- **P2-A5:** source changes during a current export and cancellation before
  publication fail; dependency failure and early cancellation fail closed.
  Empty/unindexed policies and None work exactly; legacy upgrade requires fresh
  capture. Unicode roots/content and ordered policy are exercised without
  broadening ASCII relative-path rules. Forget removes suppressed history while
  retained human revisions preserve provenance; source bytes stay untouched.
- **P2-A5/A6:** real CLI indexed and unindexed exports equal trusted-form v1
  output; stale approval fails without stdout. Missing consent, malformed,
  partial, repeated, unknown flags, oversized Unicode root bytes and excessive
  source lists reject before absent or sentinel/non-directory storage is opened.
  Typed daemon malformed root/identity/nonce/snapshot/policy and legacy binding
  errors also precede open; original metadata is never a credential.
- Existing export fixtures still test escaped whole-output bounds/overflow,
  stale suppression, empty current manifests, full manifests beyond selected
  anchors, corruption/foreign records, authorization loss, human history and
  no partial publication on the same shared pipeline.

## Verification

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **passed**, including
  formatting, locked workspace build, strict all-target Clippy, 257 tests/doctests
  passed, two unchanged long-deadline tests ignored by this normal suite, strict
  rustdoc, CLI/daemon smoke, local docs links and intentional failure-gate probe.
  Initial run caught a collapsible-if lint in the new comparison; repaired and
  reran the full pipeline successfully. No suppressions or baseline test edits.
- `cargo deny --offline --locked check`: **passed** advisories/bans/licenses/sources.
- `python3 scripts/secrets.py` after staging new files: **passed** tracked/history
  scan and synthetic-secret negative gate; rerun after this new progress file.
- `git diff --check`: **passed**; final staged/unstaged check repeated at handoff.
- Original separate `cargo test --offline --locked -p threadmark-cli --test
  local_review -- --ignored`: **passed, exit 0**, native completion received;
  **2 passed, 0 failed, 0 ignored, 20 filtered out**, finished in **300.34s**.
  Both `actual_cli_provider_deadline_closes_instead_of_original_fallback` and
  `actual_cli_idle_deadline_terminates_with_stdin_open` passed. These unchanged
  tests use synthetic loopback fixtures, not a real provider or external egress.
  Their assertions verify child termination/reader teardown and unchanged source
  and logical context; fixture Drop successfully removes each owned temporary
  directory. The original test process completed; no restart or extra cleanup
  deletion was performed. Finalization changes only this progress record,
  unstaged; the implementation/test/contract fingerprint above is unchanged.

## Review, CI and exclusions

No delegate or independent reviewer was started. Primary must review the additive
API contract and implementation before integrating. Exact remote CI run/head,
PR, merge and rollout: **not run/not created**, intentionally unauthorized.
There is no tested implementation commit SHA because implementation is deliberately
uncommitted; use the full baseline plus fingerprint above, then obtain exact-head
CI after primary integration. A local pass does not close Phase 2.

No schema, dependency, lockfile, serialization, native/provider/site change,
daemon listener, GUI/host launch, lease, credential use, external network/upload,
real provider, deployment or file export was added/performed. No Docker resources
were needed. The inherited source authorization/currentness, filesystem identity,
Forget, bounded escaped bytes, cancellation, human provenance and DELETE-journal
guard are preserved. Future explicit native export/private-file choice is outside
this backend prerequisite; there is no native export consent UX in this unit.
Plum coordination read was attempted but the linked environment was unreachable;
no message, polling, reminder or follow-up was sent.
