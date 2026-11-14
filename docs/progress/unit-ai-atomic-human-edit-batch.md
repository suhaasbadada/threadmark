# Unit AI — atomic explicit human-context batch edits

## Primary integration and independent review

Primary committed only the ten owned files as `12b3164` and applied cleanly as
**`3bf63f81a8750f447d8d12260839da4f067997e9`**, exact integrated tested runtime.
No prepared baseline/site merge history replay. Joffrey independently reproduced
the fingerprint and reviewed **CLEAR**; passed 14 batch core, six actual CLI,
13 CAS regressions, full offline workspace suite (**370 including two doctests**,
two deadlines ignored) and whitespace. He did not rerun lint/deny/secrets or native
UI tests and made no changes.

Primary full workspace gate **368 Rust tests + two doctests PASS**; strict serial
actual-CLI/all-C-fixture Swift **260 tests/40 suites PASS**; all five API gates,
offline locked deny, staged secrets and whitespace **PASS**. No fresh native
Release claim for this backend-only addition. Exact publication-head CI remains
separate. All target validation/suppression/quota checks precede appends in one
transaction; no partial outcome or automatic conflict resolution inferred.

PR #82 fresh main-targeted head `9f761c10a5eaf8dc4c3cd75a2dc8e82e278ce950`
passed all five checks (CI `43591675265`, integrated `43591675250`); fresh gates
preceded merge `9c84f6a826d73b9e51f83151b4e6567e05de9753`. Watch removed, and
exact post-merge runs `43592319046`/`43592319072`, both targeting that merge,
completed **PASS**. AH native incremental controls have reported implementation
and local tests; independent review/integration remain pending. Nine inherited
progress edits/worktrees/parent reminders preserved. No GUI/AX, live-quality,
host-delivery, deployment or phase closure claim.

## Baseline and ownership

Required local base: `cfba6b107b518af58d73e716fbaaf49c2164332d`.
Prepared branch started clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
Authorized normal `git merge --no-edit` produced merge-only baseline
`6345a45251951d43a1952fddd201a6fee1a477d4`, parents exactly those two SHAs,
preserving prepared contract/site history. No reset, switch, new worktree,
implementation commit, push, PR, credential use or network operation.

Implementation is **uncommitted on that full baseline**, not a tested committed
implementation SHA. Primary must integrate only the owned diff and obtain exact
integrated-head CI and independent review. No CI run/head or PR exists for this
unit. Phase 2/3 remain open. No native Swift/UI lane inspection or changes.

Owned inventory:

- `crates/core/src/knowledge/context_batch.rs` (new typed admission/transaction)
- `crates/core/src/knowledge/tests/context_batch_tests.rs` (new SQLite fixtures)
- `crates/core/src/knowledge.rs` (module/export only)
- `crates/core/src/knowledge/tests.rs` (test module only)
- `crates/core/src/knowledge/human_read.rs` (existing metadata helper visibility only)
- `crates/daemon/src/knowledge.rs` (new typed variant/admission/existing-store arm)
- `crates/cli/src/main.rs` (new closed grammar/help only)
- `crates/cli/tests/context_batch.rs` (new real CLI fixtures)
- `docs/contracts/human-context-batch-edit-v1.md` (written before implementation)
- this progress document.

No schema/dependency/lockfile/site/source-provider/index implementation changes.
Existing single-note trusted/CAS APIs and serialization are unchanged. No generic
transaction framework or public listener. Existing complete-history validator is
reused inside the one transaction; no nested/public writer loop.

## Contract and acceptance

[Contract](../contracts/human-context-batch-edit-v1.md): TM-01–TM-04, TM-07, TM-10;
partial P2-A1/A3/A5/A6 and P3-A4. Human declarations remain human-authored context,
not source truth, authentication or permission. No semantic conflict resolution,
links, implicit adds, namespace mixing, automatic reordering or repair.

- AI-01: closed duplicate-rejecting JSON and typed admission; 2..8 distinct IDs;
  canonical integer revisions 1..32; 4096-byte individual/32768 aggregate text;
  65536 encoded document bytes; UTF-8/NUL/unknown-field rejection before store.
- AI-02: exact registration checked in IMMEDIATE transaction before human SQL;
  nonce replacement, identity/root mismatch and Unicode byte mismatch fail closed.
- AI-03: all expected revisions/full target histories validated before any append;
  two actual SQLite connections batch-vs-single CAS cannot both accept same base.
- AI-04: max history/project budgets; Forget of any one of eight rejects all;
  deliberate fresh Update can reactivate retired history; no missing-ID fallback.
- AI-05/08: cancel after every staged append and ready-to-commit; SQL ABORT and
  actual SQLite page-capacity failure after first append; killed owned child after
  first staging, reopen/full export equality and fresh successful batch.
- AI-06: real CLI duplicate/unknown fields, operations, flags, revisions, bounds,
  invalid UTF-8/NUL/trailing document, held stdin preflight, exact encoded limit,
  absent store and legacy no-implicit-upgrade/content-free failure fixtures.
- AI-07: 2..8 mixed actions/reopen, retirement/reactivation; Build and source
  Forget preserve human histories; other project export/source bytes unchanged.
  Missing source root/malformed source policy/no snapshot do not block human edit.
  Private store file/health admission still applies; no source filesystem access.

## Verification (local, not remote acceptance)

Reproduce with `CARGO_NET_OFFLINE=true`:

```text
cargo test --offline --locked -p threadmark-core context_batch
cargo test --offline --locked -p threadmark-cli --test context_batch
python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
```

Final local results on baseline plus owned uncommitted diff:

- Full `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **passed**, 370 tests
  passed across 28 test summaries, 0 failed, 2 existing deadline fixtures ignored.
  Includes format/build, all-target clippy with warnings denied, workspace tests,
  doctests, docs with warnings denied, CLI/daemon finite smoke/status/version,
  documentation links and deliberate failing-assertion gate probe.
- Dedicated batch coverage: **14 core** (includes inert owned-child entrypoint)
  and **6 real CLI** tests passed, including the actual killed-child staging test.
- `cargo deny --offline --locked check`: **passed** advisories/bans/licenses/sources.
- `python3 scripts/secrets.py`: **passed** tracked/staged-new-file/history scans
  and deliberate synthetic secret rejection. All five new files staged for scan;
  pre-existing-file edits remain unstaged. No implementation commit was created.
- `git diff --check`: **passed**. First full run found only two new test assertion
  clippy `int_plus_one` warnings; corrected, then the entire pipeline reran green.

Full check log: session-local `unit-ai-check.log` artifact, not committed; no
private filesystem paths or source text are copied into this public evidence.

Owned implementation/tests/contract patch fingerprint, excluding this progress
document to avoid a self-reference: **SHA-256
`05fd5eb03177266468e293c5d004a6e49a795ba4ef53554096cab351865af229`**,
49797 bytes. Reproduce against the exact merge baseline using:

```text
git diff --binary HEAD -- . ':(exclude)docs/progress/unit-ai-atomic-human-edit-batch.md' | shasum -a 256
```

The fingerprint includes staged new files and unstaged owned edits; it does not
identify a committed implementation head. Only this inventory is for integration.
Existing production 300/30-second deadline fixtures remain ignored, not rerun.
Inherited stdin fixture is unchanged. No Docker, GUI, host launch or provider use.

## Limitations and remaining gates

This finite local operation is not a background companion, certified host support,
source authorization, inference, forensic erasure or semantic conflict resolution.
Receipt sorting is metadata only. Core returns only after commit; daemon has no
postcommit cancellation override. Commit uncertainty follows existing SQLite CAS.
The observer is synchronous, bounded and precommit; caller panic/process death
unwinds/recovers using the existing SQLite model. No automatic retries.

Primary independent review/integration and exact integrated-head CI are pending.
Plum coordination thread lookup returned `thread_not_found` in this environment;
no cross-agent coordination or delegated work was performed.
