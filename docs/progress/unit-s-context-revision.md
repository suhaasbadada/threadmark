# Unit S — backend expected-revision guards

## Scope and baseline

TM-01–TM-04, TM-07, TM-10; partial **P2-A1/P2-A3/P3-A4** only.
CAS prevents stale append, not semantic human-conflict links/resolution. Phase 2
and Phase 3 remain open. Reviewed-contract gate remains for any future concrete
serialization/schema changes; none are introduced here.

Initial clean prepared head: `661bdb3e11118efe979cc7adf06c39db723bf133`.
Required local base: `77da1a886567c9ce432fb345a44e5089839c49bc`.
Authorized normal merge preserved both histories; merge-only tested baseline:
`58518ba3c41e1f797b6bf0607d5a4ba9b61a3cf2`.
Implementation is an **uncommitted owned delta** on that baseline, not a tested
implementation commit. No reset, branch switch, worktree creation, implementation
commit, push, PR, deployment, external provider or source modification.

## Owned inventory

- `crates/core/src/knowledge.rs`: shared append guards, legacy wrappers retained.
- `crates/core/src/knowledge/context_revision.rs`: new binding, validators and
  separately named revision APIs; test-only pre-commit fault seam.
- `crates/core/src/knowledge/tests.rs`: dedicated test module registration.
- `crates/core/src/knowledge/tests/context_revision_tests.rs`: synthetic actual
  SQLite transaction, isolation, history, budget and recovery evidence.
- `crates/daemon/src/knowledge.rs`: new opt-in variants, pre-open validation,
  existing-store requirement, core cancellation/commit authority.
- `crates/cli/src/main.rs`: four-flag opt-in grammar and early validation; old
  namespace-only/unbound forms remain available unchanged.
- `crates/cli/tests/context_revision.rs`: CLI/daemon integration, compatibility,
  pre-stdin malformed-input rejection and absent-store evidence.
- `docs/contracts/human-context-revision-v1.md`: versioned additive API/CLI contract.
- `docs/progress/unit-s-context-revision.md`: this acceptance/handoff record.

## Acceptance and verification

Tested full baseline SHA: `58518ba3c41e1f797b6bf0607d5a4ba9b61a3cf2`, plus
the uncommitted owned delta. SHA-256 owned-content fingerprint (all eight inventory
files except this self-referential progress record):
`0fa548fababdfcea6f977e4321b761c1be5567a1d65d57bd44ffa72271f54d64`.
Reproduce by sorting those eight relative paths lexicographically and hashing
the concatenation of `UTF-8 path + NUL + exact file bytes + NUL` for each path.
This identifies tested working-tree content, not a nonexistent implementation SHA.

Passed on this delta:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: formatting, locked workspace
  build, all-target Clippy with warnings denied, workspace tests, doctests,
  rustdoc with warnings denied, finite CLI/daemon diagnostics, local docs links
  and the intentional-failing-test gate. Workspace tests: 237 passed plus two
  passing doctests; two unchanged long deadline tests ignored.
- Dedicated core revision suite: 10 passed (includes the no-op child entry when
  not invoked by its owning parent). Dedicated CLI/daemon suite: 3 passed.
- `cargo deny --offline --locked check`: advisories, bans, licenses, sources pass
  using local cached policy data; not a claim of freshly downloaded advisories.
- `python3 scripts/secrets.py`: history/tracked working-tree scan and synthetic
  negative probe pass, with new files staged for inclusion.
- Final staged and unstaged whitespace checks passed.

The first full check caught a compile-only error in the newly added concurrent
test (`Project` is intentionally not `Clone`). The fixture now independently
captures each connection's project; the complete full check was rerun and passed.

Acceptance evidence:

| Partial acceptance | Evidence |
| --- | --- |
| P2-A1 | Actual two-connection stale update and stale retire leave identical history; concurrent update/retire for one revision yield one success and one scope mismatch; root/identity/incarnation/project mismatches and identical re-registration reject with zero append; similarly named project remains untouched. |
| P2-A3 | Fresh writes append exactly one; pre-commit cancellation after actual insertion, SQL trigger failure, and killed owned processes at the real pre-commit boundary preserve prior history; reopen/rebuild recover. Revision 32 and project row 4096 cannot append; invalid/overflow revisions and malformed flags cannot create storage. |
| P3-A4 | Retirement retains bounded history and excludes active search; fresh explicit update reactivates, stale update fails; Forget suppression survives restart/rebuild; source bytes and peer history preserved; trusted unbound and namespace-only forms retain compatibility; duplicate add stays rejected. |

Malformed CLI metadata is tested with stdin intentionally held open: it exits
without waiting for text or touching a missing store. All failure diagnostics
remain content-free. Tests use synthetic temporary stores and owned subprocesses;
workspace provider/transport tests use synthetic loopback fixtures, no live
provider or external network. No dedicated new disk-full injection was needed:
existing workspace transaction/disk-full recovery suites also pass, while this
unit directly tests append failure/kill/cancel rollback.

## Exclusions and integration gates

No Swift/native UI, provider, adapter, site, dependency, lockfile, schema or
serialization changes. No semantic decision-conflict detection or resolution,
conflict/supersession links, prepared-brief generation invalidation, certified host
support, background listener, live inference or full-phase completion claim.
Legacy forms intentionally do not gain CAS. Source-policy-only changes preserve
human-edit namespace; this unit does not add source reads or source authority.

No delegate/reviewer was spawned. Primary review/integration remains required.
Exact CI run/head: **not run; no push/PR authorized**. No claim about remote CI,
merge to the integration branch, deployment or native acceptance. Docker unneeded.
The unchanged ignored production 300-second process deadline and 30-second
provider deadline tests are not explicitly rerun by this unit.
The required Plum inbox read was attempted, but the coordination tool returned
`thread_not_found` (`Thread Plum is no longer available.`); no cross-agent action
or follow-up was initiated. This backend unit has no pending external dependency.
