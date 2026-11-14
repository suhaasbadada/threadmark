# Unit AD — bound metadata-only lexical coverage

## Primary repair after independent review

Initial Joffrey review was **not clear**: 4097-line sources with NUL/invalid UTF-8
could be downgraded to local unavailable status before coverage's line-budget
check. Primary retained logical-line counts from observed raw bytes (including
partial-read failure) in the private refusal metadata; coverage rejects counts
over 4096 before downgrading a source-local error. Other shared-reader consumers
still return their original error, without new admission or normalization.

Core and actual CLI regressions now combine 4096/4097 LF bytes with NUL/invalid
UTF-8 suffixes (both whole failures); 4095 LF plus the refused byte remains a
bounded unavailable result. Counts match `str::lines` for valid empty/LF/CRLF/
Unicode/trailing-line fixtures. Database/history preservation and explicit
restoration/recovery are checked. No resource limit or original test was waived.

Primary targeted **17 coverage core + six actual-CLI tests PASS**. Full offline
workspace gate **PASS**, **317 Rust tests + two doctests** (319 total passing),
two unchanged deadlines ignored. Offline locked deny, staged-new-file secrets
and staged/unstaged whitespace **PASS**. Ignored log `target/unit-ad-repair-check.log`.
The original fingerprint below is pre-repair evidence. Independent repair recheck
and exact integrated-head CI remain later gates.

## Scope and baseline

Implementation sub-agent: Bob product unit AD. Requirements TM-01–TM-04, TM-07,
TM-10; partial P2-A1/A2/A3/A4/A6. Contract and stable AD-A1–AD-A5 were written
before implementation in [coverage-report-v1](../contracts/coverage-report-v1.md).
No equivalent per-approved-file diagnostic existed: Query reports only whole
`stale-or-unindexed`; source inspection requires an already current indexed anchor.

Starting prepared head: `661bdb3e11118efe979cc7adf06c39db723bf133`.
Required local base: `392e7d52e209d482658258352de53c8aef9ec176`.
Authorized normal `git merge --no-edit` produced full baseline/tested HEAD
`55a52036b7c9b0f7d7959f7548d84c61b8e24401`, with those two parents in that order.
It preserves the prepared baseline/site history. No branch switch, reset, extra
worktree, implementation commit, push or PR. Implementation remains uncommitted;
HEAD alone is **not** the tested implementation. Primary takes only the owned
diff against that merge baseline.

## Owned inventory and tested fingerprint

- [Core module registration/shared safe reader](../../crates/core/src/knowledge.rs)
- [New core coverage module](../../crates/core/src/knowledge/coverage.rs)
- [New core acceptance tests](../../crates/core/src/knowledge/coverage/tests.rs)
- [Typed daemon variant/validation/read-only dispatch](../../crates/daemon/src/knowledge.rs)
- [Closed CLI arm/help](../../crates/cli/src/main.rs)
- [Actual CLI acceptance tests](../../crates/cli/tests/coverage.rs)
- [Versioned contract](../contracts/coverage-report-v1.md)
- This progress document.

Tested source/contract fingerprint:
`8acb78df9882bcdb13837c6de1bab87d06d1d684d49b5b6d26e725302f9f8cfa`.
Definition: SHA-256 of each of the seven source/contract paths above sorted
lexicographically, appending UTF-8 relative path, NUL, raw file bytes, NUL.
This progress file is excluded to avoid a self-referential hash. No other owned
files, schema changes, dependencies, manifest/lock edits or generated output.

## Delivered behavior

Actual `Store::coverage_report(&Project, cancel)`, typed
`Command::CoverageReport(Project)` and `project coverage` CLI. There is no unbound
form and no implicit index, discovery, recursive scan, Git, provider or inference.
The exact captured root bytes/device-inode/incarnation, ordered policy and snapshot
(including explicit none) match before first source access. Full manifest schema,
hash, ordering and identities plus all bounded evidence rows validate before FS.
Only captured approved relative paths are read; DB evidence paths grant no scope.

Existing inspection opener is reused unchanged: existing-only READ_ONLY,
pre-SQLite header refusal of WAL, no journal normalization or implicit upgrade.
One DELETE read transaction fences peer commits. The same captured Project is
used for both source scans and fresh publication binding validation. Store health,
schema and cancellation are rechecked. Observed changes fail the whole request,
including changed refused bytes: internal-only refused-source fingerprints are
compared, never returned as current metadata.

The old descriptor walker was minimally factored into one shared single-file
reader. Existing Query/Index/Export/Z remain all-or-nothing with their prior
defaults/errors. Coverage alone can downgrade source-local errors; root authority,
dependency, corruption, cancellation and budgets fail wholly. Per-chunk successful
read bytes are charged before later read/UTF-8/NUL failure; failed files cannot
reset aggregate accounting. NOFOLLOW, root identity, device, hardlink, FIFO and
nested-repository restrictions remain in the shared path, not a duplicate walker.

Output is ordered metadata only: current byte/line counts/hash when admitted,
baseline existence/match, stored anchor **record** counts, conservative status and
summary. No source/human text, absolute root/store paths or OS error details.
Lexical-only/not-assessed labels never imply semantic percentages or Ready.
`needs_build=null` when only unreadability prevents deciding; it is true for absent
or observed mismatching baseline. Mixed files never make the project current.
Unavailable stays unknown, not a freshness attestation or a missing/permission
diagnosis. No report causes Build. Whole encoded JSON including newline is bounded
to 65536 bytes and fails, not truncates.

## Actual acceptance evidence

All fixtures are synthetic, local Rust/SQLite/CLI tests.

| ID | Evidence |
| --- | --- |
| AD-A1 | Core binding mismatches (root, identity, incarnation, ordered policy, snapshot, explicit none, Unicode byte overflow) fail before a source-boundary callback and with zero source-access counter. CLI duplicate/partial/unknown flags and invalid snapshot type reject before open; missing store is not created; held stdin does not block. |
| AD-A2 | Core and actual CLI register 64 files, unindexed report, explicit Build, current report. Empty policy, empty and blank sources, indexed zero records are distinguished without semantic-completion claims. Changed hash, identical bytes/new inode, missing/symlink/invalid UTF-8/NUL and mixed current files are conservative. Restore same inode/bytes recovers without Build. |
| AD-A3 | Core cancellation before traversal, inside the shared chunk reader, after initial read and before publication. FIFO, directory, nested repo and unreadable mode are local unknowns. Seventeen failed 64 KiB UTF-8/NUL reads exhaust aggregate budget; over-file and 4097-line inputs fail. Exact escaped-output bound includes newline (boundary pass/one-byte-over fail). CLI aggregate/file/line failures emit no partial JSON and recover explicitly. |
| AD-A4 | Corrupt manifest hash/schema/path/order and evidence path/hash/coordinate, null baseline with evidence, 16385 records and dropped SQL dependencies fail before FS. Publication dependency loss, root/incarnation rebinding, store replacement, source deletion/change and refused-byte change fail wholly. Actual separate connection cannot commit revocation under the DELETE reader guard. WAL rejected without byte/directory changes and remains WAL. CLI legacy refusal does not upgrade. |
| AD-A5 | Exact DB bytes, directory entries, source bytes and human revision history preserved through diagnostic success/failure. Core and CLI Forget invalidate old binding; explicit rebuild/report omit forgotten paths while source files/human notes remain. Previous usable baseline survives diagnostic changes/failure. |

## Verification

On the fingerprinted implementation:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py` — passed: format, locked
  workspace build, all-target Clippy with warnings denied, workspace tests,
  warnings-denied rustdoc, CLI/daemon offline smoke/version/status, local doc links,
  intentional-failure gate probe. **318 passed, 2 ignored** across 26 test targets
  (including zero-test/doc targets). Unit AD contributes **16 core + 6 actual CLI**
  tests. Existing real 300-second process / 30-second provider deadline fixtures
  remained ignored and were not rerun. Earlier iterations caught test-only Clippy
  formatting/literal and SQL parameter type errors; fixed before final full pass.
- `cargo deny --offline --locked check` — passed (advisories, bans, licenses, sources).
- `python3 scripts/secrets.py` after staging all eight owned files — passed:
  tracked-file scan and synthetic-secret rejection.
- `git diff --cached --check` — passed; final local documentation-link check
  also passed after adding this progress record.

Reproduction:

```text
cargo test --offline --locked -p threadmark-core coverage
cargo test --offline --locked -p threadmark-cli --test coverage
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
```

CLI use: `project show PROJECT` supplies the displayed registration metadata. Pass
it explicitly, unchanged, to the closed `project coverage PROJECT` grammar in the
contract. Unindexed registrations require literal `--expected-snapshot none`;
after Build recapture the displayed project. Do not reuse the old none approval
after indexing. Synthetic full-64 test is an executable end-to-end reproduction.

## Limitations and integration gates

No native UI/Swift lane inspection or duplication; no Model/provider/refinement,
retained review, export/marker semantics, landing page, background listener, phase
closure, credentials, egress, Docker, host launch or deployment.

Cooperative bounded kernel I/O is not a hard deadline, external lease, or proof
against unobservable change-and-restore between scans. Opaque open failures carry
no per-cause diagnosis; unavailable-only results never attest freshness. A real
cross-device mount, kernel partial-I/O error and disk-full/process-crash scenario
were not created for this unit. Chunk accounting, real invalid-byte failures and
cooperative mid-read cancellation are tested; shared device checks are retained.
The output-overflow test targets the exact whole-JSON encoder gate; normal healthy
64-file report metadata is below that ceiling and was tested through actual CLI.

Primary independent review: **not run by this sub-agent**. PR/CI run, full remote
head, approvals and integration acceptance: **not created/not run**; primary must
record exact integrated SHA and CI URL/run after taking the owned diff. Local green
does not close P2 or prove a deployment/companion/semantic-completeness outcome.
