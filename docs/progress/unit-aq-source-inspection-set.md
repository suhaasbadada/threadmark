# Unit AQ — coherent bounded source inspection set

## Primary integration and independent review

Only the owned diff committed as `9c95259` was applied, cleanly, as
**`38edf25525526f170cf54138d4efc9fa813251b7`**, exact integrated tested runtime.
No baseline/site merge replay or source conflict repair. The eight-file path/
NUL/bytes/NUL fingerprint was reproduced after integration, identical to
**`50e125e9098ddd510ea10fed510a47755cd96307660ff8ba0a6a385387ae2429`**.

Joffrey independently reviewed **CLEAR**, verified all owned paths/fingerprint,
checked the shared single-window helper and surrounding DELETE/read-only/source
containment boundaries, and ran **25 core + eight CLI inspection tests** plus
full offline workspace (**439 Rust tests + two doctests**), offline locked deny,
secrets and staged/unstaged whitespace. Peer-lock and same-connection mutation
evidence were explicitly distinguished; no atomic filesystem lease claimed.

Primary reran full offline workspace **439 Rust tests + two doctests PASS**,
full strict native Debug/Release with actual CLI and all nine C families (see
`target/unit-aq-integrated-native.log`), all ten API gates, bundle/plist, offline
locked deny, secrets and whitespace **PASS**. Existing single inspection and
native Context/Query/human-note flows passed against the new Rust binary. No
native inspection-set route is implied by these regression checks. Two inherited
long-deadline tests remain ignored. Exact publication-head CI remains separate.

AP is separately stacked above repaired AN; AQ publication must preserve those
separate PR/head/check gates and retarget only after its lower layers merge.
AN old 12-minute CI cancellation is a diagnosed deadline blocker, not green;
its macOS-only bounded 20-minute repair retains every test/API/bundle gate.
Inherited phase edits, local receipts and worktrees remain intact. GUI/AX/live
quality/host delivery and phase closure remain open.

TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A6 and P4-A2.
The [AQ contract](../contracts/source-inspection-set-v1.md) and stable AQ-A1–A6
IDs were written before runtime edits. This is an explicit local Rust
core/daemon/CLI product operation, not native integration or phase closure.

## Baseline and owned integration

- Initially clean assigned branch `t3/c665bc1b`, HEAD
  `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required local base: `db4c1cbf390d66236e02793ff04482f006b1a854`.
- Authorized normal `git merge --no-edit` created the ONLY new commit,
  **`ccfd97070b7273f55be627274b43cfb91feeb72f`**, with those two parents in that
  order. Its tree equals the required base. Prepared/site ancestry is intact.
  No reset, branch switch, checkout or new worktree was used.
- Full tested local HEAD is that baseline merge **plus the uncommitted owned
  patch** below. HEAD alone is not an implementation SHA. No implementation
  commit/push/PR exists. Primary must integrate ONLY this owned diff relative to
  the baseline merge, not replay baseline/site ancestry.
- Independent review: **not run**. Exact remote CI run/URL/head: **none**.
  Primary owns independent review, integrated tested SHA and exact-head CI.
- New files are staged only for tracked-file secrets scanning; modified existing
  files remain unstaged. `git diff HEAD` includes both halves. No unrelated work
  was present or changed.

Owned inventory (eight fingerprinted paths plus this document):

| Path | Change |
| --- | --- |
| `crates/core/src/knowledge/source_inspection_set.rs` | Private immutable admitted plan, closed stdin document, one-transaction all-anchor membership/read/publication |
| `crates/core/src/knowledge/source_inspection_set/tests.rs` | Fourteen actual core/SQLite synthetic acceptance tests |
| `crates/core/src/knowledge/source_inspection.rs` | Factor only the genuine current-source window constructor; old response unchanged |
| `crates/core/src/knowledge.rs` | Additive module and plan/coordinate exports |
| `crates/daemon/src/knowledge.rs` | Typed owned-plan command, strict inspection-only readonly opener and dispatch |
| `crates/cli/src/main.rs` | Additive closed inspect-set grammar, pre-stdin binding/radius admission and bounded input; old usage bytes unchanged |
| `crates/cli/tests/source_inspection_set.rs` | Eight actual CLI/daemon/core acceptance tests |
| `docs/contracts/source-inspection-set-v1.md` | Predeclared request, response, safety and AQ acceptance contract |
| `docs/progress/unit-aq-source-inspection-set.md` | This evidence and primary handoff |

Implementation/contract fingerprint (SHA-256):
**`50e125e9098ddd510ea10fed510a47755cd96307660ff8ba0a6a385387ae2429`**.
Reproduce by sorting the eight non-progress relative paths above, then hashing
each UTF-8 path + NUL + raw file bytes + NUL in sequence. This document is excluded
to avoid recursion. No schema/dependency/lockfile/site/native diff is owned.

## Product semantics and limits

After an actual literal/ranked Query, explicitly capture 2..8 distinct returned
path/line/hash coordinates and the complete Project. `SourceInspectionSet::new`
consumes the FULL binding and coordinates, purely validates all shape, then
privately freezes canonical full-policy-position/line order and explicit radius
0..3. There is no unchecked constructor, mutable accessor, deserialization bypass,
unbound form, reduced Project, ID reload or latest-snapshot substitute.

CLI flags/full binding/radius are admitted before stdin; one <=65536-byte strict
UTF-8 closed duplicate-rejecting document supplies only version and anchors. The
whole plan is admitted before storage opens. All 64 full-policy paths fit exactly
within the unchanged 80-argument global ceiling (16 fixed + 64 sources); unrelated
grammars and single inspection's existing 84-argument allowance are unchanged.
Existing-only `open_existing_for_inspection` rejects WAL headers before SQLite
opens, uses a read-only connection and never creates/upgrades/normalizes storage.

ONE read transaction checks complete current binding, DELETE journal mode, stored
manifest/snapshot integrity and ALL selected indexed row/hash/producer membership
before first source authorization/traversal. No public single-anchor API is called
by set inspection. The same full capture remains bound through all windows and
publication. The shared original window constructor verifies exact current center
text/hash and emits genuine existing line/provenance objects. Every blank or
nonblank neighbor is freshly observed text, not an additional indexed claim.
CRLF/Unicode/quotes/instruction-looking text retain existing `str::lines()` behavior.

Selection restricts returned windows, NOT source permissions or freshness reads.
Both full-manifest traversals retain every approved file, including unselected
ones, and unchanged root/file/device/inode/link/nested-repository controls. Health,
complete binding, cancellation and freshness are rechecked before publication.
The DELETE reader lock prevents peer commits behind the snapshot across the
entire set. Any mismatch/failure/overflow returns no content; never omit a stale
anchor, shorten a window/radius, retry or fall back to independent single reads.

Distinct closed set JSON factors project/root identity/incarnation/snapshot/radius/
currentness into the outer record; every ordered inspection carries path/hash/
producer/anchor_line and full lines. At most eight seven-line windows (56 lines).
Complete escaped JSON including final LF must fit 8192 bytes, or fail wholly.
No absolute root, human notes, original query, provider/approval/delivery/export or
new source authority. Explicit local stdout only. Existing single/Query/Context/
Refine/human-search/export wire defaults are unchanged.

## Acceptance evidence

| ID | Local synthetic evidence |
| --- | --- |
| AQ-A1 | Pure count/radius/path/hash/line/duplicate admission, including duplicate coordinate with different hash; full ID/root/identity/nonce/order/subset/snapshot/null/UTF-8 bounds. Composed/decomposed root bytes and old registration fail. Counter assertions isolate zero source access for every admission/binding mismatch; initial cancellation also precedes access. Owned typed daemon plan cannot be constructed with malformed shape; missing valid store is not created. |
| AQ-A2 | Actual Query and query-files captures, same/different files, reversed input canonicalized to full policy rather than alphabetical order; radii 0..3, count edges 2/8, natural file edges, blank/CRLF/Unicode/quotes/backslashes/instructions. Set records equal genuine single-inspection records for shared fields. Sparse extraction proves observed nonblank neighbors cannot become centers. Eight full seven-line windows produce exactly 56 whole lines. Actual CLI includes complete 64-source policy. |
| AQ-A3 | Last missing/forged row/hash/producer/text and corrupt manifest/missing table fail before the first-source seam and with zero source-access delta. Forged caller+persisted hash cannot bypass manifest; forged indexed text cannot match the current center. Cancellation, selected/unselected edits, deletion, root replacement, store-file permissions, unreadable approved file and missing store dependency at all four boundaries (all membership, first full read, interwindow, final publication) refuse the whole set. Symlink/hardlink/FIFO/nested-repository/WAL fail. |
| AQ-A3 coherence | Every membership/read/interwindow/publication seam asserts SQLite autocommit is false and peer policy replacement/removal cannot commit. Only after the full call ends can the peer commit. Two versus six anchors have equal source-access counts, proving two full traversals rather than N public inspections; this is instrumentation, not a performance claim. Synthetic same-connection root/identity/nonce/policy/snapshot/removal/Forget-like policy changes at all four seams separately prove full-binding publication refusal and rollback without replacement adoption. Actual CLI same-ID reincarnation rejects old capture. |
| AQ-A4 | Exact escaped whole frame of **8192 bytes including LF** succeeds; adding the next ASCII byte fails the whole set. Actual CLI escaped overflow has empty stdout, with a separately explicit radius-zero request succeeding. Recovery uses a later fresh captured plan. DB bytes, source bytes, two-revision human history and suppression marker survive successful/refused inspections. Source Forget invalidates old capture; new forgotten-path plan is invalid; rebuild cannot resurrect the forgotten path. |
| AQ-A5 | Actual process tests reject empty/malformed/extra-frame/unknown/repeated/escaped-duplicate fields, type forgery, bool/fraction/exponent/overflow line numbers, bad path/hash/count/version. Exactly 65536 stdin bytes including LF succeeds on a real store; byte 65537 fails. Invalid flags/radius/null snapshot fail promptly with held-open stdin; the bounded watchdog joins/reaps its exact child. Missing storage is not created; v2 remains byte-identical; closed WAL header rejection leaves DB bytes and directory entries unchanged with no WAL/SHM sidecars. |
| AQ-A6 | Complete offline workspace gate passes, including unchanged old single inspection and Query/Context/Refine/export/human-search tests. No native/API/default algorithm/schema/dependency/lock/site changes. |

The same-connection mutation seams deliberately simulate otherwise fenced binding
changes inside the transaction; they are NOT evidence that a peer can commit
through DELETE locking. Actual peer tests instead verify that commits are blocked.
The dependency-race fixture renames the store directory and then restores it;
initial corrupt-schema fixtures separately exercise missing indexed dependencies.
No cross-device mount fixture or atomic external filesystem lease is claimed;
unchanged descriptor containment remains inherited. Current-at-read is not future
freshness, a privacy lease, reduced I/O or a measured performance improvement.

## Reproduction and verification

```sh
cargo test --offline --locked -p threadmark-core source_inspection
cargo test --offline --locked -p threadmark-cli --test source_inspection_set
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

The actual CLI test
`aq_a2_real_query_to_inspect_set_all_radii_and_count_edges_64_sources_no_writes`
is the executable product reproduction: create synthetic approved source files,
Build, capture project, Query, take 2..8 returned coordinates, write the closed
stdin JSON, and invoke inspect-set with the exact captured full binding/radius.
No hidden metadata reload, provider or original text is involved.

- **PASS:** final offline full workspace `scripts/check.py`: format/build,
  warnings-as-errors all-target Clippy, **439 Rust tests + two doctests**, docs,
  finite CLI/daemon diagnostics and intentional failing assertion gate.
- **PASS:** `cargo deny --offline --locked check`, cached advisories/bans/licenses/
  sources. Offline cache freshness is a limitation; no refresh was attempted.
- **PASS:** secrets after staging new files (tracked-file scan and synthetic-secret
  rejection probe), final staged/unstaged whitespace checks and documentation links.
- Exactly two inherited production 300/30-second deadline fixtures stayed ignored
  and were **not rerun**, not relabeled as fresh evidence.
- Ignored local diagnostic logs: `target/unit-aq-check.log`,
  `target/unit-aq-deny.log`, `target/unit-aq-secrets.log`. No private source or
  original-query content is written to public evidence.
- Development iterations corrected test-only assumptions (eight-result Query cap,
  separate incarnation table, opaque identity shape and marker deletion guard),
  missing test-only dependency access (reused existing Python SQLite fixture
  pattern instead of adding a dependency), and a Clippy octal permission literal.
  Final passing gates supersede those earlier failed attempts.

## Exclusions and primary handoff

No subagents, implementation commit/push/PR, credentials, external egress, spend,
deployment, Docker, GUI/host launch, native AP inspection/duplication, provider,
AM preparation/Refine/retained/export algorithm edits, schema/dependency/lock/site
changes, polling or reminders. Existing synthetic loopback transport fixtures ran
only as part of inherited offline regression tests. All sources are synthetic.
T3 `Plum` read returned `thread_not_found`; no remote coordination or automatic
follow-up is claimed. Native suites, remote CI, independent review and primary
integration are **not run by this implementation unit**. Leave worktree intact.
