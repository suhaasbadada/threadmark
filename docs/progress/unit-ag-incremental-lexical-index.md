# Unit AG — opt-in bounded incremental lexical index

## Primary integration and independent review

Primary committed only the eight owned files as `ca9f638` and applied cleanly as
**`2192eb4d9b63786bf4035c956520b02fb01cf726`**, exact combined tested runtime.
No lane baseline/site history replay. Joffrey independently reproduced payload
fingerprint and reviewed **CLEAR**; ran all 188 core tests (16 AG), four AG CLI
tests and surrounding CLI regressions, full offline workspace pipeline, offline
locked deny, secrets and staged/unstaged whitespace **PASS**. Native/AF and remote
CI were not independently tested by that review.

Primary full workspace **348 Rust tests + two doctests PASS**; strict serial
actual-CLI/all-C-fixture Swift **260 tests/40 suites PASS**; all five API gates,
offline locked deny, staged secrets and whitespace **PASS**. No fresh Release
claim for this runtime-only backend addition; AF's earlier full Release is separate.
Unchanged long deadlines ignored. Full source reads and complete lexical output
validation remain mandatory: measured reuse concerns SQL rows, not source I/O or
extraction CPU avoided, and no performance benchmark is claimed.

Native coverage PR #81 at `070654ab226f3487b60212d1318d53c18eb011ba` has four
green checks and macOS pending in CI `43590580220` (integrated `43590580246`
green). This unit will be published as a separate stack layer against its branch,
not duplicate AF scope against main or merge before required gates. Parent/base
retargeting and fresh exact-head CI after any update remain explicit later gates.
PR #80 exact post-merge CI `43590490587` remains pending; integrated `43590490702`
passed at merge `6e4223cb7cd279086e2672ec5a16c07f89e4da42`, not AG evidence.
Nine inherited progress edits/worktrees/parent reminders preserved. No GUI/AX,
live-quality, host delivery, deployment or phase closure claim.

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A5/A6.
Contract: [incremental-lexical-index-v1](../contracts/incremental-lexical-index-v1.md),
defined before implementation. Phase 2 remains open.

## Baseline and ownership

- Initial clean prepared HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required local base: `3c3da3c3811d101ef60ad0f3bc55501aa0910426` (AE, AD,
  reviewed CI stdin fixture fix). Used normal `git merge --no-edit`, no branch
  switch/reset/new worktree; preserved prepared baseline and site history.
- Merge-only tested baseline HEAD: `0402a0bab719360e899003b99220467e3238f9f3`.
  Parents, in order: initial prepared HEAD and required local base above.
- No implementation commit, push, PR, remote CI, external review or merge.
  Tested implementation is an uncommitted owned diff over that complete SHA;
  never cite the baseline SHA alone as containing AG implementation.
- Primary should take only these eight owned files relative to the merge baseline:
  `crates/core/src/knowledge/incremental.rs`,
  `crates/core/src/knowledge/incremental/tests.rs`,
  `crates/core/src/knowledge.rs`, `crates/daemon/src/knowledge.rs`,
  `crates/cli/src/main.rs`, `crates/cli/tests/incremental.rs`,
  `docs/contracts/incremental-lexical-index-v1.md`, and this progress record.
  Do not take the baseline merge as the implementation diff or duplicate its
  history into the primary's already prepared branch.

## Implementation

Explicit core API `index_incremental(&Project, cancel)` plus finite progress
variant; typed daemon `IndexIncremental(Project)` and closed `index-incremental`
CLI grammar. Full captured root bytes/identity/incarnation/ordered policy/snapshot,
including explicit none, required before source access. Existing writable store
only, schema v3/v4, no migration. Coverage remains existing-only read-only.

One bounded immediate transaction captures and fences writer authority before
source traversal, through staged replacement and commit. Peers cannot commit
registration/policy/snapshot changes during the operation; preexisting peer
changes invalidate old bindings before traversal. Fresh capture/suppression,
store health and schema checks bracket SQL/publication. Holding a writer
reservation across three complete bounded scans is a deliberate local
serialization tradeoff, not a new worker/locking framework or external lease.

Shared helper factors only existing bounded anchor admission from full indexing.
Full indexing still deletes/reinserts its ordinary evidence set and preserves
old JSON. Incremental computes complete lexical output, validates all persisted
baseline records, compares every eligible unchanged file's full anchor set,
then retains those exact evidence rows. Changed/inode-replaced files replace
only their own rows. Valid non-default producers get full-file lexical replacement,
zero reuse. Missing/extra/corrupt unchanged lexical sets fail rather than heal.
Without a baseline require null manifest and zero evidence; build with reuse zero.
Empty files/policies and valid zero-anchor sets are supported.

No-op requests do three full scans and lexical validation but zero persistent
SQL writes, demonstrated by `total_changes`, row identity and database bytes.
Reports separate row reuse, row writes/deletes, snapshot update and persistent
writes. SQL evidence reuse is not source I/O avoidance, permission reuse,
semantic coverage, skipped extraction CPU, or measured performance improvement.

## Actual evidence and reproduction

All inputs synthetic, offline locked dependencies, no user stores or sources.

```text
cargo test --offline --locked -p threadmark-core knowledge::incremental
cargo test --offline --locked -p threadmark-cli --test incremental
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

- Targeted core: **16 passed**, including one owned staging-child harness
  (no-op unless explicitly invoked by its parent kill/recovery test).
- Actual CLI/daemon/core: **4 passed**.
- Offline locked deny: **passed**, advisories/bans/licenses/sources all OK.
- Full check first run caught two AG Clippy findings (type complexity and
  integer-plus-one assertion); repaired with a private `Baseline` struct and
  equivalent simpler assertion. Final full-check status recorded below.
- No unchanged ignored production 300-second/30-second deadline fixture was
  explicitly run; required-base stdin fixture fix is unchanged.

### Stable acceptance evidence

- **AG-A1:** complete root/identity/nonce/order/none/hash mismatch before source
  hook; peer snapshot/policy/re-registration/new-root replacement fails old
  capture; fresh capture rebuilds. CLI duplicate/partial/out-of-order/unknown/
  oversized UTF-8-byte-length bindings rejected before storage with held
  stdin; missing store remains absent; schema2 bytes unchanged, no migration.
- **AG-A2:** actual initial query/unindexed -> none build -> query -> validated
  incremental -> query; exact Unicode/CRLF/provenance/hash; 64 files, empty file,
  zero anchors and empty policy. Unchanged SQL `total_changes` delta **0**;
  one edited two-anchor file: **2 deletes + 1 insert + 1 manifest update**, other
  file rowid unchanged. Identical bytes with new inode: **0 reused anchors**.
- **AG-A3:** 15 corruption variants include reordered/forged manifest, invalid
  hash/identity, unknown manifest fields, orphan path/hash mismatch, malformed
  producer/text/coordinates, missing/extra lexical anchors, absent-baseline rows.
  Unknown valid producer re-extracts all lines, **0 reuse**, **1 delete/2 inserts**,
  unchanged content snapshot. Exact **1 MiB / 16384 anchors** admitted and then
  reused with zero writes; over-budget file/aggregate/lines/anchors/line length,
  NUL/UTF-8, symlink/hardlink/FIFO/directory/nested repository/replaced-root
  refusals preserve baseline. Escaped Unicode source query and report bounds.
- **AG-A4:** cancel at Read/Extracted/ReadyToCommit, prestart and during read
  chunks; source mutation at each observer boundary (before/after SQL); actual
  SQLite TEMP-trigger ABORT and page-capacity failure; store-permission dependency
  failure; recovery afterward. Owned child killed after SQL staging leaves a hot
  journal; reopen restores previous evidence rows/snapshot and human history,
  then successful incremental rebuild/query. Peer policy/snapshot/incarnation/
  evidence/removal SQL is blocked at ready-to-commit rather than racing publication.
- **AG-A5:** Forget invalidates old binding, fresh explicit-none rebuild omits
  forgotten path, marker retained, source bytes and both human revisions unchanged.
  Full-index output equality and query equality tested directly. Existing
  full-index/query/export/inspection/coverage regression suites run by full check.

## Limitations and excluded scope

This is manual lexical SQL-row reuse only, not AST/structural completeness, a
filesystem-incremental watcher, a background companion, inference, a public
listener, authenticated host support or a phase closure. No native UI/Model/
source coverage/Swift AF work, schema/dependency/lock changes, provider/refinement/
retained/export/marker semantics, Git behavior or site changes. No GUI, host
launch, Docker, credentials, spend, external egress or subagents used.

Cancellation is cooperative; filesystem changes after the last descriptor scan
are not an external lease. Precommit failures roll back, while commit I/O errors
remain uncertain under existing error semantics; successful commit is not turned
into an apparent rollback by a postcommit cancellation check. Serializing writers
can make another local writer wait/fail while scans finish. No benchmark was run.
Old-source text cannot be reconstructed for changed hashes: changed-file old rows
are structurally/provenance validated and fully replaced, never partially reused.
Empty stored sets on unchanged nonempty lexical output are ambiguous and rejected.

Independent primary review, integrated-head SHA and exact CI run/head are **not
run / not available** in this implementation child. Primary owns those gates.

## Final verification and fingerprint

Final `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **passed** formatting,
locked workspace build, all-target Clippy with warnings denied, workspace tests
(including **188 core** tests and **4 new CLI** tests), warning-denied rustdoc,
finite CLI/daemon diagnostics, local documentation links and intentional failing
test-gate probe. The two unchanged production deadline tests were reported
**ignored**, not rerun. Offline locked deny passed. No Swift/AF lane was run.
All eight owned files staged but uncommitted. `python3 scripts/secrets.py`:
**passed** tracked-file scan and synthetic-secret rejection. Both unstaged/staged
whitespace checks: **passed**. Final local documentation links: **passed**.
Final inventory contains only the eight owned files; no baseline, lockfile, site,
native/Swift or other-lane file was edited by AG.

Seven-file implementation+contract payload (excludes this self-referential progress
file) has the following reproducible SHA-256 manifest. Hash each complete file's
bytes, render lowercase digest + two spaces + relative path + LF, in this order;
the SHA-256 of that UTF-8 manifest is
`f83bebe486a8db4ffe06a3750b30976bc51214d8d8aff38d936c5cbac244fc64`.

```text
835a60cdf6e9324c6494226f3dd42327d33ceb50b232cc04092312b7c6926bf1  crates/cli/src/main.rs
5fd7cc4f19af5affd2be7b2a40ee933465770b15c17ccfbf6064be3bbc97caf6  crates/cli/tests/incremental.rs
51bd1582d5a1cab04373288f775775a2eaf196335856296d3f4d1db0a38d2ad2  crates/core/src/knowledge.rs
9821869f6d9a30f16e816a599cb6dcb920f66552fe631dd5f0d15255cafbdb6f  crates/core/src/knowledge/incremental.rs
ddebef1149b9333d304a9e9fe63aeba0555185e0bd656841103e2888b12948df  crates/core/src/knowledge/incremental/tests.rs
02fcfbcc59bb4854adb6a6cf0c1242230d6dc4f29d05826b6bdd0e40e6e14975  crates/daemon/src/knowledge.rs
1bd752e23ca0813de38f2bd5229d8043d68939ce508a7c91ae270a22c24e14c7  docs/contracts/incremental-lexical-index-v1.md
```
