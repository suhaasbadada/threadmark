# Unit AA — explicit bounded human revision comparison

## Primary integration and independent review

Primary committed only the eight owned files as `ba31e5b`, applied as
**`96e31699acaeeeebb6a3333fbd87e69391edfb11`**, the exact combined tested runtime.
One module/export insertion conflict was resolved by retaining both Z's source
inspection module and AA's comparison validator; no baseline/site history replay.
CLI comparison parser/dispatch and Z's inspection-only read-only opener/cap remain
separate and unchanged. No implicit authentication or source authority introduced.

Joffrey independently reproduced the fingerprint and reviewed **CLEAR**, passed
seven AA core tests, five actual CLI/daemon tests, all 138 lane core tests plus
doctest and whitespace. He did not rerun full pipeline/lint/deny/secrets. Primary
combined full workspace gate **PASS**, 294 Rust tests + two doctests; strict
serial actual-CLI/retained/export-C-fixture Swift **PASS**, 214 tests/30 suites.
API gate, offline locked deny, staged secrets and whitespace **PASS**. Normal
long-deadline fixtures stayed ignored. Exact publication-head CI remains later.

PR #75 passed all five checks at `b2f86f4fbf91002eac769488057078956bf7fd6a`
(CI `43582611536`, integrated `43582611570`); fresh exact-head/main/check/review/
approval/discussion/rules gates preceded merge
`b590caabba494ae33ba95736ce42d5b7c0261e81`. Watch removed after merge; separate
exact post-merge CI remains unverified. Native source inspection remains active
in its existing lane. Nine inherited progress edits/worktrees/parent reminders
preserved; GUI/AX, live-model quality, host delivery and phase closure remain open.

## Scope and baseline

Implements TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A5/A6 and P3-A4.
Contract: [human-context-comparison-v1](../contracts/human-context-comparison-v1.md).
The contract and stable AA-01..AA-06 acceptance IDs were written before code.
No equivalent explicit backend comparison existed in the inspected baseline.

Prepared initial head: `661bdb3e11118efe979cc7adf06c39db723bf133` (clean).
Required base: `074590fb8285b1ae28e74da62c504163d5d2d70c`.
Authorized normal `git merge --no-edit` produced tested baseline HEAD
`c2d0141c0459a55f53e4a2617821ec5c9e474a2d`, parents initial head and required
base in that order. Prepared/site history was preserved. No reset, branch switch,
new worktree, implementation commit, push or PR. Changes below remain uncommitted.
HEAD alone therefore does **not** identify the implementation; use the owned-file
fingerprint recorded below for integration/review. No CI run/head or independent
review exists for this uncommitted unit; primary must integrate and run exact-head
CI/review. No phase closure or runtime listener claim.

## Owned diff inventory

- `docs/contracts/human-context-comparison-v1.md` — new versioned contract.
- `crates/core/src/knowledge/context_comparison.rs` — new bound-only public core
  API and pre-storage validation; complete history selected once inside reviewed
  `read_human_bound`; compact exact logical-line delta and whole-JSON byte guard.
- `crates/core/src/knowledge/context_comparison/tests.rs` — synthetic core tests.
- `crates/core/src/knowledge.rs` — module/export and strict history retirement
  integer validation (0/1 only). Valid existing history JSON is unchanged; malformed
  retirement integers previously coerced to boolean now fail closed.
- `crates/daemon/src/knowledge.rs` — only new `CompareContextBound` variant,
  pre-open validation, existing-store selection and dispatch arm.
- `crates/cli/src/main.rs` — only new comparison parser arm and help text;
  reuses the unchanged closed human binding grammar. No stdin/content input.
- `crates/cli/tests/context_comparison.rs` — actual CLI/daemon integration tests.
- This progress file — evidence and handoff, not runtime implementation.

Primary should take only these owned edits relative to the tested merged baseline,
not the baseline merge diff or prepared site history. No Z source inspection,
source-read module/arm/helper, nativeModel/Swift/UI, profiles/refine/retained,
export/marker semantics, schema/dependency/lockfile or site edits.

## Design and guarantees

`context compare PROJECT NOTE FROM TO` requires all three exact registration flags
in order. Both revisions are explicit, 1..32, from <= to, including equality.
Validation repeats in CLI, daemon before opening, and public core before reading.
Schema 3/4 existing-store only. No unbound convenience endpoint or cached fallback.
Both selections use one fully validated same-note history inside the admitted
transaction; no preflight/unbound read, reload gap or nested transaction. The
reviewed helper checks exact UTF-8 binding before human SQL and registration again
in a fresh view before publication. Errors are existing content-free errors.

Delta consists of common prefix, old middle, new middle and common suffix; LF is
retained in each logical-line segment. Exact concatenation reconstructs both
texts, including Unicode bytes, CRLF and final newline. No full-text duplication,
normalization, truncation or minimal/semantic-diff claim. Exact flags compare text,
kind and retirement independently. JSON plus newline is at most 65536 bytes.
Valid 4096-byte texts cannot exhaust this budget even at maximal JSON escaping;
the actual whole-value guard also has synthetic exact-boundary/overflow tests.
Values publish only to explicit CLI stdout, not files, providers or host flows.

## Acceptance evidence

- **AA-01/02:** Core all-pairs reconstruction/determinism over synthetic revisions
  covers identical text, kind-only, retirement/reactivation, canonical Unicode
  byte differences, CRLF/multiline/final LF, blank logical lines, escaping and
  emoji. Actual CLI add/update/retire/compare/stale-CAS rejection/fresh reactivation
  and compare equals actual typed-daemon output. Same-revision empty middles,
  ignored supplied stdin and held-open empty stdin are tested.
- **AA-03:** Actual two-connection WAL fixture performs append, Forget, same-root
  same-ID/new-nonce replacement, changed-root replacement and cancellation at the
  real post-history boundary. Old revisions stay coherent; replacements reject
  publication; replacement private text never returns. Dropped human tables with
  exact Unicode binding mismatch prove rejection before human SQL.
- **AA-04:** Rebuild/reopen and source Forget retain comparison/history. Missing
  source root, changed source policy/snapshot and malformed unrelated project do
  not affect it; source access counter stays zero. Context Forget prevents reads
  and recreation; source bytes remain exact.
- **AA-05:** Invalid/missing/reversed/out-of-range revisions; full-history gap,
  invalid kind/text/NUL/retirement/oversize/33rd revision; missing context/Forget
  tables; early and mid-read cancellation; invalid DB and dependency failures
  fail without content publication. Main DB bytes are checked unchanged on
  failure fixtures. History validation includes unselected revisions.
- **AA-06:** Actual CLI malformed/duplicate/missing/reordered/extra flags and
  malformed revision lexemes fail with status 2 before held-open stdin, both for
  absent storage and an invalid DB. Valid absent-store calls fail without creation.
  Actual daemon repeats shape validation before opening; cancellation and missing
  revision fail. Actual schema 3 reads succeed; schema 2 rejects without migration,
  preserving main DB bytes and trusted unbound history output.

## Commands and verification

All checks below ran on the working implementation atop full baseline SHA
`c2d0141c0459a55f53e4a2617821ec5c9e474a2d`:

- `cargo fmt --all` — applied formatting only to owned edits.
- `cargo test --offline --locked -p threadmark-core context_comparison` — initial
  focused 6 tests passed; final full suite includes 7 AA core tests, all passed.
- `cargo test --offline --locked -p threadmark-cli --test context_comparison` —
  all 5 actual CLI/daemon tests passed, also passed in final full suite.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py` — final full run passed:
  format, locked workspace build, Clippy all-targets with warnings denied,
  workspace tests (including 138 core tests), doctests, warning-denied rustdoc,
  actual CLI/daemon version/status/smoke diagnostics, local doc links and the
  intentionally failing test-gate probe. Two existing production deadline tests
  stayed ignored as requested. No remote documentation fetch.
- `cargo deny --offline --locked check` — advisories, bans, licenses and sources
  all passed against local cached data; no network fetch and no lockfile edit.
- `git add` on only the five new owned files, then `python3 scripts/secrets.py` —
  tracked working-tree/history scan passed; synthetic sentinel correctly rejected.
  Existing modified source files were already tracked. All implementation remains
  uncommitted; staging is only for the required scan.
- `git diff --check HEAD` — passed for staged and unstaged owned changes.

Initial fixture failures were repaired (unique project root constraint, opening
WAL peer before enabling WAL, escaped JSON test boundary, mutable extractor).
The first full check caught Clippy's `int_plus_one` on a test assertion; it was
rewritten without changing the inclusive newline budget, and the complete second
run passed. No failed gate was waived.

### Owned-file fingerprint

SHA-256 of each final file (progress evidence excluded to avoid self-reference):

```text
1658f4bed31be88e67bc1300740d58d9e6a2d3bf07001ea368045ca95aebbb04  crates/cli/src/main.rs
3a9288ec20b331acded66416c90d58f066d440ceab6642fb94b72fff6be51f97  crates/cli/tests/context_comparison.rs
6921804a9b3cea1b64a6b19309dc10a9594bf756205b0accd35227eddf988be4  crates/core/src/knowledge.rs
5501d83b6f1eed4261f39986af7d4f111889e0ab260d680b66607a275fa4438b  crates/core/src/knowledge/context_comparison.rs
08085d3def053130119c8bf21e58d406fb3e5d7d95ece3ffa6968713cb2e6597  crates/core/src/knowledge/context_comparison/tests.rs
5485620e71986e9ea29a6a8bda20c730e91b06af6f432e85c6074b9989edc8ce  crates/daemon/src/knowledge.rs
3169cd6d088761b0123d5eb91229af80c448c09bd16b28b7e63033cdd84f9bdb  docs/contracts/human-context-comparison-v1.md
```

Aggregate: `7bca4cd374ad98f14b0cf26245f59e3762d25a7812d82da159d331941854afd0`.
Reproduce with Python standard-library `hashlib.sha256`: sort the seven relative
paths above; for each update with UTF-8 path, NUL byte, exact file bytes, NUL byte.
This identifies whole owned files on this baseline, not an implementation commit.
Only this progress document was updated after the final full runtime check;
final local docs/secrets/whitespace gates cover that evidence update.

## Limits and remaining gates

No authentication, authorization lease, external revocation guarantee, semantic
conflict detection/resolution, automatic edit retry, listener, native/UI support,
provider/Git/host call or implicit egress. Peer edits/Forget after a captured read
snapshot do not retroactively revoke it; registration replacement visible at the
fresh publication check rejects it. No durability/forensic-erasure overclaim.
No subagents, credentials, spending, deployment, GUI/host launch or Docker used.
The unchanged ignored 300-second process and 30-second provider deadline fixtures
are intentionally not rerun. Remote CI, independent primary review and exact-head
integration are not performed here.
