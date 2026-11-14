# Unit AO — bound multi-term durable human-note retrieval

## Primary integration and independent review

Owned implementation committed as `9b45b11` and cleanly applied on merged AM as
**`4afd97e31535ad7953d1735978299a03e68340e1`**, exact integrated tested runtime.
No baseline/site merge replay or conflict repair. The ordered nine-path binary
diff fingerprint was reproduced after integration, identical to
**`2796e9c37bfc7d3c94686eb7cdcf0b0db3fb9955df62bd07776a00dacbe43528`**.

Joffrey independently reviewed **CLEAR**, verified baseline/inventory/fingerprint,
checked old literal semantics against surrounding code and inherited tests (not
only the new golden fixture), and reran full offline checks (**419 tests/doctests**),
focused core/CLI regressions, offline locked deny, staged secrets and whitespace.
No native, remote CI or atomic post-publication revocation certification claimed.

Primary reran full offline workspace check, offline locked deny, secrets and
whitespace **PASS** at the exact integrated runtime. Full strict serial native
Debug and Release each **296 tests/47 suites PASS** against the new CLI, with all
fixture variables enabled; this exercises unchanged existing literal human-search
and related native flows, not a new native ranked-note implementation. Two inherited
long-deadline tests remain ignored. Publication-head CI is separate and pending.

AM #88 exact post-merge runs `43601436812` and `43601436873` both completed
**PASS** at `01546a08d8291688e1ecb41510833d20a70ab83f`. AL #87 integrated run
`43601072415` passed at `179db1f43ead127cbbc0a767b6eede92ad19064e`, but CI
`43601072392` concluded **canceled**, not success; no retry or earlier-head
substitution was performed. Nine inherited progress edits, local earlier-unit
receipts and all worktrees preserved. AN native file-scoped Context remains
independent; GUI/AX, live quality, host delivery and phase closure remain open.

## Scope and baseline

TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A5/A6 and P3-A4.
Implementation sub-agent work only; no subagents, native integration, phase
closure, implementation commit, push, PR, network access or deployment.

Initial clean task HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
Required local base: `8873b267b099efcc5545508a54ff8d46ee0be874`.
The authorized normal `git merge --no-edit` produced baseline merge
`ca2a5b9afc155a6b4bc53d9a756f15b7bf4669d7`, with those exact two parents.
Prepared/site history was retained; no reset, branch switch or new worktree.
All AO implementation/evidence remains uncommitted above that baseline. A SHA
alone therefore does not identify the tested work: use the owned diff fingerprint
recorded below as well. Primary integrates only the owned inventory, not baseline
history/site/native changes.

## Contract frozen before implementation

[human-search-ranked-v1](../contracts/human-search-ranked-v1.md) froze the distinct
version, closed grammar, mandatory complete human-read binding, normalized query
plan, selection/coverage/omission semantics and AO-01–AO-07 before runtime edits.
Read Phase 2/3 specifications and human-search, read binding, kind filtering,
Forget, revision and batch contracts first. This is an explicit usability gain:
separated terms can find notes without a contiguous query phrase, and distinct
terms outrank repetition of one term. No semantic or relevance-quality claim.

Core exports immutable `HumanRankedQuery::new(query, kinds)` and
`Store::search_context_terms_bound(project, plan, binding, cancel)`.
The constructor retains only normalized first-seen distinct terms and canonical
explicit selected kinds, never the original query. Daemon's typed
`SearchContextTermsBound` accepts that plan and prevalidates project/full binding
before existing-only store opening. CLI is exactly:

```text
context search-terms PROJECT QUERY --kinds KIND... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

No unbound variant/default, ID reload, source policy authority, stdin, provider,
cache, SQL interpolation or diagnostics logging. Existing store v3/v4 only;
valid missing store does not create and legacy v2 does not upgrade.

Implementation uses an explicit mode at the existing validated human-search
traversal boundary, not a broad shared-read framework. Existing literal wrappers
and their private callback signatures remain intact. The only source-ranked
change is widening the existing term helper's visibility to its parent module;
the source algorithm is unchanged. Old literal matches always have one matched
term, preserving their score/ID ordering and exact old JSON envelope. A golden
envelope assertion and inherited regressions protect old bytes. Single-term
all-kind candidate ordering/entries agree when budgets fit; the new response's
larger explicit metadata/scores necessarily count toward its own byte budget.

Ranked reads additionally reject any persisted per-note history above 32 rows;
all project revisions (including suppressed stale rows) count toward 4096. As
before, suppression precedes validation of latest row content; nonsuppressed
latest rows are validated even if retired or unselected. Each term's occurrences
are nonoverlapping, while distinct-term overlaps count independently. Selection
counts every eligible match, then omits whole overbudget entries and permits
later fitting entries. Header/LF bytes count; oversized headers fail entirely.

## Acceptance evidence (synthetic fixtures only)

- **AO-01:** typed empty/control/Unicode/64-byte/256-byte/8-term limits,
  first-seen deduplication; distinct terms outrank repetition; ID ties; independent
  overlap counts; Unicode lowercase without composed/decomposed normalization;
  quoted source-instruction text remains human-not-truth. Literal golden wire
  and all-kind single-term entry equivalence. Actual CLI ranking and closed fields.
- **AO-02:** latest only; kind replacement, retirement, Forget/rebuild/reopen and
  no same-ID resurrection. More than eight strong unselected notes do not consume
  selected ranking/counts/top-eight budget. Corrupt unselected/retired latest rows
  fail entirely; forgotten stale corruption suppresses; another project's corrupt
  row is not scanned. 4096 admitted / 4097 rejected revisions and 32 admitted /
  excessive per-note history rejected; text/revision/kind/boolean corruption.
- **AO-03:** actual core and CLI exact 8192-byte frame including LF, next byte
  causes whole-entry omission; escaped oversized text omitted without partial
  text, later fitting entries selected, honest counts and deterministic replay.
  Header rejection is defensive: admitted bound header limits are much smaller
  than 8192; no artificial oversized valid header fixture is claimed.
- **AO-04:** actual peer SQLite WAL edits give snapshot A, not mixed B. Same-root
  fresh nonce replacement at first/last boundaries rejects publication; actual
  different-root replacement before read rejects too. Exact Unicode binding bytes
  and unavailable human tables prove mismatch precedes human SQL. First/last
  cancellation, missing SQL dependency and private-file permission revocation
  publish no value; rollback preserves readable human history and allows retry.
- **AO-05:** actual closed CLI/daemon route; malformed/repeated/reordered/unknown/
  missing flags, empty/duplicate/unknown kinds, controls and term/shape limits.
  Held-open stdin with a bounded 3-second test deadline proves no EOF wait, even
  on a valid request to absent storage. Existing-only v3/v4 success, v2 failure
  without migration; invalid typed daemon binding/project cannot create storage.
- **AO-06:** unindexed/stale sources do not invalidate human retrieval. Source
  access instrumentation remains zero, even with absent root and deliberately
  unsafe absolute source policy. Logical export stays identical across search;
  actual closed CLI success and failed binding preserve SQLite main-file bytes.
  History and Forget markers/source fixture bytes remain intact. Byte identity
  evidence applies to these quiet non-WAL fixtures, not a forensic guarantee:
  SQLite may manage WAL/SHM sidecars/checkpoints, and concurrent writers may
  legitimately change physical bytes. No VACUUM, retention cleanup or erasure.
- **AO-07:** local verification and fingerprint recorded below. Independent
  review, integrated exact-head CI and native functional acceptance are separate
  not-run gates, not implied by local Rust tests.

## Owned inventory

- `crates/core/src/knowledge/human_ranked_search.rs`
- `crates/core/src/knowledge/human_ranked_search/tests.rs`
- `crates/core/src/knowledge/human_search.rs` (explicit traversal mode only)
- `crates/core/src/knowledge/ranked_query.rs` (helper visibility only)
- `crates/core/src/knowledge.rs` (module/export only)
- `crates/daemon/src/knowledge.rs` (typed command, admission, dispatch)
- `crates/cli/src/main.rs` (closed grammar/help only)
- `crates/cli/tests/human_ranked_search.rs`
- `docs/contracts/human-search-ranked-v1.md`
- `docs/progress/unit-ao-ranked-human-note-retrieval.md`

## Verification record

Tested HEAD/baseline: `ca2a5b9afc155a6b4bc53d9a756f15b7bf4669d7` plus the
uncommitted owned implementation and contract diff. SHA-256 of `git diff --binary
HEAD --` followed by the nine owned files above **excluding this progress file**:
`2796e9c37bfc7d3c94686eb7cdcf0b0db3fb9955df62bd07776a00dacbe43528`.
The progress file is excluded to avoid a self-referential checksum; it contains
no runtime changes. All ten owned files are staged, uncommitted; no unrelated
staged/unstaged changes were present at final verification.

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**. Formatting,
  locked workspace build, warnings-denied all-target Clippy, workspace tests,
  warnings-denied Rust documentation, CLI/daemon diagnostics, local documentation
  links and intentional-failure probe all passed. **419 tests/doctests passed**,
  zero failed, two existing ignored tests. This includes 10 AO core tests and
  4 AO CLI tests (through daemon/SQLite), plus old search/source regressions.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources.
- `python3 scripts/secrets.py`: **PASS** after staging all new owned files;
  synthetic negative probe correctly rejected.
- `git diff --check` and `git diff --cached --check`: **PASS**.
- Independent review / remote CI / native integration / phase closure: **NOT RUN**.

An initial full-gate tool invocation was accidentally bounded at one second and
timed out after the build; it is not passing evidence. The full bounded script
was restarted without that outer timeout. Its first complete run caught an AO
test's source-access counter including the separate export preservation probe's
legitimate source checks. Reset the counter immediately before the human read;
the complete rerun passed. Each script subprocess retains its existing deadline.
No inherited fixture deadlines were changed.

Reproduce: `CARGO_NET_OFFLINE=true python3 scripts/check.py`,
`cargo deny --offline --locked check`, `python3 scripts/secrets.py` after staging
the new owned files, and staged/unstaged `git diff --check`.

No schema/migration/dependency/lockfile edits; no Swift/UI/model/CI/AM preparation,
Refine/export/retained algorithm changes. No Docker or host/GUI launch. No remote
CI run/head or PR exists for this uncommitted work. Human read snapshots are
current-at-read registration checks, not atomic revocation leases: edits/Forget
after the snapshot cannot recall already captured data, and replacement after
the final check cannot recall returned/stdout data. Primary review and exact
integrated revision verification remain required. No phase is closed.
