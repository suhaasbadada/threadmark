# Unit Z — bounded source-anchor inspection

## Primary repair after independent review

Initial Joffrey review was **not clear**: the actual daemon's normal store opener
converted WAL to DELETE before the core check, and the shared 80-argument ceiling
rejected valid 61–64-file captured policies. Primary repaired both in this completed
lane without changing normal opening semantics or other command argument caps.

Inspection now uses existing-only `Store::open_existing_for_inspection`, rejecting
non-rollback SQLite header versions before SQLite opens the file, then opening a
read-only connection and checking DELETE mode without normalization. It omits
write-oriented PRAGMAs, retains private/schema/header/identity checks and the core
transaction guard. The inspection-only CLI cap is 84 total arguments; existing
per-command 64-source validation is unchanged. New actual-CLI tests prove WAL
failure has empty stdout, unchanged database bytes/mode and directory entries;
61/64-source query-to-inspection succeeds while 65 rejects. A core opener test
also proves SQL writes fail and missing stores/closed WAL sidecars are not created.

Primary targeted **11 core + six actual-CLI tests PASS**. Full workspace pipeline,
offline locked deny, staged-new-file secrets and whitespace **PASS**; full total
**282 Rust tests + two doctests**. Log: ignored `target/unit-z-repair-check.log`.
Original fingerprint below is pre-repair evidence, not this changed source.
Joffrey independently rechecked the repairs **CLEAR**, passed 11 targeted core,
six actual-CLI tests and a core/daemon/CLI regression run (248 tests + one doctest),
plus staged/unstaged whitespace. He did not rerun lint/deny/secrets or CI; unchanged
long-deadline fixtures remained ignored. Exact integrated-head CI remains outstanding.

Requirements: **TM-01–TM-04, TM-07, TM-10**, partial **P2-A1/A3/A4/A6**.
Contract and stable **Z-A1–Z-A5** IDs were written before implementation in
[source-anchor-inspection-v1](../contracts/source-anchor-inspection-v1.md).
No phase closure or independent review is claimed.

## Baseline and integration ownership

- Assigned branch initially `t3/c168ca7e`; initial clean HEAD:
  `661bdb3e11118efe979cc7adf06c39db723bf133`.
- At handoff the branch is `t3/source-anchor-line-inspection`; Git reflog records
  a branch rename at the same merge SHA. This implementation agent did not rename
  or switch branches; no worktree or checkout was created.
- Required local base: `36c77901da58e57f361baadd45a87ed599722bc4`.
- Per explicit authorization, normal `git merge --no-edit` produced the sole
  new commit, **baseline merge `5abd28207cf834c6b47041316861b8d976fd381b`**,
  with those two parents in that order. Prepared baseline/site history is intact.
- All implementation remains **uncommitted** on that full baseline SHA. There
  is no implementation commit SHA. Primary must integrate only the owned diff
  relative to that merge, not replay the baseline merge/site history.
- Exact tested implementation fingerprint (SHA-256) is
  `4362d04aa252f68e979ee3b59f9af25bc8fb29a1d2a59b98b3a974aa38141efd`.
  Compute by sorting the seven implementation/contract paths below, then hashing
  each UTF-8 relative path + NUL + its raw file bytes + NUL into one SHA-256.
  This progress file is excluded to avoid a self-referential fingerprint.

Owned diff inventory (seven fingerprinted files plus this progress document):

| Path | Owned change |
| --- | --- |
| `crates/core/src/knowledge.rs` | Additive module/public selector and validator exports |
| `crates/core/src/knowledge/source_inspection.rs` | New complete-binding indexed-anchor inspection pipeline |
| `crates/core/src/knowledge/source_inspection/tests.rs` | Ten deterministic actual core/SQLite tests |
| `crates/daemon/src/knowledge.rs` | Typed command, pure pre-open validation, existing-only store, dispatch |
| `crates/cli/src/main.rs` | Closed inspection grammar and usage; canonical decimal coordinates |
| `crates/cli/tests/source_inspection.rs` | Four actual CLI/daemon/core and typed preflight tests |
| `docs/contracts/source-anchor-inspection-v1.md` | Versioned request/output and Z acceptance contract |
| `docs/progress/unit-z-source-anchor-inspection.md` | Integration/test evidence and limitations |

New files are staged only for secret-scanner visibility; modified pre-existing
files remain unstaged. Nothing is committed/pushed/published. `git diff HEAD`
includes both parts of the owned patch. No user changes were overwritten.

## Product behavior and boundaries

No equivalent inspection product route existed in the baseline: source retrieval
returned individual indexed lines; export was a different all-evidence/history
archive. This unit adds an explicit next step after Query or QueryTerms, not an
unused helper or unbound file reader.

The CLI passes the full captured `Project` and requested path/line/hash/radius
through the daemon into core. Pure shape validation precedes existing-store open.
Core validates the complete current captured registration/policy/snapshot and
selected indexed row, producer and hash against its stored manifest **before the
first source authorization/traversal**. No expected path grants read authority.
The exact captured current project is retained through all reads and revalidation;
there is no precheck followed by an unbound ID reload. Null/legacy incarnation or
absent snapshot cannot authorize inspection, and no automatic upgrade/index occurs.

One coherent read transaction checks DELETE journal mode and fences peer writes;
WAL is rejected rather than pretending an old SQL snapshot is fresh. Existing
bounded source helpers enforce descriptor-based no-follow traversal, approved
ordered file scope, root/file identities, devices, hardlink/FIFO/nested-repository
restrictions and full-manifest hashes. The center must resolve to the exact
indexed current line. Before returning, core rechecks cancellation, store health,
the entire current manifest, and the full captured project binding. Errors publish
no content; no source/evidence/human-history writes occur in inspection.

Version-one response is distinct from unchanged Query/Export JSON. Radius 0..3
returns at most seven complete numbered lines, naturally clipped only at file
boundaries. The center is `indexed-anchor`; neighbors (including blank lines) are
`observed-source-text`, not extra indexed facts. Producer describes center
extraction only. Relative path/hash/snapshot/root identity/incarnation and
current-at-read provenance remain attached. The whole escaped JSON plus CLI
newline must fit 8192 bytes or the operation fails, without prefix/line truncation.

## Acceptance evidence

| ID | Synthetic verification |
| --- | --- |
| Z-A1 | Every complete-binding field, ordered policy, same-ID/new-nonce at same/different roots, absent/wrong snapshots, malformed bounds, Unicode UTF-8 byte overflow and composed/decomposed root byte mismatch refuse before the private first-source callback. The existing source-directory access counter additionally proves no source I/O for the field/hash cases. Caller hash mismatch and even forged evidence hash versus manifest reject before reads. |
| Z-A2 | Actual core query and actual CLI Query→inspect return surrounding code, exact center, blank neighbor, original coordinates, escaped Unicode/quotes/backslash, producer/hash/snapshot. Radius zero and file edges remain full windows. Sparse custom extraction proves approved-but-unindexed nonblank lines cannot be promoted to center anchors. Missing/blank/wrong coordinate and forged persisted text reject. |
| Z-A3 | Edits, deletion, rename, symlink, hardlink, FIFO, nested repository and root replacement refuse all content. Source change at publication, cancellation before work/first source/final publication, missing store dependency at publication, forged rows and escaped whole-output overflow reject. Restoration recovers without reindexing where identities still match. Byte-equal SQLite/source preservation and retained human note are asserted. |
| Z-A4 | A separately opened peer cannot commit removal/policy replacement at final publication under the DELETE read lock; replacement immediately after release invalidates old capture. WAL rejects before source traversal. Source Forget followed by omitted-path rebuild cannot inspect or restore the anchor; human note and source bytes survive. Actual CLI repeats same-ID/root/content/policy replacement and Forget/rebuild cases. |
| Z-A5 | Actual process grammar tests cover partial/missing/reordered/duplicate/unknown flags, noncanonical/out-of-range numbers, bad hashes/nonces/snapshots, missing path authorization, duplicate/overcapacity policy and Unicode byte bounds. Missing storage is never created. Typed daemon malformed selector fails before store open. Held stdin does not block either valid inspection or missing-binding rejection; exact owned child is bounded/reaped. |

Filesystem-device containment is inherited from the unchanged shared source
helper, not a newly mounted cross-device fixture. No native editor is involved;
unsaved native drafts are outside scope. Durable human notes are covered explicitly.

## Reproduction and verification

From the assigned checkout, using only synthetic temporary sources:

```sh
cargo test --offline --locked -p threadmark-core source_inspection
cargo test --offline --locked -p threadmark-cli --test source_inspection
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --locked --offline check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

The CLI integration test `z_a2_real_query_to_inspection_includes_surrounding_code_and_preserves_notes`
is the executable product reproduction: create a synthetic approved source, index,
capture `project show`, query `center`, and supply the result's path/line/hash and
the captured root/root identity/incarnation/snapshot/ordered policy using the exact
CLI syntax in the contract. No hidden current-ID adoption or stdin input is needed.

Final runtime gates on the baseline SHA plus fingerprint above:

- **PASS:** full `check.py` with offline Cargo: formatting, build, warnings-as-errors
  Clippy, **279 Rust tests + two doctests**, docs/warnings/local link checks, CLI and
  daemon finite smoke operations, and intentional failing-test gate. Final local
  diagnostic log is ignored `target/unit-z-check.log`, not a public artifact.
- **PASS:** `cargo deny --locked --offline check` (advisories/bans/licenses/sources).
  Advisory freshness is limited to the existing local offline cache.
- **PASS:** `python3 scripts/secrets.py` after staging new files: tracked-file scan
  passed and the synthetic secret was correctly rejected. Both `git diff --check`
  and `git diff --cached --check` passed; final progress-document links also passed.
- The unchanged production **300-second/30-second deadline fixtures stayed
  ignored**; not rerun or relabeled as new evidence. Prior W evidence remains prior.
- One initial compile iteration used an unavailable platform `mknodat`; the FIFO
  fixture now uses the existing test pattern's `mkfifo` subprocess. Initial Clippy
  found a test-only inclusive-bound spelling; corrected and full gates rerun.

## Limitations and primary gates

No independent delegate review, remote CI run/head, PR, implementation commit or
publication exists for this uncommitted unit. Primary owns contract/implementation
review, integration, a full tested integration SHA, and exact-head CI evidence.
Current-at-read is not a future filesystem lease: later edits can invalidate
already delivered text. Existing explicit private-store opening/recovery semantics
are unchanged; this unit adds no SQL/file writes to the inspection read pipeline.

No native GUI/UI, host launch/delivery, model/provider/retained/consent/marker API,
schema/dependency/lock changes, site changes, listeners, network egress, Git
subprocesses in the product path, credentials, Docker, spending, deployment,
subdelegation or reminders. Normal full workspace tests include pre-existing
synthetic loopback transport fixtures, not external providers. No real user store
or source was registered or read. T3's `Plum` thread read returned `thread_not_found`;
no coordination message or automatic follow-up is claimed.
