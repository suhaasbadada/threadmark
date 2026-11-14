# Unit AM — Explicit file-scoped Context preparation

## Primary integration and independent review

Only the eight owned paths were committed as `af61875` and applied cleanly to
primary as **`ebe9f71eee0ed128962634765c872f924a335c5c`**, exact tested integrated
runtime. No baseline/site merge replay or conflict resolution was needed. The
ordered seven-path binary-diff fingerprint was reproduced after integration,
identical to **`4cebc0e2c93179d9de0189292140a8c1ae60b7a00f4c9b75878098b524f374c0`**.

Joffrey independently reviewed **CLEAR**, verified baseline/inventory/fingerprint,
and reran all 16 new tests, the complete offline workspace check (**403 Rust tests
+ two doctests**), offline locked deny, secrets and both whitespace checks. His
workspace run included inherited synthetic loopback HTTP fixtures, not external
provider/network traffic. No native/AL inspection or remote CI was claimed.

Primary reran full offline check at the exact integrated runtime: **403 Rust tests
+ two doctests PASS**, offline locked deny, secrets and whitespace **PASS**. Full
strict serial native Debug and Release each **296 tests/47 suites PASS**, with
actual CLI and all seven C-fixture families enabled, confirm the unchanged default
Context/Refine paths against the new Rust binary. AL's eight API gates and bundle
had passed separately before the backend-only integration; native code was not
modified by AM. Two inherited long deadlines remain ignored. No GUI/AX/live
provider/host/phase closure claim. Publication-head CI is separate and pending.

AL is a separate publication with no AM changes in its PR head. Its pending
macOS check is not evidence for AM; any stacked PR must retain separate exact
head/CI and merge gates. Nine inherited progress edits and all worktrees preserved.

TM-01–TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6, P3-A3/A4,
P4-A1/A2/A3. Contract and stable AM IDs were written **before** implementation in
[file-scoped-context-v1](../contracts/file-scoped-context-v1.md). This is an explicit
local core/daemon/CLI operation, not native integration, semantic/AST understanding,
inference quality evidence, host support certification or phase closure.

## Baseline, ownership and integration

- Initial clean assigned HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required local base: `b3b60d7ecb2d2aba7c6c6021233b5bf663c4d6b0`.
- Normal authorized `git merge --no-edit` created the **only** new commit:
  `063058b4c66dad5549f277ba367164ffe785cc17`, with the initial HEAD and required
  base as its two parents. No reset, branch switch, new worktree or history rewrite.
  Its tree is identical to the required base; prepared/site history remains in its
  ancestry. No baseline/site diff belongs to AM.
- Full tested Git HEAD: `063058b4c66dad5549f277ba367164ffe785cc17` **plus the
  uncommitted owned patch below**. HEAD alone is not an implementation SHA. There
  is intentionally no implementation commit; primary must integrate only owned
  paths/diff, never replay the baseline merge as implementation.
- Remote CI URL/ID/head: **not run / none**. Independent review: **not performed
  by this child**. Exact integrated SHA, independent review and exact CI remain
  primary-owned gates; no earlier green base run is claimed for this patch.

Owned inventory (seven code/test/contract paths plus this evidence file):

| Path | Change |
| --- | --- |
| `crates/daemon/src/preparation/file_scoped.rs` | New immutable plan, private one-shot authority, Context-only preparation and bounded response |
| `crates/daemon/src/preparation/file_scoped/tests.rs` | New actual core/engine boundary and preservation tests |
| `crates/daemon/src/preparation.rs` | Export module; factor only the existing Context Request constructor |
| `crates/daemon/src/knowledge.rs` | Typed command, original admission, existing-store-only open, dispatch |
| `crates/cli/src/main.rs` | Closed explicit grammar, pre-stdin plan freeze, bounded original, help and argument cap |
| `crates/cli/tests/file_scoped_context.rs` | New actual CLI/daemon/storage tests |
| `docs/contracts/file-scoped-context-v1.md` | Predeclared contract and AM-A1–A6 |
| `docs/progress/unit-am-file-scoped-context.md` | This handoff evidence |

Patch fingerprint (SHA-256 of `git diff --binary HEAD --` the seven non-progress
paths above, in the displayed order):
`4cebc0e2c93179d9de0189292140a8c1ae60b7a00f4c9b75878098b524f374c0`. This evidence
file is excluded to avoid a self-referential digest. All owned paths are left
staged, uncommitted; no unrelated staged/unstaged work was present or altered.

## Product and immutable authority

Inspect the exact full Project and AK query-files selection, then explicitly run:

```text
threadmark --data-dir EXISTING_STORE context prepare-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Original is nonempty <=4096-byte UTF-8 stdin, no NUL; no trimming/normalization.
`FileContextPlan::new` consumes the FULL Project and FileQuery, validates through
AK, canonicalizes selection to full-policy order and privately freezes both.
There are no mutable accessors or public constructors bypassing admission. A
header that cannot fit the frame fails before stdin/store/source access.

Initial selection calls `Store::query_files_bound` directly. A private authority
owns that same plan plus the exact immutable Request and calls the same AK API
for engine revalidation and final publication. It rejects a different Request,
including original/evidence/mode differences. It is constructed in one call,
never exported, cached or retrieved by request ID. There is no unbound preflight,
ID reload, reduced Project, unfiltered CoreAuthority re-read, alternate renderer,
permission system, client-v1 change or broad retrieval/export change.

The existing engine validates and renders Mode::Context with provider access None.
Only source data that passed selected-file retrieval enters the request/brief.
Missing/no-match/unindexed/stale initial evidence is needs-input with exact
unchanged proposed original; it is not an unfiltered or failed-provider fallback.
Changes during engine/final revalidation fail the whole operation. Scope wrapper
bytes are reserved from the engine budget; final full escaped JSON **including
LF** is independently checked against 8192 bytes. No whole-entry or warning
truncation, fabricated anchor/root/nonce field, approval or delivery occurs.

**Selected files filter output candidates, not source permissions or I/O.** All
approved sources, including unselected sources, still undergo AK's full freshness
reads. No privacy isolation, AST/semantic completeness, I/O avoidance, performance
gain, filesystem lock or atomic external-revocation lease is claimed. Freshness
checks remain cooperative; synchronous work is not forcibly preempted.

## Acceptance evidence

Sixteen new tests: eight daemon unit tests and eight real-CLI integration tests,
using actual AK SQLite/source retrieval. Existing AK core tests run unchanged.

| ID | Actual evidence |
| --- | --- |
| AM-A1 | Pure plan rejection of empty/duplicate/unknown/forbidden/>64 subsets, missing/malformed full capture fields and query UTF-8 byte limits. Callback sees the full captured root/identity/nonce/policy/snapshot on every call. Closed real CLI rejects malformed/repeated/unknown flags and ranked controls with stdin deliberately held open; bounded test watchdog joins its own child. Missing valid store is not created. Legacy v2 fixture remains byte-identical and is not upgraded. |
| AM-A2 | >8 earlier/stronger unselected anchors plus a later selected anchor: only selected evidence in initial selection, actual engine preparation and final publication. Callback observes boundaries `[0,1,2]` with the identical full Project/query/mode/subset. Exact AK literal versus Unicode-lowercase ranked semantics, composed/decomposed Unicode, quotes/backslashes, canonical policy order, and all-files old Context proposed-text equivalence where evidence exists and budgets permit. Real CLI query-files -> prepare-files and both complete 64-file lists pass. |
| AM-A3 | 60 deterministic cases: both algorithms x three boundaries x peer different-root replacement, same-root/new nonce, full policy reorder, new indexed snapshot, selected Source Forget, cancellation, selected edit, unselected edit, project removal, and missing evidence-table dependency. Failures return no partial response; initial source staleness returns needs-input/original/empty evidence. Later source staleness cannot publish the old brief. AK inherited source-containment/publication tests remain unchanged and pass. |
| AM-A4 | Unindexed/empty/no-match/stale responses preserve exact original and disclose needs-input; no fabricated expertise. Genuine 12-match/8-anchor truncation exposes counts, provenance and omission coverage. Binary search exercises the last accepted escaped whole JSON/LF frame (8189..8192 bytes depending on escape/mode) and rejects the next character. A shape-valid full capture serialized at exactly 32768 bytes is rejected by its oversized selected scope header before I/O; real CLI oversized scope rejects before stdin. No cap relaxation. |
| AM-A5 | Malicious source instructions are quoted/escaped by the existing engine; originals retain exact Unicode/CRLF/newlines/negations. Actual engine provider call counter is zero for malicious content and forced authority failure, with Context/None. Product responses report provider-not-invoked, approval-not-requested, delivery-not-attempted; no approval/delivery code is called. Real CLI DB file bytes are identical before/after preview, SQL logical dump and DB bytes contain no original, human revision history and source bytes are unchanged. Old capture fails after Forget, a fresh forgotten-file subset is invalid, and rebuild cannot resurrect it. |
| AM-A6 | Old query/QueryTerms/default Context/Refine/retained/selection/client-v1 contracts and serialization remain untouched; complete offline workspace regression gates pass. No core algorithm/export/schema/dependency/lock changes. |

The exact 32768-byte test is a full capture (full policy plus selected list and
root metadata), not a fabricated 32768-byte selected-only list: existing AK paths
are capped at 240 bytes, and that cap is preserved. The output contract includes
selected paths, not invented root/nonce authority wire fields.

## Reproduction and checks

```sh
cargo test --offline --locked -p threadmark-daemon --lib file_scoped
cargo test --offline --locked -p threadmark-cli --test file_scoped_context
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

- Full `scripts/check.py`: **PASS**, format, locked workspace build, strict
  all-target Clippy, **403 Rust tests + two doctests**, rustdoc, finite diagnostic
  commands, documentation links and intentional failing-test gate.
- Exactly two inherited production 300-second/30-second deadline fixtures remain
  ignored and **were not rerun**, as requested.
- `cargo deny --offline --locked check`: **PASS**, cached advisories/bans/licenses/
  sources; no network refresh or dependency change.
- Secrets after staging new files and both whitespace checks: **PASS**. The
  tracked-file scan passes and its synthetic-secret rejection probe passes.
- Ignored local logs: `target/unit-am-check.log`, `target/unit-am-deny.log`,
  `target/unit-am-secrets.log`; no source/original content is emitted into these
  evidence logs by the new tests. Initial development had one failing synthetic
  scope fixture (used paths beyond AK's 240-byte limit); corrected the fixture,
  not production limits, before the final passing gates.

## Exclusions and limitations

No subagents, implementation commits, push, PR, credentials, installs, egress,
spend, deploy, GUI/host launch, Docker or remote coordination. No native Swift
UI/Model/AL lane inspection or edits. Inherited stdin and Swift compiler fixture
repairs are untouched. No Refine consent widening, provider/profile/retained/
export/marker semantics, schema, dependencies, lockfile or site changes. No
original retention, logging, clipboard/send or file-write capability was added.

Swift/native suites, live provider, real host handoff, remote CI, integrated
independent review and live functional acceptance are **not run** by this child.
No automatic follow-up/watch/reminder was created; no external dependency was
opened. All work remains in the assigned checkout for primary review/integration.
