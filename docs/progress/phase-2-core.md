# Phase 2 — manual Rust lexical core slice

**Status:** implemented local vertical slice, not Phase 2 completion. The user
explicitly authorized provider-independent Rust work while Phase 1 live-host and
inference gates remain open. No host certification or inference evidence is implied.
Requirements: TM-01–TM-04, TM-07, TM-10; acceptance mapping below follows
[Phase 2](../spec/phase-2-knowledge-core.md).

## Product and ownership

`threadmark --data-dir ABSOLUTE_PATH ...` calls typed synchronous daemon commands,
which call core SQLite/source-policy APIs. This is a manual executable product
path, not a listener or background daemon. Existing version/smoke/contract commands
remain available. No Python experiment, Graphify, provider, credential, Git command,
recursive discovery, service, watcher, telemetry, or runtime network is used.

The new store directory must not already exist; its existing parent must exist.
Store directory mode is 0700, database mode 0600, owner must be the effective user.
Existing unknown/empty databases or directories are not silently adopted. Existing
stores must retain private ownership/modes. Source roots and the store must be
absolute paths without symlink components (use the explicitly approved canonical
path). This Unix implementation was tested on macOS, not certified across hosts.
Store ancestors must be root/effective-user owned and not group/other writable,
apart from trusted-owner sticky directories protecting owned child entries.
macOS positive extended ACL grants are conservatively rejected on every store
ancestor, store directory, database and journal/WAL/SHM sidecar; deny-only ACLs
are permitted. Existing ACLs are never silently removed or repaired.

## Model and migration contract v1

SQLite application ID `0x544d4b31`, user version `1`, 4096-byte pages. Initialization
creates the schema in one transaction. Unknown application IDs, versions (including
forward versions), missing columns/tables, unexpected tables/views/triggers, and
nonstandard page size fail closed. There is no speculative migration or repair.
SQL parameters bind all caller/source values; errors contain no supplied content.
SQLite header identity/version/page size are checked read-only before writable
opening, so a foreign database's hot journal is not recovered before rejection.

| Table | Contract |
| --- | --- |
| `projects` | Unique stable local ID and unique canonical approved root; filesystem device/inode; exact relative source policy; optional SHA-256 content-snapshot identity and manifest. Root/name/ID is not caller authentication or Git identity. |
| `evidence` | Project/path/one-based line key; exact bounded source line, SHA-256 source hash and bounded extractor producer. Every row is observed source text, not a semantic claim or permission. |
| `context` | Project/local ID/revision key; human-authored decision, constraint, correction or pitfall; text and retirement marker. Append-only bounded edit history. Not source truth, executable authority, or authorization. |

Project IDs, root policy, evidence and human context are independent records.
Reindexing replaces only source evidence and the manifest transactionally. Source
policy replacement deletes all active evidence and clears the manifest immediately,
without deleting notes or source files. Notes are inspected separately through
`context list/show`; they are not silently mixed with factual query results.

Rollback-journal mode (`DELETE`) and full synchronous durability are used for this
finite slice, not WAL/background FTS infrastructure. Journal sidecars must also be
private regular owned files; a killed transaction's 0600 journal and recovery are
tested. This is not encrypted storage or forensic erasure; journal/filesystem
recovery, copies, backups and already exported/displayed content have separate
retention limits. No database binary is checked in.

## Scope, freshness, extraction and limits

- At most 64 projects and 64 explicitly approved files per project. Paths are
  relative ASCII components with `.rs`, `.py`, `.md` or `.txt` extensions; absolute,
  traversal, hidden components, duplicate paths and credential-like filenames are
  rejected. A declared file can be absent, but indexing then fails atomically.
- Safe `rustix` descriptor-relative `openat` walks each component with `NOFOLLOW`;
  regular files are opened `NONBLOCK` before metadata validation/bounded reading.
  FIFOs/devices, hardlinks, cross-device descendants and nested `.git` markers are
  rejected. A nested repository requires its own explicitly approved project root.
  Root filesystem identity is rechecked; no check-then-open source symlink window.
- At most 64 KiB per source, 1 MiB total input, 4096 lines/file, 1024 bytes/anchor,
  16384 anchors/project. Non-UTF-8, NUL/binary, oversize or unreadable inputs fail the
  entire index; there is no silent partial replacement.
- `SourceExtractor` receives admitted text and returns resolvable line positions;
  default `LexicalLines` indexes nonempty lines with producer `lexical-lines-v1`.
  No Rust parser, AST, graph or semantic completeness is claimed. Empty output is
  explicitly labeled, with file/anchor counts and no-semantic-coverage labeling.
- Indexing checks the AtomicBool cancellation token before/through reads,
  extraction, SQL insertion and commit. Finite progress stages include
  `ReadyToCommit`; cancellation there rolls back staged output. All source hashes,
  file identities and root identity are rechecked before publication, including
  after SQL staging. Source-policy changes by another process are checked inside
  the transaction. No worker survives return. Cancellation is cooperative: a
  request racing the SQLite commit may coincide with a committed operation, but
  canceled calls do not publish success/output. Process interruption rolls back
  an uncommitted SQLite transaction.
- Query performs bounded source reads/hash checks, not indexing or inference.
  Any mismatch/deletion/rename/unreadability suppresses the entire prior snapshot
  conservatively as `stale-or-unindexed`. `current-at-read` is a read-time statement,
  not a filesystem freeze or claim of unchanged files after response delivery.
  Results contain project, snapshot, root filesystem identity, relative path, line,
  source hash, producer, kind and coverage/currentness. Policy is checked again
  before return. Manual `index` is the only refresh mechanism.
- Lexical case-insensitive substring query: 256 input bytes, eight results and
  8192 encoded JSON bytes. Unicode text is accepted, but SQLite's built-in `lower`
  only supplies ASCII case folding; no language-aware ranking is claimed.
  Deterministic path/line-prefix selection explicitly labels `truncated` when
  matching items exceed the count/byte budget. Selected stored rows must resolve
  again to the exact current file/hash/line/text; malformed rows fail closed.
- Human text arrives on stdin, maximum 4096 bytes, 32 revisions/note and 4096
  revision records/project. SQLite values are bounded at 64 KiB, database size at
  128 MiB; content inspection/listing is bounded and malformed records fail closed.
- OS ownership/private modes are the local store boundary, not protection against
  a malicious process running as the same OS account. SQLite opens its own database
  path; this is not a custom capability VFS or a remote authorization transport.

## Dependencies and license decision

Direct versions are pinned: `rusqlite 0.42.0` (default cache disabled; `bundled` and
`limits` only), `rustix 1.1.6` (`fs`, `process`), `sha2 0.11.1`, `serde 1.0.229`
(`derive`), `serde_json 1.0.154`. Core owns these semantics; CLI/daemon only share
JSON serialization. Bundled `libsqlite3-sys 0.40.0` compiles SQLite **3.54.1** during
the build; it is not a runtime/host installation or handwritten unsafe FFI.
Workspace source continues to forbid unsafe; dependency internals are not claimed
unsafe-free or independently audited.
The macOS-only `exacl 0.13.0` safe interface is required to validate effective ACL
permissions rather than assume mode bits establish privacy. Its added `log`,
`scopeguard` and `uuid` dependencies use MIT-compatible license expressions;
the generated lock selects `uuid 1.29.2`. No ACL command runs in production;
tests set ACLs only on owned synthetic fixtures. Linux uses the POSIX mode mask.

All selected dependency license expressions can use the existing MIT allowance
except `unicode-ident 1.0.27`'s additional Unicode-3.0 table license. Its copyright,
notice/distribution requirement and warranty disclaimer were reviewed; deny policy
adds an exact-package/version exception only. Retain dependency notices (including
Unicode tables and SQLite's public-domain blessing) when packaging/distributing;
no binary redistribution occurs here. Disabling unused rusqlite cache removes the
otherwise-needed Zlib hash dependency; serde 1.0.229 unifies the locked `syn 3`
dependency instead of waiving duplicate versions. Advisory, source and duplicate
version checks remain enabled. Cargo generated the lockfile, never manual edits.

## Acceptance evidence and remaining gates

Synthetic tests are in `crates/core/src/knowledge/tests.rs` and
`crates/cli/tests/knowledge.rs`, in addition to unchanged foundation contracts.

| Acceptance | Evidence in this slice | Still open |
| --- | --- | --- |
| P2-A1 | Separate similarly named registered roots with conflicting facts/notes; durable reopen, no cross-project query or context leakage; no silent root/ID rebinding | Authenticated transport, caches and real host/worktree certification |
| P2-A2 | Edit/delete/rename, same-content inode replacement, foreign-root replacement, unreadability, explicit refresh, source revocation (including during extraction) | Watcher/debounce/overflow/automatic branch detection; Git identity is deliberately not invented |
| P2-A3 | Before/during/after-staging cancellation, injected extractor/anchor failure, actual SQLite insert abort and SQLite-full failure, SIGKILL of an owned child with staged SQL, reopen/recovery; snapshots and human edits survive | Broader platform/power-loss/worker containment tests |
| P2-A4 | Exact source-line/hash/producer/kind provenance, JSON escaping, bounded inspection and honest lexical-only/empty coverage; zero inference requests | Structural/semantic graph extraction and interpretation |
| P2-A5 | Unknown/forward schema rejection without changing database bytes; source policy invalidation never deletes sources | Export, forget/suppression, project removal, future migrations |
| P2-A6 | Fixed local approved-root policy, traversal/symlink/FIFO/hardlink/nested-root negatives, exact file/total/context/query budget tests and real CLI process journey | Full resource/latency measurements and authenticated multi-caller API |

Local verification: `cargo check --workspace`, `cargo test --workspace --locked`,
`cargo clippy --workspace --all-targets --locked -- -D warnings`, and
`cargo deny --locked check` passed during implementation. Full repository check
and staged-file secret scan results are recorded below before handoff.

Tested base HEAD: `ea0da29373536d618a0ac24d915e68a4fbcde1bb`, plus this uncommitted
implementation. No tested implementation commit SHA exists yet: committing is
owned by the primary session. Remote CI run/head: **not run for these uncommitted
changes**. Independent review: **pending primary review**. No post-merge CI claim,
Phase 1 closure, Phase 2 closure, publication, merge or deployment is made here.

## CLI usage (synthetic fixture)

After building, choose an explicit canonical synthetic fixture parent. The store
path below must be new; source root must already exist and contain the approved
synthetic file. No ambient global config or source discovery is consulted.

```sh
threadmark --data-dir "$FIXTURE/new-private-store" project add demo "$FIXTURE/source" main.rs
threadmark --data-dir "$FIXTURE/new-private-store" project list
threadmark --data-dir "$FIXTURE/new-private-store" project show demo
threadmark --data-dir "$FIXTURE/new-private-store" index demo
threadmark --data-dir "$FIXTURE/new-private-store" query demo synthetic_blue
printf '%s\n' 'Synthetic decision: keep the blue variant.' | threadmark --data-dir "$FIXTURE/new-private-store" context add demo variant decision
printf '%s\n' 'Synthetic constraint: only blue for now.' | threadmark --data-dir "$FIXTURE/new-private-store" context update demo variant constraint
threadmark --data-dir "$FIXTURE/new-private-store" context list demo
threadmark --data-dir "$FIXTURE/new-private-store" context show demo variant
threadmark --data-dir "$FIXTURE/new-private-store" context retire demo variant
threadmark --data-dir "$FIXTURE/new-private-store" project sources demo
```

The last command revokes all source-file consent and invalidates active evidence;
it does not delete the source or the separately persisted human note.

Eventual background maintenance, FTS/ranking, typed graph/relationships, semantic
claims, export/forget and management shell remain subsequent product iterations,
not silently completed by this lexical slice.

## Primary review, repairs and runnable verification

Joffrey's initial independent review found three substantive defects: path-based
SQLite access beneath replaceable ancestors, non-atomic project-limit checking,
and a replacement extractor bypassing the per-file input-line cap. Primary added
trusted ancestor validation plus descriptor-relative directory/database creation,
an immediate count/insert transaction, and core-enforced input-line validation.
Regressions cover ancestor permission/swap behavior, concurrent registration at
63 projects and an alternate extractor selecting line 5000.

Primary also revalidated selected persisted query anchors against fresh bytes,
bound the snapshot hash to its manifest, made bounded-result truncation visible,
and rejected foreign/forward SQLite headers before write-open/journal recovery.
The killed-child test covers known recovery and unknown-header byte preservation.
One full-suite attempt found a missing rollback journal; its handshake was
strengthened to assert the journal exists before reporting staged and retain the
stdin writer until after kill/reap, avoiding normal-EOF rollback racing the test.
The focused and subsequent full checks passed; this failed attempt is not hidden.

Joffrey's follow-up found the remaining macOS ACL inheritance hole despite private
mode bits. Primary added safe ACL inspection and a real macOS regression spanning
ancestor inheritance, existing store, database and sidecar grants, including
`healthy()` checks after opening. Two discarded diagnostic approaches were not
used: the protected security xattr returned EPERM, and `/dev/fd` ACL lookup did not
describe the target file. Actual path ACLs are checked from root downward under
the already-validated parent chain; same-account tampering remains outside the
OS-user isolation claim.

Latest full `python3 scripts/check.py` passed formatting, build, strict Clippy,
22 core tests (including foundation contracts), three CLI process tests, five
daemon contract tests, one daemon process test and one core doctest, rustdoc,
finite smoke commands, links and the deliberate-failure gate probe.
`cargo deny --locked check` passed with the generated pinned dependency graph.
The actual CLI integration test registers approved roots, indexes/queries source
evidence, persists/edits/retires user context across processes, invalidates stale
sources and checks content-free failures. No real host/provider, network runtime,
GUI launch, deployment or Docker test was used. Final ACL repair review, staged
secret scan, full tested commit and exact-head remote CI remain publication gates.

Joffrey independently rechecked the final ACL repair with no substantive finding;
his targeted macOS ACL and replaceable-ancestor/descriptor tests passed using
locked offline Cargo. He verified fail-closed ACL errors, trusted traversal,
descriptor-relative creation and pre-open/healthy sidecar validation. Linux and
the final complete suite remain separate evidence, not claimed by that review.

Parallel implementation was actually launched under committed adapter seam
`661bdb3` (cherry-picked into this lane as `5238b2a`): separate T3-managed shell
and provider-neutral refinement worktrees. Their implementation commits are not
claimed integrated or runtime-certified by the tests of this core slice. The
owner's ordering exception is recorded in ADR 0001; Phase 1/live-inference and
full Phase 2–4 acceptance remain open.
