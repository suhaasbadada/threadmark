# Unit AT — selected human revision export

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A5/A6 and P3-A4.
[Frozen contract](../contracts/selected-human-revision-export-v1.md).
Implementation is uncommitted; primary owns integration/review. No native work,
phase closure, PR, push, release or deployment.

## Baseline and ownership

- Started clean at `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Requested `git merge --no-edit 7c84e2c3428879d233c7c42a9ec216ab29c54e42`
  fast-forwarded, no merge commit needed. Full tested HEAD/base:
  `7c84e2c3428879d233c7c42a9ec216ab29c54e42` plus owned working-tree diff.
- Prepared/site ancestor `a61df8e` remains an ancestor (verified locally).
  No resets, switches, extra worktrees, implementation commits or lockfile edits.
- Owned new files: core `knowledge/human_revision_export.rs` and its `tests.rs`;
  CLI `tests/selected_human_revision_export.rs`; contract above; this ledger.
- Owned minimal existing edits: `crates/core/src/knowledge.rs` (exports,
  read-only existing-human-store open, shared cancellable history validator),
  `crates/daemon/src/knowledge.rs` (typed command/read-open/dispatch),
  `crates/cli/src/main.rs` (closed confirmed grammar/bounded stdin/usage).
- No Swift/model/native/CI/site/schema/dependency/lockfile/provider/retained/
  whole-project export algorithm changes. Independent AR work and AS duplicate
  coverage were not inspected or revived.

## Implementation and acceptance evidence

Contract/output fields and stable AT IDs were written before runtime changes.
Immutable owned plan validates/canonicalizes explicit ID/revision pairs before
I/O. Derived closed JSON structs reject escaped duplicate keys and non-integer
revisions. One existing bound-human read transaction admits exact registration
before human SQL, validates all bounded markers, counts scoped persisted rows,
validates whole selected histories once per ID, and extracts only requested rows.
It never resolves latest or filters retirement. A bounded counting serializer
checks complete escaped output once, including LF, before publication. Existing
CLI serializes the completed value once more for stdout (linear, no growing-row
serialization or content writes before success).

The new read-only human-export open preserves WAL; ordinary old opens and source
inspection semantics remain unchanged. Existing common store/schema admission
still checks global non-content registration/source-policy/suppression integrity;
export data selection itself reads only requested project/selected histories.
An early synthetic CLI fixture expecting corrupt persisted policy to pass was
corrected: common v4 admission must remain intact. Already-open core fixtures
prove source drafts/policy/snapshot/root cannot induce source content reads;
real CLI proves missing roots/stale snapshots with valid admitted storage.

Dedicated core tests (11):

- AT-01: owned/canonical same-ID pairs, empty/duplicate/count/ID/revision bounds,
  bool/fraction/exponent/signed/overflow integers, escaped duplicate keys,
  missing/extra keys/frames, inclusive 4096-byte input.
- AT-02: exact old/retired Unicode/CRLF/quotes/controls and provenance, same-ID
  pairs, later append preserves historical bytes, only selected content/reopen.
- AT-03: unselected corrupt row within selected history, gap/duplicate/>32,
  invalid text/kind/retired, missing/future pair, stale suppressed rows,
  4097 persisted rows/markers, source Forget retains human text, human Forget
  survives Build/reopen without resurrection; source bytes preserved.
- AT-04: Unicode-byte root/identity/nonce/project mismatch precedence, missing
  human tables, actual same-root/new-nonce replacement, two WAL connections with
  peer append/retire/Forget after first history chunk (A-only second history),
  namespace replacement refuses publication, source-access counter zero,
  no other-project/unselected-note private text validation.
- AT-05: cancel before/two history chunks/prepublication, permission loss,
  dependency failure and fresh-binding recovery; 65536/LF vs +1 counting boundary,
  eight maximally escaped texts fail whole.

Dedicated real CLI tests (7), also invoking actual typed daemon:

- AT-01/02: closed exact confirmation/flag order, held stdin invalid flags and
  held over-budget body reject promptly; bounded EOF, metadata-only JSON; exact
  canonical old/retired multi-note records and closed provenance envelope.
- AT-03: malformed selected old history, missing/future/cross-project ID,
  suppression fail whole/generic/empty stdout; Forget/Build no resurrection.
- AT-04: read-only WAL CLI with live peer connection succeeds, keeps journal WAL,
  exports explicit A revision rather than later B; absent source root works.
- AT-05: real complete output exactly 65536 UTF-8 bytes INCLUDING LF succeeds;
  65537 fails with empty stdout, no omissions. Unicode/escaped controls preserved.
- AT-06: max eight 64-byte IDs at revision 32, input 4096/+1, bad body status 2
  before absent store, valid absent store no creation, daemon cancel/no-create,
  v3 success and legacy v2 refusal remain byte-identical, isolated DELETE DB+directory entry bytes and
  logical dump/source bytes identical after success/failure; old regressions run
  by full workspace suite. No real user export or private-content log.

## Reproduction and verification

```text
cargo test --offline --locked -p threadmark-core human_revision_export
cargo test --offline --locked -p threadmark-cli --test selected_human_revision_export
CARGO_NET_OFFLINE=true python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
git diff --cached --check
```

New files are staged solely so the tracked-file secret gate covers them; existing
file edits remain unstaged. No implementation commit is made.

### Final local result

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, exit 0; fmt,
  locked workspace build, all-target clippy `-D warnings`, tests, rustdoc
  `-D warnings`, finite CLI/daemon smoke, documentation links and deliberate
  failing-test gate probe. Workspace: **459 passed, 0 failed, 2 ignored**.
  Includes **11 AT core + 7 AT real CLI tests**, and all old export/human reads/
  search/Context/inspection regression tests. No ignored deadline reruns.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources.
- `python3 scripts/secrets.py`: **PASS** after staging new files; tracked-file and
  history scan passed; synthetic sentinel correctly rejected.
- `git diff --check` and `git diff --cached --check`: **PASS**.
- Full-check local log: `unit-at-check.log` (approved harness temporary artifacts,
  not committed), SHA-256
  `5746a82a9d72b31ebfd8d2fbc739be9b7e09a205314e9d68c8b56e17cf61b8b7`.

### Tested owned-file fingerprint

SHA-256 of each tested source/test/contract file (ledger excluded to avoid a
self-referential hash). Aggregate uses sorted relative paths; feed each UTF-8
path, NUL, exact file bytes, NUL to SHA-256:
`cde141dde5689d65bdfdcd95e6c34995c11732a6621cf125f2f4852421f24c75`.

| Owned file | SHA-256 |
| --- | --- |
| `crates/cli/src/main.rs` | `cca50b316eeca9aed8d9a692d871a96b7d4634a1a7b183dc83396ba428c33025` |
| `crates/cli/tests/selected_human_revision_export.rs` | `7cc049ef185bb61047a951cfa1d2bb77e3e288d3b19ff0eb5c815ca7384aed2d` |
| `crates/core/src/knowledge.rs` | `83dd49757eb343542aed4aa9238b9e826f8ce54fceb05efb0d0a9a41d0e6bac4` |
| `crates/core/src/knowledge/human_revision_export.rs` | `e6d584838ea09060a61f1027268e5a37865c79a6b96954aa8f89da724db9f71d` |
| `crates/core/src/knowledge/human_revision_export/tests.rs` | `bea8e1f2b76c9b44892a23c97b5f739ac94f3712c5047915e8a65516030e8dbd` |
| `crates/daemon/src/knowledge.rs` | `6b8c8a6bd26fe27fe74cc4e8cbe732db8b4af15aed9aff51a28dffce10ade62a` |
| `docs/contracts/selected-human-revision-export-v1.md` | `998cefdcd967a625d98d2df2e1df53421995c23cb199b1bcb0c0c8b77bfa6f98` |

## Limits / separate gates

Current-at-read coherent snapshot plus fresh namespace check is NOT an atomic
external revocation lease: post-snapshot append/retire/Forget may not revoke A
text; replacement after the final check or later Forget cannot recall emitted
data. Root bytes/identity/incarnation are guards, not authenticated credentials.
Stored `retired_at_revision` describes that revision, never today's active policy.
Explicit consent authorizes sensitive local stdout only; redirection/sharing is
separate. No native opaque review/filewriter, import/restore, source authority,
network egress, listener, startup, clipboard, provider or forensic erasure claim.

Byte-quiet evidence applies to isolated DELETE fixtures. Read-only SQLite WAL may
touch/create permitted sidecars and peers/checkpoints can change physical files;
logical snapshot consistency, not universal physical byte identity, is promised.
Existing global metadata/schema admission is retained, not bypassed. Independent
review, primary integration and exact-head remote CI have NOT run for this diff;
no CI run/head or review approval is claimed. Both pre-existing ignored deadline
fixtures remain ignored (no `--ignored` run). No Docker/GUI/host launch/subagents.
