# Unit AK — explicit file-scoped lexical retrieval

Requirements **TM-01–TM-04, TM-07, TM-10**, partial **P2-A1/A2/A3/A4/A5/A6**.
Contract: `docs/contracts/file-scoped-retrieval-v1.md`, stable **AK-A1–AK-A6**
defined before implementation. No phase closure or product-wide filtered consent.

## Baseline and ownership

- Prepared starting HEAD: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Required local base: `e00dd28d987f78c3bca6b37916c4a61679c78d54`.
- Only authorized commit is normal `git merge --no-edit` of that base:
  **`c7f37b692a793b91c9735c968b18ed6f2b7f1f88`**, preserving both parents and
  prepared baseline/site history. No reset, branch switch or second worktree.
- Implementation remains **uncommitted** on this full merge baseline. Primary
  takes only the owned diff, not merged baseline/site/native history.
- No implementation commit, push, PR or remote CI run/head exists. Independent
  review, integration, exact published SHA and exact-head CI belong to primary.

Owned inventory (all other baseline files remain untouched):

1. `crates/core/src/knowledge/file_query.rs` — opt-in typed mode/owned selector,
   pure pre-open validation, canonical captured-policy ordering, bound-only API.
2. `crates/core/src/knowledge/file_query/tests.rs` — core AK acceptance.
3. `crates/core/src/knowledge.rs` — module/re-exports only.
4. `crates/core/src/knowledge/ranked_query.rs` — minimal shared pipeline selector,
   versioned response header before budget, literal SQLite matcher after filter.
5. `crates/daemon/src/knowledge.rs` — typed variant/preflight/existing-only dispatch.
6. `crates/cli/src/main.rs` — closed grammar/help, command-specific two-list cap.
7. `crates/cli/tests/file_query.rs` — actual CLI and typed-daemon acceptance.
8. `docs/contracts/file-scoped-retrieval-v1.md` — additive versioned contract.
9. This evidence/handoff document.

## Implementation and boundary

No equivalent file-filtered query existed in the merged baseline: literal and
ranked query accepted only complete registration/policy binding. Source inspection
selects a known anchor/window, not a retrieval candidate set. Reviewed Phase 2,
existing literal/ranked algorithms, complete Project binding, full-source helpers,
source inspection and source Forget contracts before implementation.

`query-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ...`
requires the full existing captured-project suffix. All shape checks precede
storage opening and no stdin is consumed. Missing storage is never created.
Core copies the selected paths, canonicalizes in captured full-policy order,
compares complete current Project before first source authority and uses the same
full authorized Project for both bounded source reads. No reduced-scope Project,
new permission, ID preflight/unbound reload or legacy nonce synthesis.

Selection is OUTPUT CANDIDATES ONLY. The shared ranked pipeline retains full
manifest/source freshness over ALL approved files, including unselected files.
Filtering occurs before matching, scores, match counts, top-eight and byte budget.
Literal uses a prepared parameter-bound SQLite `instr(lower(?1),lower(?2))` scalar
only after selected-row verification; no Rust Unicode-fold substitution. Ranked
retains its exact Unicode lowercase/nonoverlap/distinct-term algorithm and original
parameter-bound source-row SQL. No duplicate source walker or retrieval engine.

New format/version/scope/mode headers are included before whole-entry budget
selection. Literal result keys match existing literal anchors; ranked keeps its
score fields. Whole encoded JSON plus CLI newline <=8192; oversized explicit scope
header fails whole. No source text splitting, hidden scope shortening, or SQL value
interpolation. Existing Query/QueryTerms formats and truncation are unchanged.

Publication retains existing ranked-query fresh complete Project checks around a
second full-manifest source read, cancellation and dependency checks. WAL peer
commits are not concealed by inventing a long-lived read snapshot/lease. This is
current-at-read, **not** an atomic filesystem lock or immunity to a change after the
last check. No I/O avoidance, privacy lease or performance improvement is claimed.

## Actual local acceptance evidence

All fixtures synthetic. Core AK acceptance: **12 passed**. Actual CLI/direct daemon:
**7 passed**. These run the production core/CLI, not a duplicate fake engine.

| IDs | Actual evidence |
| --- | --- |
| AK-A1 | Full root/identity/nonce/ordered-policy/snapshot mismatch before private first-source callback; dropped evidence dependency still cannot reach callback; canonical selection ordering, zero/duplicate/unknown/traversal/forbidden/over64 subsets; exact UTF-8 root normalization mismatch; query byte and term-byte bounds. V4 store-integrity validation may reject a dropped SQL table before reporting a binding mismatch, without source authority. |
| AK-A2 | Twelve early unselected matching long escaped anchors, higher ranked distinct-term/occurrence score, selected later `z.rs` anchors still both returned; no unselected text. Full-set result equivalence with existing operations, deterministic ties/order, Unicode uppercase vs SQLite ASCII folding, composed/decomposed Unicode text, escaped text, absent matches. Literal newline is not ranked whitespace normalization. |
| AK-A3 | Unselected changed/deleted/symlink/hardlink/FIFO source makes entire snapshot stale/empty; final callback cancels, changes unselected source, revokes policy, replaces same-root registration, changes indexed snapshot or drops dependency; no partial/B output. Real WAL peer policy/index commit yields mismatch, not old-snapshot publication. Unindexed/blank sources, precancellation and recovery/rebuild paths exercised. |
| AK-A4 | Both modes admit eight complete entries, truthful match/truncation counts, long escaped UTF-8 lines force whole-entry omission; actual stdout includes newline <=8192. Explicit 64-long-path scope header overflow fails whole. Existing literal/ranked result comparisons and full old regression suite retain their formats/Context/Refine behavior. |
| AK-A5 | Source Forget invalidates old capture, new capture rejects forgotten selected path, subsequent index/select cannot resurrect forgotten path; source bytes and independent human note/history preserved. |
| AK-A6 | Actual closed parser rejects missing/partial/unknown/mode/empty/duplicate/traversal/over64 flags/subsets with held stdin, no missing-store creation. Both 64-selected and 64-full-policy lists accepted (145 total argv cap). Typed daemon independently rejects invalid requests pre-open; valid absent-store request fails existing-only. Real legacy v2 store rejects without byte changes or implicit migration. |

## Reproduction and checks

```sh
cargo test --offline --locked -p threadmark-core file_query
cargo test --offline --locked -p threadmark-cli --test file_query
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --locked --offline check
# Stage only owned new files before running the tracked-file secrets scanner.
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

Final full gate **PASS** on the payload fingerprint below: formatting, locked
workspace build, all-targets clippy with warnings denied, **387 Rust tests plus
two doctests**, rustdoc with warnings denied, finite diagnostics, documentation
links and the intentional failing-test rejection probe. This includes all 12 core
AK tests and all seven actual CLI/direct-daemon AK tests. The earlier full gate
preceded final matcher/WAL/daemon additions and is superseded by this final run.
`cargo deny --locked --offline check`: **PASS** (advisories, bans, licenses,
sources; advisory freshness is local-cache only). Staged-new-file
`python3 scripts/secrets.py`: **PASS**, including rejection sentinel.
Both unstaged and staged whitespace checks: **PASS**.
The inherited 300/30-second deadline fixtures remain ignored and were not rerun;
the inherited stdin helper fix is untouched.

### Tested working-tree identity

Full baseline/tested HEAD remains
**`c7f37b692a793b91c9735c968b18ed6f2b7f1f88`** plus the uncommitted owned payload.
There is deliberately no implementation-commit SHA to invent. Payload SHA-256:
**`21d8a1732e6c8618c9f9855c149982502f6ead06a84acb87842b98a37a71ecfc`**.
This hashes the eight inventory files other than this self-referential progress
document, in lexical relative-path order, concatenating for each file UTF-8 path,
NUL, exact file bytes, NUL. Reproduce without staging or committing:

```sh
python3 - <<'PY'
import hashlib
from pathlib import Path
paths = sorted([
    'crates/cli/src/main.rs', 'crates/cli/tests/file_query.rs',
    'crates/core/src/knowledge.rs', 'crates/core/src/knowledge/file_query.rs',
    'crates/core/src/knowledge/file_query/tests.rs',
    'crates/core/src/knowledge/ranked_query.rs', 'crates/daemon/src/knowledge.rs',
    'docs/contracts/file-scoped-retrieval-v1.md',
])
h = hashlib.sha256()
for name in paths:
    h.update(name.encode() + b'\0' + Path(name).read_bytes() + b'\0')
print(h.hexdigest())
PY
```

Only owned new files are staged to enable the tracked-file secrets scan; existing
owned modifications remain unstaged. Primary should use the full owned working
tree diff against the merge baseline, not assume the index alone is complete.

## Exclusions / limits

No AJ/native Swift inspection or changes. No native UI/Model, new retrieval consent,
Context/Refine/retained/provider integration, schema/dependency/lockfile, site,
export/marker semantics, recursive discovery, Git source inspection, network
egress, credentials, Docker, installation, deployment or GUI/host launch. Existing
source NOFOLLOW/device/inode/link/FIFO/nested-repository helpers are unchanged and
covered by the full inherited regression gate. New mode does not imply every
product source path is output-filtered. Raw source content is delivered only to
explicit local stdout; no automatic provider transmission or file export.

No implementation subagents or independent review claimed. No remote publication,
exact-head CI, native/GUI runtime or phase acceptance closure claimed.
